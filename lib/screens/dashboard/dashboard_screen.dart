import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/feeding_timer_card.dart';
import '../../widgets/dashboard/time_to_calm_card.dart';
import '../../widgets/dashboard/stress_chart_card.dart';
import '../../widgets/dashboard/status_cards_row.dart';
import '../../widgets/dashboard/device_status_bar.dart';
import '../../widgets/dashboard/behavior_state_card.dart';
import '../../widgets/dashboard/journal_quick_entry.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context, provider)),

            // ── Device status bar ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: DeviceStatusBar(provider: provider),
              ),
            ),

            // ── Feeding Timer (Hero CTA) ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: FeedingTimerCard(provider: provider),
              ),
            ),

            // ── Current Behavior State ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: BehaviorStateCard(provider: provider),
              ),
            ),

            // ── Time-to-Calm ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TimeToCalmCard(provider: provider),
              ),
            ),

            // ── Stress Reduction Chart ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: StressChartCard(provider: provider),
              ),
            ),

            // ── Status Cards Row ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: StatusCardsRow(provider: provider),
              ),
            ),

            // ── Journal Quick Entry ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: JournalQuickEntry(provider: provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PetHealthProvider provider) {
    final pet = provider.pet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Pet avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sageGreen, width: 2.5),
            ),
            child: const Center(
              child: Text('🐶', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_greeting()}!',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                pet.name,
                style: AppTextStyles.headlineLarge,
              ),
            ],
          ),
          const Spacer(),
          // Notification bell
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}
