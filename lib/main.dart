// =============================================================================
// main.dart — 应用入口 & 全局路由守卫
// =============================================================================
// 职责：
//   1. 初始化 Firebase
//   2. 配置系统 UI（竖屏锁定、状态栏透明）
//   3. 通过 _AuthGate 根据 Firebase 登录状态自动决定显示登录页还是主页
//
// 路由逻辑（_AuthGate）：
//   ┌─────────────────────────────────────────────────────────────┐
//   │  Firebase 未初始化  →  AuthScreen(firebaseAvailable: false)  │
//   │                        （纯 UI 预览模式，按钮直接跳主页）      │
//   │  Firebase 已初始化，等待状态  →  SplashScreen（加载动画）     │
//   │  authStateChanges 返回 User  →  MainNavScreen（主页）        │
//   │  authStateChanges 返回 null  →  AuthScreen（登录页）         │
//   └─────────────────────────────────────────────────────────────┘
//
// 为什么用 StreamBuilder 而不是 Navigator？
//   StreamBuilder 监听 Firebase auth 流，登录/退出时自动重建 Widget 树，
//   无需手动调用 Navigator.push，彻底避免路由栈混乱导致退出无效的问题。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'providers/pet_health_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/main_nav_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'theme/app_theme.dart';

// Firebase 是否初始化成功的全局标志。
// 使用全局变量（而非 Provider）是因为它在 runApp 前就确定了，
// 且只需在 _AuthGate 这一处读取。
bool _firebaseReady = false;

void main() async {
  // 确保 Flutter 引擎绑定完成，才能调用 Firebase.initializeApp 等平台方法
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 初始化 Firebase，使用 firebase_options.dart 中为各平台配置的参数
    // [TODO: 异常处理] 若 google-services.json / GoogleService-Info.plist 配置错误，
    //   或网络完全断开，这里会抛出异常。当前处理：降级为 firebaseAvailable=false 的 UI 预览模式。
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
  } catch (_) {
    // Firebase 初始化失败时，App 进入纯 UI 模式（适合开发期无网络环境调试）
    _firebaseReady = false;
  }

  // 锁定竖屏方向，防止横屏布局破坏 UI
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 让状态栏透明，使 App 内容延伸到状态栏区域（配合 SafeArea 使用）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // 深色图标（适合浅色背景）
    ),
  );

  runApp(const PetotecoApp());
}

// =============================================================================
// PetotecoApp — 应用根 Widget
// =============================================================================
// 负责：全局 Provider 注入 + MaterialApp 配置
// Provider 在此处注册，整个 Widget 树都可通过 context.watch/read 访问。
class PetotecoApp extends StatelessWidget {
  const PetotecoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // PetHealthProvider：宠物健康数据（喂食计时、行为状态、BLE 设备等）
        ChangeNotifierProvider(create: (_) => PetHealthProvider()),
        // LocaleProvider：语言切换（中文/英文），控制整个 App 的文案语言
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      // Consumer<LocaleProvider> 确保语言切换后 MaterialApp 级别的文字也更新
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'Petoteco',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme, // 全局主题（颜色、字体、组件样式）
            builder: (context, child) {
              // 限制系统字体缩放范围：
              // 防止用户将系统字体放到极大时 App 布局破坏
              final mediaQuery = MediaQuery.of(context);
              final clampedTextScaler = mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85, // 最小缩小到 85%
                maxScaleFactor: 1.0, // 最大保持 100%（不随系统放大）
              );
              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: clampedTextScaler),
                child: ScrollConfiguration(
                  behavior: _NoGlowScrollBehavior(), // 去掉列表滚动到底的蓝色光晕
                  child: child!,
                ),
              );
            },
            // 根页面：由 _AuthGate 根据登录状态决定显示哪个页面
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

// =============================================================================
// _AuthGate — 路由守卫
// =============================================================================
// 这是整个 App 导航的核心控制器。
// 通过监听 Firebase authStateChanges 流，实现无代码跳转的自动路由：
//   - 用户登录成功 → Firebase 推送 User 对象 → StreamBuilder 重建 → 显示 MainNavScreen
//   - 用户退出登录 → Firebase 推送 null → StreamBuilder 重建 → 显示 AuthScreen
//
// 为什么是 StatelessWidget？
//   因为 _AuthGate 本身不维护状态，所有状态由 Firebase 的 Stream 驱动。
//   使用 StreamBuilder 就足够了，无需 setState。
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // Firebase 未就绪时进入纯 UI 预览模式（开发调试用）
    if (!_firebaseReady) {
      return const AuthScreen(firebaseAvailable: false);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 等待 Firebase 返回初始登录状态（App 冷启动时有约 0.5-1 秒等待）
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // 有登录用户 → 进入主页（注意：这里不判断 emailVerified，如需强制验证邮箱可在此加逻辑）
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavScreen();
        }

        // 无登录用户 → 进入登录页
        return const AuthScreen(firebaseAvailable: true);
      },
    );
  }
}

// =============================================================================
// _SplashScreen — 启动加载页
// =============================================================================
// 在 Firebase 返回初始登录状态之前短暂显示，避免页面闪白或闪现登录页。
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🐾', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            CircularProgressIndicator(
              color: AppColors.sageGreen,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// 去掉列表滚动到边缘时的蓝色 glow 光晕效果（Android 默认有，iOS 没有）
class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // 直接返回 child，跳过 glow 效果渲染
  }
}
