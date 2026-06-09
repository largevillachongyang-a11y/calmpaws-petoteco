// =============================================================================
// user_device_api_service.dart — 用户设备绑定 API
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';
import '../models/bound_device.dart';
import 'api_exception.dart';
import 'auth_api_helper.dart';

class UserDeviceApiService {
  static final UserDeviceApiService _instance = UserDeviceApiService._internal();
  factory UserDeviceApiService() => _instance;
  UserDeviceApiService._internal();

  final _auth = AuthApiHelper.instance;

  Future<List<BoundDevice>> fetchDevices() async {
    final resp = await _auth.get(
      _auth.uri('/api/user/devices'),
      signOutOn401: false,
    );
    if (resp.statusCode != 200) {
      throw ApiException.fromStatus(resp.statusCode, body: resp.body);
    }
    if (resp.body.isEmpty) return [];
    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) return [];
    final raw = data['devices'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BoundDevice.fromJson)
        .where((d) => d.deviceId.isNotEmpty)
        .toList();
  }

  Future<void> bindDevice({
    required String deviceId,
    required String deviceKey,
  }) async {
    final resp = await _auth.post(
      _auth.uri('/api/user/bind_device'),
      body: {
        'device_id': deviceId.trim(),
        'device_key': deviceKey.trim(),
      },
      retryOn401: true,
    );
    if (resp.statusCode == 200) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[UserDeviceAPI] 绑定成功：$deviceId');
      }
      return;
    }
    throw ApiException.fromStatus(resp.statusCode, body: resp.body);
  }

  Future<void> unbindDevice(String deviceId) async {
    final resp = await _auth.post(
      _auth.uri('/api/user/unbind_device'),
      body: {'device_id': deviceId.trim()},
    );
    if (resp.statusCode == 200) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[UserDeviceAPI] 解绑成功：$deviceId');
      }
      return;
    }
    throw ApiException.fromStatus(resp.statusCode, body: resp.body);
  }

  /// 注册 FCM 推送 token（登录后 / token 刷新时调用）。
  Future<void> registerFcmToken(String fcmToken) async {
    final resp = await _auth.post(
      _auth.uri('/api/user/register_fcm'),
      body: {
        'fcm_token': fcmToken,
        'device_type': _deviceType(),
      },
    );
    if (resp.statusCode == 200) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[UserDeviceAPI] FCM token 已注册');
      }
      return;
    }
    throw ApiException.fromStatus(resp.statusCode, body: resp.body);
  }

  String _deviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'web';
    }
  }
}
