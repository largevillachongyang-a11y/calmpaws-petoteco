// =============================================================================
// provisioning_service.dart — 项圈配网服务
// =============================================================================
// 职责：
//   管理项圈的 Wi-Fi 配网流程。
//   Web 平台：手动输入服务器 IP，直接测试连通性。
//   原生平台（未来）：BLE 扫描 CalmPaws_Config → 发送 Wi-Fi 凭证 → 项圈连网。
//
// 配网协议（固件侧，预留）：
//   BLE 设备名：CalmPaws_Config
//   Service UUID：4fafc201-1fb5-459e-8fcc-c5c9c331914b
//   Characteristic UUID（写）：beb5483e-36e1-4688-b7f5-ea07361b26a8
//   写入格式（\n 分隔）：SSID\nPASSWORD\nSERVER_URL\nDEVICE_ID
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';

/// 配网步骤枚举
enum ProvisionStep {
  idle,       // 未开始
  verifying,  // 验证服务器中
  done,       // 成功
  error,      // 失败
}

/// 配网结果
class ProvisionResult {
  final bool success;
  final String? serverUrl;
  final String? errorMessage;
  final bool corsLikely; // 失败原因可能是浏览器CORS，建议强制保存
  const ProvisionResult({
    required this.success,
    this.serverUrl,
    this.errorMessage,
    this.corsLikely = false,
  });
}

class ProvisioningService {
  static final ProvisioningService _instance = ProvisioningService._internal();
  factory ProvisioningService() => _instance;
  ProvisioningService._internal();

  ProvisionStep _step = ProvisionStep.idle;
  String _statusMessage = '';
  ProvisionStep get step => _step;
  String get statusMessage => _statusMessage;

  final _stepController = StreamController<ProvisionStep>.broadcast();
  Stream<ProvisionStep> get stepStream => _stepController.stream;

  void _setStep(ProvisionStep s, String msg) {
    _step = s;
    _statusMessage = msg;
    _stepController.add(s);
    if (kDebugMode) debugPrint('[Provision] $s: $msg');
  }

  // ── 验证并保存服务器地址 ────────────────────────────────────────────────

  /// 尝试连接 /health，成功则返回 success=true
  /// CORS / 超时时 corsLikely=true，提示用户可强制保存
  Future<ProvisionResult> verify({required String serverUrl}) async {
    final url = serverUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty) {
      _setStep(ProvisionStep.error, '请输入服务器地址');
      return const ProvisionResult(success: false, errorMessage: '请输入服务器地址');
    }

    _setStep(ProvisionStep.verifying, '正在连接服务器...');

    try {
      final resp = await http
          .get(EnvironmentConfig.apiUri('/api/health', baseUrlOverride: url))
          .timeout(EnvironmentConfig.requestTimeout);

      if (resp.statusCode == 200) {
        _setStep(ProvisionStep.done, '服务器连接成功 ✅');
        return ProvisionResult(success: true, serverUrl: url);
      } else {
        _setStep(ProvisionStep.error, '服务器返回 ${resp.statusCode}');
        return ProvisionResult(
          success: false,
          errorMessage: '服务器返回异常: ${resp.statusCode}',
        );
      }
    } on TimeoutException {
      _setStep(ProvisionStep.error, '连接超时');
      return const ProvisionResult(
        success: false,
        errorMessage: '连接超时，请检查 IP 和端口是否正确',
        corsLikely: false,
      );
    } catch (e) {
      // Web 浏览器跨域请求 / 网络不通时抛异常
      final msg = e.toString();
      final isCors = msg.contains('XMLHttpRequest') ||
          msg.contains('Failed to fetch') ||
          msg.contains('NetworkError') ||
          msg.contains('CORS') ||
          msg.contains('cross-origin');
      if (isCors) {
        _setStep(ProvisionStep.error, '浏览器安全限制，建议直接保存');
      } else {
        _setStep(ProvisionStep.error, '无法连接服务器');
      }
      return ProvisionResult(
        success: false,
        errorMessage: isCors ? '浏览器 CORS 限制，服务器可能实际可达' : '连接失败: $e',
        corsLikely: isCors,
      );
    }
  }

  void reset() => _setStep(ProvisionStep.idle, '');

  void dispose() => _stepController.close();
}
