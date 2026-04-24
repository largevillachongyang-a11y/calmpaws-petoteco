import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';

class TimeToCalmCard extends StatelessWidget {
  final PetHealthProvider provider;
  const TimeToCalmCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final history = provider.sessionHistory;
    final hasSessions = history.isNotEmpty;

    // Calculate average
    double avg = 0;
    if (hasSessions) {
      final completed = history.where((s) => s.timeToCalm != null).toList();
      if (completed.isNotEmpty) {
        avg = completed
                .map((s) => s.timeToCalm!)
                .reduce((a, b) => a + b) /
            completed.length;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sageMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hourglass_bottom_rounded,
                    color: AppColors.sageGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                s.ttcTitle,
                style: AppTextStyles.headlineSmall,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sageMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.ttcSessions(history.length),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.sageGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (!hasSessions)
            _EmptyState()
          else ...[
            // Main metric
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMinutes(history.first.timeToCalm ?? 0),
                  style: AppTextStyles.metricValue(
                      color: AppColors.sageGreen),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.ttcMin,
                    style: AppTextStyles.metricUnit(
                        color: AppColors.sageGreen),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      s.ttcAvg(_formatMinutes(avg.round())),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.trending_down_rounded,
                            color: AppColors.sageGreen, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          s.ttcWeekTrend,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.sageGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${s.ttcLastSession}${_timeAgo(history.first.feedTime, s)}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),

            // Mini history row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: history
                  .take(4)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => _SessionDot(
                        session: e.value,
                        label: _dayLabel(e.key, s),
                        minLabel: s.ttcMin,
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),
            // Before/after comparison
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sageMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _CompareChip(
                    label: s.ttcStressBefore,
                    value: '${history.first.stressCountBefore ?? "—"}',
                    unit: s.ttcEvents,
                    color: AppColors.warmOrange,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                  _CompareChip(
                    label: s.ttcStressAfter,
                    value: '${history.first.stressCountAfter ?? "—"}',
                    unit: s.ttcEvents,
                    color: AppColors.sageGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 查看全部按钮
            GestureDetector(
              onTap: () => _showAllHistory(context, history, s),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.ttcViewAll,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.sageGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 13, color: AppColors.sageGreen),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllHistory(
      BuildContext context, List<FeedingSession> history, dynamic s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedingHistorySheet(history: history, s: s),
    );
  }

  String _formatMinutes(int seconds) {
    return (seconds / 60).toStringAsFixed(0);
  }

  String _timeAgo(DateTime t, dynamic s) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return s.daysAgo(diff.inDays);
    if (diff.inHours > 0) return s.hoursAgo(diff.inHours);
    return s.minutesAgo(diff.inMinutes);
  }

  String _dayLabel(int index, dynamic s) {
    if (index == 0) return s.today;
    if (index == 1) return s.yesterday;
    return s.daysAgo(index);
  }
}

class _SessionDot extends StatelessWidget {
  final dynamic session;
  final String label;
  final String minLabel;
  const _SessionDot({required this.session, required this.label, required this.minLabel});

  @override
  Widget build(BuildContext context) {
    final secs = session.timeToCalm as int? ?? 0;
    final mins = (secs / 60).round();
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.sageMuted,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$mins',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.sageGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall,
        ),
        Text(
          minLabel,
          style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _CompareChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _CompareChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.sageMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('⏱️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.timerNoSession, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                Text(s.timerNoSessionDesc, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 完整喂食历史 BottomSheet ───────────────────────────────────────────────────
class _FeedingHistorySheet extends StatelessWidget {
  final List<FeedingSession> history;
  final dynamic s;
  const _FeedingHistorySheet({required this.history, required this.s});

  @override
  Widget build(BuildContext context) {
    final isZh = context.watch<LocaleProvider>().isZh;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    isZh ? '喂食历史记录' : 'Feeding History',
                    style: AppTextStyles.headlineSmall,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sageMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isZh ? '共 ${history.length} 次' : '${history.length} sessions',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.sageGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            if (history.isNotEmpty) _SummaryBar(history: history, isZh: isZh),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _HistoryItem(
                  session: history[i],
                  index: i,
                  isZh: isZh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<FeedingSession> history;
  final bool isZh;
  const _SummaryBar({required this.history, required this.isZh});

  @override
  Widget build(BuildContext context) {
    final completed = history.where((s) => s.timeToCalm != null).toList();
    if (completed.isEmpty) return const SizedBox.shrink();
    final times = completed.map((s) => s.timeToCalm!).toList();
    final avg = times.reduce((a, b) => a + b) / times.length;
    final fastest = times.reduce((a, b) => a < b ? a : b);
    final slowest = times.reduce((a, b) => a > b ? a : b);
    String fmt(int secs) {
      final m = (secs / 60).round();
      return isZh ? '$m 分钟' : '${m}m';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.sageMuted.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCell(label: isZh ? '平均' : 'Avg', value: fmt(avg.round()), color: AppColors.sageGreen),
          _StatCell(label: isZh ? '最快' : 'Best', value: fmt(fastest), color: AppColors.successGreen),
          _StatCell(label: isZh ? '最慢' : 'Slowest', value: fmt(slowest), color: AppColors.warmOrange),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final FeedingSession session;
  final int index;
  final bool isZh;
  const _HistoryItem({required this.session, required this.index, required this.isZh});

  @override
  Widget build(BuildContext context) {
    final secs = session.timeToCalm ?? 0;
    final mins = (secs / 60).round();
    final diff = DateTime.now().difference(session.feedTime);
    final timeLabel = diff.inDays > 0
        ? (isZh ? '${diff.inDays} 天前' : '${diff.inDays}d ago')
        : diff.inHours > 0
            ? (isZh ? '${diff.inHours} 小时前' : '${diff.inHours}h ago')
            : (isZh ? '${diff.inMinutes} 分钟前' : '${diff.inMinutes}m ago');
    final dateStr =
        '${session.feedTime.month}/${session.feedTime.day} ${session.feedTime.hour.toString().padLeft(2, '0')}:${session.feedTime.minute.toString().padLeft(2, '0')}';
    final before = session.stressCountBefore ?? 0;
    final after = session.stressCountAfter ?? 0;
    final improved = after < before;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: index == 0
              ? AppColors.sageGreen.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: index == 0 ? AppColors.sageMuted : AppColors.divider,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: index == 0 ? AppColors.sageGreen : AppColors.textSecondary,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(dateStr,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text(timeLabel,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(isZh ? '应激：' : 'Stress: ',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                    Text('$before',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.warmOrange, fontWeight: FontWeight.w700)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textMuted),
                    ),
                    Text('$after',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: improved ? AppColors.sageGreen : AppColors.warmOrange,
                            fontWeight: FontWeight.w700)),
                    if (improved) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.trending_down_rounded, size: 13, color: AppColors.sageGreen),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$mins',
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: index == 0 ? AppColors.sageGreen : AppColors.textSecondary,
                    height: 1.0,
                  )),
              Text(isZh ? '分钟' : 'min',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
