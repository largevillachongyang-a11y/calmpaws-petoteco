import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'providers/pet_health_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/main_nav_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'theme/app_theme.dart';

bool _firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
  } catch (_) {
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
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate — StatefulWidget，处理 Redirect 回调后的状态恢复
// ─────────────────────────────────────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // Web Redirect 回调处理中
  bool _processingRedirect = false;

  @override
  void initState() {
    super.initState();
    if (_firebaseReady && kIsWeb) {
      _handleRedirectResult();
    }
  }

  Future<void> _handleRedirectResult() async {
    setState(() => _processingRedirect = true);
    try {
      // 消费 Redirect 结果；普通刷新时返回空结果，不抛异常
      await FirebaseAuth.instance.getRedirectResult();
      // 成功后 authStateChanges 自动触发，StreamBuilder 自动切换页面
    } catch (_) {
      // 普通刷新或网络错误时忽略
    }
    if (mounted) setState(() => _processingRedirect = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return const AuthScreen(firebaseAvailable: false);
    }
    // Redirect 处理期间显示 splash，避免闪现登录页
    if (_processingRedirect) {
      return const _SplashScreen();
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavScreen();
        }
        return const AuthScreen(firebaseAvailable: true);
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
