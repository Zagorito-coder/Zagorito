import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/app_shell.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_language': 'fr',
      'theme_is_dark': false,
      'unread_personal_spot_badge_count': 0,
    });
    ThemeController.instance.setDark(false);
  });

  testWidgets(
    'la barre ouvre Marées, préserve les index et revient aux Spots',
    (tester) async {
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
            key: appShellKey,
            pageBuilderForTesting: (index) => ColoredBox(
              key: ValueKey<String>('shell-page-$index'),
              color: Colors.transparent,
              child: Center(child: Text('page $index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const homeKey = ValueKey<String>('bottom-nav-home');
      const tidesKey = ValueKey<String>('bottom-nav-tides');
      const mapKey = ValueKey<String>('bottom-nav-spots');
      const mySpotsKey = ValueKey<String>('bottom-nav-my-spots');
      const settingsKey = ValueKey<String>('bottom-nav-settings');

      expect(
          find.byKey(const ValueKey<String>('shell-page-3')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('shell-page-1')), findsNothing);
      expect(
          find.byKey(const ValueKey<String>('bottom-nav-fish')), findsNothing);

      final centers = [
        tester.getCenter(find.byKey(homeKey)).dx,
        tester.getCenter(find.byKey(tidesKey)).dx,
        tester.getCenter(find.byKey(mapKey)).dx,
        tester.getCenter(find.byKey(mySpotsKey)).dx,
        tester.getCenter(find.byKey(settingsKey)).dx,
      ];
      expect(centers, orderedEquals([...centers]..sort()));

      await tester.tap(find.byKey(tidesKey));
      await tester.pump();

      expect(
          find.byKey(const ValueKey<String>('shell-page-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('shell-page-3')), findsNothing);
      final tidesSemantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(tidesKey),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(tidesSemantics.properties.label, 'Marées');
      expect(tidesSemantics.properties.selected, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
          find.byKey(const ValueKey<String>('shell-page-3')), findsOneWidget);

      appShellKey.currentState!.notifyPersonalSpotCreated();
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('personal-spot-notification-badge'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(tidesKey));
      await tester.pump();
      expect(
        find.byKey(
          const ValueKey<String>('personal-spot-notification-badge'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(mySpotsKey));
      await tester.pump();
      expect(
          find.byKey(const ValueKey<String>('shell-page-2')), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('personal-spot-notification-badge'),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
