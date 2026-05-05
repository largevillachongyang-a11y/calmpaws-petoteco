// =============================================================================
// wifi_config_service.dart — 服务器地址配置与连接管理
// =============================================================================
// 职责：
//   管理服务器IP地址的配置和持久化，提供连接测试功能。
//   （BLE配网由固件的CalmPaws_Config蓝牙设备处理，本服务管理APP侧的服务器地址）
//
// 使用场景：
//   1. 用户在设置页面输入服务器IP地址
//   2. APP启动时自动加载并连接服务器
//   3. 测试服务器连通性
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_api_service.dart';

class WifiConfigService {
  static final WifiConfigService _instance = WifiConfigService._internal();
  factory WifiConfigService() => _instance;
  WifiConfigService._internal();

  static const String _kServerUrl  = 'server_base_url';
  static const String _kDeviceId   = 'server_device_id';

  // 默认值（与固件 SERVER_DEFAULT 保持一致）
  static const String kDefaultServerUrl  = 'http://10.217.248.160:5000';
  static const String kDefaultDeviceId   = 'collar_001';

  String _serverUrl = kDefaultServerUrl;
  String _deviceId  = kDefaultDeviceId;

  String get serverUrl => _serverUrl;
  String get deviceId  => _deviceId;

  /// APP启动时调用，加载持久化的服务器配置
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_kServerUrl) ?? kDefaultServerUrl;
    _deviceId  = prefs.getString(_kDeviceId)  ?? kDefaultDeviceId;
    if (kDebugMode) debugPrint('[WifiConfig] 已加载配置：$_serverUrl / $_deviceId');
  }

  /// 保存服务器配置并更新 ServerApiService
  Future<bool> saveConfig({
    required String serverUrl,
    required String deviceId,
  }) async {
    final url = serverUrl.trim().replaceAll(RegExp(r'/$'), '');
    final id  = deviceId.trim();

    if (url.isEmpty || id.isEmpty) return false;

    // 先测试连通性
    final api = ServerApiService();
    await api.configure(baseUrl: url, deviceId: id);
    final ok = await api.healthCheck();

    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kServerUrl, url);
      await prefs.setString(_kDeviceId,  id);
      _serverUrl = url;
      _deviceId  = id;
      if (kDebugMode) debugPrint('[WifiConfig] 配置已保存：$url / $id');
    } else {
      if (kDebugMode) debugPrint('[WifiConfig] 服务器无法连接：$url');
    }
    return ok;
  }

  /// 强制保存（不做连接测试，适用于浏览器环境）
  Future<void> forceSave({
    required String serverUrl,
    required String deviceId,
  }) async {
    final url = serverUrl.trim().replaceAll(RegExp(r'/$'), '');
    final id  = deviceId.trim();
    if (url.isEmpty || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrl, url);
    await prefs.setString(_kDeviceId,  id);
    _serverUrl = url;
    _deviceId  = id;
    if (kDebugMode) debugPrint('[WifiConfig] 强制保存配置：$url / $id');
  }

  /// 测试服务器连通性（不保存）
  Future<bool> testConnection(String serverUrl) async {
    try {
      final api = ServerApiService();
      await api.configure(baseUrl: serverUrl, deviceId: _deviceId);
      return await api.healthCheck();
    } catch (_) {
      return false;
    }
  }

  /// 重置为默认配置
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kServerUrl);
    await prefs.remove(_kDeviceId);
    _serverUrl = kDefaultServerUrl;
    _deviceId  = kDefaultDeviceId;
    final api = ServerApiService();
    await api.configure(baseUrl: _serverUrl, deviceId: _deviceId);
  }
}
