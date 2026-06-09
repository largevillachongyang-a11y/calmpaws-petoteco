// =============================================================================
// device_binding_provider.dart — 用户绑定设备列表与当前选中项
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bound_device.dart';
import '../services/api_exception.dart';
import '../services/user_device_api_service.dart';

class DeviceBindingProvider extends ChangeNotifier {
  final _api = UserDeviceApiService();

  List<BoundDevice> _devices = [];
  String? _selectedDeviceId;
  bool _isLoading = false;
  String? _errorMessage;

  List<BoundDevice> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasDevices => _devices.isNotEmpty;

  BoundDevice? get selectedDevice {
    if (_selectedDeviceId == null) return null;
    for (final d in _devices) {
      if (d.deviceId == _selectedDeviceId) return d;
    }
    return _devices.isNotEmpty ? _devices.first : null;
  }

  String? get selectedDeviceId => selectedDevice?.deviceId;

  Future<void> loadDevices({String? preferDeviceId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _devices = await _api.fetchDevices();
      await _resolveSelection(preferDeviceId: preferDeviceId);
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = _messageFor(e);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> bindDevice({
    required String deviceId,
    required String deviceKey,
  }) async {
    _errorMessage = null;
    try {
      await _api.bindDevice(deviceId: deviceId, deviceKey: deviceKey);
      await loadDevices(preferDeviceId: deviceId.trim());
    } on ApiException catch (e) {
      _errorMessage = _messageFor(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unbindDevice(String deviceId) async {
    _errorMessage = null;
    try {
      await _api.unbindDevice(deviceId);
      _devices.removeWhere((d) => d.deviceId == deviceId);
      if (_selectedDeviceId == deviceId) {
        _selectedDeviceId = _devices.isNotEmpty ? _devices.first.deviceId : null;
        await _persistSelection();
      }
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = _messageFor(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> selectDevice(String deviceId) async {
    if (!_devices.any((d) => d.deviceId == deviceId)) return;
    _selectedDeviceId = deviceId;
    await _persistSelection();
    notifyListeners();
  }

  Future<void> _resolveSelection({String? preferDeviceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_device_id');
    final candidates = [
      if (preferDeviceId != null && preferDeviceId.isNotEmpty) preferDeviceId,
      if (saved != null && saved.isNotEmpty) saved,
    ];
    for (final id in candidates) {
      if (_devices.any((d) => d.deviceId == id)) {
        _selectedDeviceId = id;
        await _persistSelection();
        return;
      }
    }
    _selectedDeviceId = _devices.isNotEmpty ? _devices.first.deviceId : null;
    await _persistSelection();
  }

  Future<void> _persistSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedDeviceId == null) {
      await prefs.remove('selected_device_id');
    } else {
      await prefs.setString('selected_device_id', _selectedDeviceId!);
    }
  }

  void clear() {
    _devices = [];
    _selectedDeviceId = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  String _messageFor(ApiException e) {
    return switch (e.kind) {
      ApiErrorKind.unauthorized => '登录已过期，请重新登录',
      ApiErrorKind.forbidden => '无权操作此设备',
      ApiErrorKind.notFound => '设备不存在',
      ApiErrorKind.conflict => '设备已被其他用户绑定',
      ApiErrorKind.server => '服务器异常，请稍后重试',
      ApiErrorKind.network => e.message,
      ApiErrorKind.unknown => e.message,
    };
  }
}
