// =============================================================================
// local_notification_service.dart — 本地系统推送通知服务
// =============================================================================
// 职责：封装 flutter_local_notifications 的初始化、权限请求、发送通知。
//
// 通知渠道（Android）：
//   • calm_paws_alerts  — 紧急预警（高优先级，响铃+震动）
//   • calm_paws_feeding — 喂食记录（普通优先级）
//   • calm_paws_reports — 日报推送（普通优先级，安静）
//   • calm_paws_system  — 系统通知（低优先级）
//
// 使用方式：
//   1. 在 main() 中调用 LocalNotificationService.instance.init()
//   2. 在 NotificationProvider.addNotification() 中调用 showNotification()
//   3. 权限状态可通过 isGranted getter 检查
//
// 平台说明：
//   Web 平台不支持本地推送（浏览器 Notification API 需额外处理），
//   在 kIsWeb == true 时所有操作 no-op 静默跳过。
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── 通知渠道 ID 常量 ─────────────────────────────────────────────────────────
const String _kChannelAlerts  = 'calm_paws_alerts';
const String _kChannelFeeding = 'calm_paws_feeding';
const String _kChannelReports = 'calm_paws_reports';
const String _kChannelSystem  = 'calm_paws_system';

// ── 通知 ID 分配规则（避免覆盖） ───────────────────────────────────────────
// alert: 1000-1999 | feeding: 2000-2999 | report: 3000 | system: 4000-4999
const int _kIdBaseAlert   = 1000;
const int _kIdBaseFeeding = 2000;
const int _kIdReport      = 3000;
const int _kIdBaseSystem  = 4000;

/// 本地推送通知服务单例
///
/// 生命周期：
///   init() → [showNotification() 多次] → dispose()（可选）
class LocalNotificationService {
  LocalNotificationService._internal();

  /// 全局单例
  static final LocalNotificationService instance =
      LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 权限是否已授予（Android 13+ / iOS 需要动态请求）
  bool _isGranted = false;

  // 是否已完成初始化
  bool _initialized = false;

  // 用于生成递增通知 ID（防止同类型通知互相覆盖）
  int _alertIdCounter   = _kIdBaseAlert;
  int _feedingIdCounter = _kIdBaseFeeding;
  int _systemIdCounter  = _kIdBaseSystem;

  // ────────────────────────────────────────────────────────────────────────
  // 公开 Getter
  // ────────────────────────────────────────────────────────────────────────

  /// 系统通知权限是否已授予
  bool get isGranted => _isGranted;

  /// 是否已完成初始化
  bool get isInitialized => _initialized;

  // ────────────────────────────────────────────────────────────────────────
  // 初始化
  // ────────────────────────────────────────────────────────────────────────

  /// 初始化本地推送服务。
  ///
  /// 在 main() 的 runApp 前调用，确保渠道在 Android 8+ 上正确创建。
  /// Web 平台自动 no-op。
  Future<void> init() async {
    // Web 不支持本地推送，静默跳过
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // ── Android 初始化设置 ──────────────────────────────────────────────
    // @mipmap/ic_launcher 是 Flutter 默认图标；
    // 正式上线可替换为专用通知图标（单色、透明背景 PNG，存放在 mipmap-* 目录）
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ── iOS/macOS 初始化设置 ────────────────────────────────────────────
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,  // 不在初始化时自动弹权限，由 requestPermission() 控制
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      // 通知点击回调（应用前台时）
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 创建 Android 通知渠道
    await _createAndroidChannels();

    _initialized = true;

    assert(() {
      debugPrint('[LocalNotificationService] initialized');
      return true;
    }());
  }

  // ────────────────────────────────────────────────────────────────────────
  // 权限请求
  // ────────────────────────────────────────────────────────────────────────

  /// 请求系统通知权限（Android 13+ / iOS 必须）。
  ///
  /// 返回 true 表示用户授予权限，false 表示拒绝。
  /// 应在应用启动后（非首屏）调用，避免太早打扰用户。
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    bool granted = false;

    // Android 13+ (API 33) 需要 POST_NOTIFICATIONS 权限
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final result = await androidPlugin.requestNotificationsPermission();
      granted = result ?? false;
    }

    // iOS 权限请求
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = result ?? false;
    }

    _isGranted = granted;

    assert(() {
      debugPrint('[LocalNotificationService] permission granted: $granted');
      return true;
    }());

    return granted;
  }

  // ────────────────────────────────────────────────────────────────────────
  // 发送通知
  // ────────────────────────────────────────────────────────────────────────

  /// 发送预警通知（高优先级，响铃+震动）。
  ///
  /// 用于：颤抖预警、频繁应激、长时间踱步、嗜睡预警。
  Future<void> showAlertNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    final id = _alertIdCounter++;
    // 限制 alert ID 范围在 1000-1999
    if (_alertIdCounter >= _kIdBaseFeeding) _alertIdCounter = _kIdBaseAlert;

    await _show(
      id: id,
      title: title,
      body: body,
      channelId: _kChannelAlerts,
      priority: Priority.high,
      importance: Importance.high,
    );
  }

  /// 发送喂食完成通知（普通优先级）。
  Future<void> showFeedingNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    final id = _feedingIdCounter++;
    if (_feedingIdCounter >= _kIdReport) _feedingIdCounter = _kIdBaseFeeding;

    await _show(
      id: id,
      title: title,
      body: body,
      channelId: _kChannelFeeding,
      priority: Priority.defaultPriority,
      importance: Importance.defaultImportance,
    );
  }

  /// 发送每日报告通知（安静，不响铃）。
  Future<void> showReportNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    await _show(
      id: _kIdReport,  // 日报固定 ID，新日报覆盖旧日报
      title: title,
      body: body,
      channelId: _kChannelReports,
      priority: Priority.low,
      importance: Importance.low,
    );
  }

  /// 发送系统通知（最低优先级）。
  Future<void> showSystemNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    final id = _systemIdCounter++;
    if (_systemIdCounter >= 5000) _systemIdCounter = _kIdBaseSystem;

    await _show(
      id: id,
      title: title,
      body: body,
      channelId: _kChannelSystem,
      priority: Priority.min,
      importance: Importance.min,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // 私有方法
  // ────────────────────────────────────────────────────────────────────────

  /// 统一发送通知（内部方法）。
  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required Priority priority,
    required Importance importance,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _channelName(channelId),
        channelDescription: _channelDescription(channelId),
        importance: importance,
        priority: priority,
        // 使用 App 默认图标；正式上线可改为专用通知图标
        icon: '@mipmap/ic_launcher',
        // 高优先级通知在 Android 10+ 显示横幅（heads-up notification）
        fullScreenIntent: channelId == _kChannelAlerts,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(id, title, body, details);

    } catch (e) {
      assert(() {
        debugPrint('[LocalNotificationService] show error: $e');
        return true;
      }());
    }
  }

  /// 创建 Android 通知渠道（Android 8.0+ 必须）。
  Future<void> _createAndroidChannels() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // 预警渠道（高优先级）
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelAlerts,
        '宠物预警',
        description: '颤抖、频繁应激、踱步、嗜睡等紧急预警通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // 喂食渠道（普通）
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelFeeding,
        '喂食记录',
        description: '喂食会话完成时的记录通知',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    // 日报渠道（安静）
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelReports,
        '每日健康报告',
        description: '每晚 20:00 的宠物健康日报',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    // 系统渠道（最低）
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelSystem,
        '系统通知',
        description: '应用系统级通知',
        importance: Importance.min,
        playSound: false,
      ),
    );
  }

  /// 通知渠道名称（用于 Android 设置界面显示）。
  String _channelName(String channelId) {
    switch (channelId) {
      case _kChannelAlerts:  return '宠物预警';
      case _kChannelFeeding: return '喂食记录';
      case _kChannelReports: return '每日健康报告';
      default:               return '系统通知';
    }
  }

  /// 通知渠道描述。
  String _channelDescription(String channelId) {
    switch (channelId) {
      case _kChannelAlerts:  return '颤抖、频繁应激、踱步、嗜睡等紧急预警通知';
      case _kChannelFeeding: return '喂食会话完成时的记录通知';
      case _kChannelReports: return '每晚 20:00 的宠物健康日报';
      default:               return '应用系统级通知';
    }
  }

  /// 通知点击回调（应用前台/后台唤醒时）。
  void _onNotificationTap(NotificationResponse response) {
    // 目前仅打印日志；后续可根据 payload 路由到对应页面
    assert(() {
      debugPrint(
        '[LocalNotificationService] tapped: id=${response.id}, '
        'payload=${response.payload}',
      );
      return true;
    }());
  }
}
