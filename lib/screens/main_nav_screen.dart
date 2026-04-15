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

  @override
  void initState() {
    super.initState();
    // 登录成功后立即加载该用户的宠物数据
    // 使用 addPostFrameCallback 确保 Widget 树已构建完成（可安全访问 context）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPetData();
    });
  }

  // 根据当前 Firebase 登录用户加载其宠物档案
  // 业务逻辑：Firebase User.uid 作为数据 key，不同账号互相隔离
  Future<void> _loadUserPetData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      // 将 Firebase uid 传给 PetHealthProvider，从 SharedPreferences 读取该用户的宠物数据
      await context.read<PetHealthProvider>().loadPetForUser(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();

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
                  message: provider.alertMessage,
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
