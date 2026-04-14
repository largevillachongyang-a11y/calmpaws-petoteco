import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

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
          ],
        ],
      ),
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
