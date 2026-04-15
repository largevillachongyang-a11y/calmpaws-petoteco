import 'package:flutter/material.dart';

class AppColors {
  // Primary palette - Warm Natural
  static const Color cream = Color(0xFFFAF7F2);
  static const Color warmWhite = Color(0xFFFFFEFC);
  static const Color sageGreen = Color(0xFF7BAE8B);
  static const Color sageLight = Color(0xFFB8D4C0);
  static const Color sageMuted = Color(0xFFE8F2EC);
  static const Color warmOrange = Color(0xFFE8845A);
  static const Color warmOrangeLight = Color(0xFFF5C4B0);
  static const Color warmOrangeMuted = Color(0xFFFDF0EB);

  // Status colors
  static const Color alertRed = Color(0xFFE05C5C);
  static const Color alertRedMuted = Color(0xFFFCECEC);
  static const Color warningAmber = Color(0xFFF0A500);
  static const Color warningAmberMuted = Color(0xFFFFF6E0);
  static const Color successGreen = Color(0xFF5BAE7A);
  static const Color successMuted = Color(0xFFEAF6EF);

  // Text colors
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Card & surface
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEEE9E0);
  static const Color shadowColor = Color(0x14000000);

  // Chart colors
  static const Color chartBefore = Color(0xFFE8845A);
  static const Color chartAfter = Color(0xFF7BAE8B);
  static const Color chartGrid = Color(0xFFF0EBE3);
}

class AppTextStyles {
  static const String fontFamily = 'SF Pro Display';

  // Display - Hero numbers (e.g. "28 min")
  static const TextStyle displayLarge = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -1.5,
    height: 1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -1.0,
    height: 1.1,
  );

  // Headline
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body - accessibility optimized (minimum 16sp)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Label
  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.3,
  );

  // Metric value style
  static TextStyle metricValue({Color? color}) => TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w800,
    color: color ?? AppColors.textPrimary,
    letterSpacing: -1.0,
    height: 1.0,
  );

  static TextStyle metricUnit({Color? color}) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.textSecondary,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // ─────────────────────────────────────────────────────────────────────
      // 🔑 全局禁用 InkWell/InkResponse 的蓝色 splash/highlight/hover 蒙版
      // Web 端鼠标悬浮时 Material3 默认用 primaryContainer(偏蓝)填充，
      // 设为 NoSplash + 透明 highlightColor 一次性解决所有蒙版问题
      // ─────────────────────────────────────────────────────────────────────
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sageGreen,
        primary: AppColors.sageGreen,
        secondary: AppColors.warmOrange,
        surface: AppColors.cream,
        brightness: Brightness.light,
        error: AppColors.alertRed,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadowColor: AppColors.shadowColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineMedium,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBackground,
        selectedItemColor: AppColors.sageGreen,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.warmOrange),
          foregroundColor: WidgetStateProperty.all(AppColors.textOnDark),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      // ── TextButton：完全禁用蓝色 hover/splash ───────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.sageGreen),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      // ── OutlinedButton：完全禁用蓝色 hover/splash ───────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.sageGreen),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.sageMuted,
        selectedColor: AppColors.sageGreen,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
      // ── Dialog内按钮也禁用蓝色蒙版 ──────────────────────────────────────────
      // Dialog在Material3里有自己的buttonTheme，会覆盖全局textButtonTheme
      // 必须在此单独声明，否则Dialog里的TextButton鼠标悬停仍显示蓝色
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.cardBackground,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

// Spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

// Border radius constants
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 20.0;
  static const double xl = 28.0;
  static const double xxl = 36.0;
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(20));
}
