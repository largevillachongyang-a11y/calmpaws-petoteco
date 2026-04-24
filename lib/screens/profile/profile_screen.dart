// =============================================================================
// profile_screen.dart — "我的" 个人中心页面
// =============================================================================
// 展示内容：
//   1. 用户信息头像区：显示 Firebase 真实用户名和邮箱
//      • displayName: 注册时填写的姓名（通过 updateDisplayName 保存）
//      • email: Firebase Auth 账号邮箱
//      [注意] 这里的名字是「用户名」，不是「宠物名」。
//              宠物名（如 Biscuit）显示在 Dashboard 和宠物页面顶部。
//
//   2. 订阅卡片（_buildSubscriptionCard）：
//      当前为 Demo 数据，显示固定的订阅状态和产品信息。
//      [TODO: API 需求] 接入后端时替换为：GET /api/subscriptions/{userId}
//        返回: { plan, status, nextBillingDate, daysLeft }
//
//   3. 菜单列表（_buildMenuSection）：
//      各菜单项点击弹出对应 Dialog/BottomSheet，均已实现。
//
//   4. 退出登录（_showSignOutDialog）：
//      调用 AuthService.signOut() → Firebase 清除登录状态
//      → _AuthGate StreamBuilder 自动跳回登录页（无需手动 Navigator）
//
// 为什么是 StatefulWidget？
//   需要响应语言切换（context.watch<LocaleProvider>()），
//   StatefulWidget 配合 build() 中的 watch 确保语言切换后整页重建。
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../dev/edge_impulse_screen.dart';
import '../dev/ota_screen.dart';
import '../onboarding/onboarding_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen — StatefulWidget（修复语言切换 & 菜单弹窗）
// 根本原因：StatelessWidget 中的辅助方法无法响应 context.watch()，
// 导致语言切换按钮不刷新、菜单 context 失效。
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    // 使用 watch 确保语言切换后整个页面重建
    final provider = context.watch<PetHealthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final s = localeProvider.strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, localeProvider, s)),
            SliverToBoxAdapter(child: _buildSubscriptionCard(context, s)),
            SliverToBoxAdapter(child: _buildMenuSection(context, provider, s)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Header（用户信息 + 语言切换）──────────────────────────────────────────
  Widget _buildHeader(BuildContext context, LocaleProvider localeProvider, dynamic s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(22),
      // clipBehavior: 防止 InkWell/ripple 效果溢出圆角边界，避免蓝色蒙版残留
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // 用户信息行
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.sageGreen, Color(0xFF5A9970)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 字体放大时自动缩小，不截断
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        () {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return 'Guest';
                          if (user.displayName != null && user.displayName!.isNotEmpty) {
                            return user.displayName!;
                          }
                          // 没有 displayName 时用邮箱 @ 前的部分
                          final email = user.email ?? '';
                          return email.contains('@') ? email.split('@').first : email;
                        }(),
                        style: AppTextStyles.headlineMedium,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        FirebaseAuth.instance.currentUser?.email ?? '',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 订阅状态标签
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sageMuted,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.profileSubscriber,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.sageGreen,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.cream, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 语言切换按钮 ─────────────────────────────────────────────────
          // 用 GestureDetector 替代 Material+InkWell，避免 WebView/微信浏览器
          // 中 InkWell splash/highlight 产生蓝色蒙版残留
          GestureDetector(
            onTap: () {
              localeProvider.toggle();
              if (!mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeProvider.isZh
                        ? '语言已切换为中文 🇨🇳'
                        : 'Language switched to English 🇺🇸',
                  ),
                  backgroundColor: AppColors.sageGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Row(
                children: [
                  // 国旗（固定大小，不受字体缩放影响）
                  Text(
                    localeProvider.languageFlag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  // 标签 — 用 Flexible 防止溢出
                  const Flexible(
                    child: Text(
                      'Language / 语言',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 当前语言徽章 — 固定宽度防止挤压
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      localeProvider.isZh ? '中文' : 'EN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 切换提示箭头图标，简洁不占多余空间
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 订阅卡片 ─────────────────────────────────────────────────────────────
  Widget _buildSubscriptionCard(BuildContext context, dynamic s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8845A), Color(0xFFD4694A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmOrange.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.subLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.subActive,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 订阅详情：两行两列，避免中文时三格挤在一行溢出
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _SubStat(label: s.profilePlan, value: s.profilePlanValue)),
                  const SizedBox(width: 8),
                  Expanded(child: _SubStat(label: s.profileZenBelly, value: s.profileDaysLeft)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _SubStat(label: s.profileNextBilling, value: s.profileNextBillingDate)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showManageSubscription(context, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        s.profileManage,
                        style: const TextStyle(
                          color: AppColors.warmOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showReorderDialog(context, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        s.profileReorder,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 菜单列表 ──────────────────────────────────────────────────────────────
  Widget _buildMenuSection(BuildContext context, PetHealthProvider provider, dynamic s) {
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
        children: [
          _MenuItem(
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.sageGreen,
            label: s.profileOrders,
            onTap: () => _showOrderHistory(context, s),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.support_agent_rounded,
            iconColor: AppColors.warmOrange,
            label: s.profileSupport,
            badge: s.profileSupportBadge,
            onTap: () => _showSupport(context, s),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.help_outline_rounded,
            iconColor: AppColors.sageGreen,
            label: s.profileDeviceGuide,
            onTap: () => _showDeviceGuide(context, s),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.system_update_alt_rounded,
            iconColor: const Color(0xFF6B7FD4),
            label: s.profileOta,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OtaScreen()),
            ),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.psychology_rounded,
            iconColor: AppColors.warningAmber,
            label: s.profileEdgeImpulse,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EdgeImpulseScreen()),
            ),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF6B7FD4),
            label: s.profileReports,
            onTap: () => _showHealthReports(context, provider, s),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.notifications_none_rounded,
            iconColor: AppColors.warmOrange,
            label: s.profileNotifications,
            onTap: () => _showNotifDialog(context),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.textMuted,
            label: s.profilePrivacy,
            onTap: () => _showPrivacyDialog(context),
          ),
          const _Divider(),
          _MenuItem(
            icon: Icons.logout_rounded,
            iconColor: AppColors.alertRed,
            label: s.profileSignOut,
            onTap: () => _showSignOut(context, s),
          ),
          const _Divider(),
          // ── 删除账号（App Store / Google Play 强制要求）────────────────────
          _MenuItem(
            icon: Icons.delete_forever_rounded,
            iconColor: AppColors.alertRed.withValues(alpha: 0.7),
            label: s.profileDeleteAccount,
            onTap: () => _showDeleteAccount(context, s, provider),
          ),
          // ── Debug: 手动触发每日总结（仅开发模式）─────────────────────────
          if (kDebugMode) ...[
            const _Divider(),
            _MenuItem(
              icon: Icons.bug_report_outlined,
              iconColor: AppColors.warningAmber,
              label: '🛠 触发每日总结（测试）',
              onTap: () {
                provider.triggerDailySummaryForTest();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ 每日总结已触发，检查通知中心'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            const _Divider(),
            _MenuItem(
              icon: Icons.restart_alt_rounded,
              iconColor: AppColors.sageGreen,
              label: '🛠 重置 Onboarding（测试）',
              onTap: () async {
                await OnboardingScreen.resetForDebug();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Onboarding 已重置，下次登录将重新显示'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 弹窗方法（全部使用 StatefulWidget 的 mounted context，确保安全）
  // ─────────────────────────────────────────────────────────────────────────

  void _showManageSubscription(BuildContext context, dynamic s) {
    final petName = context.read<PetHealthProvider>().pet.name;
    showModalBottomSheet(
      barrierColor: Colors.black54,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: AppColors.cream,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          28 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(s.subSheetTitle, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(s.subSheetBody(petName), style: AppTextStyles.bodyMedium),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.sageMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.subProgress, style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 8),
                  _ProgressRow(label: s.subAnxiety, value: '↓ 34%', color: AppColors.sageGreen),
                  _ProgressRow(label: s.subTtc, value: '↓ 18%', color: AppColors.sageGreen),
                  _ProgressRow(label: s.subSleep, value: '↑ 12%', color: AppColors.sageGreen),
                  const SizedBox(height: 8),
                  Text(
                    s.subWarning,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.alertRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                label: Text(s.subPause),
                style: OutlinedButton.styleFrom(

                  overlayColor: Colors.transparent,                  foregroundColor: AppColors.warmOrange,
                  side: const BorderSide(color: AppColors.warmOrangeLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  s.subCancel,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderHistory(BuildContext context, dynamic s) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.profileOrders),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OrderRow(date: s.formatDate(DateTime(2025, 7, 14)), item: 'ZenBelly 3-Pack', status: s.orderDelivered, amount: '\$99.00'),
            _OrderRow(date: s.formatDate(DateTime(2025, 4, 8)),  item: 'ZenBelly Refill', status: s.orderDelivered, amount: '\$34.99'),
            _OrderRow(date: s.formatDate(DateTime(2025, 1, 2)),  item: 'Starter Bundle',  status: s.orderDelivered, amount: '\$99.00'),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }

  void _showSupport(BuildContext context, dynamic s) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.supportTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.supportDesc, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            Text(s.supportResponse, style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            // 联系方式
            _ContactRow(icon: Icons.email_outlined, label: 'support@petoteco.com'),
            const SizedBox(height: 6),
            _ContactRow(icon: Icons.chat_bubble_outline_rounded, label: 'Live Chat (9am–6pm PST)'),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.close),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
            child: Text(s.supportChat, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeviceGuide(BuildContext context, dynamic s) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.guideTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideStep(step: 1, text: s.guideStep1),
              _GuideStep(step: 2, text: s.guideStep2),
              _GuideStep(step: 3, text: s.guideStep3),
              _GuideStep(step: 4, text: s.guideStep4),
              _GuideStep(step: 5, text: s.guideStep5),
              _GuideStep(step: 6, text: s.guideStep6),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
            child: Text(s.guideGotIt, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHealthReports(BuildContext context, PetHealthProvider provider, dynamic s) {
    final sessions = provider.sessionHistory;
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.profileReports),
        content: sessions.isEmpty
            ? Text(s.timerNoSessionDesc, style: AppTextStyles.bodyMedium)
            : SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sessions
                      .take(5)
                      .map((session) => _SessionReportRow(session: session))
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }

  void _showSignOut(BuildContext context, dynamic s) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.signOutTitle),
        content: Text(s.signOutConfirm, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(overlayColor: Colors.transparent),
            onPressed: () async {
              Navigator.pop(ctx); // 先关弹窗
              // 退出前同时清除宠物数据和通知数据，防止下一个账号登录后短暂显示上一个用户的数据
              if (ctx.mounted) {
                ctx.read<PetHealthProvider>().clearUserData();
                ctx.read<NotificationProvider>().clearUserData(); // 清除通知记录
              }
              await AuthService().signOut(); // 真正退出登录
              // AuthGate 监听 Firebase 状态变化，会自动跳转回登录页
            },
            child: Text(s.signOutBtn, style: const TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
  }

  // ── 删除账号弹窗 ──────────────────────────────────────────────────────────
  // 需要用户手动输入 "DELETE" 确认，防止误操作。
  // 删除成功后清空本地数据，Firebase authStateChanges 推送 null，自动跳回登录页。
  void _showDeleteAccount(BuildContext context, dynamic s, PetHealthProvider provider) {
    final TextEditingController confirmCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      barrierColor: Colors.black54,
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 22),
              const SizedBox(width: 8),
              Text(s.deleteAccountTitle,
                  style: const TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.deleteAccountWarning, style: AppTextStyles.bodySmall),
              const SizedBox(height: 16),
              Text(s.deleteAccountConfirmHint,
                  style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                onChanged: (_) => setDlgState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () {
                confirmCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(s.cancel, style: const TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: (confirmCtrl.text.trim().toUpperCase() == 'DELETE' && !isLoading)
                  ? () async {
                      setDlgState(() => isLoading = true);
                      final isZh = context.read<LocaleProvider>().isZh;

                      // 1. 先清除 Firestore 数据
                      // （Firestore 批量删除可在此扩展：使用 AuthService().currentUser?.uid 作为 key）
                      // 当前由 Security Rules 在账号删除后拒绝访问，无需显式删除 Firestore 文档

                      // 2. 清除本地 Provider 数据
                      if (ctx.mounted) {
                        ctx.read<PetHealthProvider>().clearUserData();
                        ctx.read<NotificationProvider>().clearUserData();
                      }

                      // 3. 删除 Firebase Auth 账号
                      final err = await AuthService().deleteAccount(isZh: isZh);

                      if (!ctx.mounted) return;
                      confirmCtrl.dispose();
                      Navigator.pop(ctx);

                      if (err != null) {
                        // 失败：显示错误 SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err),
                            backgroundColor: AppColors.alertRed,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                      // 成功：authStateChanges 推送 null，AuthGate 自动跳回登录页
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: confirmCtrl.text.trim().toUpperCase() == 'DELETE' && !isLoading
                    ? AppColors.alertRed
                    : AppColors.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(s.deleteAccountBtn),
            ),
          ],
        ),
      ),
    );
  }

  void _showReorderDialog(BuildContext context, dynamic s) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.profileReorder),
        content: Text(
          s.reorderBody,
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 打开商城弹窗 — 实际 App 中将跳转 WebView
              _showStoreDialogFromProfile(context, s);
            },
            style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
            child: Text(s.shopOpenBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStoreDialogFromProfile(BuildContext context, dynamic s) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(s.shopOpenTitle),
        content: Text(s.shopOpenDesc),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.sageGreen, overlayColor: Colors.transparent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
            child: Text(s.shopOpenBtn, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 消息通知弹窗 — 内部直接读取当前语言，不依赖外部传入的 String
  void _showNotifDialog(BuildContext context) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) {
        // 内部用 Consumer 确保内容总是当前语言
        return Consumer<LocaleProvider>(
          builder: (_, lp, __) {
            final ls = lp.strings;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: Text(ls.profileNotifications),
              content: Text(ls.notifSettingsBody, style: AppTextStyles.bodyMedium),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
                  child: Text(ls.ok, style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 隐私弹窗 — 内部直接读取当前语言
  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      barrierColor: Colors.black54,
      context: context,
      builder: (ctx) {
        return Consumer<LocaleProvider>(
          builder: (_, lp, __) {
            final ls = lp.strings;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: Text(ls.profilePrivacy),
              content: Text(ls.privacyBody, style: AppTextStyles.bodyMedium),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
                  child: Text(ls.ok, style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 辅助小 Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SubStat extends StatelessWidget {
  final String label;
  final String value;
  const _SubStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FittedBox: 字体放大时自动缩小 label，防止溢出
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // 图标容器
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              // 标签
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 徽章 + 箭头
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sageMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.sageGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 74, endIndent: 20);
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProgressRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final String date;
  final String item;
  final String status;
  final String amount;
  const _OrderRow({
    required this.date,
    required this.item,
    required this.status,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: AppTextStyles.labelLarge.copyWith(fontSize: 14)),
                Text(date, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: AppTextStyles.labelLarge.copyWith(fontSize: 14)),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.sageGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int step;
  final String text;
  const _GuideStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.sageGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.sageGreen),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _SessionReportRow extends StatelessWidget {
  final dynamic session;
  const _SessionReportRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final secs = session.timeToCalm as int? ?? 0;
    final mins = (secs / 60).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_timeAgo(session.feedTime as DateTime, s), style: AppTextStyles.bodySmall),
          Text(
            s.sessionMinToCalm(mins),
            style: AppTextStyles.labelLarge.copyWith(fontSize: 14, color: AppColors.sageGreen),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t, dynamic s) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return s.daysAgo(diff.inDays);
    if (diff.inHours > 0) return s.hoursAgo(diff.inHours);
    if (diff.inMinutes > 0) return s.minutesAgo(diff.inMinutes);
    return s.today;
  }
}
