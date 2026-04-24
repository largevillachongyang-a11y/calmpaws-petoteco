// =============================================================================
// onboarding_screen.dart — 设备首次配对引导（Onboarding）
// =============================================================================
//
// 触发条件：
//   用户首次登录（或从未完成引导）时，MainNavScreen.initState 检测
//   SharedPreferences 中的 "onboarding_shown" 标志。
//   若标志不存在，调用 OnboardingScreen.showIfNeeded(context) 弹出此引导。
//
// 展示方式：
//   使用 showModalBottomSheet 全屏底部弹出（isDismissible: false 强制阅读）。
//   用户点击「完成」或「跳过」后写入标志，之后永不再弹出。
//
// 步骤设计（5步）：
//   Step 1 — 欢迎 🐾：介绍 App 功能，建立信任感
//   Step 2 — 充电 🔋：首次使用前充电 2 小时
//   Step 3 — 开启蓝牙 📡：手机蓝牙设置
//   Step 4 — 连接设备 🔗：在宠物页点击「连接设备」
//   Step 5 — 完成 ✅：佩戴项圈，开始使用
//
// 持久化：
//   SharedPreferences key: "onboarding_shown" = true
//   写入时机：用户点击任意完成/跳过按钮
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

// SharedPreferences 中标记引导是否已展示过的 key
const String _kOnboardingShownKey = 'onboarding_shown';

// =============================================================================
// OnboardingScreen — 静态入口方法
// =============================================================================
class OnboardingScreen {
  /// 检查是否需要显示引导，若需要则弹出全屏引导 BottomSheet。
  ///
  /// 设计原则：
  ///   - 使用 SharedPreferences 持久化「已显示」标志
  ///   - 仅在「从未显示过」时弹出（用 await 等待 prefs 异步加载）
  ///   - 调用方在 addPostFrameCallback 中调用，确保 Widget 树已构建
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_kOnboardingShownKey) ?? false;

    // 若已显示过，直接返回
    if (alreadyShown) return;

    // 写入标志（即使用户未完成引导也不再重复弹出）
    // 这样避免每次登录都弹，仅首次弹出
    await prefs.setBool(_kOnboardingShownKey, true);

    // context 检查，确保 Widget 仍然挂载
    if (!context.mounted) return;

    // 弹出引导 BottomSheet（不可通过背景点击关闭，强制用户阅读或主动跳过）
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,   // 允许内容高于半屏
      isDismissible: false,        // 禁止点击背景关闭
      enableDrag: false,           // 禁止下滑关闭
      backgroundColor: Colors.transparent, // 使用自定义圆角背景
      builder: (_) => _OnboardingBottomSheet(
        isZh: context.read<LocaleProvider>().isZh,
      ),
    );
  }

  /// 调试用：重置「已显示」标志，下次打开 App 会再次显示引导。
  /// 仅在 kDebugMode 时调用（在 Profile Debug 菜单中）。
  static Future<void> resetForDebug() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingShownKey);
  }
}

// =============================================================================
// _OnboardingBottomSheet — 5步引导内容
// =============================================================================
class _OnboardingBottomSheet extends StatefulWidget {
  final bool isZh;
  const _OnboardingBottomSheet({required this.isZh});

  @override
  State<_OnboardingBottomSheet> createState() => _OnboardingBottomSheetState();
}

class _OnboardingBottomSheetState extends State<_OnboardingBottomSheet> {
  int _currentStep = 0;  // 当前步骤索引（0~4）
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 切换到下一步，最后一步时关闭引导
  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      // 最后一步：关闭引导
      Navigator.of(context).pop();
    }
  }

  /// 跳过引导
  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(widget.isZh);

    return Container(
      // 容器高度：屏幕高度的 78%，确保内容充分展示
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          // ── 顶部拖动条（视觉提示）──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── 标题栏：跳过按钮 + 步骤指示器 ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 步骤点指示器
                Row(
                  children: List.generate(5, (i) => _StepDot(isActive: i == _currentStep, isCompleted: i < _currentStep)),
                ),
                // 跳过按钮（最后一步隐藏）
                if (_currentStep < 4)
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      overlayColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: Text(
                      widget.isZh ? '跳过' : 'Skip',
                      style: AppTextStyles.labelSmall,
                    ),
                  )
                else
                  const SizedBox(width: 56), // 占位对齐
              ],
            ),
          ),

          // ── 步骤内容区（PageView 实现平滑翻页）─────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // 禁止手势滑动，只能点按钮
              itemCount: steps.length,
              onPageChanged: (i) => setState(() => _currentStep = i),
              itemBuilder: (_, i) => _StepPage(step: steps[i]),
            ),
          ),

          // ── 底部按钮区 ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  _currentStep < 4
                      ? (widget.isZh ? '下一步' : 'Next')
                      : (widget.isZh ? '开始使用 🐾' : 'Get Started 🐾'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 5 个步骤的内容数据
  List<_StepData> _buildSteps(bool isZh) => [
    // ── Step 1：欢迎 ──────────────────────────────────────────────────────
    _StepData(
      emoji: '🐾',
      title: isZh ? '欢迎来到 Petoteco！' : 'Welcome to Petoteco!',
      description: isZh
          ? '通过 ZenBelly 项圈，实时监测爱宠的行为与健康状态。\n\n让我们用 2 分钟完成设备设置，开始记录宠物每一个珍贵时刻。'
          : 'ZenBelly collar tracks your pet\'s behavior and wellness in real time.\n\nLet\'s take 2 minutes to set up your device and start recording every precious moment.',
      tips: [],
    ),
    // ── Step 2：充电 ──────────────────────────────────────────────────────
    _StepData(
      emoji: '🔋',
      title: isZh ? '首次使用前充电' : 'Charge Before First Use',
      description: isZh
          ? '为确保项圈正常工作，首次使用前请充电至少 2 小时。'
          : 'To ensure the collar works properly, please charge it for at least 2 hours before first use.',
      tips: isZh
          ? ['使用随附 USB-C 充电线', '充电指示灯闪烁 → 充电中', '充电指示灯长亮 → 充电完成']
          : ['Use the included USB-C cable', 'LED flashing → Charging', 'LED solid → Fully charged'],
    ),
    // ── Step 3：开启蓝牙 ──────────────────────────────────────────────────
    _StepData(
      emoji: '📡',
      title: isZh ? '开启手机蓝牙' : 'Enable Bluetooth',
      description: isZh
          ? '项圈通过蓝牙低功耗（BLE）与手机通信，请确保手机蓝牙已开启。'
          : 'The collar communicates via Bluetooth Low Energy (BLE). Please make sure Bluetooth is enabled on your phone.',
      tips: isZh
          ? ['iOS：设置 → 蓝牙 → 打开', 'Android：下拉快捷菜单 → 蓝牙图标', '保持手机与项圈距离在 10 米以内']
          : ['iOS: Settings → Bluetooth → On', 'Android: Swipe down → Bluetooth icon', 'Keep phone within 10 meters of the collar'],
    ),
    // ── Step 4：连接设备 ──────────────────────────────────────────────────
    _StepData(
      emoji: '🔗',
      title: isZh ? '连接 ZenBelly 项圈' : 'Connect Your Collar',
      description: isZh
          ? '前往「宠物」页面，点击「连接设备」按钮，手机会自动搜索并连接附近的 ZenBelly 项圈。'
          : 'Go to the "My Pet" tab and tap "Connect Device". Your phone will automatically scan and connect to the nearby ZenBelly collar.',
      tips: isZh
          ? ['将手机靠近项圈 30cm 以内', '首次连接约需 5–10 秒', '连接成功后状态栏显示 🟢 实时']
          : ['Hold phone within 30cm of collar', 'First connection takes 5–10 seconds', 'Status bar shows 🟢 Live when connected'],
    ),
    // ── Step 5：完成 ──────────────────────────────────────────────────────
    _StepData(
      emoji: '✅',
      title: isZh ? '佩戴项圈，开始监测！' : 'Put On the Collar — You\'re All Set!',
      description: isZh
          ? '将项圈戴在宠物颈部，保留两指宽松度（避免过紧造成不适）。\n\n项圈连接后会自动开始采集行为数据，30 秒内仪表盘将开始显示实时状态。'
          : 'Put the collar on your pet\'s neck with a 2-finger gap (not too tight). \n\nOnce connected, the collar automatically starts collecting behavioral data. Your dashboard will show live status within 30 seconds.',
      tips: isZh
          ? ['✂️ 过长的链条可以裁剪至合适长度', '🛁 洗澡前请取下项圈（防水等级 IPX4）', '🔋 建议每 3 天充一次电']
          : ['✂️ Trim excess strap to fit', '🛁 Remove before bathing (IPX4 rated)', '🔋 Charge every 3 days for best performance'],
    ),
  ];
}

// =============================================================================
// _StepData — 步骤内容数据结构
// =============================================================================
class _StepData {
  final String emoji;
  final String title;
  final String description;
  final List<String> tips; // 小贴士列表（可为空）

  const _StepData({
    required this.emoji,
    required this.title,
    required this.description,
    required this.tips,
  });
}

// =============================================================================
// _StepPage — 单个步骤页面布局
// =============================================================================
class _StepPage extends StatelessWidget {
  final _StepData step;
  const _StepPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 大 Emoji 图标
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.sageMuted,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Center(
              child: Text(step.emoji, style: const TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 24),

          // 步骤标题
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // 步骤描述
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),

          // 小贴士（若有）
          if (step.tips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.divider,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: step.tips.map((tip) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    tip,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// _StepDot — 步骤指示点
// =============================================================================
class _StepDot extends StatelessWidget {
  final bool isActive;
  final bool isCompleted;
  const _StepDot({required this.isActive, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.sageGreen
        : isCompleted
            ? AppColors.sageGreen.withValues(alpha: 0.35)
            : AppColors.textMuted.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: isActive ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
