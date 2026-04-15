import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HealthCalendarCard — 健康日历融合视图
// 传感器层（📡）与主人记录层（👤）分开展示，不合并计算
// ─────────────────────────────────────────────────────────────────────────────
class HealthCalendarCard extends StatefulWidget {
  const HealthCalendarCard({super.key});

  @override
  State<HealthCalendarCard> createState() => _HealthCalendarCardState();
}

class _HealthCalendarCardState extends State<HealthCalendarCard> {
  // 选中的日期，默认今天
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final s = context.watch<LocaleProvider>().strings;
    final records = provider.getDailyRecords(days: 14);
    // 找到选中日期的 record
    final selectedRecord = records.firstWhere(
      (r) => _isSameDay(r.date, _selected),
      orElse: () => DailyRecord(date: _selected),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行 ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  s.calendarTitle,
                  style: AppTextStyles.headlineSmall,
                ),
                const Spacer(),
                // 图例
                _LegendDot(color: AppColors.sageGreen, label: s.calendarSensor),
                const SizedBox(width: 10),
                _LegendDot(color: AppColors.warmOrange, label: s.calendarOwner),
                const SizedBox(width: 10),
                // 写日记按钮
                GestureDetector(
                  onTap: () => _showWriteJournalDialog(context, provider, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✍️', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          s.calendarWriteJournal,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 日期格子横条 ──────────────────────────────────────────────────
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: records.length,
              itemBuilder: (ctx, i) {
                final r = records[i];
                final isSelected = _isSameDay(r.date, _selected);
                final isToday = _isSameDay(r.date, DateTime.now());
                return _DayCell(
                  record: r,
                  isSelected: isSelected,
                  isToday: isToday,
                  s: s,
                  onTap: () => setState(() => _selected = r.date),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          const SizedBox(height: 14),

          // ── 选中日期详情 ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _DayDetail(record: selectedRecord, s: s),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showWriteJournalDialog(BuildContext context, PetHealthProvider provider, dynamic s) {
    // 检查今天是否已有记录
    final today = DateTime.now();
    final hasToday = provider.journalEntries.any((e) =>
        e.date.year == today.year &&
        e.date.month == today.month &&
        e.date.day == today.day);
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => _WriteJournalDialog(
        provider: provider,
        hasExistingEntry: hasToday,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 日期格子
// ─────────────────────────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DailyRecord record;
  final bool isSelected;
  final bool isToday;
  final dynamic s;
  final VoidCallback onTap;

  const _DayCell({
    required this.record,
    required this.isSelected,
    required this.isToday,
    required this.s,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stressLevel = record.stressLevel; // 0–3
    // 传感器层颜色点
    final sensorColor = stressLevel == 0
        ? AppColors.divider
        : stressLevel == 1
            ? AppColors.sageGreen
            : stressLevel == 2
                ? AppColors.warmOrangeLight
                : AppColors.alertRed;

    final hasOwner = record.journalEntry != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sageGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.sageGreen, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 星期
            Text(
              _weekdayLabel(record.date, s),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            // 日期数字
            Text(
              '${record.date.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // 双点指示器
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 传感器点
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white60 : sensorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                // 主人记录点（有记录才显示，无记录显示透明占位）
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (hasOwner ? Colors.white : Colors.transparent)
                        : (hasOwner ? AppColors.warmOrange : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(DateTime d, dynamic s) {
    // 使用 s.locale 判断语言
    final isZh = s.locale == 'zh';
    const zhDays = ['一', '二', '三', '四', '五', '六', '日'];
    const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    // weekday: 1=Mon, 7=Sun
    final idx = d.weekday - 1;
    return isZh ? zhDays[idx] : enDays[idx];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 选中日详情：两层分开展示，不合并计算
// ─────────────────────────────────────────────────────────────────────────────
class _DayDetail extends StatelessWidget {
  final DailyRecord record;
  final dynamic s;
  const _DayDetail({required this.record, required this.s});

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(record.date, DateTime.now());
    final dateLabel = isToday ? s.today : _formatDate(record.date, s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期标题
        Text(
          dateLabel,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),

        if (!record.hasAnyData)
          _EmptyDay(s: s)
        else ...[
          // ── 传感器层 ────────────────────────────────────────────────────
          _SensorLayer(summary: record.sensorSummary, s: s),
          if (record.sensorSummary != null && record.journalEntry != null)
            const SizedBox(height: 10),
          // ── 主人记录层 ──────────────────────────────────────────────────
          _OwnerLayer(entry: record.journalEntry, s: s),
        ],
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime d, dynamic s) {
    final isZh = s.locale == 'zh';
    return isZh ? '${d.month}月${d.day}日' : '${_monthName(d.month)} ${d.day}';
  }

  String _monthName(int m) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m];
  }
}

// ── 传感器层组件 ─────────────────────────────────────────────────────────────
class _SensorLayer extends StatelessWidget {
  final SensorDaySummary? summary;
  final dynamic s;
  const _SensorLayer({required this.summary, required this.s});

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      // 设备离线
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Text('📡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(s.calendarSensor, style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(s.calendarOffline,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    final stress = summary!.avgStressScore;
    final stressColor = stress < 35
        ? AppColors.sageGreen
        : stress < 65
            ? AppColors.warmOrange
            : AppColors.alertRed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stressColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stressColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('📡', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(s.calendarSensor,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (summary!.hasFeeding)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.sageMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.calendarFed,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.sageGreen, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // 数据格子
          Row(
            children: [
              _SensorStat(
                label: s.calendarStress,
                value: '${stress.round()}',
                unit: s.calendarPts,
                color: stressColor,
              ),
              const SizedBox(width: 8),
              _SensorStat(
                label: s.calendarEvents,
                value: '${summary!.stressEventCount}',
                unit: s.calendarTimes,
                color: stressColor,
              ),
              const SizedBox(width: 8),
              _SensorStat(
                label: s.calendarActivity,
                value: '${summary!.activityScore}',
                unit: s.calendarPts,
                color: AppColors.sageGreen,
              ),
              if (summary!.timeToCalmSecs != null) ...[
                const SizedBox(width: 8),
                _SensorStat(
                  label: s.calendarTtc,
                  value: '${(summary!.timeToCalmSecs! / 60).toStringAsFixed(1)}',
                  unit: s.ttcMin,
                  color: AppColors.sageGreen,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _SensorStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 主人记录层组件 ─────────────────────────────────────────────────────────────
class _OwnerLayer extends StatelessWidget {
  final JournalEntry? entry;
  final dynamic s;
  const _OwnerLayer({required this.entry, required this.s});

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      // 未填写，显示提示但不报错
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Text('👤', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text(s.calendarOwner,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(s.calendarNoEntry,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warmOrangeMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warmOrangeLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('👤', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(s.calendarOwner,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warmOrange, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          // 四项表情指标
          Row(
            children: [
              _OwnerStat(emoji: entry!.moodEmoji, label: s.journalMood),
              _OwnerStat(emoji: entry!.appetiteEmoji, label: s.journalAppetite),
              _OwnerStat(emoji: entry!.energyEmoji, label: s.journalEnergy),
              _OwnerStat(emoji: entry!.stoolEmoji, label: s.journalStool),
            ],
          ),
          // 备注（如有）
          if (entry!.notes != null && entry!.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry!.notes!,
                style: AppTextStyles.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerStat extends StatelessWidget {
  final String emoji;
  final String label;
  const _OwnerStat({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── 无数据占位 ─────────────────────────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  final dynamic s;
  const _EmptyDay({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('🌙', style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(s.calendarNoData,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── 图例点 ─────────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10)),
      ],
    );
  }
}

// ── 写日记弹窗 ─────────────────────────────────────────────────────────────────
class _WriteJournalDialog extends StatefulWidget {
  final PetHealthProvider provider;
  final bool hasExistingEntry;
  const _WriteJournalDialog({required this.provider, required this.hasExistingEntry});

  @override
  State<_WriteJournalDialog> createState() => _WriteJournalDialogState();
}

class _WriteJournalDialogState extends State<_WriteJournalDialog> {
  String _mood     = '😊';
  String _appetite = '🍖';
  String _energy   = '⚡';
  String _stool    = '🟤';
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  const Text('📓', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.journalTodayTitle, style: AppTextStyles.headlineMedium),
                  ),
                ],
              ),
              // 今天已有记录提示
              if (widget.hasExistingEntry) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warmOrangeMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warmOrangeLight),
                  ),
                  child: Text(
                    s.calendarTodayExists,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.warmOrange),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 表情选择行
              _EmojiPickRow(
                title: s.journalMood,
                options: const ['😊', '😐', '😰', '😣', '🤒'],
                selected: _mood,
                onSelect: (v) => setState(() => _mood = v),
              ),
              const SizedBox(height: 14),
              _EmojiPickRow(
                title: s.journalAppetite,
                options: const ['🍖', '😐', '🚫'],
                selected: _appetite,
                onSelect: (v) => setState(() => _appetite = v),
              ),
              const SizedBox(height: 14),
              _EmojiPickRow(
                title: s.journalEnergy,
                options: const ['⚡', '😴', '🐌'],
                selected: _energy,
                onSelect: (v) => setState(() => _energy = v),
              ),
              const SizedBox(height: 14),
              _EmojiPickRow(
                title: s.journalStool,
                options: const ['🟤', '🟡', '🔴', '💧'],
                selected: _stool,
                onSelect: (v) => setState(() => _stool = v),
              ),
              const SizedBox(height: 16),

              // 文字备注
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: s.journalNotes,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  filled: true,
                  fillColor: AppColors.cream,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.provider.addJournalEntry(JournalEntry(
                      id: 'j_${DateTime.now().millisecondsSinceEpoch}',
                      date: DateTime.now(),
                      stoolEmoji:    _stool,
                      moodEmoji:     _mood,
                      appetiteEmoji: _appetite,
                      energyEmoji:   _energy,
                      notes: _notesController.text.isNotEmpty
                          ? _notesController.text
                          : null,
                      negativeFlags: (_mood == '😰' || _mood == '😣')
                          ? ['anxiety']
                          : [],
                    ));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.journalSaved),
                        backgroundColor: AppColors.sageGreen,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(

                    overlayColor: Colors.transparent,                    backgroundColor: AppColors.sageGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    s.journalSave,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 表情选择行 ─────────────────────────────────────────────────────────────────
class _EmojiPickRow extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  const _EmojiPickRow({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: options
              .map((e) => GestureDetector(
                    onTap: () => onSelect(e),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected == e
                            ? AppColors.sageMuted
                            : AppColors.cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected == e
                              ? AppColors.sageGreen
                              : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
