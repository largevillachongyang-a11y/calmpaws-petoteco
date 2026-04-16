import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pet/health_calendar_card.dart';

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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sageGreen, width: 3),
            ),
            child: const Center(child: Text('🐶', style: TextStyle(fontSize: 38))),
          ),
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

  Widget _buildDeviceSection(BuildContext context, PetHealthProvider provider, dynamic s) {
    final connected = provider.deviceConnected;
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
              Text(s.petDevice, style: AppTextStyles.headlineSmall),
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
              Expanded(child: _DeviceStat(label: s.petBattery, value: '${provider.battery}%', icon: Icons.battery_4_bar_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _DeviceStat(label: s.petSignal, value: s.petSignalGood, icon: Icons.bluetooth_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _DeviceStat(label: s.petSync, value: s.petSyncLive, icon: Icons.sync_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          // 焦虑模拟滑块（演示专用）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.petAnxietySlider, style: AppTextStyles.labelMedium),
                  ),
                  // 演示徽章
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warmOrangeLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.petDemoTag,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warmOrange),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(provider.anxietyLevel * 100).round()}%',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.warmOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(s.petAnxietySliderDesc, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Text(
                s.petAnxietySliderHint,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.warmOrange,
                  inactiveTrackColor: AppColors.warmOrangeLight,
                  thumbColor: AppColors.warmOrange,
                  overlayColor: AppColors.warmOrange.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: provider.anxietyLevel,
                  onChanged: (v) => provider.anxietyLevel = v,
                  min: 0,
                  max: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: connected ? provider.disconnectDevice : provider.connectDevice,
              icon: Icon(
                connected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_rounded,
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
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => _EditPetDialog(pet: pet, provider: provider, s: s),
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
  const _DeviceStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: AppColors.sageGreen, size: 20),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16, color: AppColors.sageGreen)),
          Text(label, style: AppTextStyles.labelSmall, textAlign: TextAlign.center),
        ],
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
    String _moodDesc(String emoji) {
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

    String _appetiteDesc(String emoji) {
      const map = {
        '🍖': {'en': 'Good appetite', 'zh': '食欲良好'},
        '😐': {'en': 'Normal', 'zh': '正常'},
        '🚫': {'en': 'Poor appetite', 'zh': '食欲不佳'},
        '🍗': {'en': 'Good appetite', 'zh': '食欲良好'},
      };
      final lang = ls.locale == 'zh' ? 'zh' : 'en';
      return map[emoji]?[lang] ?? emoji;
    }

    String _energyDesc(String emoji) {
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
                desc: _moodDesc(entry.moodEmoji),
              ),
              _DetailRow(
                emoji: entry.appetiteEmoji,
                label: ls.journalAppetite,
                desc: _appetiteDesc(entry.appetiteEmoji),
              ),
              _DetailRow(
                emoji: entry.energyEmoji,
                label: ls.journalEnergy,
                desc: _energyDesc(entry.energyEmoji),
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
  const _EditPetDialog({required this.pet, required this.provider, required this.s});

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

              // ── 保存按钮 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    overlayColor: Colors.transparent,
                    backgroundColor: AppColors.sageGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    // 解析年龄和体重，无效输入保留原值
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
                    // 先保存数据（await），再关闭对话框
                    // 注意：await 后不能用 build 参数的 context，改用 State.mounted + State.context
                    final cloudOk = await widget.provider.updatePet(newPet);
                    if (!mounted) return;
                    // 关闭编辑对话框
                    Navigator.of(context).pop();
                    // 通过 SnackBar 告知用户云端同步状态
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          cloudOk
                            ? '✅ 宠物档案已保存并同步到云端'
                            : '⚠️ 已保存到本机，云端同步失败\n请检查网络或 Firestore 规则',
                          style: const TextStyle(fontSize: 13),
                        ),
                        backgroundColor: cloudOk ? const Color(0xFF4CAF50) : const Color(0xFFF59E0B),
                        duration: Duration(seconds: cloudOk ? 2 : 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Text(locS.petSave, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
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
