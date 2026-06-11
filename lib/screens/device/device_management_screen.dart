import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_binding_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import 'bind_device_screen.dart';

class DeviceManagementScreen extends StatelessWidget {
  const DeviceManagementScreen({super.key});

  Future<void> _confirmUnbind(BuildContext context, String deviceId) async {
    final s = context.read<LocaleProvider>().strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deviceUnbindConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.timerCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.deviceUnbind,
                style: const TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<DeviceBindingProvider>().unbindDevice(deviceId);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final provider = context.watch<DeviceBindingProvider>();
    final devices = provider.devices;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(s.deviceMyDevices, style: AppTextStyles.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BindDeviceScreen()),
          );
          if (context.mounted) {
            await context.read<DeviceBindingProvider>().loadDevices();
          }
        },
        backgroundColor: AppColors.sageGreen,
        foregroundColor: AppColors.textOnDark,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          s.deviceAddAction,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.sageGreen))
          : devices.isEmpty
              ? _EmptyState(
                  s: s,
                  onAdd: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BindDeviceScreen()),
                    );
                  })
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = devices[i];
                    final bound = d.boundAt != null
                        ? s.deviceBoundAt(s.formatDate(d.boundAt!))
                        : d.deviceId;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(d.speciesEmoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.deviceId,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bound,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _confirmUnbind(context, d.deviceId),
                            child: Text(
                              s.deviceUnbind,
                              style: const TextStyle(color: AppColors.alertRed),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final dynamic s;
  final VoidCallback onAdd;

  const _EmptyState({required this.s, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📿', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(s.deviceEmptyTitle, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              s.deviceEmptyHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: AppColors.textOnDark,
              ),
              child: Text(s.deviceAddAction),
            ),
          ],
        ),
      ),
    );
  }
}
