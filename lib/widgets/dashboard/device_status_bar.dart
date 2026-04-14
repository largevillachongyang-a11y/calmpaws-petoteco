import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class DeviceStatusBar extends StatelessWidget {
  final PetHealthProvider provider;
  const DeviceStatusBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    // 监听语言切换
    final s = context.watch<LocaleProvider>().strings;
    final connected = provider.deviceConnected;
    final battery = provider.battery;
    final lowBattery = battery < 20;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: connected ? AppColors.sageMuted : AppColors.alertRedMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          // 状态指示点
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected ? AppColors.sageGreen : AppColors.alertRed,
              shape: BoxShape.circle,
              boxShadow: connected
                  ? [BoxShadow(color: AppColors.sageGreen.withValues(alpha: 0.5), blurRadius: 4)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // 设备状态文字
          Expanded(
            child: Text(
              connected ? s.deviceLive : s.deviceOffline,
              style: AppTextStyles.labelMedium.copyWith(
                color: connected ? AppColors.sageGreen : AppColors.alertRed,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 已连接：显示电量和蓝牙
          if (connected) ...[
            Icon(
              lowBattery
                  ? Icons.battery_alert_rounded
                  : battery > 60
                      ? Icons.battery_full_rounded
                      : Icons.battery_4_bar_rounded,
              color: lowBattery ? AppColors.alertRed : AppColors.sageGreen,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '$battery%',
              style: AppTextStyles.labelSmall.copyWith(
                color: lowBattery ? AppColors.alertRed : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.bluetooth_connected_rounded, color: AppColors.sageGreen, size: 16),
            const SizedBox(width: 4),
            Text(
              s.deviceBle,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.sageGreen,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ] else
            // 未连接：显示连接按钮
            GestureDetector(
              onTap: provider.connectDevice,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.alertRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.deviceConnect,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
