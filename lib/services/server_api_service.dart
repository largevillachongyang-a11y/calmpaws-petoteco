// =============================================================================
// server_api_service.dart — 真实服务器 HTTP 轮询服务（Bearer 鉴权）
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment_config.dart';
import '../models/history_models.dart';
import '../models/models.dart';
import '../models/server_alert.dart';
import 'api_exception.dart';
import 'auth_api_helper.dart';

class ServerApiService {
  static final ServerApiService _instance = ServerApiService._internal();
  factory ServerApiService() => _instance;
  ServerApiService._internal();

  final _auth = AuthApiHelper.instance;

  String _baseUrl = EnvironmentConfig.baseUrl;
  String _deviceId = '';
  static const int _pollIntervalSeconds = 2;

  String get baseUrl => _baseUrl;
  String get deviceId => _deviceId;
  bool get hasDeviceId => _deviceId.isNotEmpty;

  bool _isRunning = false;
  bool _deviceOnline = false;
  String _connectionStatus = 'disconnected';
  DateTime? _lastPacketTime;
  int _lastPacketTimestamp = 0;
  String? _lastErrorMessage;

  void Function(int sleepNoRollSec, double? lastRollTime, String sleepState,
      int continuousCalmSec)? onSleepStateReceived;
  void Function()? onStatus204;
  void Function(int statusCode)? onHttpError;

  bool get isRunning => _isRunning;
  bool get deviceOnline => _deviceOnline;
  String get connectionStatus => _connectionStatus;
  DateTime? get lastPacketTime => _lastPacketTime;
  String? get lastErrorMessage => _lastErrorMessage;

  Timer? _pollTimer;
  Timer? _appOnlineTimer;
  final StreamController<BlePacket> _controller =
      StreamController<BlePacket>.broadcast();

  Stream<BlePacket> get stream => _controller.stream;

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
    _deviceId = prefs.getString('server_device_id') ?? '';
    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[ServerAPI] 加载已保存配置：$_baseUrl / $_deviceId');
    }
  }

  Future<void> start() async {
    if (_isRunning) return;
    if (_deviceId.isEmpty) {
      await loadSavedConfig();
    }
    if (_deviceId.isEmpty) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] 未设置 device_id，跳过启动');
      }
      return;
    }
    _isRunning = true;
    _connectionStatus = 'connecting';

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
      debugPrint('[ServerAPI] 已启动轮询：$_baseUrl / $_deviceId');
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
    _lastErrorMessage = null;
    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[ServerAPI] 已停止');
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> notifyAppOnline() async {
    if (_deviceId.isEmpty) return;
    try {
      final resp = await _auth.post(
        _auth.uri('/api/app_online', baseUrlOverride: _baseUrl),
        body: {'device_id': _deviceId},
        signOutOn401: false,
      );
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
    if (_deviceId.isEmpty) return;
    try {
      final resp = await _auth.get(
        _auth.uri('/api/status/$_deviceId', baseUrlOverride: _baseUrl),
        signOutOn401: false,
      );

      if (resp.statusCode == 200) {
        _lastErrorMessage = null;
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
          final sleepNoRollSec =
              (data['sleep_no_roll_sec'] as num?)?.toInt() ?? 0;
          final lastRollTime = (data['last_roll_time'] as num?)?.toDouble();
          final sleepState = (data['sleep_state'] as String?) ?? 'unknown';
          final continuousCalmSec =
              (data['continuous_calm_sec'] as num?)?.toInt() ?? 0;
          onSleepStateReceived?.call(
              sleepNoRollSec, lastRollTime, sleepState, continuousCalmSec);
          _controller.add(packet);
          if (EnvironmentConfig.debugMode && kDebugMode) {
            debugPrint(
                '[ServerAPI] 收到数据包：anxiety=${packet.anxietyScore} bat=${packet.battery}%');
          }
        }
      } else if (resp.statusCode == 204) {
        _connectionStatus = 'connected';
        _lastErrorMessage = null;
        onStatus204?.call();
        if (EnvironmentConfig.debugMode && kDebugMode) {
          debugPrint('[ServerAPI] 204 暂无新数据');
        }
      } else if (resp.statusCode == 403) {
        _setError('forbidden', '无权访问此设备');
        onHttpError?.call(403);
      } else {
        _setError('error', 'HTTP ${resp.statusCode}');
        onHttpError?.call(resp.statusCode);
      }
    } on TimeoutException {
      _setError('error', '请求超时');
    } on ApiException catch (e) {
      _setError('error', e.message);
    } catch (e) {
      _setError('error', '连接失败：$e');
    }
  }

  BlePacket? _parsePacket(Map<String, dynamic> data) {
    try {
      return BlePacket(
        timestamp: _parseUnixSeconds(data['timestamp']) ??
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
        anxietyScore:
            (_parseDouble(data['anxiety_score']) ?? 0.0).clamp(0.0, 100.0),
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

  int? _parseUnixSeconds(dynamic v) {
    final ts = _parseInt(v);
    if (ts == null) return null;
    return ts > 100000000000 ? ts ~/ 1000 : ts;
  }

  void _setError(String status, String msg) {
    _deviceOnline = false;
    _connectionStatus = status;
    _lastErrorMessage = msg;
    if (EnvironmentConfig.debugMode && kDebugMode) {
      debugPrint('[ServerAPI] 错误：$msg');
    }
  }

  Future<HistoryResponse> fetchHistory(
    String range, {
    int? from,
    int? to,
  }) async {
    assert(HistoryRange.all.contains(range), 'range must be 24h, 7d or 30d');
    if (_deviceId.isEmpty) {
      return HistoryResponse.error('', range, '未选择设备');
    }

    final query = <String, String>{'range': range};
    if (from != null) query['from'] = from.toString();
    if (to != null) query['to'] = to.toString();

    try {
      final resp = await _auth.get(
        _auth.uri(
          '/api/history/$_deviceId',
          baseUrlOverride: _baseUrl,
          queryParameters: query,
        ),
        signOutOn401: false,
      );

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
          debugPrint(
              '[ServerAPI] fetchHistory $range：${parsed.points.length} 点');
        }
        return parsed;
      }

      if (resp.statusCode == 204) {
        return HistoryResponse.empty(_deviceId, range);
      }

      if (resp.statusCode == 403) {
        return HistoryResponse.error(_deviceId, range, '请先绑定此设备');
      }

      if (resp.statusCode == 401) {
        final legacy = await _fetchHistoryWithLegacyKeyIfNeeded(
          resp,
          range,
          query,
        );
        if (legacy != null) return legacy;
        return HistoryResponse.error(_deviceId, range, '历史接口鉴权失败，请联系服务器检查');
      }

      return HistoryResponse.error(
        _deviceId,
        range,
        'HTTP ${resp.statusCode}',
      );
    } on ApiException catch (e) {
      final msg =
          e.kind == ApiErrorKind.unauthorized ? '历史接口鉴权失败，请联系服务器检查' : e.message;
      return HistoryResponse.error(_deviceId, range, msg);
    } on TimeoutException {
      return HistoryResponse.error(_deviceId, range, '请求超时');
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] fetchHistory $range 失败：$e');
      }
      return HistoryResponse.error(_deviceId, range, '连接失败：$e');
    }
  }

  Future<HistoryResponse?> _fetchHistoryWithLegacyKeyIfNeeded(
    http.Response bearerResponse,
    String range,
    Map<String, String> query,
  ) async {
    if (EnvironmentConfig.legacyHistoryDeviceKey.isEmpty) return null;
    if (!bearerResponse.body.contains('invalid key')) return null;

    final legacyQuery = <String, String>{
      ...query,
      'key': EnvironmentConfig.legacyHistoryDeviceKey,
    };

    try {
      final resp = await http
          .get(
            EnvironmentConfig.apiUri(
              '/api/history/$_deviceId',
              baseUrlOverride: _baseUrl,
              queryParameters: legacyQuery,
            ),
          )
          .timeout(EnvironmentConfig.requestTimeout);

      if (resp.statusCode == 200) {
        if (resp.body.isEmpty) return HistoryResponse.empty(_deviceId, range);
        final data = jsonDecode(resp.body);
        if (data is! Map<String, dynamic>) {
          return HistoryResponse.error(_deviceId, range, '响应格式无效');
        }
        return HistoryResponse.fromJson(data, range: range);
      }
      if (resp.statusCode == 204) {
        return HistoryResponse.empty(_deviceId, range);
      }
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] legacy history retry failed: $e');
      }
    }

    return null;
  }

  Future<List<ServerAlert>> fetchAlertsList() async {
    if (_deviceId.isEmpty) return [];
    try {
      final resp = await _auth.get(
        _auth.uri('/api/alerts/$_deviceId', baseUrlOverride: _baseUrl),
        signOutOn401: false,
      );

      if (resp.statusCode != 200 || resp.body.isEmpty) return [];

      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) return [];

      final raw = data['alerts'];
      if (raw is! List) return [];

      final alerts =
          raw.map(ServerAlert.fromJson).where((a) => !a.isEmpty).toList();
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] fetchAlerts：${alerts.length} 条');
      }
      return alerts;
    } catch (e) {
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] fetchAlertsList 失败：$e');
      }
      return [];
    }
  }

  Future<bool> healthCheck() async {
    try {
      final resp = await http
          .get(_auth.uri('/api/health', baseUrlOverride: _baseUrl))
          .timeout(EnvironmentConfig.requestTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetDevice() async {
    if (_deviceId.isEmpty) return false;
    try {
      final resp = await _auth.post(
        _auth.uri('/api/reset/$_deviceId', baseUrlOverride: _baseUrl),
        body: const {},
        signOutOn401: false,
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> setSpecies(String species) async {
    if (_deviceId.isEmpty) return '未选择设备';
    try {
      final resp = await _auth.post(
        _auth.uri('/api/set_species', baseUrlOverride: _baseUrl),
        body: {
          'device_id': _deviceId,
          'species': species,
        },
        signOutOn401: false,
      );

      if (resp.statusCode == 200) {
        if (EnvironmentConfig.debugMode && kDebugMode) {
          final body = jsonDecode(resp.body);
          debugPrint('[ServerAPI] set_species 成功：species=$species '
              'sample_rate=${body['sample_rate']}');
        }
        return null;
      } else {
        final msg = 'set_species 失败：HTTP ${resp.statusCode}';
        if (EnvironmentConfig.debugMode && kDebugMode) {
          debugPrint('[ServerAPI] $msg');
        }
        return msg;
      }
    } on TimeoutException {
      const msg = 'set_species 超时';
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] $msg');
      }
      return msg;
    } catch (e) {
      final msg = 'set_species 异常：$e';
      if (EnvironmentConfig.debugMode && kDebugMode) {
        debugPrint('[ServerAPI] $msg');
      }
      return msg;
    }
  }
}
