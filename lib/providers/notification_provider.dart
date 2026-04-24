// =============================================================================
// notification_provider.dart — 应用内通知系统状态管理
// =============================================================================
// 职责：管理应用内所有通知的增删查改，提供未读数量、按类型筛选等功能。
//
// 通知来源：
//   1. 焦虑预警（shiver / activity）— 由 PetHealthProvider._checkAlerts() 触发
//   2. 喂食记录完成 — 喂食会话结束后自动生成通知
//   3. 健康日志提醒 — 若当天未填写日志，App 前台时提示
//   4. [TODO] FCM 推送 — 远端服务器在检测到异常后主动推送（Firebase Messaging）
//
// 通知类型（NotificationType）：
//   • alert   — 紧急预警（红色，焦虑/颤抖）
//   • feeding — 喂食记录完成（绿色）
//   • journal — 日志提醒（蓝色）
//   • system  — 系统通知（灰色）
//
// 数据持久化：
//   通知列表存储在 Firestore users/{uid}/notifications/{notifId}
//   未读状态通过 Firestore 文档的 read 字段管理
//   登录后自动从 Firestore 加载最近 50 条通知
//
// [TODO: FCM 集成] 在 main.dart 中初始化 firebase_messaging，
//   监听 FirebaseMessaging.onMessage（前台）和 onMessageOpenedApp（后台点击），
//   收到推送后调用 NotificationProvider.addNotification() 即可在通知中心显示。
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/local_notification_service.dart';

// ── 通知类型枚举 ────────────────────────────────────────────────────────────
// 用于通知列表的颜色、图标区分
enum NotificationType {
  alert,   // 紧急预警（红色）
  feeding, // 喂食完成（绿色）
  journal, // 日志提醒（蓝色）
  system,  // 系统通知（灰色）
}

// ── 单条通知数据模型 ─────────────────────────────────────────────────────────
// 不可变数据类，状态变更通过 copyWith 创建新实例
class AppNotification {
  // 通知唯一 ID，格式：notif_{timestamp}_{type}
  final String id;

  // 通知类型，决定图标颜色和排序权重
  final NotificationType type;

  // 通知标题（简短，一行内）
  final String title;

  // 通知正文（可多行，不超过 3 行）
  final String body;

  // 通知产生时间（用于排序和"几分钟前"显示）
  final DateTime createdAt;

  // 是否已读（false = 未读，影响未读数角标和列表样式）
  final bool isRead;

  // 关联操作类型（可选），点击通知后导航到对应页面
  // 例如：'dashboard' | 'pet' | 'shop' | null
  final String? actionRoute;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.actionRoute,
  });

  // ── 从 Firestore 文档反序列化 ────────────────────────────────────────────
  factory AppNotification.fromFirestore(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      type: _parseType(data['type'] as String? ?? 'system'),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['is_read'] as bool? ?? false,
      actionRoute: data['action_route'] as String?,
    );
  }

  // ── 序列化为 Firestore 文档 ──────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,                          // 枚举名称字符串
      'title': title,
      'body': body,
      'created_at': Timestamp.fromDate(createdAt),
      'is_read': isRead,
      'action_route': actionRoute,
    };
  }

  // ── 创建已读版本 ─────────────────────────────────────────────────────────
  AppNotification copyWithRead() {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: true,
      actionRoute: actionRoute,
    );
  }

  // ── 解析类型字符串 ───────────────────────────────────────────────────────
  static NotificationType _parseType(String value) {
    switch (value) {
      case 'alert':   return NotificationType.alert;
      case 'feeding': return NotificationType.feeding;
      case 'journal': return NotificationType.journal;
      default:        return NotificationType.system;
    }
  }
}

// =============================================================================
// NotificationProvider — 通知状态管理
// =============================================================================
class NotificationProvider extends ChangeNotifier {
  // ── 当前用户 ID（登录后设置，退出后清除）──────────────────────────────────
  String? _currentUserId;

  // ── 通知列表（内存缓存，登录后从 Firestore 加载）────────────────────────
  // 按 createdAt 倒序排列（最新的在最前）
  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // ── 未读数量（用于图标角标）─────────────────────────────────────────────
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  // ── 数据加载状态 ─────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Firestore 引用（辅助方法）───────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _notifCollection(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');

  // ── 登录后初始化通知数据 ─────────────────────────────────────────────────
  // 调用时机：MainNavScreen.initState → PetHealthProvider.loadPetForUser() 后调用
  //
  // 业务流程：
  //   1. 保存 userId 供后续操作使用
  //   2. 从 Firestore 加载最近 50 条通知（避免加载过多影响性能）
  //   3. 加载完成后触发 UI 刷新（通知图标角标更新）
  Future<void> loadForUser(String userId) async {
    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      // 简单查询，不加 orderBy 避免 Firestore 复合索引问题
      // 内存中完成排序，数据量（50条）不影响性能
      final snapshot = await _notifCollection(userId).limit(50).get();

      final loaded = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc.data(), doc.id))
          .toList();

      // 按时间倒序（最新通知在顶部）
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _notifications.clear();
      _notifications.addAll(loaded);
    } catch (e) {
      // 加载失败静默处理，显示空通知列表
      // [TODO: 异常处理] 若 Firestore 权限错误，向用户显示提示
      assert(() {
        debugPrint('[NotificationProvider] loadForUser error: $e');
        return true;
      }());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 退出登录时清除数据 ───────────────────────────────────────────────────
  // 防止下一个账号登录时看到上一个账号的通知
  void clearUserData() {
    _currentUserId = null;
    _notifications.clear();
    notifyListeners();
  }

  // ── 添加新通知 ───────────────────────────────────────────────────────────
  // 调用时机：
  //   • 预警触发（PetHealthProvider → addAlert()）
  //   • 喂食记录完成（PetHealthProvider._completeFeedingSession()）
  //   • [TODO] FCM 推送到达（前台时）
  //
  // 策略：
  //   1. 先加入内存列表（UI 立即刷新，用户能看到角标）
  //   2. 异步写入 Firestore（不阻塞 UI）
  //   3. 相同类型通知在 1 分钟内不重复添加（防止频繁触发）
  Future<void> addNotification({
    required NotificationType type,
    required String title,
    required String body,
    String? actionRoute,
  }) async {
    final now = DateTime.now();

    // 防重复：相同标题通知 120 秒内不重复触发
    // 对于 alert 类型，不同 title（shiver/stress/lethargy）算不同通知，允许通过
    // 对于 feeding/system 类型，按 title 去重避免重复记录
    final recentSameTitle = _notifications.where((n) =>
      n.title == title &&
      now.difference(n.createdAt).inSeconds < 120
    );
    if (recentSameTitle.isNotEmpty) return;

    final notif = AppNotification(
      id: 'notif_${now.millisecondsSinceEpoch}_${type.name}',
      type: type,
      title: title,
      body: body,
      createdAt: now,
      actionRoute: actionRoute,
    );

    // 1. 更新内存（立即刷新 UI，角标数字增加）
    _notifications.insert(0, notif);
    if (_notifications.length > 100) {
      // 保持最多 100 条，防止内存无限增长
      _notifications.removeRange(100, _notifications.length);
    }
    notifyListeners();

    // 2. 发送系统级本地推送通知（推送到手机通知栏）
    //    Web 平台会自动 no-op 跳过（LocalNotificationService 内部判断 kIsWeb）
    _fireLocalNotification(type: type, title: title, body: body, actionRoute: actionRoute);

    // 3. 异步写入 Firestore（换手机后历史通知可恢复）
    if (_currentUserId != null) {
      try {
        await _notifCollection(_currentUserId!).doc(notif.id).set(notif.toFirestore());
      } catch (e) {
        assert(() {
          debugPrint('[NotificationProvider] addNotification write error: $e');
          return true;
        }());
      }
    }
  }

  // ── 触发本地系统推送 ─────────────────────────────────────────────────────
  // 根据通知类型选择对应的渠道发送系统通知。
  // 不 await，避免阻塞调用方；内部错误由 LocalNotificationService 捕获。
  // actionRoute='dashboard' 且 type=system 时识别为日报，走报告渠道（安静）。
  void _fireLocalNotification({
    required NotificationType type,
    required String title,
    required String body,
    String? actionRoute,
  }) {
    final svc = LocalNotificationService.instance;
    switch (type) {
      case NotificationType.alert:
        svc.showAlertNotification(title: title, body: body);
        break;
      case NotificationType.feeding:
        svc.showFeedingNotification(title: title, body: body);
        break;
      case NotificationType.system:
        // actionRoute='dashboard' 的系统通知为每日健康日报，使用安静的报告渠道
        if (actionRoute == 'dashboard') {
          svc.showReportNotification(title: title, body: body);
        } else {
          svc.showSystemNotification(title: title, body: body);
        }
        break;
      case NotificationType.journal:
        // 日志提醒走系统通知渠道（低优先级）
        svc.showSystemNotification(title: title, body: body);
        break;
    }
  }

  // ── 标记单条通知为已读 ───────────────────────────────────────────────────
  // 用户点击通知时调用，更新内存和 Firestore
  Future<void> markAsRead(String notifId) async {
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx == -1) return;
    if (_notifications[idx].isRead) return; // 已读则跳过

    // 更新内存（立即反映在角标上）
    _notifications[idx] = _notifications[idx].copyWithRead();
    notifyListeners();

    // 异步更新 Firestore
    if (_currentUserId != null) {
      try {
        await _notifCollection(_currentUserId!).doc(notifId).update({'is_read': true});
      } catch (e) {
        assert(() {
          debugPrint('[NotificationProvider] markAsRead error: $e');
          return true;
        }());
      }
    }
  }

  // ── 标记全部已读 ─────────────────────────────────────────────────────────
  // 用户进入通知中心页面时调用，清除角标
  Future<void> markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    // 批量更新内存
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWithRead();
      }
    }
    notifyListeners();

    // 批量写入 Firestore（用 batch 减少请求次数）
    if (_currentUserId != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final n in unread) {
          final ref = _notifCollection(_currentUserId!).doc(n.id);
          batch.update(ref, {'is_read': true});
        }
        await batch.commit();
      } catch (e) {
        assert(() {
          debugPrint('[NotificationProvider] markAllAsRead error: $e');
          return true;
        }());
      }
    }
  }

  // ── 删除单条通知 ─────────────────────────────────────────────────────────
  // 用户在通知中心左滑删除时调用
  Future<void> deleteNotification(String notifId) async {
    _notifications.removeWhere((n) => n.id == notifId);
    notifyListeners();

    if (_currentUserId != null) {
      try {
        await _notifCollection(_currentUserId!).doc(notifId).delete();
      } catch (e) {
        assert(() {
          debugPrint('[NotificationProvider] deleteNotification error: $e');
          return true;
        }());
      }
    }
  }

  // ── 清除全部通知 ─────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    final ids = _notifications.map((n) => n.id).toList();
    _notifications.clear();
    notifyListeners();

    if (_currentUserId != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in ids) {
          final ref = _notifCollection(_currentUserId!).doc(id);
          batch.delete(ref);
        }
        await batch.commit();
      } catch (e) {
        assert(() {
          debugPrint('[NotificationProvider] clearAll error: $e');
          return true;
        }());
      }
    }
  }

  // ── 通知类型的本地化标签（用于通知列表标签显示）─────────────────────────
  static String typeLabel(NotificationType type, bool isZh) {
    switch (type) {
      case NotificationType.alert:   return isZh ? '紧急预警' : 'Alert';
      case NotificationType.feeding: return isZh ? '喂食记录' : 'Feeding';
      case NotificationType.journal: return isZh ? '日志提醒' : 'Journal';
      case NotificationType.system:  return isZh ? '系统通知' : 'System';
    }
  }

  // ── 通知类型对应的颜色 ───────────────────────────────────────────────────
  static Color typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.alert:   return const Color(0xFFE53935); // 红色
      case NotificationType.feeding: return const Color(0xFF43A047); // 绿色
      case NotificationType.journal: return const Color(0xFF1E88E5); // 蓝色
      case NotificationType.system:  return const Color(0xFF757575); // 灰色
    }
  }

  // ── 通知类型对应的图标 ───────────────────────────────────────────────────
  static IconData typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.alert:   return Icons.warning_rounded;
      case NotificationType.feeding: return Icons.restaurant_rounded;
      case NotificationType.journal: return Icons.edit_note_rounded;
      case NotificationType.system:  return Icons.info_outline_rounded;
    }
  }

  // ── 时间显示格式（几分钟前 / 几小时前 / 日期）──────────────────────────
  static String timeAgo(DateTime time, bool isZh) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) {
      return isZh ? '刚刚' : 'Just now';
    } else if (diff.inMinutes < 60) {
      return isZh ? '${diff.inMinutes} 分钟前' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return isZh ? '${diff.inHours} 小时前' : '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return isZh ? '${diff.inDays} 天前' : '${diff.inDays}d ago';
    } else {
      // 超过 7 天显示具体日期
      return '${time.month}/${time.day}';
    }
  }
}
