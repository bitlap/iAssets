import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/widgets/asset/asset_dialogs.dart';
import 'package:assets/widgets/records/records_op_tab.dart';
import 'package:assets/widgets/records/records_div_tab.dart';
import 'package:assets/widgets/stock/edit_delete_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

Widget host(Widget child, {Key? key}) => MaterialApp(
  key: key,
  locale: L10n.currentLocale,
  supportedLocales: L10n.supportedLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  setUpAll(() async => storage = await initializeTestStorage());
  tearDownAll(() => storage.deleteSync(recursive: true));
  tearDown(() => L10n.applyLanguage('zh'));

  for (final feeType in [
    SettingsService.feeTypeFixed,
    SettingsService.feeTypePercentage,
  ]) {
    testWidgets(
      'default price and $feeType fees save correctly in all 33 languages',
      (tester) async {
        for (final language in L10n.languages.keys) {
          L10n.applyLanguage(language);
          await tester.runAsync(() async {
            await SettingsService.setDefaultFeeType(feeType);
            await SettingsService.setDefaultFeeValue(1.23);
          });
          OperationRecord? saved;
          await tester.pumpWidget(
            host(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => EditStockDialog(
                      stock: stock().copyWith(secid: ''),
                      isAdd: true,
                      onSave: (_, record, _) => saved = record,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
              key: ValueKey(language),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.byType(TextField).at(0))
                .controller!
                .text,
            '12.0000',
            reason: language,
          );
          await tester.enterText(find.byType(TextField).at(1), '2');
          await tester.pumpAndSettle();
          final expected = feeType == SettingsService.feeTypeFixed
              ? 1.23
              : .2952;
          await tester.ensureVisible(find.text(AppConfig.btnConfirmBuy));
          await tester.tap(find.text(AppConfig.btnConfirmBuy));
          await tester.pumpAndSettle();
          expect(saved, isNotNull, reason: language);
          expect(saved!.amount, 12, reason: language);
          expect(saved!.shares, 2, reason: language);
          expect(saved!.fee, closeTo(expected, 1e-9), reason: language);
          expect(saved!.action, TradeAction.open);
          expect(tester.takeException(), isNull, reason: language);
        }
      },
    );
  }

  testWidgets('a nonempty invalid fee blocks saving instead of becoming zero', (
    tester,
  ) async {
    L10n.applyLanguage('en');
    OperationRecord? saved;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => EditStockDialog(
                stock: stock().copyWith(secid: ''),
                isAdd: true,
                onSave: (_, record, _) => saved = record,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '2');
    tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text =
        '1,23';
    await tester.tap(find.text(AppConfig.btnConfirmBuy));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text(AssetConfig.toastInvalidBalance), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '1.23');
    await tester.tap(find.text(AppConfig.btnConfirmBuy));
    await tester.pumpAndSettle();
    expect(saved!.fee, 1.23);
  });

  for (final language in ['de', 'fr', 'ar', 'bn']) {
    testWidgets(
      'editing cash without changing its balance preserves the amount in $language',
      (tester) async {
        L10n.applyLanguage(language);
        CashAccount? saved;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showCashAssetDialog(
                    context,
                    cash: CashAccount(
                      id: 'cash',
                      name: 'Savings',
                      balance: 1234.56,
                    ),
                    defaultCurrency: 'USD',
                    assetCount: 1,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(1))
              .controller!
              .text,
          '1234.5600',
        );
        await tester.enterText(find.byType(TextField).first, 'Renamed savings');
        await tester.ensureVisible(find.text(AppConfig.btnClose));
        await tester.tap(find.text(AppConfig.btnClose));
        await tester.pumpAndSettle();
        expect(saved, isNotNull);
        expect(saved!.balance, 1234.56);
        expect(saved!.name, 'Renamed savings');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'trade and dividend edits preserve unchanged numeric fields in $language',
      (tester) async {
        L10n.applyLanguage(language);
        OperationRecord? savedTrade;
        final original = OperationRecord(
          date: DateTime(2026, 11, 8),
          type: StockConfig.opBuyType,
          description: 'Open TEST',
          action: TradeAction.open,
          amount: 12.34,
          shares: 2,
          fee: 1.23,
        );
        await tester.pumpWidget(
          host(
            OperationRecordsTab(
              stock: stock(),
              operationRecords: [original],
              onEditRecord: (_, _, record) => savedTrade = record,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('${StockConfig.opOpenPosition} TEST'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '12.3400',
        );
        await tester.tap(find.text(AppConfig.btnClose));
        await tester.pumpAndSettle();
        expect(savedTrade, isNotNull);
        expect(savedTrade!.amount, 12.34);
        expect(savedTrade!.shares, 2);
        expect(savedTrade!.fee, 1.23);
        expect(savedTrade!.action, TradeAction.open);
        DividendRecord? savedDividend;
        final originalDividend = dividend(amount: 1.23, shares: 2, tax: .15);
        await tester.pumpWidget(
          host(
            DividendRecordsTab(
              stock: stock(),
              dividendRecords: [originalDividend],
              onEditRecord: (_, _, record) => savedDividend = record,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNWidgets(2));
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '1.2300',
        );
        await tester.ensureVisible(find.text(AppConfig.btnClose));
        await tester.tap(find.text(AppConfig.btnClose));
        await tester.pumpAndSettle();
        expect(savedDividend, isNotNull);
        expect(savedDividend!.amount, 1.23);
        expect(savedDividend!.shares, 2);
        expect(savedDividend!.taxRate, .15);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
