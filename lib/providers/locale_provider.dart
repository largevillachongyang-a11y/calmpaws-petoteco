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
// 语言状态说明：
//   • 初始语言根据系统语言自动检测（中文系统 → 'zh'，其他 → 'en'）
//   • 当前不持久化语言设置（App 重启后重新检测系统语言）
//   [TODO] 如需持久化用户手动选择的语言，在 toggle/setLocale 中用
//          shared_preferences 保存，并在 initState 时读取。
// =============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  // 根据设备系统语言自动设置默认语言
  String _locale = _detectSystemLocale();

  static String _detectSystemLocale() {
    // 获取系统语言，中文系统默认中文，其他默认英文
    final sysLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return sysLang == 'zh' ? 'zh' : 'en';
  }

  String get locale => _locale;
  AppStrings get strings => AppStrings.of(_locale);
  bool get isZh => _locale == 'zh';

  void setLocale(String locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void toggle() {
    _locale = _locale == 'en' ? 'zh' : 'en';
    notifyListeners();
  }

  String get languageLabel => _locale == 'en' ? '中文' : 'English';
  String get languageFlag => _locale == 'en' ? '🇨🇳' : '🇺🇸';
}

/// Convenience extension — access strings from BuildContext directly
/// Usage: context.s.timerTitle
/// Uses Provider.of with listen:true so widgets rebuild on locale change.
extension LocaleContext on BuildContext {
  LocaleProvider get locale => Provider.of<LocaleProvider>(this, listen: true);
  AppStrings get s => Provider.of<LocaleProvider>(this, listen: true).strings;
}
