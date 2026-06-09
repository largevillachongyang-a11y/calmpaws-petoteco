import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_binding_provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class DeviceStatusBar extends StatelessWidget {
  final PetHealthProvider provider;
  const DeviceStatusBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final connected = provider.deviceConnected;
    final battery = provider.battery;
    final lowBattery = battery < 20;
    final isSyncing = provider.isSyncing;
    final syncStatus = provider.syncStatus;
    // 服务器连接状态（connected/connecting/error/disconnected）
    final srvStatus = provider.serverConnectionStatus;
    final isForbidden = connected && srvStatus == 'forbidden';
    final hasError = connected && (srvStatus == 'error' || isForbidden);
    final awaitingData = connected && !hasError && provider.statusAwaitingCachedData;
    final deviceBinding = context.watch<DeviceBindingProvider>();
    final activeId = provider.serverDeviceId;
    final deviceDisplayName = () {
      if (!connected) return s.deviceOffline;
      if (isForbidden) return s.deviceForbidden;
      if (hasError) return s.deviceServerError;
      if (awaitingData) return s.statusNoCachedData;
      if (activeId.isNotEmpty) {
        return '${s.deviceSwitchLabel} · $activeId';
      }
      final url = provider.serverBaseUrl;
      final host = Uri.tryParse(url)?.host ?? url;
      return s.deviceCollarHost(host);
    }();
    // 状态点颜色：error 时用红色
    final dotColor = (!connected || hasError)
        ? AppColors.alertRed
        : awaitingData
            ? AppColors.warningAmber
            : AppColors.sageGreen;
    final barColor = (!connected || hasError)
        ? AppColors.alertRedMuted
        : awaitingData
            ? AppColors.warningAmberMuted
            : AppColors.sageMuted;

    return Column(
      children: [
        // ── 主状态栏 ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: barColor,
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
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: (connected && !hasError)
                      ? [BoxShadow(color: AppColors.sageGreen.withValues(alpha: 0.5), blurRadius: 4)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // 设备状态文字
              Expanded(
                child: Text(
                  deviceDisplayName,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: dotColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 已连接：显示电量、蓝牙、SYNC按钮
              if (connected && !hasError && !awaitingData) ...[  // 有数据时显示电量/蓝牙/SYNC
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
                const SizedBox(width: 8),
                const Icon(Icons.bluetooth_connected_rounded,
                    color: AppColors.sageGreen, size: 16),
                const SizedBox(width: 4),
                Text(
                  s.deviceBle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.sageGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                // ── SYNC 按钮 ────────────────────────────────────────────────
                GestureDetector(
                  onTap: isSyncing
                      ? null
                      : () => provider.requestSync(
                            locale: context.read<LocaleProvider>().locale,
                          ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSyncing
                          ? AppColors.sageMuted
                          : AppColors.sageGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSyncing
                            ? AppColors.sageGreen.withValues(alpha: 0.3)
                            : AppColors.sageGreen.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSyncing)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.sageGreen,
                            ),
                          )
                        else
                          const Icon(Icons.sync_rounded,
                              color: AppColors.sageGreen, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          isSyncing ? s.syncInProgress : s.petSync,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.sageGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (hasError)
                // 服务器错误：显示重试按钮
                GestureDetector(
                  onTap: provider.connectDevice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.deviceRetry,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                // 未连接：显示连接按钮
                GestureDetector(
                  onTap: provider.connectDevice,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.deviceConnect,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (deviceBinding.devices.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: deviceBinding.selectedDeviceId,
                  items: deviceBinding.devices
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.deviceId,
                          child: Text('${d.speciesEmoji} ${d.deviceId}'),
                        ),
                      )
                      .toList(),
                  onChanged: (id) async {
                    if (id == null || id == deviceBinding.selectedDeviceId) return;
                    await deviceBinding.selectDevice(id);
                    await provider.switchActiveDevice(id);
                  },
                ),
              ),
            ),
          ),
        // ── 204 暂无缓存数据提示 ───────────────────────────────────────────
        if (awaitingData)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warningAmberMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 14,
                  color: AppColors.warningAmber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.statusNoCachedDataHint,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // ── SYNC 状态提示条（有状态时才显示）─────────────────────────────────
        if (syncStatus.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: syncStatus.startsWith('✅')
                  ? AppColors.sageMuted
                  : AppColors.warningAmberMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  syncStatus.startsWith('✅')
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 14,
                  color: syncStatus.startsWith('✅')
                      ? AppColors.sageGreen
                      : AppColors.warningAmber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    syncStatus,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11,
                      color: syncStatus.startsWith('✅')
                          ? AppColors.sageGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
