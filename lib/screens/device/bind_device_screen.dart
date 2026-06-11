import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/device_binding_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';

/// 绑定项圈：device_id + device_key（包装盒）。
class BindDeviceScreen extends StatefulWidget {
  final VoidCallback? onBound;

  const BindDeviceScreen({super.key, this.onBound});

  @override
  State<BindDeviceScreen> createState() => _BindDeviceScreenState();
}

class _BindDeviceScreenState extends State<BindDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _bind(
      deviceId: _idCtrl.text.trim(),
      deviceKey: _keyCtrl.text.trim(),
    );
  }

  Future<void> _bind({
    required String deviceId,
    required String deviceKey,
  }) async {
    final s = context.read<LocaleProvider>().strings;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<DeviceBindingProvider>().bindDevice(
            deviceId: deviceId,
            deviceKey: deviceKey,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.deviceBindSuccess)),
      );
      widget.onBound?.call();
    } on ApiException catch (e) {
      setState(() => _error = _apiMessage(e, s));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<DeviceQrPayload>(
      MaterialPageRoute(builder: (_) => const DeviceQrScannerScreen()),
    );
    if (!mounted || result == null) return;

    _idCtrl.text = result.deviceId;
    _keyCtrl.text = result.deviceKey;
    await _bind(deviceId: result.deviceId, deviceKey: result.deviceKey);
  }

  String _apiMessage(ApiException e, dynamic s) {
    return switch (e.kind) {
      ApiErrorKind.notFound => s.deviceBindNotFound,
      ApiErrorKind.unauthorized => s.deviceBindWrongKey,
      ApiErrorKind.conflict => s.deviceBindConflict,
      _ => e.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(s.deviceBindTitle, style: AppTextStyles.headlineMedium),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.deviceBindSubtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _scanQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(s.deviceScanQrAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sageGreen,
                    side: const BorderSide(color: AppColors.sageGreen),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        s.authOr,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _idCtrl,
                  decoration: InputDecoration(
                    labelText: s.deviceIdLabel,
                    hintText: 'collar_001',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? s.deviceIdLabel : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _keyCtrl,
                  decoration: InputDecoration(
                    labelText: s.deviceKeyLabel,
                  ),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? s.deviceKeyLabel : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.alertRed, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sageGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(s.deviceBindAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class DeviceQrPayload {
  final String deviceId;
  final String deviceKey;

  const DeviceQrPayload({
    required this.deviceId,
    required this.deviceKey,
  });

  static DeviceQrPayload? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final jsonPayload = _parseJson(text);
    if (jsonPayload != null) return jsonPayload;

    final uriPayload = _parseUri(text);
    if (uriPayload != null) return uriPayload;

    final queryPayload = _parseUri('calmpaws://bind?$text');
    if (queryPayload != null) return queryPayload;

    final pairPayload = _parseDelimited(text);
    if (pairPayload != null) return pairPayload;

    return null;
  }

  static DeviceQrPayload? _parseJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      return _fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static DeviceQrPayload? _parseUri(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.queryParameters.isEmpty) return null;
    return _fromMap(uri.queryParameters);
  }

  static DeviceQrPayload? _parseDelimited(String text) {
    final parts = text
        .split(RegExp(r'[\s|,;]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length != 2) return null;
    return _valid(parts[0], parts[1]);
  }

  static DeviceQrPayload? _fromMap(Map<dynamic, dynamic> map) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    return _valid(
      pick(['device_id', 'deviceId', 'id']),
      pick(['device_key', 'deviceKey', 'key']),
    );
  }

  static DeviceQrPayload? _valid(String? id, String? key) {
    if (id == null || key == null) return null;
    if (id.isEmpty || key.isEmpty) return null;
    return DeviceQrPayload(deviceId: id, deviceKey: key);
  }
}

class DeviceQrScannerScreen extends StatefulWidget {
  const DeviceQrScannerScreen({super.key});

  @override
  State<DeviceQrScannerScreen> createState() => _DeviceQrScannerScreenState();
}

class _DeviceQrScannerScreenState extends State<DeviceQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty) {
        raw = barcode.rawValue;
        break;
      }
    }
    if (raw == null) return;

    final payload = DeviceQrPayload.parse(raw);
    if (payload == null) {
      final s = context.read<LocaleProvider>().strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.deviceScanQrInvalid)),
      );
      return;
    }

    _handled = true;
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(s.deviceScanQrTitle),
        actions: [
          IconButton(
            tooltip: 'Flash',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Camera',
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.deviceScanQrNoCamera,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                s.deviceScanQrHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
