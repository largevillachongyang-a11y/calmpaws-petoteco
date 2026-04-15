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

// Firebase是否成功初始化（Web预览时可能因appId未配置而失败）
bool _firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase（出错时降级为本地模式）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
  } catch (e) {
    // Web预览时Firebase可能未配置Web应用，降级运行
    _firebaseReady = false;
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const PetotecoApp());
}

class PetotecoApp extends StatelessWidget {
  const PetotecoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PetHealthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'Petoteco',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final clampedTextScaler = mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.0,
              );
              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: clampedTextScaler),
                child: ScrollConfiguration(
                  behavior: _NoGlowScrollBehavior(),
                  child: child!,
                ),
              );
            },
    // ── 根据登录状态决定显示哪个页面 ──────────────────────────────────
            // 🔧 临时：强制显示登录页预览（确认UI后改回 _AuthGate）
            home: const AuthScreen(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate — 监听 Firebase Auth 状态，自动切换登录页/主页
// ─────────────────────────────────────────────────────────────────────────────
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // Firebase未初始化（Web预览模式）→ 直接进主页
    if (!_firebaseReady) {
      return const MainNavScreen();
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 等待连接
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        // 已登录 → 进主页
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavScreen();
        }
        // 未登录 → 进登录页
        return const AuthScreen();
      },
    );
  }
}

// ── 启动加载页 ────────────────────────────────────────────────────────────────
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

/// 去掉列表滚动到边缘时的 glow 光晕
class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
