import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class StatusCardsRow extends StatelessWidget {
  final PetHealthProvider provider;
  const StatusCardsRow({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final sleepQuality = provider.lastNightSleepQuality;
    final calmTrend = provider.todayCalmTrend;
    final activityScore = provider.currentActivityScore;
    final stressCount = provider.latestPacket?.strC ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: '😴',
                title: s.cardSleep,
                value: '$sleepQuality',
                unit: s.cardActivityOut,
                subtitle: sleepQuality >= 70 ? s.cardSleepOk : s.cardSleepBad,
                accentColor: sleepQuality >= 70 ? AppColors.sageGreen : AppColors.warningAmber,
                bgColor: sleepQuality >= 70 ? AppColors.sageMuted : AppColors.warningAmberMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: '📊',
                title: s.cardAnxiety,
                value: calmTrend < 0
                    ? '${calmTrend.toStringAsFixed(0)}%'
                    : '+${calmTrend.toStringAsFixed(0)}%',
                unit: s.cardAnxietyVsYday,
                subtitle: calmTrend < 0 ? s.cardAnxietyLess : s.cardAnxietyMore,
                accentColor: calmTrend < 0 ? AppColors.sageGreen : AppColors.warmOrange,
                bgColor: calmTrend < 0 ? AppColors.sageMuted : AppColors.warmOrangeMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: '⚡',
                title: s.cardActivity,
                value: '$activityScore',
                unit: s.cardActivityOut,
                subtitle: activityScore >= 40 ? s.cardActivityOk : s.cardActivityLow,
                accentColor: activityScore >= 40 ? AppColors.sageGreen : AppColors.alertRed,
                bgColor: activityScore >= 40 ? AppColors.sageMuted : AppColors.alertRedMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: '🎯',
                title: s.cardStress,
                value: '$stressCount',
                unit: s.cardStressWindow,
                subtitle: stressCount < 3 ? s.cardStressOk : s.cardStressHigh,
                accentColor: stressCount < 3 ? AppColors.sageGreen : AppColors.warmOrange,
                bgColor: stressCount < 3 ? AppColors.sageMuted : AppColors.warmOrangeMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final Color accentColor;
  final Color bgColor;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.accentColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: accentColor, height: 1.0),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 3),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: accentColor.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
