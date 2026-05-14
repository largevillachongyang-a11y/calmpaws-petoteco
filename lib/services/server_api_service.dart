// =============================================================================
// server_api_service.dart — 真实服务器 HTTP 轮询服务
// =============================================================================
// 职责：
//   替代 MockBleService，通过 HTTP 每5秒轮询服务器 /api/status/<device_id>
//   获取真实项圈数据（BlePacket），以 Stream 形式推送给 PetHealthProvider。
//
// 架构说明：
//   ┌─────────────────────────────────────────────────┐
//   │  ServerApiService (本文件)                       │
//   │  ─────────────────────────────────────────────  │
//   │  • pollStatus()：每5秒 GET /api/status/{id}     │
//   │  • notifyAppOnline()：通知服务器APP在线          │
//   │  • stream → BlePacket（累计值，差值由上层算）    │
//   └─────────────────────────────────────────────────┘
//
// 服务器 API 说明（对应 server.py）：
//   GET  /api/status/<device_id>   → 返回最新 BlePacket JSON 或 204
//   POST /api/app_online           → 通知服务器APP在线（切换实时模式5s间隔）
//   GET  /api/alerts/<device_id>   → 获取低电量等告警信息
//   GET  /api/health               → 健康检查
//
// 使用方式：
//   final svc = ServerApiService();
//   svc.configure(baseUrl: 'http://10.217.248.160:5000', deviceId: 'collar_001');
//   svc.start();
//   svc.stream.listen((packet) { ... });
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ServerApiService {
  static final ServerApiService _instance = ServerApiService._internal();
  factory ServerApiService() => _instance;
  ServerApiService._internal();

  // ── 配置 ──────────────────────────────────────────────────────────────────
  String _baseUrl  = 'https://api.myvideotest2026.top';  // 公网服务器HTTPS
  String _deviceId = 'collar_001';
  static const int _pollIntervalSeconds = 2;
  static const Duration _httpTimeout = Duration(seconds: 4);

  String get baseUrl  => _baseUrl;
  String get deviceId => _deviceId;

  // ── 状态 ──────────────────────────────────────────────────────────────────
  bool _isRunning = false;
  bool _deviceOnline = false;
  String _connectionStatus = 'disconnected'; // disconnected / connecting / connected / error
  DateTime? _lastPacketTime;
  int _lastPacketTimestamp = 0;  // 上次处理的包的timestamp，用于去重

  // ── 睡眠状态回调（B方案：服务器持久化，重连可恢复）────────────────────────
  // Provider注册此回调，每次收到新包时同步服务器睡眠计时到Provider
  void Function(int sleepNoRollSec, double? lastRollTime, String sleepState, int continuousCalmSec)? onSleepStateReceived;

  bool get isRunning        => _isRunning;
  bool get deviceOnline     => _deviceOnline;
  String get connectionStatus => _connectionStatus;
  DateTime? get lastPacketTime => _lastPacketTime;

  // ── Stream ─────────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  Timer? _appOnlineTimer;
  final StreamController<BlePacket> _controller =
      StreamController<BlePacket>.broadcast();

  Stream<BlePacket> get stream => _controller.stream;

  // ── 配置方法 ───────────────────────────────────────────────────────────────

  /// 配置服务器地址和设备ID，并持久化到 SharedPreferences
  Future<void> configure({
    required String baseUrl,
    required String deviceId,
  }) async {
    _baseUrl  = baseUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    _deviceId = deviceId.trim();

    // 持久化配置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_url',  _baseUrl);
    await prefs.setString('server_device_id', _deviceId);

    if (kDebugMode) debugPrint('[ServerAPI] 配置已更新：$_baseUrl / $_deviceId');
  }

  /// 从 SharedPreferences 加载已保存的配置
  Future<void> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl  = prefs.getString('server_base_url')  ?? _baseUrl;
    _deviceId = prefs.getString('server_device_id') ?? _deviceId;
    if (kDebugMode) debugPrint('[ServerAPI] 加载已保存配置：$_baseUrl / $_deviceId');
  }

  // ── 启动/停止 ──────────────────────────────────────────────────────────────

  /// 启动轮询（先通知服务器APP在线，再开始轮询）
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _connectionStatus = 'connecting';

    await loadSavedConfig();

    // 立即通知服务器APP在线（让项圈切换到5s实时模式）
    await notifyAppOnline();

    // 立即轮询一次
    await _poll();

    // 每5秒轮询一次
    _pollTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (_) => _poll(),
    );

    // 每30秒再次通知服务器APP在线（防止服务器超时切换回60s模式）
    _appOnlineTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => notifyAppOnline(),
    );

    if (kDebugMode) debugPrint('[ServerAPI] 已启动轮询：$_baseUrl');
  }

  void stop() {
    _pollTimer?.cancel();
    _appOnlineTimer?.cancel();
    _pollTimer = null;
    _appOnlineTimer = null;
    _isRunning = false;
    _deviceOnline = false;
    _connectionStatus = 'disconnected';
    if (kDebugMode) debugPrint('[ServerAPI] 已停止');
  }

  void dispose() {
    stop();
    _controller.close();
  }

  // ── 核心 API 方法 ──────────────────────────────────────────────────────────

  /// 通知服务器 APP 已在线（服务器收到后将项圈上传间隔切换为5s）
  Future<void> notifyAppOnline() async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/app_online'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': _deviceId}),
      ).timeout(_httpTimeout);

      if (resp.statusCode == 200) {
        if (kDebugMode) debugPrint('[ServerAPI] APP在线通知成功');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ServerAPI] APP在线通知失败：$e');
    }
  }

  /// 轮询最新设备状态
  Future<void> _poll() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/status/$_deviceId'),
      ).timeout(_httpTimeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
        // 跳过重复包（项圈5秒上传一次，APP轮询更快，避免同一包触发多次差值计算）
        if (ts > 0 && ts == _lastPacketTimestamp) {
          _connectionStatus = 'connected';
          return;
        }
        final packet = _parsePacket(data);
        if (packet != null) {
          _deviceOnline = true;
          _connectionStatus = 'connected';
          _lastPacketTime = DateTime.now();
          if (ts > 0) _lastPacketTimestamp = ts;
          // 解析并回传睡眠状态（B方案）
          final sleepNoRollSec    = (data['sleep_no_roll_sec']   as num?)?.toInt() ?? 0;
          final lastRollTime      = (data['last_roll_time']      as num?)?.toDouble();
          final sleepState        = (data['sleep_state']   as String?) ?? 'unknown';
          final continuousCalmSec = (data['continuous_calm_sec'] as num?)?.toInt() ?? 0;
          onSleepStateReceived?.call(sleepNoRollSec, lastRollTime, sleepState, continuousCalmSec);
          _controller.add(packet);
          if (kDebugMode) {
            debugPrint('[ServerAPI] 收到数据包：strC=${packet.strC} shivD=${packet.shivD} paceD=${packet.paceD} bat=${packet.battery}%');
          }
        }
      } else if (resp.statusCode == 204) {
        // 204 = 服务器在线但项圈暂无新数据（正常，继续等待）
        _connectionStatus = 'connected';
        if (kDebugMode) debugPrint('[ServerAPI] 204 暂无新数据');
      } else {
        _setError('HTTP ${resp.statusCode}');
      }
    } on TimeoutException {
      _setError('请求超时');
    } catch (e) {
      _setError('连接失败：$e');
    }
  }

  /// 解析服务器返回的 JSON → BlePacket
  /// 服务器 server.py 输出格式：
  /// {
  ///   "timestamp": 1700000000,
  ///   "str_c": 2, "str_d": 15,
  ///   "shiv_c": 0, "shiv_d": 0,
  ///   "pace_d": 10, "play_d": 5,
  ///   "roll_c": 1, "battery": 82,
  ///   "label": "calm", "confidence": 0.87,
  ///   "uncertainty": false
  /// }
  BlePacket? _parsePacket(Map<String, dynamic> data) {
    try {
      return BlePacket(
        timestamp: _parseInt(data['timestamp']) ?? 
                   (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        strC:  _parseInt(data['str_c'])   ?? 0,
        strD:  _parseDouble(data['str_d']) ?? 0.0,   // 服务器返回float如4.5，不能截断
        shivC: _parseInt(data['shiv_c'])   ?? 0,
        shivD: _parseDouble(data['shiv_d']) ?? 0.0,  // 服务器返回float
        paceD: _parseDouble(data['pace_d']) ?? 0.0,  // 关键：3.5s截成3会导致paceD>3判断失败
        playD: _parseDouble(data['play_d']) ?? 0.0,  // 服务器返回float
        rollC: _parseInt(data['roll_c'])   ?? 0,
        battery: _parseInt(data['battery']) ?? 100,
        rssi: _parseInt(data['rssi']) ?? -70,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ServerAPI] 解析数据包失败：$e  data=$data');
      return null;
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// 解析服务器返回的 float 字段（str_d / shiv_d / pace_d / play_d）
  /// 服务器 algorithm.py 用 round(x, 1) 返回如 4.5、3.5 等小数
  /// 不能用 _parseInt 否则 3.5 → 3，导致 paceD > 3 判断失败
  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _setError(String msg) {
    _deviceOnline = false;
    _connectionStatus = 'error';
    if (kDebugMode) debugPrint('[ServerAPI] 错误：$msg');
  }

  // ── 辅助 API ──────────────────────────────────────────────────────────────

  /// 获取低电量等告警信息
  Future<Map<String, dynamic>?> fetchAlerts() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/alerts/$_deviceId'),
      ).timeout(_httpTimeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ServerAPI] fetchAlerts 失败：$e');
    }
    return null;
  }

  /// 健康检查（用于测试服务器连通性）
  Future<bool> healthCheck() async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/health'),
      ).timeout(_httpTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 重置设备算法状态（调试用）
  Future<bool> resetDevice() async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/reset/$_deviceId'),
      ).timeout(_httpTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 物种设置 ───────────────────────────────────────────────────────────────

  /// 通知服务器当前宠物物种，服务器据此下发对应的 sample_rate
  ///
  /// POST /api/set_species
  /// Body: { "device_id": "collar_001", "species": "cat" | "dog" }
  /// 成功返回 { "status": "ok", "species": "cat", "sample_rate": 26 }
  ///
  /// 物种 → 采样率对应关系（V7.10 固件）：
  ///   dog → 104 Hz（ISM330DHCX 高频模式，适合跑步/跳跃等大幅运动）
  ///   cat →  26 Hz（ISM330DHCX 低频模式，猫咪步态分析）
  ///
  /// 返回值：
  ///   null → 请求成功
  ///   String → 错误描述（网络失败 / 服务器返回非 200）
  Future<String?> setSpecies(String species) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/set_species'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'species': species,
        }),
      ).timeout(_httpTimeout);

      if (resp.statusCode == 200) {
        if (kDebugMode) {
          final body = jsonDecode(resp.body);
          debugPrint('[ServerAPI] set_species 成功：species=$species '
              'sample_rate=${body['sample_rate']}');
        }
        return null; // 成功
      } else {
        final msg = 'set_species 失败：HTTP ${resp.statusCode}';
        if (kDebugMode) debugPrint('[ServerAPI] $msg');
        return msg;
      }
    } on TimeoutException {
      const msg = 'set_species 超时';
      if (kDebugMode) debugPrint('[ServerAPI] $msg');
      return msg;
    } catch (e) {
      final msg = 'set_species 异常：$e';
      if (kDebugMode) debugPrint('[ServerAPI] $msg');
      return msg;
    }
  }
}
