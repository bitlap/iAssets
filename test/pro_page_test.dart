import 'package:assets/l10n/l10n.dart';
import 'package:assets/services/pro_service.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/app_theme.dart';
import 'package:assets/widgets/pro/pro_page.dart';
import 'package:assets/widgets/crypto/crypto_page.dart';
import 'package:assets/services/crypto/crypto_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/pro_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => L10n.applyLanguage(L10n.langZh));

  for (final language in [L10n.langZh, L10n.langZhHant, L10n.langEn]) {
    for (final brightness in Brightness.values) {
      testWidgets('Pro plans fit a narrow screen in $language / $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        L10n.applyLanguage(language);
        AppColors.applyBrightness(brightness);
        await setTestPro(enabled: false);
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.data(brightness), home: const ProPage()),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(L10n.t('proFreeLimits')),
          180,
        );
        expect(find.text(L10n.t('proFreeLimits')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(L10n.t('proMonthlyName')),
          200,
        );
        expect(find.text(L10n.t('proMonthlyName')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(L10n.t('proYearlyName')),
          200,
        );
        expect(find.text(L10n.t('proYearlyName')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(L10n.t('proLifetimeName')),
          200,
        );
        expect(find.text(L10n.t('proLifetimeName')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('free crypto shows upgrade screen and no account contents', (
    tester,
  ) async {
    await setTestPro(enabled: false);
    final store = CryptoStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CryptoPage(
            store: store,
            currency: 'USD',
            onCurrencyChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProGate), findsOneWidget);
    expect(store.initialized, isFalse);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('permanent Pro owners are not offered another purchase', (
    tester,
  ) async {
    await setTestPro();
    await tester.pumpWidget(const MaterialApp(home: ProPage()));
    await tester.pumpAndSettle();
    expect(ProService.instance.isPro, isTrue);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text(L10n.t('proLifetimeActive')), findsOneWidget);
  });
}
