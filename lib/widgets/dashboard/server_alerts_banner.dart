import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/server_alert.dart';
import '../../providers/locale_provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';

/// 展示 /api/alerts 返回的设备级告警（如低电量）。
class ServerAlertsBanner extends StatelessWidget {
  final PetHealthProvider provider;
  const ServerAlertsBanner({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final alerts = provider.serverAlerts.where((a) => !a.isEmpty).toList();
    if (alerts.isEmpty) return const SizedBox.shrink();

    final s = context.watch<LocaleProvider>().strings;
    final isZh = context.watch<LocaleProvider>().isZh;

    return Column(
      children: alerts.map((alert) {
        final (icon, color, bg) = _styleFor(alert);
        final text = _displayText(alert, s, isZh);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.serverAlertsTitle,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  (IconData, Color, Color) _styleFor(ServerAlert alert) {
    final t = alert.type.toLowerCase();
    if (t.contains('battery') || t.contains('low_power')) {
      return (
        Icons.battery_alert_rounded,
        AppColors.alertRed,
        AppColors.alertRedMuted,
      );
    }
    if (alert.severity == 'critical' || t.contains('critical')) {
      return (
        Icons.error_outline_rounded,
        AppColors.alertRed,
        AppColors.alertRedMuted,
      );
    }
    return (
      Icons.info_outline_rounded,
      AppColors.warningAmber,
      AppColors.warningAmberMuted,
    );
  }

  String _displayText(ServerAlert alert, dynamic s, bool isZh) {
    if (alert.message.trim().isNotEmpty) return alert.message.trim();
    final t = alert.type.toLowerCase();
    if (t.contains('battery') && alert.battery != null) {
      return s.serverAlertLowBattery(alert.battery!);
    }
    if (t.contains('battery')) {
      return s.serverAlertLowBatteryGeneric;
    }
    return isZh ? '设备告警：${alert.type}' : 'Device alert: ${alert.type}';
  }
}
