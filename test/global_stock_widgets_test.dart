import 'dart:convert';
import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/utils/market_util.dart';
import 'package:assets/widgets/common/app_filter_dropdown.dart';
import 'package:assets/widgets/dividend/dividend_filter_row.dart';
import 'package:assets/widgets/stock/search_stock_dialog.dart';
import 'package:assets/widgets/stock/stock_list_header.dart';
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
    for (final entry in {
      '沪A': ('600519', '1', 'CNY'),
      '深A': ('000001', '0', 'CNY'),
      '日股': ('7203', '176', 'JPY'),
      '韩股': ('005930', '177', 'KRW'),
      '英股': ('HSBA', '155', 'GBP'),
      '粉单': ('NSRGY', '153', 'USD'),
    }.entries) {
      testWidgets('search and add ${entry.key} in $language at 320px', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        L10n.applyLanguage(language);
        final (code, exchange, currency) = entry.value;
        StockModel? added;
        OperationRecord? trade;
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
                          onStockAdded: (stock, record) {
                            added = stock;
                            trade = record;
                          },
                        ),
                      ),
                      child: const Text('Open search'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open search'));
            await tester.pumpAndSettle();
            for (final market in MarketUtil.searchMarkets) {
              expect(find.text(MarketUtil.marketLabel(market)), findsOneWidget);
            }
            await tester.tap(find.text(MarketUtil.marketLabel(entry.key)));
            await tester.enterText(find.byType(TextField), '$code-$language');
            await tester.pump(
              Duration(milliseconds: AppConfig.searchDebounceMs + 1),
            );
            await tester.pumpAndSettle();
            expect(find.text(code), findsOneWidget);
            expect(tester.takeException(), isNull);
            // A different market shows an empty state; switching back restores results.
            await tester.tap(find.text(MarketUtil.marketLabel('港股')));
            await tester.pump();
            expect(find.text(code), findsNothing);
            expect(
              find.text(
                StockConfig.searchNotFoundMarket.replaceAll(
                  '{market}',
                  MarketUtil.marketLabel('港股'),
                ),
              ),
              findsOneWidget,
            );
            await tester.tap(
              find.text(MarketUtil.marketLabel(entry.key)).first,
            );
            await tester.pump();
            await tester.tap(find.text(code));
            await tester.pumpAndSettle();
            final inputs = find.byType(TextField);
            expect(
              tester.widget<TextField>(inputs.at(1)).controller!.text,
              '10.0000',
            );
            // The search input remains behind the confirmation dialog.
            await tester.enterText(inputs.at(1), '10');
            await tester.enterText(inputs.at(2), '2');
            await tester.tap(find.text(AppConfig.btnConfirmAdd));
            await tester.pumpAndSettle();
            expect(added, isNotNull);
            expect(added!.marketType, entry.key);
            expect(added!.currency, currency);
            expect(added!.secid, '$exchange.$code');
            expect(added!.totalValue, 20);
            expect(trade!.amount, 10);
            expect(trade!.shares, 2);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.url.host == 'qt.gtimg.cn') {
              expect(['沪A', '深A'], contains(entry.key));
              return http.Response('v_test="1~company~$code~10~0";', 200);
            }
            final Object response;
            if (request.url.host == 'searchapi.eastmoney.com') {
              response = {
                'QuotationCodeTable': {
                  'Data': [
                    {
                      'Code': code,
                      'Name': 'Global company',
                      'SecurityTypeName': entry.key,
                      'QuoteID': '$exchange.$code',
                    },
                  ],
                },
              };
            } else {
              response = {
                'data': {
                  'diff': [
                    {
                      'f12': code,
                      'f13': int.parse(exchange),
                      'f1': 2,
                      'f2': entry.key == '英股' ? 100000 : 1000,
                      'f3': 10,
                    },
                  ],
                },
              };
            }
            return http.Response(
              jsonEncode(response),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
      });
    }

    testWidgets(
      'portfolio and dividend filters expose every market in $language',
      (tester) async {
        L10n.applyLanguage(language);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  StockListHeader(
                    sortColumn: 'name',
                    sortAscending: true,
                    onColumnTap: (_) {},
                    filterMarket: null,
                    onMarketChanged: (market) => selected = market,
                  ),
                  DividendFilterRow(
                    filterMarket: null,
                    sortKey: 'name',
                    sortAscending: true,
                    onFilterChanged: (market) => selected = market,
                    onSortChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        final dropdown = tester.widget<AppFilterDropdown<String>>(
          find.byType(AppFilterDropdown<String>),
        );
        expect(dropdown.items.map((item) => item.value), [
          null,
          ...MarketUtil.holdingMarkets,
        ]);
        final row = find.byType(DividendFilterRow);
        for (final market in ['日股', '韩股', '英股', '粉单']) {
          final pill = find.descendant(
            of: row,
            matching: find.text(MarketUtil.marketLabel(market)),
          );
          await tester.scrollUntilVisible(
            pill,
            120,
            scrollable: find
                .descendant(of: row, matching: find.byType(Scrollable))
                .first,
          );
          await tester.tap(pill);
          expect(selected, market);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
