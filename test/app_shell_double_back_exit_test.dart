import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'le double retour quitte uniquement pendant la fenêtre de deux secondes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_language': 'fr',
        'theme_is_dark': false,
        'unread_personal_spot_badge_count': 0,
      });
      var exitCount = 0;
      final shellKey = GlobalKey<AppShellState>();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppShell(
            key: shellKey,
            exitAppForTesting: () => exitCount += 1,
            disablePostLaunchTasksForTesting: true,
            pageBuilderForTesting: (index) => ColoredBox(
              key: ValueKey<String>('shell-page-$index'),
              color: Colors.transparent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shellState = shellKey.currentState!;

      shellState.handleSystemBackForTesting();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Appuyez encore une fois sur Retour pour quitter.'),
        findsOneWidget,
      );
      expect(exitCount, 0);

      await tester.pump(const Duration(milliseconds: 1600));
      shellState.handleSystemBackForTesting();
      await tester.pump();
      expect(exitCount, 1);

      shellState.handleSystemBackForTesting();
      await tester.pump(const Duration(milliseconds: 2100));
      shellState.handleSystemBackForTesting();
      await tester.pump();
      expect(exitCount, 1);
      expect(
        find.text('Appuyez encore une fois sur Retour pour quitter.'),
        findsOneWidget,
      );

      shellState.handleSystemBackForTesting();
      await tester.pump();
      expect(exitCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
