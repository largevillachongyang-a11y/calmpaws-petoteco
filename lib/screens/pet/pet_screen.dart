import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pet/health_calendar_card.dart';
import '../setup/wifi_provision_screen.dart';
import '../../services/wifi_config_service.dart';
import '../../services/server_api_service.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final s = context.watch<LocaleProvider>().strings;
    final pet = provider.pet;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, pet, provider, s)),
            SliverToBoxAdapter(child: _buildHealthTags(pet, s)),
            SliverToBoxAdapter(child: _buildDeviceSection(context, provider, s)),
            // ── 物种选择卡片（选猫/狗后立即通知服务器切换采样率）─────────────
            SliverToBoxAdapter(child: _SpeciesCard(pet: pet, provider: provider)),
            // 健康日历融合视图（传感器 + 主人记录，数据分层不合并）
            const SliverToBoxAdapter(child: HealthCalendarCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext ctx, PetProfile pet, PetHealthProvider provider, dynamic s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _PetAvatar(provider: provider),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 宠物名 — 字体放大时自动缩小不换行
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(pet.name, style: AppTextStyles.headlineLarge),
                ),
                const SizedBox(height: 4),
                // 品种+年龄 — 本地化，字体放大时自动缩小不换行
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${s.translateBreed(pet.breed)} · ${s.ageLabelLocalized(pet.ageMonths)}',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
                // 体重+物种
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${pet.weightKg} kg · ${pet.species == 'dog' ? '🐕' : '🐈'} ${s.translateSpecies(pet.species)}',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditDialog(ctx, pet, provider, s),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.sageMuted, shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, color: AppColors.sageGreen, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTags(PetProfile pet, dynamic s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏷️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(s.petHealthTags, style: AppTextStyles.headlineSmall),
            ],
          ),
          const SizedBox(height: 14),
          if (pet.healthTags.isEmpty)
            Text(s.petNoTags, style: AppTextStyles.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pet.healthTags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.warmOrangeMuted,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.warmOrangeLight),
                        ),
                        child: Text(
                          s.translateTag(tag),
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.warmOrange,
                            fontSize: 13,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  /// RSSI → 信号强度文字
  String _rssiLabel(int rssi, dynamic s) {
    if (rssi >= -60) return s.petSignalGood;        // 强
    if (rssi >= -75) return '一般';                 // 中
    return '较弱';                                  // 弱
  }

  /// RSSI → 图标
  IconData _rssiIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_wifi_4_bar_rounded;
    if (rssi >= -75) return Icons.network_wifi_2_bar_rounded;
    return Icons.network_wifi_1_bar_rounded;
  }

  Widget _buildDeviceSection(BuildContext context, PetHealthProvider provider, dynamic s) {
    final connected = provider.deviceConnected;
    final srvStatus  = provider.serverConnectionStatus; // connected/error/connecting/disconnected
    final rssi       = provider.rssi;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('CalmPaws 项圈', style: AppTextStyles.headlineSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: connected ? AppColors.sageMuted : AppColors.alertRedMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  connected ? s.petConnected : s.petOffline,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppColors.sageGreen : AppColors.alertRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DeviceStat(
                label: s.petBattery,
                value: connected ? '${provider.battery}%' : '--',
                icon: connected && provider.battery > 20
                    ? Icons.battery_4_bar_rounded
                    : connected
                        ? Icons.battery_alert_rounded
                        : Icons.battery_unknown_rounded,
                iconColor: connected && provider.battery <= 20
                    ? AppColors.alertRed : null,
              )),
              const SizedBox(width: 12),
              // 信号：根据 RSSI 动态显示
              Expanded(child: _DeviceStat(
                label: s.petSignal,
                value: connected ? _rssiLabel(rssi, s) : '--',
                icon: connected ? _rssiIcon(rssi) : Icons.signal_wifi_off_rounded,
                subtitle: connected ? '$rssi dBm' : null,
              )),
              const SizedBox(width: 12),
              // 同步状态：根据 serverConnectionStatus 动态显示
              Expanded(child: _DeviceStat(
                label: s.petSync,
                value: switch (srvStatus) {
                  'connected'    => s.petSyncLive,
                  'connecting'   => '连接中',
                  'error'        => 'Error',
                  _              => '离线',
                },
                icon: switch (srvStatus) {
                  'connected'    => Icons.sync_rounded,
                  'connecting'   => Icons.sync_problem_rounded,
                  'error'        => Icons.sync_disabled_rounded,
                  _              => Icons.sync_disabled_rounded,
                },
                iconColor: srvStatus == 'error' ? AppColors.alertRed : null,
              )),
            ],
          ),
          const SizedBox(height: 16),
          // 演示滑块已迁移到调试面板（我的页面长按版本号）
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: connected
                  ? provider.disconnectDevice
                  : () async {
                      // 已有保存的IP → 直接重连，不进配网向导
                      // 首次使用（IP为空）→ 进配网向导
                      final savedUrl = WifiConfigService().serverUrl;
                      if (savedUrl.isNotEmpty) {
                        provider.connectDevice();
                      } else {
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const WifiProvisionScreen(),
                          ),
                        );
                      }
                    },
              icon: Icon(
                connected ? Icons.bluetooth_disabled_rounded : Icons.wifi_rounded,
                size: 18,
              ),
              label: Text(connected ? s.petDisconnect : s.petConnectBtn),
              style: OutlinedButton.styleFrom(

                overlayColor: Colors.transparent,                foregroundColor: connected ? AppColors.alertRed : AppColors.sageGreen,
                side: BorderSide(color: connected ? AppColors.alertRed : AppColors.sageGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, PetProfile pet, PetHealthProvider provider, dynamic s) {
    // 用父页面 context 的 ScaffoldMessenger，对话框关闭后依然有效
    final scaffoldMsg = ScaffoldMessenger.of(context);
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => _EditPetDialog(
        pet: pet,
        provider: provider,
        s: s,
        onSaved: (String? cloudErr) {
          final ls = context.read<LocaleProvider>().strings;
          // 在父页面上下文中显示 SnackBar（不受对话框 unmount 影响）
          String msg;
          Color bgColor;
          int secs;
          if (cloudErr == null) {
            msg = ls.petProfileSaved;
            bgColor = const Color(0xFF4CAF50);
            secs = 2;
          } else if (cloudErr == 'permission-denied') {
            msg = ls.petProfileFirestoreDenied;
            bgColor = const Color(0xFFF59E0B);
            secs = 6;
          } else if (cloudErr == 'network-error' || cloudErr == 'timeout') {
            msg = ls.petProfileSavedLocal;
            bgColor = const Color(0xFFF59E0B);
            secs = 4;
          } else if (cloudErr == 'unauthenticated') {
            msg = ls.petProfileAuthError;
            bgColor = const Color(0xFFEF5350);
            secs = 4;
          } else {
            msg = ls.petProfileCloudError(cloudErr);
            bgColor = const Color(0xFFF59E0B);
            secs = 5;
          }
          scaffoldMsg.showSnackBar(SnackBar(
            content: Text(msg, style: const TextStyle(fontSize: 13)),
            backgroundColor: bgColor,
            duration: Duration(seconds: secs),
            behavior: SnackBarBehavior.floating,
          ));
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 设备状态指标小卡片
// ─────────────────────────────────────────────────────────────────────────────
class _DeviceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;   // 副标题（如 "-65 dBm"）
  final Color? iconColor;   // 覆盖图标颜色（如 error 时红色）
  const _DeviceStat({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.sageGreen;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16, color: color)),
          Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 物种选择卡片 — 用户选猫/狗后立即 POST /api/set_species 通知服务器
// 服务器收到后在下次心跳中下发对应的 sample_rate，项圈切换 IMU 采样率
// ─────────────────────────────────────────────────────────────────────────────
class _SpeciesCard extends StatefulWidget {
  final PetProfile pet;
  final PetHealthProvider provider;

  const _SpeciesCard({required this.pet, required this.provider});

  @override
  State<_SpeciesCard> createState() => _SpeciesCardState();
}

class _SpeciesCardState extends State<_SpeciesCard> {
  bool _syncing = false; // 正在同步中（显示加载动画）

  Future<void> _selectSpecies(String species) async {
    if (_syncing || species == widget.pet.species) return;

    setState(() => _syncing = true);

    // 步骤1：本地更新（立即刷新 UI）
    final newPet = widget.pet.copyWith(species: species);
    widget.provider.updatePetLocal(newPet);

    // 步骤2：后台并发执行 —— 通知服务器 + 同步云端
    final apiResult = await ServerApiService().setSpecies(species);

    if (mounted) setState(() => _syncing = false);

    // 步骤3：后台同步 Firestore（不阻塞 UI）
    widget.provider.syncPetToCloud();

    // 步骤4：显示结果 SnackBar
    if (mounted) {
      final isZh = context.read<LocaleProvider>().isZh;
      final speciesName = isZh
          ? (species == 'dog' ? '狗狗 🐕' : '猫咪 🐈')
          : (species == 'dog' ? 'Dog 🐕' : 'Cat 🐈');

      if (apiResult == null) {
        // 成功
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isZh
              ? '✅ 已切换为$speciesName，项圈采样率将在下次心跳同步'
              : '✅ Switched to $speciesName — sample rate will sync on next heartbeat'),
          backgroundColor: AppColors.sageGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
      } else {
        // 失败（网络问题），但本地已更新，提示用户
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isZh
              ? '⚠️ 本地已保存$speciesName，服务器同步失败：$apiResult'
              : '⚠️ Saved locally as $speciesName, server sync failed: $apiResult'),
          backgroundColor: AppColors.warningAmber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听 provider 以响应物种变化（来自编辑弹窗的保存操作）
    final pet = context.watch<PetHealthProvider>().pet;
    final s = context.watch<LocaleProvider>().strings;
    final isZh = context.watch<LocaleProvider>().isZh;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 12,
          offset: const Offset(0, 3),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('🔬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isZh ? '宠物物种' : 'Pet Species',
                  style: AppTextStyles.headlineSmall,
                ),
              ),
              // 同步中：显示小加载圈
              if (_syncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.sageGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 副标题说明
          Text(
            isZh
                ? '选择后 APP 会通知项圈自动切换 IMU 采样率'
                : 'APP will notify the collar to adjust IMU sample rate',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          // 选择按钮行
          Row(
            children: [
              Expanded(
                child: _SpeciesButton(
                  emoji: '🐕',
                  label: s.petSpeciesDog,
                  sublabel: isZh ? '高频运动检测' : 'High-motion detection',
                  selected: pet.species == 'dog',
                  loading: _syncing && pet.species != 'dog',
                  onTap: _syncing ? null : () => _selectSpecies('dog'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SpeciesButton(
                  emoji: '🐈',
                  label: s.petSpeciesCat,
                  sublabel: isZh ? '轻盈步态分析' : 'Light gait analysis',
                  selected: pet.species == 'cat',
                  loading: _syncing && pet.species != 'cat',
                  onTap: _syncing ? null : () => _selectSpecies('cat'),
                ),
              ),
            ],
          ),
          // 当前状态提示
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sageMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.sageGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isZh
                        ? '当前：${pet.species == 'dog' ? '狗狗 🐕' : '猫咪 🐈'} · 切换后项圈在下次心跳（≤30s）同步'
                        : 'Current: ${pet.species == 'dog' ? 'Dog 🐕' : 'Cat 🐈'} · Collar syncs on next heartbeat (≤30s)',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.sageGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 物种选择按钮（大按钮样式，含 emoji + 名称 + 采样率说明）
class _SpeciesButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _SpeciesButton({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageMuted : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.sageGreen : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.sageGreen : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.sageGreen : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.watch<LocaleProvider>().isZh ? '✓ 已选' : '✓ Selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 日记历史行（已迁移至 HealthCalendarCard）—— 保留备用
// ─────────────────────────────────────────────────────────────────────────────
// ignore: unused_element
class _JournalRow extends StatelessWidget {
  final JournalEntry entry;
  final dynamic s;
  const _JournalRow({required this.entry, required this.s});

  @override
  Widget build(BuildContext context) {
    final hasNotes = entry.notes != null && entry.notes!.isNotEmpty;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 第一行：日期 + 表情 + 展开提示 ──
            Row(
              children: [
                // 日期标签
                SizedBox(
                  width: 32,
                  child: Text(
                    _dateLabel(entry.date, s),
                    style: AppTextStyles.labelSmall,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                // 4 个表情（固定大小，不受系统字体影响）
                Text(entry.moodEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(entry.appetiteEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(entry.energyEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(entry.stoolEmoji, style: const TextStyle(fontSize: 20)),
                const Spacer(),
                // 点击展开提示箭头
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
            // ── 第二行：notes 备注（单独一行，可展示更多内容）──
            if (hasNotes) ...[
              const SizedBox(height: 6),
              Text(
                entry.notes!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 点击弹出完整日记详情
  void _showDetail(BuildContext context) {
    final ls = context.read<LocaleProvider>().strings;
    final dateStr = _dateLabel(entry.date, ls);

    // 情绪/食欲/精力/粪便对应中英文描述
    String moodDesc(String emoji) {
      const map = {
        '😌': {'en': 'Relaxed', 'zh': '放松'},
        '😊': {'en': 'Happy', 'zh': '开心'},
        '😰': {'en': 'Anxious', 'zh': '焦虑'},
        '😣': {'en': 'Stressed', 'zh': '应激'},
        '🤒': {'en': 'Unwell', 'zh': '不适'},
        '😐': {'en': 'Neutral', 'zh': '一般'},
      };
      final lang = ls.locale == 'zh' ? 'zh' : 'en';
      return map[emoji]?[lang] ?? emoji;
    }

    String appetiteDesc(String emoji) {
      const map = {
        '🍖': {'en': 'Good appetite', 'zh': '食欲良好'},
        '😐': {'en': 'Normal', 'zh': '正常'},
        '🚫': {'en': 'Poor appetite', 'zh': '食欲不佳'},
        '🍗': {'en': 'Good appetite', 'zh': '食欲良好'},
      };
      final lang = ls.locale == 'zh' ? 'zh' : 'en';
      return map[emoji]?[lang] ?? emoji;
    }

    String energyDesc(String emoji) {
      const map = {
        '⚡': {'en': 'High energy', 'zh': '精力充沛'},
        '😴': {'en': 'Low energy', 'zh': '精力不足'},
        '💤': {'en': 'Sleepy', 'zh': '嗜睡'},
        '😪': {'en': 'Tired', 'zh': '疲倦'},
      };
      final lang = ls.locale == 'zh' ? 'zh' : 'en';
      return map[emoji]?[lang] ?? emoji;
    }

    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            const Text('📓', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              ls.locale == 'zh'
                  ? '$dateStr 日记'
                  : '$dateStr Journal',
              style: AppTextStyles.headlineMedium,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态指标行
              _DetailRow(
                emoji: entry.moodEmoji,
                label: ls.journalMood,
                desc: moodDesc(entry.moodEmoji),
              ),
              _DetailRow(
                emoji: entry.appetiteEmoji,
                label: ls.journalAppetite,
                desc: appetiteDesc(entry.appetiteEmoji),
              ),
              _DetailRow(
                emoji: entry.energyEmoji,
                label: ls.journalEnergy,
                desc: energyDesc(entry.energyEmoji),
              ),
              _DetailRow(
                emoji: entry.stoolEmoji,
                label: ls.journalStool,
                desc: '',
              ),
              // 备注
              if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ls.journalNotes,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(entry.notes!, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
            child: Text(ls.close, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime d, dynamic s) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month) return s.today;
    if (d.day == now.day - 1 && d.month == now.month) return s.yesterday;
    return '${d.month}/${d.day}';
  }
}

/// 日记详情中的单行指标（已迁移至 HealthCalendarCard）
// ignore: unused_element
class _DetailRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String desc;
  const _DetailRow({required this.emoji, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                if (desc.isNotEmpty)
                  Text(desc, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 编辑宠物档案弹窗
// ─────────────────────────────────────────────────────────────────────────────
class _EditPetDialog extends StatefulWidget {
  final PetProfile pet;
  final PetHealthProvider provider;
  final dynamic s;
  /// 保存完成回调：cloudErr == null 表示成功，非 null 为错误类型字符串
  /// 在父页面 context 中调用，避免对话框 unmount 后 context 失效
  final void Function(String? cloudErr)? onSaved;
  const _EditPetDialog({
    required this.pet,
    required this.provider,
    required this.s,
    this.onSaved,
  });

  @override
  State<_EditPetDialog> createState() => _EditPetDialogState();
}

class _EditPetDialogState extends State<_EditPetDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _breedCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _weightCtrl;
  late String _species; // 'dog' 或 'cat'
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pet.name);
    _breedCtrl = TextEditingController(text: widget.pet.breed);
    _ageCtrl = TextEditingController(text: widget.pet.ageMonths.toString());
    _weightCtrl = TextEditingController(text: widget.pet.weightKg.toString());
    _species = widget.pet.species;
    _selectedTags = List.from(widget.pet.healthTags);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // 统一的输入框样式
  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.cream,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final locS = context.watch<LocaleProvider>().strings;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locS.petEditTitle, style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),

              // ── 宠物名称 ──
              TextField(
                controller: _nameCtrl,
                decoration: _inputDecoration(locS.petNameLabel),
              ),
              const SizedBox(height: 12),

              // ── 宠物类型（狗狗 / 猫咪）──
              Text(locS.petSpeciesLabel, style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  _SpeciesChip(
                    label: locS.petSpeciesDog,
                    emoji: '🐶',
                    selected: _species == 'dog',
                    onTap: () => setState(() => _species = 'dog'),
                  ),
                  const SizedBox(width: 10),
                  _SpeciesChip(
                    label: locS.petSpeciesCat,
                    emoji: '🐱',
                    selected: _species == 'cat',
                    onTap: () => setState(() => _species = 'cat'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 品种 ──
              TextField(
                controller: _breedCtrl,
                decoration: _inputDecoration(locS.petBreedLabel),
              ),
              const SizedBox(height: 12),

              // ── 年龄 + 体重（同排）──
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(locS.petAgeLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(locS.petWeightLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 健康标签 ──
              Text(locS.petHealthTags, style: AppTextStyles.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kHealthTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.sageMuted : AppColors.cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.sageGreen : AppColors.divider),
                      ),
                      child: Text(
                        locS.translateTag(tag),
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? AppColors.sageGreen : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── 取消 / 保存 按钮行 ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.sageGreen.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(locS.cancel, style: const TextStyle(color: AppColors.sageGreen, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        overlayColor: Colors.transparent,
                        backgroundColor: AppColors.sageGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final age = int.tryParse(_ageCtrl.text.trim()) ?? widget.pet.ageMonths;
                        final weight = double.tryParse(_weightCtrl.text.trim()) ?? widget.pet.weightKg;
                        final newPet = widget.pet.copyWith(
                          name: _nameCtrl.text.trim(),
                          species: _species,
                          breed: _breedCtrl.text.trim(),
                          ageMonths: age,
                      weightKg: weight,
                      healthTags: _selectedTags,
                        );

                        // 步骤1：写入内存 + 本地缓存（立即生效，不依赖网络）
                        widget.provider.updatePetLocal(newPet);

                        // 步骤2：立即关闭对话框（此后 mounted = false，不可再用 context）
                        if (mounted) Navigator.of(context).pop();

                        // 步骤3：物种有变化时通知服务器切换采样率（后台静默，不影响 UI）
                        if (_species != widget.pet.species) {
                          ServerApiService().setSpecies(_species);
                        }

                        // 步骤4：后台同步 Firestore，通过回调把结果交给父页面处理
                        final cloudErr = await widget.provider.syncPetToCloud();
                        widget.onSaved?.call(cloudErr);
                      },
                      child: Text(locS.petSave, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 物种选择 chip（狗狗 / 猫咪）
class _SpeciesChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _SpeciesChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageMuted : AppColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.sageGreen : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? AppColors.sageGreen : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 宠物头像组件（支持照片上传）─────────────────────────────────────────────────
class _PetAvatar extends StatefulWidget {
  final PetHealthProvider provider;
  const _PetAvatar({required this.provider});

  @override
  State<_PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<_PetAvatar> {
  bool _uploading = false;
  bool _showCancel = false;
  bool _cancelled = false;

  Future<void> _pickAndUpload() async {
    final ls = context.read<LocaleProvider>().strings;
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,  // 移动端压缩，Web端无效
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();

    // ── 文件大小检查
    // Web 端 image_picker 不压缩，移动端 maxWidth/imageQuality 有效
    // 统一上限 5MB，超出则拒绝并告知实际大小
    const int maxBytes = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxBytes) {
      if (mounted) {
        final sizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ls.petPhotoTooLarge(sizeMB)),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
      return;
    }

    // ── 开始上传
    _cancelled = false;
    setState(() { _uploading = true; _showCancel = false; });

    // 3秒后显示取消按钮
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _uploading && !_cancelled) {
        setState(() => _showCancel = true);
      }
    });

    try {
      final err = await widget.provider.uploadPetPhoto(bytes);

      if (_cancelled) return;

      if (mounted) {
        final ls = context.read<LocaleProvider>().strings;
        String msg;
        Color bg;
        if (err == null) {
          msg = ls.petPhotoUpdated;
          bg = AppColors.sageGreen;
        } else if (err == 'timeout') {
          msg = ls.petPhotoUploadTimeout;
          bg = AppColors.alertRed;
        } else if (err == 'storage-permission-denied') {
          msg = ls.petPhotoStorageDenied;
          bg = AppColors.alertRed;
        } else if (err == 'network-error') {
          msg = ls.petPhotoNetworkError;
          bg = AppColors.alertRed;
        } else if (err == 'not-logged-in') {
          msg = ls.petPhotoLoginRequired;
          bg = AppColors.alertRed;
        } else if (err == 'image-too-large') {
          msg = ls.petPhotoTooLargeFirestore;
          bg = AppColors.alertRed;
        } else {
          msg = ls.petPhotoUploadFailed(err);
          bg = AppColors.alertRed;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted && !_cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('上传失败：${e.toString()}'),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() { _uploading = false; _showCancel = false; });
    }
  }

  void _cancelUpload() {
    _cancelled = true;
    if (mounted) setState(() { _uploading = false; _showCancel = false; });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final photoUrl = provider.pet.photoPath;
    final revision = provider.petPhotoRevision;
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sageGreen, width: 3),
            ),
            child: ClipOval(
              child: _uploading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.sageGreen,
                          ),
                        ),
                        if (_showCancel) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _cancelUpload,
                            child: const Text(
                              '✕',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.alertRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          key: ValueKey('pet_avatar_upload_${revision}_$photoUrl'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('🐶', style: TextStyle(fontSize: 38)),
                          ),
                        )
                      : const Center(
                          child: Text('🐶', style: TextStyle(fontSize: 38)),
                        ),
            ),
          ),
          if (!_uploading)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.sageGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
