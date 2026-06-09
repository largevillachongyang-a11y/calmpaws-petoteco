// =============================================================================
// firestore_service.dart — Firestore 数据持久化服务层
// =============================================================================
// 职责：封装所有 Firestore 读写操作，向 PetHealthProvider 提供统一接口。
// UI 层和 Provider 层不直接调用 FirebaseFirestore SDK，只调用本服务。
//
// Firestore 数据结构（路径设计）：
//   users/
//     {uid}/                          ← 每个用户一个文档（存用户级配置）
//       journal_entries/              ← 子集合：健康日志
//         {entryId}                   ← 一条日志
//
// 为什么按 uid 分路径而不是在文档里加 userId 字段？
//   • Firestore 安全规则可以直接用 request.auth.uid == userId 路径匹配
//   • 无需复合索引即可实现用户数据隔离
//   • 符合 Firestore 官方推荐的多租户数据模式
//
// 查询策略（避免复合索引）：
//   • 只用单字段 where 或直接按 ID 读取，避免 where + orderBy 组合
//   • 排序统一在内存中完成（数据量小，性能不是瓶颈）
//
// [TODO: 异常处理] 断网时 Firestore SDK 会自动使用本地缓存（离线模式），
//   但写操作会进入队列，恢复联网后自动同步。
//   当前不做额外断网提示，依赖 SDK 默认行为。
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:typed_data';
import '../models/models.dart';
import '../utils/image_data_url.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 集合路径辅助方法 ─────────────────────────────────────────────────────────
  // 集中管理路径字符串，避免散落在各方法中拼写错误

  /// 健康日志子集合引用
  CollectionReference<Map<String, dynamic>> _journalEntries(String uid) =>
      _db.collection('users').doc(uid).collection('journal_entries');

  // =============================================================================
  // 宠物档案（PetProfile）P0-1：换机不丢宠物档案
  // =============================================================================

  /// 保存宠物档案到 Firestore
  /// 调用时机：用户在宠物页面编辑并保存宠物信息后
  /// 路径：users/{uid}/pet_profile（顶层文档，避免子集合规则问题）
  /// 返回值：true = 写入成功，false = 写入失败（可让调用方显示提示）
  /// 保存宠物档案到 Firestore
  /// 返回 null = 成功；返回字符串 = 失败原因（用于 UI 展示）
  Future<String?> savePetProfile(String uid, PetProfile pet) async {
    try {
      await _db.collection('users').doc(uid)
          .collection('pet_profile').doc('main').set({
        'pet_id':   pet.id,
        'name':     pet.name,
        'species':  pet.species,
        'breed':    pet.breed,
        'age_months': pet.ageMonths,
        'weight_kg':  pet.weightKg,
        'health_tags': pet.healthTags,
        'photo_url':  pet.photoPath ?? '',
        'created_at': Timestamp.fromDate(pet.createdAt),
        'updated_at': FieldValue.serverTimestamp(),
        'owner_uid': uid,
      }, SetOptions(merge: true));
      debugFirestore('savePetProfile OK: uid=$uid name=${pet.name}');
      return null; // null = 成功
    } catch (e) {
      final msg = e.toString();
      debugFirestore('savePetProfile FAILED: $msg');
      // 识别常见错误类型，返回用户友好信息
      if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
        return 'permission-denied';
      } else if (msg.contains('unavailable') || msg.contains('network')) {
        return 'network-error';
      } else if (msg.contains('unauthenticated') || msg.contains('UNAUTHENTICATED')) {
        return 'unauthenticated';
      }
      return 'unknown: $msg';
    }
  }

  /// 从 Firestore 加载宠物档案（换机恢复）
  /// 先尝试新路径 pet_profile，再 fallback 旧路径 pet/profile
  Future<PetProfile?> loadPetProfile(String uid) async {
    // ── 先尝试新路径 ──────────────────────────────────────────────────
    try {
      final doc = await _db.collection('users').doc(uid)
          .collection('pet_profile').doc('main').get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        debugFirestore('loadPetProfile OK (new path): ${d['name']}');
        return _petFromMap(d, uid);
      }
    } catch (e) {
      debugFirestore('loadPetProfile new-path error: $e');
    }

    // ── fallback：旧路径（兼容已有数据）──────────────────────────────
    try {
      final doc = await _db.collection('users').doc(uid)
          .collection('pet').doc('profile').get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        debugFirestore('loadPetProfile OK (legacy path): ${d['name']}');
        return _petFromMap(d, uid);
      }
    } catch (e) {
      debugFirestore('loadPetProfile legacy-path error: $e');
    }

    debugFirestore('loadPetProfile: no data found for uid=$uid');
    return null;
  }

  PetProfile _petFromMap(Map<String, dynamic> d, String uid) {
    return PetProfile(
      id:         (d['pet_id']   as String?) ?? 'pet_$uid',
      name:       (d['name']     as String?) ?? '',
      species:    (d['species']  as String?) ?? 'dog',
      breed:      (d['breed']    as String?) ?? '',
      ageMonths:  (d['age_months'] as num?)?.toInt() ?? 0,
      weightKg:   (d['weight_kg']  as num?)?.toDouble() ?? 0.0,
      photoPath:  (d['photo_url']  as String?)?.isNotEmpty == true
                      ? d['photo_url'] as String
                      : null,
      healthTags: List<String>.from(d['health_tags'] ?? []),
      createdAt:  (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // =============================================================================
  // 头像上传（Web 用 Firestore data URL，App 用 Firebase Storage）
  // =============================================================================

  static const int _maxDataUrlPhotoBytes = 700 * 1024;

  String _photoAsDataUrl(List<int> imageBytes) {
    if (imageBytes.length > _maxDataUrlPhotoBytes) {
      throw Exception('image-too-large-for-firestore');
    }
    return bytesToJpegDataUrl(imageBytes);
  }

  bool _shouldUseDataUrlFallback(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('cors') ||
        msg.contains('404') ||
        msg.contains('network') ||
        msg.contains('failed to fetch') ||
        msg.contains('storage');
  }

  /// 宠物头像：Web / Storage 失败时写入 data URL（绕过 Storage CORS）
  Future<String> uploadPetPhoto(String uid, List<int> imageBytes) async {
    if (kIsWeb) {
      final dataUrl = _photoAsDataUrl(imageBytes);
      debugFirestore('uploadPetPhoto (web data URL) len=${dataUrl.length}');
      return dataUrl;
    }
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('pet_photos')
          .child(uid)
          .child('avatar.jpg');
      final uploadTask = ref.putData(
        Uint8List.fromList(imageBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugFirestore('uploadPetPhoto OK: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('uploadPetPhoto Storage failed, fallback data URL: $e');
      if (_shouldUseDataUrlFallback(e)) {
        return _photoAsDataUrl(imageBytes);
      }
      rethrow;
    }
  }

  /// 用户资料头像（存 users/{uid}.user_photo_url）
  Future<String> saveUserPhoto(String uid, List<int> imageBytes) async {
    final dataUrl = _photoAsDataUrl(imageBytes);
    await _db.collection('users').doc(uid).set(
      {'user_photo_url': dataUrl, 'updated_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    debugFirestore('saveUserPhoto OK: uid=$uid len=${dataUrl.length}');
    return dataUrl;
  }

  Future<String?> loadUserPhotoUrl(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final url = doc.data()?['user_photo_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      debugFirestore('loadUserPhotoUrl error: $e');
    }
    return null;
  }

  // =============================================================================
  // 健康日志（JournalEntry）
  // =============================================================================

  /// 保存一条健康日志到 Firestore
  ///
  /// 调用时机：用户在 Dashboard「快速记录」卡片填写并提交后立即调用
  ///
  /// [API 需求] Firestore 文档结构：
  ///   {
  ///     "date": Timestamp,              ← 记录日期
  ///     "stool_emoji": String,          ← 大便状态 emoji
  ///     "mood_emoji": String,           ← 情绪状态 emoji
  ///     "appetite_emoji": String,       ← 食欲状态 emoji
  ///     "energy_emoji": String,         ← 精力状态 emoji
  ///     "notes": String | null,         ← 文字备注
  ///     "negative_flags": string list,  ← 异常标记，触发商城推荐逻辑
  ///     "created_at": Timestamp
  ///   }
  Future<void> saveJournalEntry(String uid, JournalEntry entry) async {
    try {
      await _journalEntries(uid).doc(entry.id).set({
        'date': Timestamp.fromDate(entry.date),
        'stool_emoji': entry.stoolEmoji,
        'mood_emoji': entry.moodEmoji,
        'appetite_emoji': entry.appetiteEmoji,
        'energy_emoji': entry.energyEmoji,
        'notes': entry.notes,
        'negative_flags': entry.negativeFlags,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugFirestore('saveJournalEntry error: $e');
    }
  }

  /// 加载最近 N 条健康日志
  ///
  /// 调用时机：用户登录后自动加载，宠物页面健康日历需要这些数据
  Future<List<JournalEntry>> loadJournalEntries(String uid,
      {int limit = 60}) async {
    try {
      final snapshot = await _journalEntries(uid).limit(limit * 2).get();

      final entries = snapshot.docs.map((doc) {
        final d = doc.data();
        return JournalEntry(
          id: doc.id,
          date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
          stoolEmoji: (d['stool_emoji'] as String?) ?? '💩',
          moodEmoji: (d['mood_emoji'] as String?) ?? '😊',
          appetiteEmoji: (d['appetite_emoji'] as String?) ?? '🍖',
          energyEmoji: (d['energy_emoji'] as String?) ?? '⚡',
          notes: d['notes'] as String?,
          // Firestore 存的是 List<dynamic>，需要转成 List<String>
          negativeFlags: List<String>.from(d['negative_flags'] ?? []),
        );
      }).toList();

      // 内存排序：按记录日期倒序
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries.take(limit).toList();
    } catch (e) {
      debugFirestore('loadJournalEntries error: $e');
      return [];
    }
  }

  // =============================================================================
  // 离线数据补传
  // =============================================================================

  /// 将单条离线差值包写入 Firestore（SYNC流程调用）
  /// 路径：users/{uid}/offline_packets/{dateStr}_{timestamp}
  Future<void> saveDailyOfflinePacket({
    required String userId,
    required String dateStr,
    required dynamic packet, // BlePacket
  }) async {
    try {
      final col = _db
          .collection('users')
          .doc(userId)
          .collection('offline_packets');
      await col.doc('${dateStr}_${packet.timestamp}').set({
        'date': dateStr,
        'timestamp': packet.timestamp,
        'str_c':  packet.strC,
        'str_d':  packet.strD,
        'shiv_c': packet.shivC,
        'shiv_d': packet.shivD,
        'pace_d': packet.paceD,
        'play_d': packet.playD,
        'roll_c': packet.rollC,
        'synced_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugFirestore('saveDailyOfflinePacket error: $e');
    }
  }

  // =============================================================================
  // 工具方法
  // =============================================================================

  /// 开发调试日志（生产环境不输出）
  /// 避免在生产代码中直接使用 print()
  void debugFirestore(String message) {
    // ignore: avoid_print
    assert(() {
      // ignore: avoid_print
      print('[FirestoreService] $message');
      return true;
    }());
  }
}
