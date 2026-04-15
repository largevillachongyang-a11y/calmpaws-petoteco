// =============================================================================
// feeding_timer_card.dart — 喂食计时卡片（首页核心 CTA）
// =============================================================================
// 业务逻辑：
//   状态1：未喂食 → 显示「已喂食 ZenBelly」按钮，用户点击开始计时
//   状态2：计时中 → 显示已经过去的时间 + 当前行为状态 + 取消按钮
//   状态3：已完成 → 显示本次 Time-to-Calm 和上次比较
//
// Time-to-Calm 是产品的核心指标，证明 ZenBelly 工作有效。
// 它由 PetHealthProvider.startFeedingSession() 开始，
// BLE 数据检测到宠物持续平静后自动结束。
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';

class FeedingTimerCard extends StatelessWidget {
  final PetHealthProvider provider;
  const FeedingTimerCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final session = provider.activeSession;
    final isActive = session != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  AppColors.sageGreen,
                  const Color(0xFF5A9970),
                ]
              : [
                  AppColors.warmOrange,
                  const Color(0xFFD4694A),
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.sageGreen : AppColors.warmOrange)
                .withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isActive
          ? _ActiveTimer(provider: provider)
          : _FeedButton(provider: provider),
    );
  }
}

/// The CTA button when no session is active
class _FeedButton extends StatelessWidget {
  final PetHealthProvider provider;
  const _FeedButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('💊', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              // 🔑 FIX: Expanded prevents title overflow in Row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.s.timerTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      context.s.timerSubtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      // 🔑 FIX: Allow 2 lines for long translations
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.s.timerDesc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              provider.startFeedingSession();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              // 🔑 FIX: Use Flexible so button text wraps instead of overflowing
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_rounded,
                      color: AppColors.warmOrange, size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.s.timerStart,
                      style: const TextStyle(
                        color: AppColors.warmOrange,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      // 🔑 FIX: Allow 2 lines if text is long (e.g. Chinese)
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Show last session if exists
          if (provider.sessionHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  // 🔑 FIX: Flexible prevents last-session text overflow
                  Flexible(
                    child: Text(
                      '${context.s.timerLastSession} ${provider.lastTimeToCalmLabel} ${context.s.timerToCalm}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The active timer display with behavior progress
class _ActiveTimer extends StatelessWidget {
  final PetHealthProvider provider;
  const _ActiveTimer({required this.provider});

  @override
  Widget build(BuildContext context) {
    final elapsed = provider.sessionElapsedSeconds;
    final behavior = provider.currentBehavior;
    final anxietyScore = provider.currentAnxietyScore;

    // Progress arc: 0-100 maps to 0.0-1.0
    // We expect calm within ~30 min = 1800 sec
    final progress = (elapsed / 1800.0).clamp(0.0, 1.0);
    final calmProgress = ((100 - anxietyScore) / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  // 🔑 FIX: Flexible prevents header text overflow
                  Flexible(
                    child: Text(
                      context.s.timerActive,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showCancelDialog(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.s.timerCancel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Central timer display + calm ring
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer anxiety ring
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1.0 - calmProgress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(
                        Colors.white,
                        Colors.redAccent.shade100,
                        1.0 - calmProgress,
                      )!,
                    ),
                  ),
                ),
                // Inner elapsed ring
                SizedBox(
                  width: 148,
                  height: 148,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.sessionElapsedLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.s.timerElapsed,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${behavior.emoji} ${behavior.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Behavior progress bar
          _BehaviorProgressBar(
            calmProgress: calmProgress,
            anxietyScore: anxietyScore,
            s: context.s,
          ),

          const SizedBox(height: 16),

          // Behavior milestones
          _BehaviorMilestones(elapsed: elapsed, behavior: behavior, s: context.s),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final s = context.read<LocaleProvider>().strings;
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.timerCancel),
        content: Text(s.timerCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.timerKeepTracking),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.cancelFeedingSession();
            },
            child: Text(s.cancel, style: const TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
  }
}

class _BehaviorProgressBar extends StatelessWidget {
  final double calmProgress;
  final int anxietyScore;
  final dynamic s;

  const _BehaviorProgressBar({
    required this.calmProgress,
    required this.anxietyScore,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.timerCalmProgress,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              s.timerCalmPct((calmProgress * 100).round()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: calmProgress,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _BehaviorLabel(emoji: '😰', label: s.behaviorAnxious, active: anxietyScore > 60),
            _BehaviorLabel(emoji: '😐', label: s.behaviorSettling, active: anxietyScore >= 20 && anxietyScore <= 60),
            _BehaviorLabel(emoji: '😌', label: s.behaviorCalm, active: anxietyScore < 20),
          ],
        ),
      ],
    );
  }
}

class _BehaviorLabel extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;

  const _BehaviorLabel({
    required this.emoji,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _BehaviorMilestones extends StatelessWidget {
  final int elapsed;
  final PetBehaviorState behavior;
  final dynamic s;

  const _BehaviorMilestones({required this.elapsed, required this.behavior, required this.s});

  @override
  Widget build(BuildContext context) {
    final milestones = [
      _Milestone(minSec: 0, maxSec: 300, label: s.milestoneJustGiven, emoji: '💊', reached: elapsed >= 0),
      _Milestone(minSec: 300, maxSec: 900, label: s.milestoneAbsorbing, emoji: '🔄', reached: elapsed >= 300),
      _Milestone(minSec: 900, maxSec: 1800, label: s.milestoneSettling, emoji: '😐', reached: elapsed >= 900),
      _Milestone(minSec: 1800, maxSec: 99999, label: s.milestoneCalm, emoji: '😌',
          reached: behavior == PetBehaviorState.calm && elapsed > 1800),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: milestones
            .map((m) => _MilestoneChip(milestone: m))
            .toList(),
      ),
    );
  }
}

class _Milestone {
  final int minSec;
  final int maxSec;
  final String label;
  final String emoji;
  final bool reached;

  const _Milestone({
    required this.minSec,
    required this.maxSec,
    required this.label,
    required this.emoji,
    required this.reached,
  });
}

class _MilestoneChip extends StatelessWidget {
  final _Milestone milestone;
  const _MilestoneChip({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: milestone.reached
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: milestone.reached
                ? Border.all(color: Colors.white, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              milestone.emoji,
              style: TextStyle(
                fontSize: 16,
                color: milestone.reached
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          milestone.label,
          style: TextStyle(
            color: milestone.reached
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
