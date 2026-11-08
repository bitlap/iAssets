import 'dart:io';

import 'package:assets/l10n/l10n.dart';
import 'package:assets/widgets/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));
  tearDown(() => L10n.applyLanguage(L10n.langZh));

  testWidgets('settings remain readable at 320px in all 33 languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in L10n.languages.keys) {
      L10n.applyLanguage(language);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(language),
          locale: L10n.currentLocale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsPage(
            currentCurrency: 'USD',
            onCurrencyChanged: (_) {},
            onSortChanged: (_) {},
            onSortDirectionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: language);
      for (var scroll = 0; scroll < 4; scroll++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: language);
      }
    }
  });
}
