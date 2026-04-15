// =============================================================================
// dashboard_screen.dart — 健康仪表盘（首页 Tab）
// =============================================================================
// 这是用户每天最常用的页面，展示宠物当前实时健康状态。
//
// 页面构成（从上到下）：
//   Header      — 宠物头像 + 宠物名（pet.name，非用户名）+ 问候语 + 通知铃
//   DeviceStatusBar — BLE 设备连接状态 + 电量 + 信号强度
//   FeedingTimerCard  — 核心 CTA：「已喂食 ZenBelly」按钮 + 计时器
//   BehaviorStateCard — 当前行为状态（平静/踱步/应激/玩耍/发抖）
//   TimeToCalmCard    — Time-to-Calm 趋势（上次 vs 平均）
//   StressChartCard   — 14 天压力折线图
//   StatusCardsRow    — 活动量 / 昨晚睡眠 / 应激次数 三小卡片
//   JournalQuickEntry — 今日快速记录（大便/心情/食欲/精力）
//
// 数据来源：
//   全部从 PetHealthProvider 读取，Provider 通过 BLE 数据流实时更新。
//   [TODO: API 需求] 真实后端接入后，部分历史数据应从服务端加载，
//   如 14 天压力历史：GET /api/health-stats/{petId}?days=14
//
// 为什么用 StatelessWidget？
//   页面本身不持有状态，所有数据来自 PetHealthProvider。
//   通过 context.watch<PetHealthProvider>() 在 Provider 变化时自动重建。
// =============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
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
      body: SafeArea(top: false,
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
    final s = context.watch<LocaleProvider>().strings;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting(s)}!',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  pet.name,
                  style: AppTextStyles.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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

  String _greeting(dynamic s) {
    final h = DateTime.now().hour;
    if (h < 12) return s.greetingMorning;
    if (h < 17) return s.greetingAfternoon;
    return s.greetingEvening;
  }
}
