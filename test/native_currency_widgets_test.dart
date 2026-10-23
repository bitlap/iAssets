import 'dart:convert';
import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/exchange_rate_service.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/services/serde/converters.dart';
import 'package:assets/widgets/common/currency_selector.dart';
import 'package:assets/widgets/common/info_row_widget.dart';
import 'package:assets/widgets/stock/search_stock_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  setUpAll(() async {
    storage = await initializeTestStorage();
    await SettingsService.getDefaultFeeType();
  });
  tearDownAll(() => storage.deleteSync(recursive: true));
  tearDown(() => L10n.applyLanguage(L10n.langZh));

  for (final language in [L10n.langZh, L10n.langZhHant, L10n.langEn]) {
    for (final row in [
      ('0HCX', 'CHF', 24.565),
      ('0RUQ', 'SEK', .16),
      ('0NUQ', 'SEK', 0.0),
    ]) {
      testWidgets('London ${row.$2} search and persistence in $language', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        L10n.applyLanguage(language);
        StockModel? added;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SearchStockDialog(
                          onStockAdded: (stock, _) => added = stock,
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Search'));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byType(TextField),
              '${row.$1}-$language',
            );
            await tester.pump(
              Duration(milliseconds: AppConfig.searchDebounceMs + 1),
            );
            await tester.pumpAndSettle();
            if (row.$3 > 0) {
              expect(
                find.text('${row.$3.toStringAsFixed(4)} ${row.$2}'),
                findsOneWidget,
              );
            }
            await tester.tap(find.text(row.$1));
            await tester.pumpAndSettle();
            if (row.$3 == 0) {
              // Missing quotes must allow the user to choose the input currency.
              await tester.tap(find.byType(DropdownButtonFormField<String>));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.text('SEK').last,
                100,
                scrollable: find.byType(Scrollable).last,
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('SEK').last);
              await tester.pumpAndSettle();
            } else {
              final currency = tester.widget<InfoRowWidget>(
                find.byWidgetPredicate(
                  (w) =>
                      w is InfoRowWidget &&
                      w.label == StockConfig.customStockCurrency,
                ),
              );
              expect(currency.value, row.$2);
            }
            final fields = find.byType(TextField);
            await tester.enterText(fields.at(1), '10');
            await tester.enterText(fields.at(2), '2');
            await tester.tap(find.text(AppConfig.btnConfirmAdd));
            await tester.pumpAndSettle();
            expect(added!.currency, row.$2);
            expect(added!.currentPrice, row.$3 > 0 ? row.$3 : 10);
            final restored = stocksFromJson(stocksToJson([added!])).single;
            expect(restored.currency, row.$2);
            expect(restored.currentPrice, added!.currentPrice);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.url.host == 'searchapi.eastmoney.com') {
              return http.Response(
                jsonEncode({
                  'QuotationCodeTable': {
                    'Data': [
                      {
                        'Code': row.$1,
                        'Name': 'London security',
                        'SecurityTypeName': '英股',
                        'JYS': 'LSE',
                        'QuoteID': '155.${row.$1}',
                      },
                    ],
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (request.url.host == 'query1.finance.yahoo.com' && row.$3 > 0) {
              return http.Response(
                File(
                  'test/fixtures/global_quotes/${row.$1}.L.json',
                ).readAsStringSync(),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            expect(request.url.host, isNot('open.er-api.com'));
            return http.Response('', 404);
          }),
        );
      });
    }

    testWidgets('currency switch includes all added units in $language', (
      tester,
    ) async {
      L10n.applyLanguage(language);
      String selected = 'GBP';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => CurrencySelector.show(
                  context: context,
                  selectedCurrency: selected,
                  onCurrencyChanged: (value) => selected = value,
                ),
                child: const Text('Currency'),
              ),
            ),
          ),
        ),
      );
      for (final code in [
        'SEK',
        'NOK',
        'DKK',
        'PLN',
        'CZK',
        'HUF',
        'NZD',
        'ZAR',
        'ILS',
        'MXN',
        'TRY',
        'GBp',
        'GBX',
      ]) {
        expect(ExchangeRateService.supportedCurrencies, contains(code));
        await tester.tap(find.text('Currency'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(code),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(code));
        await tester.pumpAndSettle();
        expect(selected, code);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
