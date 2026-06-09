import 'package:flutter/material.dart';
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
    final s = context.read<LocaleProvider>().strings;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<DeviceBindingProvider>().bindDevice(
            deviceId: _idCtrl.text.trim(),
            deviceKey: _keyCtrl.text.trim(),
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
                    style: const TextStyle(color: AppColors.alertRed, fontSize: 13),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
