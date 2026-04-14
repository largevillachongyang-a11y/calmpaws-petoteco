import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sageMuted
              : Colors.transparent,
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
