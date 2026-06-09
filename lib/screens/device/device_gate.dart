import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_binding_provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../screens/device/bind_device_screen.dart';
import '../../screens/main_nav_screen.dart';
import '../../theme/app_theme.dart';

/// 登录后：拉取绑定设备 → 有设备进主页 / 无设备进绑定页。
class DeviceGate extends StatefulWidget {
  final String userId;

  const DeviceGate({super.key, required this.userId});

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final deviceProvider = context.read<DeviceBindingProvider>();
    final petProvider = context.read<PetHealthProvider>();
    await deviceProvider.loadDevices();
    if (!mounted) return;

    final id = deviceProvider.selectedDeviceId;
    if (id != null && id.isNotEmpty) {
      await petProvider.activateBoundDevice(id);
      if (mounted) setState(() => _activated = true);
    } else {
      setState(() => _activated = false);
    }
  }

  Future<void> _onBound() async {
    final deviceProvider = context.read<DeviceBindingProvider>();
    final petProvider = context.read<PetHealthProvider>();
    await deviceProvider.loadDevices();
    final id = deviceProvider.selectedDeviceId;
    if (id != null) {
      await petProvider.activateBoundDevice(id);
    }
    if (mounted) setState(() => _activated = deviceProvider.hasDevices);
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceBindingProvider>();

    if (deviceProvider.isLoading && !deviceProvider.hasDevices && !_activated) {
      return const _LoadingSplash();
    }

    if (deviceProvider.errorMessage != null &&
        !deviceProvider.hasDevices &&
        !_activated) {
      return _ErrorSplash(
        message: deviceProvider.errorMessage!,
        onRetry: _bootstrap,
      );
    }

    if (!deviceProvider.hasDevices && !_activated) {
      return BindDeviceScreen(onBound: _onBound);
    }

    return MainNavScreen(key: ValueKey(widget.userId));
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.sageGreen, strokeWidth: 2),
      ),
    );
  }
}

class _ErrorSplash extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorSplash({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: AppColors.sageGreen),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
