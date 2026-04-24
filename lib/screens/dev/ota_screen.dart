// =============================================================================
// ota_screen.dart — E3 OTA 固件升级
// =============================================================================
// 功能：
//   - 检查固件更新（连接设备后读取当前版本，对比服务器最新版）
//   - 展示更新日志（变更内容、修复 Bug 列表）
//   - 开始 OTA 升级（BLE DFU 分包传输，带进度条）
//   - 升级成功 / 失败 状态展示
//
// 协议框架（硬件对接预留）：
//   - 使用 BLE Write Characteristic 发送 OTA_START / DATA / DONE / ABORT 命令
//   - SERVICE_UUID & CHAR_UUID 与硬件 V6.1 保持一致
//   - 实际 flutter_blue_plus DFU 逻辑在 B10 中完善
// =============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OTA 状态机
// ─────────────────────────────────────────────────────────────────────────────
enum _OtaState {
  idle,        // 初始：未检查
  checking,    // 正在检查服务器
  upToDate,    // 已是最新版
  available,   // 有可用更新
  downloading, // 正在下载固件包
  flashing,    // 正在通过 BLE 写入设备
  success,     // 升级成功
  failed,      // 升级失败
}

// ─────────────────────────────────────────────────────────────────────────────
// 固件版本信息（模型）
// ─────────────────────────────────────────────────────────────────────────────
class _FirmwareVersion {
  final String version;       // 如 "V6.2.1"
  final String releaseDate;   // 如 "2025-06-01"
  final List<String> changes; // 更新日志
  final int fileSizeKb;       // 固件包大小
  final bool isCritical;      // 是否强制升级

  const _FirmwareVersion({
    required this.version,
    required this.releaseDate,
    required this.changes,
    required this.fileSizeKb,
    this.isCritical = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock 数据：服务器端最新版本（真实环境替换为 GET /api/firmware/latest）
// ─────────────────────────────────────────────────────────────────────────────
const _kCurrentDeviceFirmware = 'V6.1.0';  // 设备当前版本（由 BLE 读取）
const _kLatestFirmware = _FirmwareVersion(
  version: 'V6.2.0',
  releaseDate: '2025-06-10',
  fileSizeKb: 128,
  isCritical: false,
  changes: [
    '🔧 修复 ISM330 传感器在低温下采样偏差问题',
    '📡 优化 BLE 重连策略，断线恢复时间从 30s 降至 8s',
    '🧠 更新行为分类模型 v2.1（颤抖识别准确率 +12%）',
    '⚡ 降低深度睡眠电流消耗 15%，续航提升约 18 小时',
    '📦 新增 SYNC_ACK 握手协议，文件传输稳定性增强',
    '🐛 修复偶发的 LittleFS 写入失败导致数据丢失 Bug',
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// OTA 屏幕
// ─────────────────────────────────────────────────────────────────────────────
class OtaScreen extends StatefulWidget {
  const OtaScreen({super.key});

  @override
  State<OtaScreen> createState() => _OtaScreenState();
}

class _OtaScreenState extends State<OtaScreen>
    with SingleTickerProviderStateMixin {
  _OtaState _state = _OtaState.idle;
  double _progress = 0.0;       // 0.0 – 1.0
  String _progressLabel = '';
  String? _errorMessage;
  bool _changelogExpanded = true;

  Timer? _mockTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.85, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── 检查更新 ──────────────────────────────────────────────────────────────
  Future<void> _checkUpdate() async {
    setState(() {
      _state = _OtaState.checking;
      _errorMessage = null;
    });

    // Mock: 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // 比较版本号：设备 V6.1.0 < 服务器 V6.2.0
    setState(() {
      _state = _OtaState.available;
    });
  }

  // ── 开始 OTA 升级（Mock 流程）────────────────────────────────────────────
  Future<void> _startOta() async {
    HapticFeedback.mediumImpact();

    // Step 1: 下载固件包
    setState(() {
      _state = _OtaState.downloading;
      _progress = 0;
      _progressLabel = '正在从服务器下载固件包…';
    });

    await _simulateProgress(
      duration: const Duration(seconds: 3),
      onProgress: (p) => setState(() {
        _progress = p;
        _progressLabel =
            '下载中 ${(p * _kLatestFirmware.fileSizeKb).toStringAsFixed(0)} / ${_kLatestFirmware.fileSizeKb} KB';
      }),
    );
    if (!mounted) return;

    // Step 2: BLE DFU 写入设备
    setState(() {
      _state = _OtaState.flashing;
      _progress = 0;
      _progressLabel = '正在通过 BLE 写入设备固件…';
    });

    await _simulateProgress(
      duration: const Duration(seconds: 5),
      onProgress: (p) {
        final packets = (p * 512).toInt(); // 假设 512 个数据包
        setState(() {
          _progress = p;
          _progressLabel = '写入数据包 $packets / 512';
        });
      },
    );
    if (!mounted) return;

    // Step 3: 验证 + 重启
    setState(() {
      _progressLabel = '固件校验中，设备即将重启…';
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _state = _OtaState.success;
    });
  }

  // ── 模拟进度推进 ──────────────────────────────────────────────────────────
  Future<void> _simulateProgress({
    required Duration duration,
    required ValueChanged<double> onProgress,
  }) async {
    final steps = 40;
    final stepDuration = duration ~/ steps;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (!mounted) return;
      onProgress(i / steps);
    }
  }

  // ── 中止升级 ──────────────────────────────────────────────────────────────
  void _abortOta() {
    _mockTimer?.cancel();
    setState(() {
      _state = _OtaState.available;
      _progress = 0;
      _progressLabel = '';
    });
  }

  // ── 重置到初始 ────────────────────────────────────────────────────────────
  void _reset() {
    setState(() {
      _state = _OtaState.idle;
      _progress = 0;
      _progressLabel = '';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final isConnected = provider.latestPacket != null; // 近似判断设备是否在线

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('固件升级 (OTA)',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text('Over-The-Air Firmware Update',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          // 协议说明按钮
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => _showProtocolInfo(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── 设备连接状态 ───────────────────────────────────────────────
              _DeviceStatusCard(
                  isConnected: isConnected,
                  currentVersion: _kCurrentDeviceFirmware),
              const SizedBox(height: 16),

              // ── 主内容区（根据 OTA 状态切换）──────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.05), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: _buildMainContent(key: ValueKey(_state)),
              ),
              const SizedBox(height: 16),

              // ── BLE 协议说明（常驻底部）──────────────────────────────────
              if (_state == _OtaState.idle ||
                  _state == _OtaState.upToDate ||
                  _state == _OtaState.available)
                _ProtocolCard(changelogExpanded: _changelogExpanded,
                    onToggle: () => setState(
                        () => _changelogExpanded = !_changelogExpanded)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent({Key? key}) {
    switch (_state) {
      case _OtaState.idle:
        return _IdleCard(key: key, onCheck: _checkUpdate);

      case _OtaState.checking:
        return _CheckingCard(key: key, pulseAnim: _pulseAnim);

      case _OtaState.upToDate:
        return _UpToDateCard(key: key, onReset: _reset);

      case _OtaState.available:
        return _AvailableCard(
          key: key,
          firmware: _kLatestFirmware,
          currentVersion: _kCurrentDeviceFirmware,
          changelogExpanded: _changelogExpanded,
          onToggleChangelog: () =>
              setState(() => _changelogExpanded = !_changelogExpanded),
          onStart: _startOta,
        );

      case _OtaState.downloading:
      case _OtaState.flashing:
        return _ProgressCard(
          key: key,
          state: _state,
          progress: _progress,
          progressLabel: _progressLabel,
          onAbort: _abortOta,
        );

      case _OtaState.success:
        return _SuccessCard(
          key: key,
          newVersion: _kLatestFirmware.version,
          onDone: () => Navigator.pop(context),
        );

      case _OtaState.failed:
        return _FailedCard(
          key: key,
          message: _errorMessage ?? '升级过程中发生未知错误',
          onRetry: _startOta,
          onCancel: _reset,
        );
    }
  }

  void _showProtocolInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _ProtocolInfoSheet(),
    );
  }
}

// =============================================================================
// 设备状态卡
// =============================================================================
class _DeviceStatusCard extends StatelessWidget {
  final bool isConnected;
  final String currentVersion;
  const _DeviceStatusCard(
      {required this.isConnected, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // 设备图标
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.sageGreen.withValues(alpha: 0.1)
                  : AppColors.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('📡', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZenBelly Collar',
                  style: AppTextStyles.headlineSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? AppColors.sageGreen
                            : AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? '已连接' : 'Mock 模式',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isConnected
                            ? AppColors.sageGreen
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('当前版本',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted)),
              Text(
                currentVersion,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 各状态卡片
// =============================================================================

// ── 初始状态 ──────────────────────────────────────────────────────────────────
class _IdleCard extends StatelessWidget {
  final VoidCallback onCheck;
  const _IdleCard({super.key, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('检查固件更新',
              style:
                  AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮检查是否有新版固件。\n建议在 Wi-Fi 环境下执行升级。',
            style:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: '检查更新',
            icon: Icons.system_update_rounded,
            onTap: onCheck,
          ),
        ],
      ),
    );
  }
}

// ── 检查中 ────────────────────────────────────────────────────────────────────
class _CheckingCard extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _CheckingCard({super.key, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      child: Column(
        children: [
          ScaleTransition(
            scale: pulseAnim,
            child: const Text('📡', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 20),
          Text('正在检查更新…',
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: AppColors.sageMuted,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.sageGreen),
            ),
          ),
          const SizedBox(height: 10),
          Text('联系服务器，请稍候…',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── 已是最新版 ────────────────────────────────────────────────────────────────
class _UpToDateCard extends StatelessWidget {
  final VoidCallback onReset;
  const _UpToDateCard({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('固件已是最新版本',
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('当前版本 $_kCurrentDeviceFirmware 已是服务器上的最新版本，无需升级。',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onReset,
            child: Text('重新检查',
                style: TextStyle(color: AppColors.sageGreen)),
          ),
        ],
      ),
    );
  }
}

// ── 有可用更新 ────────────────────────────────────────────────────────────────
class _AvailableCard extends StatelessWidget {
  final _FirmwareVersion firmware;
  final String currentVersion;
  final bool changelogExpanded;
  final VoidCallback onToggleChangelog;
  final VoidCallback onStart;

  const _AvailableCard({
    super.key,
    required this.firmware,
    required this.currentVersion,
    required this.changelogExpanded,
    required this.onToggleChangelog,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('🆕', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('发现新版本 ${firmware.version}',
                        style: AppTextStyles.headlineSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '发布日期 ${firmware.releaseDate}  ·  ${firmware.fileSizeKb} KB',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (firmware.isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.alertRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.alertRed.withValues(alpha: 0.4)),
                  ),
                  child: const Text('重要',
                      style: TextStyle(
                          color: AppColors.alertRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 版本跳转
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sageMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentVersion,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(firmware.version,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sageGreen)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 更新日志
          GestureDetector(
            onTap: onToggleChangelog,
            child: Row(
              children: [
                Text('更新日志',
                    style: AppTextStyles.labelSmall
                        .copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(
                  changelogExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
          if (changelogExpanded) ...[
            const SizedBox(height: 10),
            ...firmware.changes.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(c,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // 升级按钮
          _PrimaryButton(
            label: '立即升级',
            icon: Icons.system_update_alt_rounded,
            onTap: onStart,
            color: const Color(0xFF4D9267),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '升级过程约 2–3 分钟，请保持蓝牙连接',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 进度中（下载 / 写入）────────────────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  final _OtaState state;
  final double progress;
  final String progressLabel;
  final VoidCallback onAbort;

  const _ProgressCard({
    super.key,
    required this.state,
    required this.progress,
    required this.progressLabel,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final isFlashing = state == _OtaState.flashing;
    final icon = isFlashing ? '⚡' : '⬇️';
    final title = isFlashing ? '正在写入设备' : '正在下载固件';
    final color = isFlashing ? AppColors.warningAmber : const Color(0xFF6B7FD4);

    return _CardWrapper(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          Text(title,
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: AppColors.sageMuted,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progressLabel,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          if (isFlashing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warningAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warningAmber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '写入过程中请勿关闭 APP 或断开蓝牙，否则可能导致设备固件损坏',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warningAmber),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onAbort,
            icon: const Icon(Icons.cancel_outlined,
                color: AppColors.alertRed, size: 18),
            label: const Text('中止升级',
                style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
  }
}

// ── 升级成功 ──────────────────────────────────────────────────────────────────
class _SuccessCard extends StatelessWidget {
  final String newVersion;
  final VoidCallback onDone;
  const _SuccessCard(
      {super.key, required this.newVersion, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text('升级成功！',
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '设备固件已成功升级到 $newVersion\n设备正在重启，约需 30 秒…',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.sageGreen, size: 18),
                const SizedBox(width: 8),
                Text('当前版本 $newVersion',
                    style: const TextStyle(
                        color: AppColors.sageGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
              label: '完成', icon: Icons.done_rounded, onTap: onDone),
        ],
      ),
    );
  }
}

// ── 升级失败 ──────────────────────────────────────────────────────────────────
class _FailedCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  const _FailedCard(
      {super.key,
      required this.message,
      required this.onRetry,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      child: Column(
        children: [
          const Text('❌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('升级失败',
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.alertRed),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(
                    label: '重试', icon: Icons.refresh_rounded, onTap: onRetry),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLE 协议说明卡（底部常驻）
// =============================================================================
class _ProtocolCard extends StatelessWidget {
  final bool changelogExpanded;
  final VoidCallback onToggle;
  const _ProtocolCard(
      {required this.changelogExpanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: const Color(0xFF6B7FD4).withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.code_rounded,
                  color: Color(0xFF6B7FD4), size: 18),
              const SizedBox(width: 8),
              Text('BLE OTA 协议（开发者）',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: const Color(0xFF6B7FD4),
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            ('OTA_START', '0x01 + 4字节文件大小', '通知设备准备接收固件'),
            ('DATA', '0x02 + 序号(2B) + 数据(128B)', '分包传输固件数据'),
            ('OTA_DONE', '0x03 + CRC32(4B)', '传输完成，触发 CRC 校验'),
            ('OTA_ABORT', '0x04', '中止升级，设备恢复原版本'),
            ('ACK', '0x10 + 序号(2B)', '设备确认收到每个数据包'),
            ('OTA_STATUS', '0x11 + 状态码(1B)', '设备返回当前 OTA 状态'),
          ].map(
            (item) {
              final (cmd, format, desc) = item;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7FD4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(cmd,
                          style: const TextStyle(
                              color: Color(0xFF6B7FD4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(format,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'monospace')),
                          Text(desc,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 协议说明 BottomSheet（详细版）
// =============================================================================
class _ProtocolInfoSheet extends StatelessWidget {
  const _ProtocolInfoSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text('OTA 对接说明',
                  style: AppTextStyles.headlineMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(height: 24),
          ...[
            ('SERVICE_UUID', '4fafc201-1fb5-459e-8fcc-c5c9c331914b'),
            ('CHAR_UUID (Write)', 'beb5483e-36e1-4688-b7f5-ea07361b26a8'),
            ('CHAR_UUID (Notify)', 'cba1d466-344c-4be3-ab3f-189f80dd7518'),
            ('包大小', '128 字节/包'),
            ('超时重传', '3 次，每次 5s 超时'),
            ('CRC', 'CRC32，整个固件文件'),
            ('实现依赖', 'B10 flutter_blue_plus DFU'),
          ].map(
            (item) {
              final (k, v) = item;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(k,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(v,
                          style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w500,
                              fontFamily: v.contains('-') ? 'monospace' : null)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.warningAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warningAmber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前为 UI 框架 + Mock 流程。实际 BLE DFU 写入功能将在 B10 完善后启用。',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.warningAmber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('关闭',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 公共 Widget
// =============================================================================

class _CardWrapper extends StatelessWidget {
  final Widget child;
  const _CardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.sageGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
