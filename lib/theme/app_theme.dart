// =============================================================================
// app_theme.dart — 全局设计系统
// =============================================================================
// 包含：
//   AppColors     — 所有颜色常量（主色调为暖绿色 #7BAE8B，辅色为暖橙色 #E8845A）
//   AppTextStyles — 字体样式系统（基于 SF Pro Display，移动端最小 14sp）
//   AppTheme      — Flutter ThemeData 配置（Material3）
//   AppSpacing    — 间距常量（xs/sm/md/lg/xl/xxl）
//   AppRadius     — 圆角常量
//
// 重要设计决策：
//   1. useMaterial3: true — 启用 Material3 设计系统
//   2. splashFactory: NoSplash — 全局禁用点击水波纹，避免蓝色蒙版问题
//   3. surfaceTint: Colors.transparent — 禁用 Material3 的海拔着色层
//      （该层会根据 primary 颜色给组件表面染色，在绿色主题下会偏蓝）
//   4. focusColor: Colors.transparent — 禁用焦点高亮（Web 端键盘导航会触发）
//   5. scrim: Colors.black — Dialog/BottomSheet 遮罩为纯黑色
//
// ⚠️ 注意：修改颜色时请同时更新 AppColors 和 colorScheme.copyWith 中的对应值，
//          确保 Material3 自动生成的颜色被正确覆盖。
// =============================================================================
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
    // 先生成 colorScheme，然后完整覆盖所有蓝色相关颜色
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.sageGreen,
      primary: AppColors.sageGreen,
      secondary: AppColors.warmOrange,
      surface: AppColors.cream,
      brightness: Brightness.light,
      error: AppColors.alertRed,
      scrim: Colors.black,
    ).copyWith(
      // Material3 fromSeed 可能生成蓝色 primaryContainer/secondaryContainer
      // 强制覆盖为绿色调，彻底消灭一切蓝色来源
      primaryContainer: AppColors.sageMuted,
      secondaryContainer: const Color(0xFFFFF3E8),
      onPrimaryContainer: AppColors.sageGreen,
      onSecondaryContainer: AppColors.warmOrange,
      // surfaceContainerHighest 是 InkWell hover 的来源之一
      surfaceContainerHighest: AppColors.sageMuted,
      surfaceContainerHigh: AppColors.cream,
      surfaceContainer: AppColors.cream,
      surfaceContainerLow: AppColors.cream,
      surfaceContainerLowest: AppColors.cream,
      surfaceTint: Colors.transparent, // 消除 Material3 的主题着色层
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      // 确保 scrim/barrier 相关颜色为纯黑色
      scrim: Colors.black,
      shadow: Colors.black12,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // ─────────────────────────────────────────────────────────────────────
      // 🔑 全局禁用所有 InkWell/InkResponse 的蓝色 splash/highlight/hover 蒙版
      // ─────────────────────────────────────────────────────────────────────
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
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
      // ── 所有 Surface 相关 Widget 禁用 Material3 的 surfaceTint 蓝色渲染 ───
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.textPrimary),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      // ── Dialog内按钮也禁用蓝色蒙版 ──────────────────────────────────────────
      // Dialog在Material3里有自己的buttonTheme，会覆盖全局textButtonTheme
      // 必须在此单独声明，否则Dialog里的TextButton鼠标悬停仍显示蓝色
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.cardBackground,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // 强制 Dialog 遮罩为纯黑色，避免 Material3 scrim 颜色偏蓝
        barrierColor: Colors.black54,
      ),
      // ── BottomSheet：强制遮罩为纯黑色 ──────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        modalBackgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // Material3 BottomSheet 使用 colorScheme.scrim 作为遮罩
        // surfaceTintColor 会给表面添加着色层 - 设为透明
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black54,
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
