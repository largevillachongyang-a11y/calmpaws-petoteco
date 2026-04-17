// =============================================================================
// main_nav_screen.dart — 主导航框架
// =============================================================================
// 职责：
//   1. 底部 Tab 栏导航（健康/宠物/商城/我的）
//   2. 全局预警横幅（AlertBanner）悬浮在所有页面顶部
//   3. 通过 IndexedStack 保持各 Tab 页面状态（切换 Tab 不会重建页面）
//   4. 登录后加载当前用户的宠物数据（loadPetForUser）
//
// 导航设计原则：
//   • IndexedStack 保留所有页面实例，切换无延迟，但内存占用稍高
//   • 如内存紧张可改为按需构建（pageIndex == _currentIndex 时才渲染）
//   • _currentIndex 仅本地状态，不需要 Provider
//
// 用户数据加载流程：
//   _AuthGate → 检测到 Firebase User → 显示 MainNavScreen
//   → initState 调用 PetHealthProvider.loadPetForUser(uid)
//   → SharedPreferences 读取该用户的宠物数据
//   → Dashboard 和宠物页面自动刷新显示该用户的宠物名
//
// 退出登录流程：
//   用户在 ProfileScreen 点击退出 → AuthService.signOut() → Firebase 清除状态
//   → _AuthGate 的 StreamBuilder 收到 authStateChanges(null) → 重建显示 AuthScreen
//   → PetHealthProvider.clearUserData() 清除宠物数据（防止下一个用户看到上一个人的数据）
//   整个流程无需手动 Navigator.pop，由 StreamBuilder 自动完成。
// =============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/pet_health_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'pet/pet_screen.dart';
import 'shop/shop_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/common/alert_banner.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    PetScreen(),
    ShopScreen(),
    ProfileScreen(),
  ];

  // 监听 PetHealthProvider 的预警状态，自动将预警转发到通知中心
  // 这样用户就算关闭预警横幅，历史通知记录仍然保留
  String _lastAlertType = ''; // 记录上一次处理的预警类型，防止重复写入

  @override
  void initState() {
    super.initState();
    // 登录成功后立即加载该用户的宠物数据
    // 使用 addPostFrameCallback 确保 Widget 树已构建完成（可安全访问 context）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPetData();
      // 注册 PetHealthProvider 监听器，预警变化时自动写入通知
      context.read<PetHealthProvider>().addListener(_onPetHealthChanged);
      // 注册喂食完成回调
      _registerFeedingCallback();
    });
  }

  @override
  void dispose() {
    // 退出页面时取消监听，防止内存泄漏
    // 同时清除所有回调，避免喂食/预警/总结完成后试图访问已卸载的 context
    final petProvider = context.read<PetHealthProvider>();
    petProvider.removeListener(_onPetHealthChanged);
    petProvider.onFeedingCompleted = null;
    petProvider.onAlertNotification = null;
    petProvider.onDailySummaryReady = null;
    super.dispose();
  }

  // 注册所有 P1 回调（喂食完成 + 预警通知 + 每日总结）
  // PetHealthProvider 通过回调将事件转发到 NotificationProvider，避免循环依赖
  void _registerFeedingCallback() {
    if (!mounted) return;
    final petProvider = context.read<PetHealthProvider>();
    final isZh = context.read<LocaleProvider>().isZh;

    // ── 喂食完成通知 ──────────────────────────────────────────────────────────
    petProvider.onFeedingCompleted = (session) {
      if (!mounted) return;
      final notifProvider = context.read<NotificationProvider>();
      final petName = petProvider.pet.name;
      final ttcLabel = session.timeToCalm != null
          ? (session.timeToCalm! < 60
              ? '${session.timeToCalm}s'
              : '${session.timeToCalm! ~/ 60}m ${session.timeToCalm! % 60}s')
          : '--';

      notifProvider.addNotification(
        type: NotificationType.feeding,
        title: isZh ? '✅ 喂食记录完成' : '✅ Feeding Session Recorded',
        body: isZh
            ? '$petName 喂食后平静用时 $ttcLabel。ZenBelly 健康趋势已更新。'
            : '$petName calmed down in $ttcLabel after feeding. Trend updated.',
        actionRoute: 'dashboard',
      );
    };

    // ── P1 预警通知（发抖/应激频繁/昏睡）────────────────────────────────────
    // type: 'shiver_alert' | 'stress_frequent' | 'lethargy'
    petProvider.onAlertNotification = (type, title, body) {
      if (!mounted) return;
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.addNotification(
        type: NotificationType.alert,
        title: title,
        body: body,
        actionRoute: 'dashboard',
      );
    };

    // ── P1-3 每日健康总结通知（晚 20:00）──────────────────────────────────────
    petProvider.onDailySummaryReady = (summary) {
      if (!mounted) return;
      final notifProvider = context.read<NotificationProvider>();
      final summaryText = summary.toSummaryText(isZh);

      notifProvider.addNotification(
        type: NotificationType.system,
        title: isZh
            ? '📊 ${summary.petName} 今日健康总结'
            : '📊 ${summary.petName}\'s Daily Health Summary',
        body: summaryText,
        actionRoute: 'dashboard',
      );
    };
  }

  // 宠物健康数据变化时的回调（主要监听 AlertBanner 横幅预警状态）
  //
  // 设计原则：
  //   PetHealthProvider 不直接持有 NotificationProvider（避免循环依赖）
  //   而是由 MainNavScreen 作中间层，监听 PetHealthProvider 预警，转发到 NotificationProvider
  //
  // 防重复逻辑：
  //   _lastAlertType 记录上一次写入的预警类型
  //   只有预警类型发生变化时才写入新通知，避免 BLE 每秒触发频繁写入
  void _onPetHealthChanged() {
    if (!mounted) return;
    final petProvider = context.read<PetHealthProvider>();
    final notifProvider = context.read<NotificationProvider>();
    final isZh = context.read<LocaleProvider>().isZh;

    if (petProvider.hasAlert && petProvider.alertType != _lastAlertType) {
      _lastAlertType = petProvider.alertType;

      // activity 和 pacing_long 由监听器写入通知中心
      // shiver / stress_frequent / lethargy / sleep_disturbed 由回调直接写入（_registerFeedingCallback）
      if (petProvider.alertType == 'activity') {
        final petName = petProvider.pet.name;
        notifProvider.addNotification(
          type: NotificationType.alert,
          title: isZh ? '⚠️ 活动量偏低' : '⚠️ Activity Alert',
          body: isZh
              ? '$petName 今日活动量偏低，建议充分户外玩耍或联系兽医检查。'
              : "${petName}'s activity is below normal today. Consider a vet check.",
          actionRoute: 'dashboard',
        );
      } else if (petProvider.alertType == 'pacing_long') {
        // pacing_long 也通过回调写入，此处仅做横幅刷新，不重复写通知
      }
    } else if (!petProvider.hasAlert && _lastAlertType.isNotEmpty) {
      _lastAlertType = '';
    }
  }

  // 根据当前 Firebase 登录用户加载其宠物档案 + 通知数据
  // 业务逻辑：Firebase User.uid 作为数据 key，不同账号互相隔离
  //
  // 加载顺序：
  //   1. PetHealthProvider.loadPetForUser() — 加载宠物档案 + Firestore 历史数据
  //   2. NotificationProvider.loadForUser() — 加载历史通知（并发进行）
  //
  // 两者并发执行减少总等待时间
  Future<void> _loadUserPetData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      // 并发加载：宠物数据 + 通知历史，减少总等待时间
      await Future.wait([
        context.read<PetHealthProvider>().loadPetForUser(user.uid),
        context.read<NotificationProvider>().loadForUser(user.uid),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final isZh = context.watch<LocaleProvider>().isZh;
    final petName = provider.pet.name;

    // Bug1 修复：根据当前语言动态生成预警横幅文案，而非使用 Provider 内存储的固定字符串
    String localizedAlertMessage = provider.alertMessage;
    if (provider.hasAlert) {
      switch (provider.alertType) {
        case 'shiver':
          final mins = provider.continuousShiverSeconds ~/ 60;
          localizedAlertMessage = isZh
              ? '🆘 $petName 已持续发抖 $mins 分钟，请立即检查！'
              : '🆘 $petName has been shivering for ${mins}m. Check now!';
        case 'stress_frequent':
          localizedAlertMessage = isZh
              ? '⚠️ $petName 应激反应频繁，过去1小时超过10次'
              : '⚠️ $petName stress actions >10x in past hour';
        case 'lethargy':
          localizedAlertMessage = isZh
              ? '⚠️ $petName 白天异常静止，疑似昏睡（状态F）'
              : '⚠️ $petName unusually still all day — possible lethargy';
        case 'activity':
          localizedAlertMessage = isZh
              ? '⚠️ $petName 今日活动量偏低'
              : "⚠️ $petName's activity is below normal today.";
        default:
          localizedAlertMessage = provider.alertMessage;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        // ⚠️ 修复：把 Stack + AlertBanner 放在 SafeArea 内部
        // 这样预警横幅不会遮挡状态栏，高度紧凑只占一行
        child: Stack(
          children: [
            // 页面内容区（各 Tab 页内部各自有 SafeArea）
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            // 全局预警横幅 —— 悬浮在内容顶部，不含系统状态栏区域
            if (provider.hasAlert)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AlertBanner(
                  message: localizedAlertMessage,
                  alertType: provider.alertType,
                  onDismiss: provider.dismissAlert,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // 使用 watch 确保语言切换后底部导航标签实时更新
    final s = context.watch<LocaleProvider>().strings;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.favorite_rounded,
                label: s.navHealth,
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.pets_rounded,
                label: s.navMyPet,
                isSelected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.shopping_bag_rounded,
                label: s.navShop,
                isSelected: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: s.navMe,
                isSelected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sageMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.sageGreen : AppColors.textMuted,
              size: 26,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.sageGreen
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
