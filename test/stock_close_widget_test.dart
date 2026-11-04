import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/widgets/stock/edit_delete_dialogs.dart';
import 'package:assets/widgets/stock/stock_card.dart';
import 'package:assets/widgets/stock/stock_portfolio_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));
  setUp(() async {
    for (final file in directory.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SettingsService.reload();
  });

  testWidgets('closing a position removes it from holdings and totals', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await IcloudStorage.saveStocks(
        [stock()],
        {
          'TEST': [trade()],
        },
        {
          'TEST': [dividend()],
        },
      );
    });

    final key = GlobalKey<StockPortfolioPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StockPortfolioPage(key: key)),
      ),
    );
    for (var i = 0; i < 100 && key.currentState!.stocks.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(key.currentState!.stocks, hasLength(1));
    await tester.pump();
    expect(find.byType(StockCard), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(StockCard), matching: find.text('TEST')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.more_horiz));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StockConfig.opReducePosition));
    await tester.pumpAndSettle();
    final dialog = find.byType(EditStockDialog);
    expect(dialog, findsOneWidget);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)).at(1),
      '10',
    );
    await tester.tap(find.text(AppConfig.btnConfirmSell));
    await tester.pumpAndSettle();
    expect(find.text(StockConfig.closeRemovesData), findsOneWidget);
    await tester.tap(find.text(AppConfig.btnCancel).last);
    await tester.pumpAndSettle();
    expect(key.currentState!.stocks, hasLength(1));

    await tester.tap(find.text(AppConfig.btnConfirmSell));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StockConfig.opClosePosition).last);
    await tester.pumpAndSettle();

    expect(key.currentState!.stocks, isEmpty);
    expect(key.currentState!.totalAssets, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
