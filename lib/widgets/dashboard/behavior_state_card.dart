import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class BehaviorStateCard extends StatelessWidget {
  final PetHealthProvider provider;
  const BehaviorStateCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    // 监听语言切换
    final s = context.watch<LocaleProvider>().strings;
    final behavior = provider.currentBehavior;
    final packet = provider.latestPacket;

    final (bgColor, accentColor, label, desc) = _stateInfo(behavior, s);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // 行为 Emoji
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(behavior.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "当前状态" 标签行
                Row(
                  children: [
                    Text(
                      s.rightNow,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accentColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: AppTextStyles.bodySmall),
                if (packet != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MiniStat(icon: '😣', label: s.statStress, value: '${packet.strC}x'),
                      const SizedBox(width: 12),
                      _MiniStat(icon: '🚶', label: s.statPacing, value: '${packet.paceD}s'),
                      const SizedBox(width: 12),
                      _MiniStat(icon: '🎾', label: s.statPlay, value: '${packet.playD}s'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 焦虑评分环
          if (packet != null)
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: packet.anxietyScore / 100,
                    strokeWidth: 5,
                    backgroundColor: accentColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                  Text(
                    '${packet.anxietyScore}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  (Color, Color, String, String) _stateInfo(PetBehaviorState state, dynamic s) {
    switch (state) {
      case PetBehaviorState.calm:
        return (AppColors.sageMuted, AppColors.sageGreen, s.stateCalm, s.stateCalmDesc);
      case PetBehaviorState.pacing:
        return (AppColors.warmOrangeMuted, AppColors.warmOrange, s.statePacing, s.statePacingDesc);
      case PetBehaviorState.stressed:
        return (const Color(0xFFFFF0E0), const Color(0xFFD97706), s.stateStressed, s.stateStressedDesc);
      case PetBehaviorState.playing:
        return (AppColors.sageMuted, AppColors.sageGreen, s.statePlaying, s.statePlayingDesc);
      case PetBehaviorState.shivering:
        return (AppColors.alertRedMuted, AppColors.alertRed, s.stateShivering, s.stateSiveringDesc);
      case PetBehaviorState.sleeping:
        return (const Color(0xFFF0F4FF), const Color(0xFF6B7FD4), s.stateSleeping, s.stateSleepingDesc);
    }
  }
}

class _MiniStat extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
