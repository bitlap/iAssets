import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/config/app_colors.dart';
import 'package:assets/config/app_theme.dart';
import 'package:assets/config/stock_config.dart';
import 'package:assets/widgets/common/currency_selector.dart';
import 'package:assets/widgets/common/form_sheet.dart';
import 'package:assets/widgets/stock/add_stock_sheet.dart';
import 'package:assets/models/crypto/crypto_models.dart';
import 'package:assets/services/crypto/crypto_store.dart';
import 'package:assets/widgets/crypto/crypto_page.dart';
import 'package:assets/widgets/crypto/crypto_text.dart';
import 'package:assets/widgets/crypto/add_exchange_sheet.dart';
import 'package:assets/widgets/asset/asset_header.dart';
import 'crypto_store_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AppColors.applyBrightness(Brightness.light);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp/iassets-tests',
        );
  });
  for (final brightness in Brightness.values) {
    for (final lang in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
      testWidgets(
        'crypto and asset summary fit a narrow phone in $lang / $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          L10n.applyLanguage(lang);
          AppColors.applyBrightness(brightness);
          final time = DateTime.utc(2026, 10, 17);
          final store = CryptoStore(
            reader: fixtures.FakeReader(fixtures.sample(time)),
            persistence: fixtures.MemoryPersistence(),
            clock: () => time,
          );
          await store.add(await store.test(fixtures.connection()));
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
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
          expect(find.text(StockConfig.assetTotalAssets), findsOneWidget);
          expect(find.byIcon(Icons.visibility_outlined), findsNothing);
          expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
          expect(find.text('Account'), findsOneWidget);
          expect(
            find.widgetWithText(TextButton, L10n.t('cryptoAdd')),
            findsNothing,
          );
          expect(find.text(updateText(time)), findsNothing);
          for (final key in [
            'cryptoBreakdownFutures',
            'cryptoBreakdownSpot',
            'cryptoBreakdownLead',
          ]) {
            expect(find.text(L10n.t(key)), findsOneWidget);
          }
          final futuresX = tester
              .getTopLeft(find.text(L10n.t('cryptoBreakdownFutures')))
              .dx;
          final spotX = tester
              .getTopLeft(find.text(L10n.t('cryptoBreakdownSpot')))
              .dx;
          final leadX = tester
              .getTopLeft(find.text(L10n.t('cryptoBreakdownLead')))
              .dx;
          expect(futuresX, lessThan(spotX));
          expect(spotX, lessThan(leadX));
          expect(find.text(L10n.t('cryptoScope')), findsNothing);
          expect(find.text(L10n.t('cryptoIncomplete')), findsNothing);
          expect(find.text(L10n.t('cryptoNotes')), findsNothing);
          expect(find.text(L10n.t('cryptoRefreshHint')), findsNothing);

          expect(find.text(r'$1050.00'), findsAtLeastNWidgets(1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AssetHeader(
                    totalAssets: 1350,
                    stockTotalValue: 200,
                    cryptoTotalValue: 1050,
                    cryptoIncomplete: true,
                    cryptoUpdatedAt: time,
                    currency: 'USD',
                    onCurrencyTap: () {},
                    totalsByType: const {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(L10n.t('cryptoTitle')), findsOneWidget);
          expect(find.text(L10n.t('cryptoIncomplete')), findsNothing);
          final header = tester.getRect(find.byType(AssetHeader));
          final title = tester.getRect(find.text(StockConfig.assetTotalAssets));
          final help = tester.getRect(find.byIcon(Icons.help_outline));
          final currency = tester.getRect(find.byType(CurrencySelectorButton));
          expect(find.text(StockConfig.assetPositionRatioLabel), findsNothing);
          expect(
            tester.widget<Icon>(find.byIcon(Icons.help_outline)).color,
            AppColors.warning,
          );
          expect(help.left, greaterThanOrEqualTo(title.right));
          expect(help.left - title.right, lessThan(12));
          expect(currency.left, greaterThan(help.right));
          expect(header.right - currency.right, lessThan(45));
          await tester.tap(find.byIcon(Icons.help_outline));
          await tester.pumpAndSettle();
          expect(
            find.text(StockConfig.assetPositionRatioLabel),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          store.dispose();
        },
      );
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'shared currency, confirmation and stock/crypto form sheets work in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        AppColors.applyBrightness(brightness);
        L10n.applyLanguage(L10n.langZh);
        final time = DateTime.utc(2026, 10, 17);
        final store = CryptoStore(
          reader: fixtures.FakeReader(fixtures.sample(time)),
          persistence: fixtures.MemoryPersistence(),
          clock: () => time,
        );
        await store.add(await store.test(fixtures.connection()));
        var currency = 'USD';
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.data(brightness),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: CryptoPage(
                  store: store,
                  currency: currency,
                  onCurrencyChanged: (value) =>
                      setState(() => currency = value),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CurrencySelectorButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'currency overlay');
        await tester.ensureVisible(find.text('CNY'));
        await tester.tap(find.text('CNY'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'currency changed');
        expect(currency, 'CNY');
        expect(find.byType(CurrencySelectorButton), findsOneWidget);
        await tester.ensureVisible(find.byTooltip(L10n.t('cryptoRemove')));
        await tester.tap(find.byTooltip(L10n.t('cryptoRemove')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'remove dialog');
        expect(find.text(L10n.t('cryptoRemoveConfirm')), findsOneWidget);
        await tester.tap(find.text(L10n.t('cryptoCancel')));
        await tester.pumpAndSettle();
        expect(store.connections, hasLength(1));
        tester.state<CryptoPageState>(find.byType(CryptoPage)).addConnection();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'form opened');
        expect(find.byType(AppFormSheet), findsOneWidget);
        expect(
          tester.getCenter(find.byIcon(Icons.close)).dx,
          greaterThan(tester.getCenter(find.text(L10n.t('cryptoAdd'))).dx),
        );
        for (final role in [
          CryptoAccountRole.regular,
          CryptoAccountRole.lead,
        ]) {
          expect(
            find.byKey(ValueKey('crypto-role-${role.name}')),
            findsOneWidget,
          );
        }
        expect(find.byKey(const ValueKey('crypto-role-copy')), findsNothing);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextFormField).last);
        await tester.tap(find.byType(TextFormField).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(find.byType(AppFormSheet), findsNothing);
        showCustomStockSheet(
          tester.element(find.byType(CryptoPage)),
          initialCurrency: 'USD',
          existingSymbols: {},
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'form opened');
        expect(find.byType(AppFormSheet), findsOneWidget);
        expect(
          tester.getCenter(find.byIcon(Icons.close)).dx,
          lessThan(tester.getCenter(find.text(StockConfig.addCustomStock)).dx),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
  for (final brightness in Brightness.values) {
    for (final lang in [L10n.langZh, L10n.langEn]) {
      testWidgets(
        'account choices stay inside a narrow $brightness / $lang sheet',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          AppColors.applyBrightness(brightness);
          L10n.applyLanguage(lang);
          final store = CryptoStore(
            reader: fixtures.FakeReader(fixtures.sample(DateTime.utc(2026))),
            persistence: fixtures.MemoryPersistence(),
          );
          addTearDown(store.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showAddExchangeSheet(context, store),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('crypto-role-lead')));
          await tester.pumpAndSettle();
          for (final key in [
            'crypto-role-regular',
            'crypto-role-lead',
            'crypto-market-spot',
            'crypto-market-futures',
          ]) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
          }
          await tester.tap(find.byKey(const ValueKey('crypto-market-spot')));
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('crypto-market-futures')),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'PnL follows market color preference immediately in $brightness',
      (tester) async {
        AppColors.applyBrightness(brightness);
        AppColors.applyMarketColorPreference(true);
        addTearDown(() => AppColors.applyMarketColorPreference(true));
        L10n.applyLanguage(L10n.langZh);
        tester.view.physicalSize = const Size(600, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final time = DateTime.utc(2026, 10, 17);
        final base = fixtures.sample(time);
        final snapshot = CryptoSnapshot(
          accountId: base.accountId,
          updatedAt: time,
          balances: [],
          wallets: base.wallets,
          positions: [
            CryptoPosition(
              symbol: 'BTCUSDT',
              wallet: 'USD-M',
              isLong: true,
              quantity: amount('1'),
              unit: 'BTC',
              settlement: 'USDT',
              unrealizedPnl: amount('50'),
            ),
            CryptoPosition(
              symbol: 'ETHUSDT',
              wallet: 'USD-M',
              isLong: false,
              quantity: amount('1'),
              unit: 'ETH',
              settlement: 'USDT',
              unrealizedPnl: amount('-10'),
            ),
          ],
        );
        final store = CryptoStore(
          reader: fixtures.FakeReader(snapshot),
          persistence: fixtures.MemoryPersistence(),
          clock: () => time,
        );
        await store.add(await store.test(fixtures.connection()));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.data(brightness),
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
        await tester.tap(find.text(L10n.t('cryptoContracts')));
        await tester.pumpAndSettle();
        Color? color(String text) =>
            tester.widget<Text>(find.text(text)).style?.color;
        expect(color('50 USDT'), AppColors.danger);
        expect(color('-10 USDT'), AppColors.success);
        AppColors.applyMarketColorPreference(false);
        await tester.pumpAndSettle();
        expect(color('50 USDT'), AppColors.success);
        expect(color('-10 USDT'), AppColors.danger);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
  for (final tradingRisk in [false, true]) {
    testWidgets(
      'adding (trading risk: $tradingRisk) requires a test; editing invalidates it',
      (tester) async {
        L10n.applyLanguage(L10n.langEn);
        tester.view.physicalSize = const Size(600, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final time = DateTime.utc(2026, 10, 17);
        final store = CryptoStore(
          reader: fixtures.FakeReader(
            fixtures.sample(
              time,
              notices: tradingRisk ? ['tradingPermission'] : [],
            ),
          ),
          persistence: fixtures.MemoryPersistence(),
          clock: () => time,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AddExchangeSheet(store: store)),
          ),
        );
        await tester.pumpAndSettle();
        GestureDetector addButton() => tester.widget<GestureDetector>(
          find.byKey(const ValueKey('crypto-save')),
        );
        expect(addButton().onTap, isNull);
        expect(find.text('Binance'), findsOneWidget);
        expect(find.text('OKX'), findsNothing);
        expect(find.text('Bybit'), findsNothing);
        expect(
          find.byType(DropdownButtonFormField<CryptoExchange>),
          findsNothing,
        );
        expect(find.text(L10n.t('cryptoScope')), findsOneWidget);
        expect(find.text(L10n.t('cryptoNotes')), findsOneWidget);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'My account');
        await tester.enterText(fields.at(1), 'fake-key');
        await tester.enterText(fields.at(2), 'fake-secret');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(L10n.t('cryptoTest')));
        await tester.tap(find.text(L10n.t('cryptoTest')));
        await tester.pumpAndSettle();
        expect(addButton().onTap, isNotNull);
        if (tradingRisk) {
          expect(
            find.text(L10n.t('cryptoLeadTradingPermission')),
            findsOneWidget,
          );
          expect(find.text(L10n.t('cryptoRiskTestPassed')), findsOneWidget);
        }
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), 'changed-key');
        await tester.pumpAndSettle();
        expect(addButton().onTap, isNull);
        expect(store.connections, isEmpty);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
  testWidgets(
    'switching Spot/Futures lead market invalidates test and resets acknowledgement',
    (tester) async {
      L10n.applyLanguage(L10n.langEn);
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final time = DateTime.utc(2026, 10, 17);
      final store = CryptoStore(
        reader: fixtures.FakeReader(fixtures.sample(time)),
        persistence: fixtures.MemoryPersistence(),
        clock: () => time,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AddExchangeSheet(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crypto-role-lead')));
      await tester.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<CryptoLeadMarket>),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('crypto-market-futures')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('crypto-market-spot')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('crypto-market-spot')));
      await tester.pumpAndSettle();
      expect(find.text(L10n.t('cryptoScopeBinanceSpotLead')), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Spot portfolio');
      await tester.enterText(fields.at(1), 'fake-key');
      await tester.enterText(fields.at(2), 'fake-secret');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(L10n.t('cryptoTest')));
      await tester.tap(find.text(L10n.t('cryptoTest')));
      await tester.pumpAndSettle();
      GestureDetector addButton() => tester.widget<GestureDetector>(
        find.byKey(const ValueKey('crypto-save')),
      );
      expect(addButton().onTap, isNotNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('crypto-market-futures')),
      );
      await tester.tap(find.byKey(const ValueKey('crypto-market-futures')));
      await tester.pumpAndSettle();
      expect(addButton().onTap, isNull);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(store.connections, isEmpty);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
