import 'dart:io';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/widgets/asset/assets_page.dart';
import 'package:assets/widgets/pro/pro_page.dart';
import 'package:assets/widgets/stock/stock_portfolio_page.dart';
import 'package:assets/widgets/stock/search_stock_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/core_fixtures.dart';
import 'support/pro_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));
  setUp(() async {
    await setTestPro(enabled: false);
    for (final file in directory.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SettingsService.reload();
  });

  testWidgets('fourth stock opens Pro instead of search and keeps all data', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await IcloudStorage.saveStocks(
        [stock(symbol: 'A'), stock(symbol: 'B'), stock(symbol: 'C')],
        {},
        {},
      );
    });
    final key = GlobalKey<StockPortfolioPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StockPortfolioPage(key: key)),
      ),
    );
    for (var i = 0; i < 100 && key.currentState!.stocks.length != 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(key.currentState!.stocks.length, 3);
    key.currentState!.showSearchStockDialog();
    await tester.pumpAndSettle();
    expect(find.byType(ProPage), findsOneWidget);
    expect(find.byType(SearchStockDialog), findsNothing);
    expect(find.text(L10n.t('proReasonStocks')), findsOneWidget);
    expect(key.currentState!.stocks.length, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('fourth asset type is blocked before opening an editor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await IcloudStorage.saveAssets([
        CashAccount(id: 'cash'),
        CurrentAccount(id: 'current'),
        TimeDeposit(id: 'deposit'),
      ]);
    });
    final key = GlobalKey<AssetsPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetsPage(key: key, stockTotalValue: 0, currency: 'USD'),
        ),
      ),
    );
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    key.currentState!.onAddAsset(AssetType.wealthProduct);
    await tester.pumpAndSettle();
    expect(find.byType(ProPage), findsOneWidget);
    expect(find.text(L10n.t('proReasonAssetTypes')), findsOneWidget);
    await tester.runAsync(() async {
      expect((await IcloudStorage.loadAssets()).length, 3);
    });
    await tester.pumpWidget(const SizedBox());
  });
}
