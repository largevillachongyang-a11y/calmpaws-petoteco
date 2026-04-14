import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/pet_health_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/main_nav_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
            // ─────────────────────────────────────────────────────────────
            // 🔑 CRITICAL FIX: Clamp system textScaleFactor
            // 锁定字体缩放比在 0.85x ~ 1.0x，防止手机"大字体"模式破坏布局。
            // maxScaleFactor: 1.0 = 禁止系统字体放大影响 App 内排版。
            // minScaleFactor: 0.85 = 允许小屏幕适度缩小。
            // ─────────────────────────────────────────────────────────────
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final clampedTextScaler = mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.0,
              );
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: clampedTextScaler,
                ),
                // ScrollBehavior: 去掉列表滚动到顶/底时的蓝色 glow 光晕
                child: ScrollConfiguration(
                  behavior: _NoGlowScrollBehavior(),
                  child: child!,
                ),
              );
            },
            home: const MainNavScreen(),
          );
        },
      ),
    );
  }
}

/// 去掉 Android/Web 列表滚动到边缘时的蓝色 glow 光晕
class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // 不加任何 glow 效果
  }
}
