// =============================================================================
// server_api_service.dart — 真实服务器 HTTP 轮询服务
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment_config.dart';
import '../models/history_models.dart';
import '../models/models.dart';

class ServerApiService {
  static final ServerApiService _instance = ServerApiService._internal();
  factory ServerApiService() => _instance;
  ServerApiService._internal();

  String _baseUrl = EnvironmentConfig.baseUrl;
  String _deviceId = EnvironmentConfig.testDeviceId;
  static const int _pollIntervalSeconds = 2;

  String get baseUrl => _baseUrl;
  String get deviceId => _deviceId;

  bool _isRunning = false;
  bool _deviceOnline = false;
  String _connectionStatus = 'disconnected';
  DateTime? _lastPacketTime;
  int _lastPacketTimestamp = 0;

  void Function(int sleepNoRollSec, double? lastRollTime, String sleepState, int continuousCalmSec)? onSleepStateReceived;
  /// /api/status 返回 204（暂无新缓存）时通知 UI
  void Function()? onStatus204;

  bool get isRunning => _isRunning;
  bool get deviceOnline => _deviceOnline;
  String get connectionStatus => _connectionStatus;
  DateTime? get lastPacketTime => _lastPacketTime;

  Timer? _pollTimer;
  Timer? _appOnlineTimer;
  final StreamController<BlePacket> _controller =
      StreamController<BlePacket>.broadcast();

  Stream<BlePacket> get stream => _controller.stream;

  Uri _uri(String path, {Map<String, String>? queryParameters}) =>
      EnvironmentConfig.apiUri(
        path,
        baseUrlOverride: _baseUrl,
        queryParameters: queryParameters,
      );

  Future<void> configure({
    required String baseUrl,
    required String deviceId,
  }) async {
    _baseUrl = EnvironmentConfig.normalizeBaseUrl(baseUrl);
    _deviceId = deviceId.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_url', _baseUrl);
    await prefs.setString('server_device_id', _deviceId);

    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[ServerAPI] 配置已更新：$_baseUrl / $_deviceId');
    }
  }

  Future<void> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_base_url') ?? EnvironmentConfig.baseUrl;
    _deviceId = prefs.getString('server_device_id') ?? EnvironmentConfig.testDeviceId;
    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[ServerAPI] 加载已保存配置：$_baseUrl / $_deviceId');
    }
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _connectionStatus = 'connecting';

    await loadSavedConfig();
    await notifyAppOnline();
    await _poll();

    _pollTimer = Timer.periodic(
      const Duration(seconds: _pollIntervalSeconds),
      (_) => _poll(),
    );

    _appOnlineTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => notifyAppOnline(),
    );

    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[ServerAPI] 已启动轮询：$_baseUrl');
    }
  }

  void stop() {
    _pollTimer?.cancel();
    _appOnlineTimer?.cancel();
    _pollTimer = null;
    _appOnlineTimer = null;
    _isRunning = false;
    _deviceOnline = false;
    _connectionStatus = 'disconnected';
    if (EnvironmentConfig.debugMode && kDebugMode) debugPrint('[ServerAPI] 已停止');
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> notifyAppOnline() async {
    try {
      final resp = await http.post(
        _uri('/api/app_online'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': _deviceId}),
      ).timeout(EnvironmentConfig.requestTimeout);

      if (resp.statusCode == 200 && EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] APP在线通知成功');
      }
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] APP在线通知失败：$e');
      }
    }
  }

  Future<void> _poll() async {
    try {
      final resp = await http.get(
        _uri('/api/status/$_deviceId'),
      ).timeout(EnvironmentConfig.requestTimeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
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
          final sleepNoRollSec = (data['sleep_no_roll_sec'] as num?)?.toInt() ?? 0;
          final lastRollTime = (data['last_roll_time'] as num?)?.toDouble();
          final sleepState = (data['sleep_state'] as String?) ?? 'unknown';
          final continuousCalmSec = (data['continuous_calm_sec'] as num?)?.toInt() ?? 0;
          onSleepStateReceived?.call(sleepNoRollSec, lastRollTime, sleepState, continuousCalmSec);
          _controller.add(packet);
          if (EnvironmentConfig.debugMode && kDebugMode) {
            debugPrint('[ServerAPI] 收到数据包：anxiety=${packet.anxietyScore} strC=${packet.strC} shivD=${packet.shivD} paceD=${packet.paceD} bat=${packet.battery}%');
          }
        }
      } else if (resp.statusCode == 204) {
        _connectionStatus = 'connected';
        onStatus204?.call();
        if (EnvironmentConfig.debugMode && kDebugMode) {
          debugPrint('[ServerAPI] 204 暂无新数据');
        }
      } else {
        _setError('HTTP ${resp.statusCode}');
      }
    } on TimeoutException {
      _setError('请求超时');
    } catch (e) {
      _setError('连接失败：$e');
    }
  }

  BlePacket? _parsePacket(Map<String, dynamic> data) {
    try {
      return BlePacket(
        timestamp: _parseInt(data['timestamp']) ??
            (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        strC: _parseInt(data['str_c']) ?? 0,
        strD: _parseDouble(data['str_d']) ?? 0.0,
        shivC: _parseInt(data['shiv_c']) ?? 0,
        shivD: _parseDouble(data['shiv_d']) ?? 0.0,
        paceD: _parseDouble(data['pace_d']) ?? 0.0,
        playD: _parseDouble(data['play_d']) ?? 0.0,
        rollC: _parseInt(data['roll_c']) ?? 0,
        battery: _parseInt(data['battery']) ?? 100,
        rssi: _parseInt(data['rssi']) ?? -70,
        anxietyScore: (_parseDouble(data['anxiety_score']) ?? 0.0).clamp(0.0, 100.0),
        serverLabel: data['label'] as String?,
      );
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] 解析数据包失败：$e  data=$data');
      }
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
    if (EnvironmentConfig.debugMode && kDebugMode) debugPrint('[ServerAPI] 错误：$msg');
  }

  /// 拉取历史曲线数据（24h / 7d / 30d）。
  /// /api/history 正常返回 200（含空 points）；网络/解析失败返回带 error 的空响应。
  Future<HistoryResponse> fetchHistory(
    String range, {
    int? from,
    int? to,
  }) async {
    assert(HistoryRange.all.contains(range), 'range must be 24h, 7d or 30d');

    final query = <String, String>{'range': range};
    if (from != null) query['from'] = from.toString();
    if (to != null) query['to'] = to.toString();

    try {
      final resp = await http
          .get(_uri('/api/history/$_deviceId', queryParameters: query))
          .timeout(EnvironmentConfig.requestTimeout);

      if (resp.statusCode == 200) {
        if (resp.body.isEmpty) {
          return HistoryResponse.empty(_deviceId, range);
        }
        final data = jsonDecode(resp.body);
        if (data is! Map<String, dynamic>) {
          return HistoryResponse.error(_deviceId, range, '响应格式无效');
        }
        final parsed = HistoryResponse.fromJson(data, range: range);
        if (EnvironmentConfig.debugMode && kDebugMode) {
          debugPrint('[ServerAPI] fetchHistory $range：${parsed.points.length} 点 '
              'online_minutes=${parsed.summary.onlineMinutes}');
        }
        return parsed;
      }

      if (resp.statusCode == 204) {
        return HistoryResponse.empty(_deviceId, range);
      }

      return HistoryResponse.error(
        _deviceId,
        range,
        'HTTP ${resp.statusCode}',
      );
    } on TimeoutException {
      return HistoryResponse.error(_deviceId, range, '请求超时');
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] fetchHistory $range 失败：$e');
      }
      return HistoryResponse.error(_deviceId, range, '连接失败：$e');
    }
  }

  Future<Map<String, dynamic>?> fetchAlerts() async {
    try {
      final resp = await http.get(
        _uri('/api/alerts/$_deviceId'),
      ).timeout(EnvironmentConfig.requestTimeout);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] fetchAlerts 失败：$e');
      }
    }
    return null;
  }

  Future<bool> healthCheck() async {
    try {
      final resp = await http.get(
        _uri('/api/health'),
      ).timeout(EnvironmentConfig.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetDevice() async {
    try {
      final resp = await http.post(
        _uri('/api/reset/$_deviceId'),
      ).timeout(EnvironmentConfig.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> setSpecies(String species) async {
    try {
      final resp = await http.post(
        _uri('/api/set_species'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'species': species,
        }),
      ).timeout(EnvironmentConfig.requestTimeout);

      if (resp.statusCode == 200) {
        if (EnvironmentConfig.debugMode && kDebugMode) {
          final body = jsonDecode(resp.body);
          debugPrint('[ServerAPI] set_species 成功：species=$species '
              'sample_rate=${body['sample_rate']}');
        }
        return null;
      } else {
        final msg = 'set_species 失败：HTTP ${resp.statusCode}';
        if (EnvironmentConfig.debugMode && kDebugMode) debugPrint('[ServerAPI] $msg');
        return msg;
      }
    } on TimeoutException {
      const msg = 'set_species 超时';
      if (EnvironmentConfig.debugMode && kDebugMode) debugPrint('[ServerAPI] $msg');
      return msg;
    } catch (e) {
      final msg = 'set_species 异常：$e';
      if (EnvironmentConfig.debugMode && kDebugMode) debugPrint('[ServerAPI] $msg');
      return msg;
    }
  }
}
