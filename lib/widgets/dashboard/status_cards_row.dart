import 'package:flutter/material.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';

class StatusCardsRow extends StatelessWidget {
  final PetHealthProvider provider;
  const StatusCardsRow({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final sleepQuality = provider.lastNightSleepQuality;
    final calmTrend = provider.todayCalmTrend;
    final activityScore = provider.currentActivityScore;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: '😴',
                title: 'Last Night Sleep',
                value: '$sleepQuality',
                unit: '/ 100',
                subtitle: sleepQuality >= 70
                    ? '✅ Healthy restful sleep'
                    : '⚠️ Restless night',
                accentColor: sleepQuality >= 70
                    ? AppColors.sageGreen
                    : AppColors.warningAmber,
                bgColor: sleepQuality >= 70
                    ? AppColors.sageMuted
                    : AppColors.warningAmberMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: '📊',
                title: 'Today\'s Anxiety',
                value: calmTrend < 0
                    ? '${calmTrend.toStringAsFixed(0)}%'
                    : '+${calmTrend.toStringAsFixed(0)}%',
                unit: 'vs yday',
                subtitle: calmTrend < 0
                    ? '✅ Less anxious today'
                    : '⚠️ More anxious today',
                accentColor: calmTrend < 0
                    ? AppColors.sageGreen
                    : AppColors.warmOrange,
                bgColor: calmTrend < 0
                    ? AppColors.sageMuted
                    : AppColors.warmOrangeMuted,
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
                title: 'Activity Score',
                value: '$activityScore',
                unit: '/ 100',
                subtitle: activityScore >= 40
                    ? '✅ Normal vitality'
                    : '⚠️ Low activity',
                accentColor: activityScore >= 40
                    ? AppColors.sageGreen
                    : AppColors.alertRed,
                bgColor: activityScore >= 40
                    ? AppColors.sageMuted
                    : AppColors.alertRedMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: '🎯',
                title: 'Stress Events',
                value: '${provider.latestPacket?.strC ?? 0}',
                unit: 'this window',
                subtitle: (provider.latestPacket?.strC ?? 0) < 3
                    ? '✅ Under control'
                    : '⚠️ Elevated stress',
                accentColor: (provider.latestPacket?.strC ?? 0) < 3
                    ? AppColors.sageGreen
                    : AppColors.warmOrange,
                bgColor: (provider.latestPacket?.strC ?? 0) < 3
                    ? AppColors.sageMuted
                    : AppColors.warmOrangeMuted,
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
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 3),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
