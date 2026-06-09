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
import 'user_device_api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    debugPrint('[FCM] 后台消息：${message.notification?.title}');
  }
}

typedef FcmPushHandler = void Function({
  required String title,
  required String body,
  String? type,
});

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _userApi = UserDeviceApiService();
  bool _initialized = false;
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
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      if (!kIsWeb) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _dispatchMessage(initial);
      }

      messaging.onTokenRefresh.listen((token) {
        unawaited(registerTokenIfLoggedIn(forcedToken: token));
      });

      _initialized = true;
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[FCM] 初始化完成');
      }
    } catch (e) {
      _lastRegisterError = 'FCM init: $e';
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[FCM] 初始化失败：$e');
      }
    }
  }

  Future<void> registerTokenIfLoggedIn({String? forcedToken}) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (!_initialized) await init();

    try {
      String? token = forcedToken;
      token ??= await _fetchToken();
      if (token == null || token.isEmpty) {
        _lastRegisterError = kIsWeb
            ? 'Web 端需配置 fcmWebVapidKey 才能获取 FCM token'
            : '无法获取 FCM token';
        return;
      }

      await _userApi.registerFcmToken(token);
      _lastRegisteredToken = token;
      _lastRegisterError = null;
      _lastRegisterAt = DateTime.now();
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[FCM] 已注册 token（${token.substring(0, 12)}…）');
      }
    } catch (e) {
      _lastRegisterError = e.toString();
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[FCM] register 失败：$e');
      }
    }
  }

  Future<String?> _fetchToken() async {
    final messaging = FirebaseMessaging.instance;
    if (kIsWeb) {
      final vapid = EnvironmentConfig.fcmWebVapidKey;
      if (vapid.isEmpty) return null;
      return messaging.getToken(vapidKey: vapid);
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

    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[FCM] 收到推送：$title — $body');
    }
  }
}
