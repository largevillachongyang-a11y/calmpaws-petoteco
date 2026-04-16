// =============================================================================
// locale_provider.dart — 应用语言状态管理
// =============================================================================
// 职责：管理中/英文切换，所有多语言文案通过 AppStrings 统一访问。
//
// 使用方式：
//   • 在 Widget 中读取文案：final s = context.watch<LocaleProvider>().strings;
//   • 快捷方式（Extension）：final s = context.s;
//   • 切换语言：context.read<LocaleProvider>().toggle();
//
// P0-2 语言偏好持久化：
//   • 用户手动切换语言后，通过 SharedPreferences 持久化到本地
//   • App 重启时优先读取已保存的偏好，其次才检测系统语言
//   • key: 'user_locale'，值为 'zh' 或 'en'
// =============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'user_locale';

  // 初始语言由系统语言决定，initLocale() 加载后会从 SharedPreferences 覆盖
  String _locale = _detectSystemLocale();

  static String _detectSystemLocale() {
    final sysLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return sysLang == 'zh' ? 'zh' : 'en';
  }

  String get locale => _locale;
  AppStrings get strings => AppStrings.of(_locale);
  bool get isZh => _locale == 'zh';

  // P0-2：App 启动时加载持久化的语言偏好
  // 调用时机：main.dart 初始化时，或 MultiProvider 创建后调用
  Future<void> initLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && (saved == 'zh' || saved == 'en')) {
        _locale = saved;
        notifyListeners();
      }
    } catch (e) {
      // 读取失败时保持系统默认语言，不影响正常使用
      assert(() {
        debugPrint('[LocaleProvider] initLocale error: $e');
        return true;
      }());
    }
  }

  void setLocale(String locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    _saveLocale(locale);
  }

  void toggle() {
    _locale = _locale == 'en' ? 'zh' : 'en';
    notifyListeners();
    _saveLocale(_locale);
  }

  // P0-2：持久化语言偏好到 SharedPreferences
  Future<void> _saveLocale(String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, locale);
    } catch (e) {
      assert(() {
        debugPrint('[LocaleProvider] _saveLocale error: $e');
        return true;
      }());
    }
  }

  String get languageLabel => _locale == 'en' ? '中文' : 'English';
  String get languageFlag => _locale == 'en' ? '🇨🇳' : '🇺🇸';
}

/// Convenience extension — access strings from BuildContext directly
extension LocaleContext on BuildContext {
  LocaleProvider get locale => Provider.of<LocaleProvider>(this, listen: true);
  AppStrings get s => Provider.of<LocaleProvider>(this, listen: true).strings;
}
