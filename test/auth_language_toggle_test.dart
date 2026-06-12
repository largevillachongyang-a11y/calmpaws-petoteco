import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petoteco/providers/locale_provider.dart';
import 'package:petoteco/screens/auth/auth_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('auth screen language button switches login copy',
      (WidgetTester tester) async {
    final localeProvider = LocaleProvider()..setLocale('zh');

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider,
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: [
            Locale('zh'),
            Locale('en'),
          ],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthScreen(firebaseAvailable: false),
        ),
      ),
    );

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('欢迎回来'), findsNothing);
  });
}
