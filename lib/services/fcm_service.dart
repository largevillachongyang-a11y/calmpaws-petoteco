// =============================================================================
// fcm_service.dart — FCM 注册与推送接收（最终对接 P1）
// =============================================================================

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';
import '../firebase_options.dart';
import 'fcm_sw_register.dart';
import 'fcm_web_token_stub.dart'
    if (dart.library.html) 'fcm_web_token_web.dart';
import 'user_device_api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  _fcmLog('后台消息：${message.notification?.title}');
}

typedef FcmPushHandler = void Function({
  required String title,
  required String body,
  String? type,
});

void _fcmLog(String message) {
  if (!EnvironmentConfig.debugMode) return;
  // release Web 预览也输出，便于 DevTools 联调
  print('[FCM] $message');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _userApi = UserDeviceApiService();
  bool _initialized = false;
  bool _webSupported = true;
  String? _lastRegisteredToken;
  String? _lastRegisterError;
  DateTime? _lastRegisterAt;

  FcmPushHandler? onPushReceived;

  bool get isInitialized => _initialized;
  String? get lastRegisteredToken => _lastRegisteredToken;
  String? get lastRegisterError => _lastRegisterError;
  DateTime? get lastRegisterAt => _lastRegisterAt;

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        _webSupported = await FirebaseMessaging.instance.isSupported();
        if (!_webSupported) {
          _lastRegisterError = '当前浏览器不支持 FCM';
          _fcmLog('浏览器不支持 FCM');
          return;
        }
        await registerFcmServiceWorkerIfNeeded();
      } else {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      final messaging = FirebaseMessaging.instance;

      if (!kIsWeb) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      } catch (e) {
        _fcmLog('onMessage 监听失败：$e');
      }

      if (!kIsWeb) {
        try {
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);
          final initial = await messaging.getInitialMessage();
          if (initial != null) _dispatchMessage(initial);
        } catch (e) {
          _fcmLog('onMessageOpenedApp/getInitialMessage 失败：$e');
        }

        messaging.onTokenRefresh.listen((token) {
          unawaited(registerTokenIfLoggedIn(forcedToken: token));
        });
      }

      _initialized = true;
      _fcmLog('初始化完成');
    } catch (e) {
      _lastRegisterError = 'FCM init: $e';
      _fcmLog('初始化失败：$e');
    }
  }

  Future<void> registerTokenIfLoggedIn({String? forcedToken}) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    // Web 预览：FCM 子路径 + compat SDK 仍不稳定，先跳过以免闪退；移动端不受影响
    if (kIsWeb) {
      _fcmLog('Web 预览暂跳过 FCM（不影响登录与 Dashboard）');
      return;
    }
    if (!_initialized) await init();

    try {
      String? token = forcedToken;
      token ??= await _fetchToken();
      if (token == null || token.isEmpty) {
        _lastRegisterError ??= kIsWeb
            ? 'Web 无法获取 FCM token（检查 SW / 通知权限）'
            : '无法获取 FCM token';
        _fcmLog('跳过 register_fcm：$_lastRegisterError');
        return;
      }

      _fcmLog('正在 POST register_fcm…');
      await _userApi.registerFcmToken(token);
      _lastRegisteredToken = token;
      _lastRegisterError = null;
      _lastRegisterAt = DateTime.now();
      _fcmLog('已注册 token（${token.substring(0, 12)}…）');
    } catch (e) {
      _lastRegisterError = e.toString();
      _fcmLog('register 失败：$e');
    }
  }

  Future<String?> _fetchToken() async {
    final messaging = FirebaseMessaging.instance;
    if (kIsWeb) {
      final vapid = EnvironmentConfig.fcmWebVapidKey;
      if (vapid.isEmpty) {
        _lastRegisterError = '未配置 fcmWebVapidKey';
        return null;
      }

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _fcmLog('通知权限：${settings.authorizationStatus}');

      final allowed = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        _lastRegisterError = '浏览器未授权通知权限';
        return null;
      }

      await registerFcmServiceWorkerIfNeeded();

      final token = await fetchWebFcmToken(vapid);
      if (token != null && token.isNotEmpty) return token;
      _lastRegisterError = 'Web getToken 返回空';
      return null;
    }
    return messaging.getToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _dispatchMessage(message);
  }

  void _handleOpenedApp(RemoteMessage message) {
    _dispatchMessage(message);
  }

  void _dispatchMessage(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'CalmPaws';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        '';
    final type = message.data['type'] as String?;

    onPushReceived?.call(title: title, body: body, type: type);
    _fcmLog('收到推送：$title — $body');
  }
}
