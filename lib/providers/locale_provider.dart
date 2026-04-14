import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  String _locale = 'en'; // default: English

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
