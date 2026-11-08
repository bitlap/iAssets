import 'dart:io';

import 'package:assets/l10n/l10n.dart';
import 'package:assets/config/app_config.dart';
import 'package:assets/widgets/common/app_number_field.dart';
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
      for (final key in ['sectionFee', 'sortLabel', 'feedbackLabel']) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final header = find.text(L10n.t(key));
        await tester.scrollUntilVisible(
          header,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$language/$key expanded',
        );
        if (key == 'feedbackLabel') {
          expect(find.text(AppConfig.repositoryUrl), findsOneWidget);
          Navigator.of(
            tester.element(find.text(AppConfig.repositoryUrl)),
          ).pop();
        } else {
          if (key == 'sectionFee') {
            expect(find.byType(AppNumberField), findsOneWidget);
          } else {
            expect(find.byType(ChoiceChip), findsNWidgets(2));
            final ascending = find.widgetWithText(
              ChoiceChip,
              L10n.t('sortAscending'),
            );
            final descending = find.widgetWithText(
              ChoiceChip,
              L10n.t('sortDescending'),
            );
            final target = tester.widget<ChoiceChip>(ascending).selected
                ? descending
                : ascending;
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(tester.widget<ChoiceChip>(target).selected, isTrue);
          }
          await tester.ensureVisible(header);
          await tester.pumpAndSettle();
          await tester.tap(header);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$language/$key');
      }
    }
  });
}
