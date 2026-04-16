// =============================================================================
// firestore_service.dart — Firestore 数据持久化服务层
// =============================================================================
// 职责：封装所有 Firestore 读写操作，向 PetHealthProvider 提供统一接口。
// UI 层和 Provider 层不直接调用 FirebaseFirestore SDK，只调用本服务。
//
// Firestore 数据结构（路径设计）：
//   users/
//     {uid}/                          ← 每个用户一个文档（存用户级配置）
//       feeding_sessions/             ← 子集合：喂食记录
//         {sessionId}                 ← 一次喂食会话
//       journal_entries/              ← 子集合：健康日志
//         {entryId}                   ← 一条日志
//       daily_stress/                 ← 子集合：每日压力数据
//         {yyyy-MM-dd}                ← 以日期字符串为文档 ID，方便按日期查询
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
import '../models/models.dart';
import '../services/mock_ble_service.dart' show DailyStressDataPoint;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 集合路径辅助方法 ─────────────────────────────────────────────────────────
  // 集中管理路径字符串，避免散落在各方法中拼写错误

  /// 喂食记录子集合引用
  CollectionReference<Map<String, dynamic>> _feedingSessions(String uid) =>
      _db.collection('users').doc(uid).collection('feeding_sessions');

  /// 健康日志子集合引用
  CollectionReference<Map<String, dynamic>> _journalEntries(String uid) =>
      _db.collection('users').doc(uid).collection('journal_entries');

  /// 每日压力数据子集合引用
  CollectionReference<Map<String, dynamic>> _dailyStress(String uid) =>
      _db.collection('users').doc(uid).collection('daily_stress');

  // =============================================================================
  // 宠物档案（PetProfile）P0-1：换机不丢宠物档案
  // =============================================================================

  /// 保存宠物档案到 Firestore
  /// 调用时机：用户在宠物页面编辑并保存宠物信息后
  /// 路径：users/{uid}/pet_profile（顶层文档，避免子集合规则问题）
  /// 返回值：true = 写入成功，false = 写入失败（可让调用方显示提示）
  Future<bool> savePetProfile(String uid, PetProfile pet) async {
    try {
      // 使用顶层路径 users/{uid}/pet_profile，规则更简单：
      //   match /users/{uid}/pet_profile { allow read, write: if request.auth.uid == uid; }
      await _db.collection('users').doc(uid)
          .collection('pet_profile').doc('main').set({
        'pet_id':   pet.id,
        'name':     pet.name,
        'species':  pet.species,
        'breed':    pet.breed,
        'age_months': pet.ageMonths,
        'weight_kg':  pet.weightKg,
        'health_tags': pet.healthTags,
        'created_at': Timestamp.fromDate(pet.createdAt),
        'updated_at': FieldValue.serverTimestamp(),
        'owner_uid': uid, // 冗余字段，方便规则调试
      }, SetOptions(merge: true));
      debugFirestore('savePetProfile OK: uid=$uid name=${pet.name}');
      return true;
    } catch (e) {
      debugFirestore('savePetProfile FAILED: $e');
      return false;
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
      healthTags: List<String>.from(d['health_tags'] ?? []),
      createdAt:  (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // =============================================================================
  // 喂食记录（FeedingSession）
  // =============================================================================

  /// 保存一条喂食记录到 Firestore
  ///
  /// 调用时机：
  ///   • 用户点击「已喂食」按钮，会话结束（_completeFeedingSession）后调用
  ///   • 不在会话进行中实时保存，避免频繁写入
  ///
  /// [API 需求] Firestore 文档结构：
  ///   {
  ///     "feed_time": Timestamp,           ← 喂食时间
  ///     "time_to_calm": int | null,       ← 平静用时（秒），进行中为 null
  ///     "stress_before": int | null,      ← 喂食前压力计数
  ///     "stress_after": int | null,       ← 喂食后压力计数
  ///     "created_at": Timestamp           ← 文档创建时间（用于排序）
  ///   }
  ///
  /// [TODO: 异常处理] 写入失败时（如断网），Firestore 会离线缓存并在恢复后自动重试。
  ///   如需明确提示用户"保存失败"，捕获异常并返回错误状态。
  Future<void> saveFeedingSession(String uid, FeedingSession session) async {
    try {
      await _feedingSessions(uid).doc(session.id).set({
        'feed_time': Timestamp.fromDate(session.feedTime),
        'time_to_calm': session.timeToCalm,
        'stress_before': session.stressCountBefore,
        'stress_after': session.stressCountAfter,
        // SERVER_TIMESTAMP 由 Firestore 服务端填写，确保时间一致性
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // 静默失败：不影响 UI，下次网络恢复后重试
      // [TODO: 异常处理] 如需用户感知，向上抛出异常并在 UI 显示 SnackBar
      debugFirestore('saveFeedingSession error: $e');
    }
  }

  /// 加载最近 N 条喂食记录
  ///
  /// 调用时机：用户登录后，MainNavScreen.initState 间接触发
  ///
  /// 排序策略：按 feed_time 倒序取前 limit 条，在内存中完成，无需复合索引
  ///
  /// [API 需求] 返回格式同 saveFeedingSession 的文档结构
  /// [TODO: 异常处理] 若 Firestore 规则拒绝访问（未登录/规则配置错误），
  ///   会抛出 permission-denied 异常，调用方需处理
  Future<List<FeedingSession>> loadFeedingSessions(String uid,
      {int limit = 30}) async {
    try {
      // 简单查询，不加 orderBy，避免触发 Firestore 复合索引要求
      final snapshot = await _feedingSessions(uid).limit(limit * 2).get();

      final sessions = snapshot.docs.map((doc) {
        final d = doc.data();
        return FeedingSession(
          id: doc.id,
          // Timestamp → DateTime 转换，处理 null 情况
          feedTime: (d['feed_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
          timeToCalm: d['time_to_calm'] as int?,
          stressCountBefore: d['stress_before'] as int?,
          stressCountAfter: d['stress_after'] as int?,
        );
      }).toList();

      // 内存排序：按喂食时间倒序（最新的在最前）
      sessions.sort((a, b) => b.feedTime.compareTo(a.feedTime));

      // 截取所需数量
      return sessions.take(limit).toList();
    } catch (e) {
      debugFirestore('loadFeedingSessions error: $e');
      return []; // 加载失败返回空列表，UI 显示"暂无记录"
    }
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
  ///     "negative_flags": List<String>, ← 异常标记，触发商城推荐逻辑
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
  // 每日压力数据（DailyStressDataPoint）
  // =============================================================================

  /// 保存/更新一个每日压力数据点
  ///
  /// 调用时机：
  ///   • 每天结束时（或 App 退出前）保存当天汇总数据
  ///   • 使用 set with merge:true，允许当天多次更新（如当天重新喂食后更新数据）
  ///
  /// 文档 ID 使用 'yyyy-MM-dd' 格式，方便按日期精确查询，无需额外索引
  ///
  /// [API 需求] Firestore 文档结构：
  ///   {
  ///     "day_index": int,              ← 相对今天的天数偏移（0=今天，-1=昨天...）
  ///     "stress_score": double,        ← 当天平均压力分 0-100
  ///     "is_after_treatment": bool,    ← 当天是否使用了 ZenBelly 产品
  ///     "label": String,               ← 显示标签（"Mon", "Tue" 等）
  ///     "date": Timestamp,             ← 实际日期（用于精确时间范围查询）
  ///     "updated_at": Timestamp
  ///   }
  Future<void> saveDailyStressPoint(
      String uid, DailyStressDataPoint point, DateTime date) async {
    try {
      // 以 'yyyy-MM-dd' 作为文档 ID，同一天多次调用只会更新不会重复创建
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _dailyStress(uid).doc(dateStr).set({
        'day_index': point.dayIndex,
        'stress_score': point.stressScore,
        'is_after_treatment': point.isAfterTreatment,
        'label': point.label,
        'date': Timestamp.fromDate(date),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge:true 避免覆盖同一天已有数据
    } catch (e) {
      debugFirestore('saveDailyStressPoint error: $e');
    }
  }

  /// 加载最近 N 天的压力数据
  ///
  /// 调用时机：用户登录后，用于渲染 Dashboard 压力趋势图
  ///
  /// 排序策略：不使用 orderBy 避免 Firestore 复合索引错误，
  ///   改为加载所有数据后在内存中按 dayIndex 排序（数据量小，性能不是瓶颈）
  /// 返回值按 dayIndex 升序排列（图表从左到右 = 最旧到最新）
  Future<List<DailyStressDataPoint>> loadDailyStressPoints(String uid,
      {int days = 14}) async {
    try {
      // 不加 orderBy，避免触发 Firestore 单字段索引之外的复合索引要求
      final snapshot =
          await _dailyStress(uid).limit(days * 2).get();

      final points = snapshot.docs.map((doc) {
        final d = doc.data();
        return DailyStressDataPoint(
          dayIndex: (d['day_index'] as num?)?.toInt() ?? 0,
          stressScore: (d['stress_score'] as num?)?.toDouble() ?? 0.0,
          isAfterTreatment: (d['is_after_treatment'] as bool?) ?? false,
          label: (d['label'] as String?) ?? '',
        );
      }).toList();

      // 按 dayIndex 升序（图表左边是最旧的数据）
      points.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
      return points;
    } catch (e) {
      debugFirestore('loadDailyStressPoints error: $e');
      return [];
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
