import 'dart:convert';
import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/utils/market_util.dart';
import 'package:assets/widgets/common/app_filter_dropdown.dart';
import 'package:assets/widgets/common/app_ui.dart';
import 'package:assets/widgets/common/info_row_widget.dart';
import 'package:assets/widgets/dividend/dividend_filter_row.dart';
import 'package:assets/widgets/stock/search_stock_dialog.dart';
import 'package:assets/widgets/stock/stock_list_header.dart';
import 'package:assets/widgets/stock/stock_style.dart';
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
      'NASDAQ': ('AAPL', '105', 'USD'),
      'NYSE': ('KO', '106', 'USD'),
      'AMEX': ('SPY', '107', 'USD'),
      'HK': ('00700', '116', 'HKD'),
      '京A': ('920002', '0', 'CNY'),
      '沪A': ('600519', '1', 'CNY'),
      '深A': ('000001', '0', 'CNY'),
      'JPX': ('7203', '176', 'JPY'),
      'KRX': ('005930', '177', 'KRW'),
      'LSE': ('HSBA', '155', 'GBP'),
      'OTCBB': ('NSRGY', '153', 'USD'),
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
        final otherMarket = entry.key == 'NASDAQ' ? 'NYSE' : 'NASDAQ';
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
              final pill = tester.widget<FilterPill>(
                find.widgetWithText(FilterPill, MarketUtil.marketLabel(market)),
              );
              expect(pill.color, StockStyle.marketColor(market));
            }
            await tester.tap(find.text(MarketUtil.marketLabel(entry.key)));
            await tester.enterText(find.byType(TextField), '$code-$language');
            await tester.pump(
              Duration(milliseconds: AppConfig.searchDebounceMs + 1),
            );
            await tester.pumpAndSettle();
            expect(find.text(code), findsOneWidget);
            final resultLabel = tester.widget<Text>(
              find.text(MarketUtil.marketLabel(entry.key)).last,
            );
            expect(resultLabel.style!.color, StockStyle.marketColor(entry.key));
            expect(tester.takeException(), isNull);
            // A different market shows an empty state; switching back restores results.
            await tester.tap(find.text(MarketUtil.marketLabel(otherMarket)));
            await tester.pump();
            expect(find.text(code), findsNothing);
            expect(
              find.text(
                StockConfig.searchNotFoundMarket.replaceAll(
                  '{market}',
                  MarketUtil.marketLabel(otherMarket),
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
            final marketInfo = tester.widget<InfoRowWidget>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is InfoRowWidget &&
                    widget.label == StockConfig.searchMarket,
              ),
            );
            expect(marketInfo.valueColor, StockStyle.marketColor(entry.key));
            if (entry.key == 'LSE') expect(find.text('GBP'), findsOneWidget);
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
            if (request.url.host == 'query1.finance.yahoo.com') {
              return http.Response(
                jsonEncode({
                  'chart': {
                    'result': [
                      {
                        'meta': {
                          'symbol': request.url.pathSegments.last,
                          'currency': 'GBp',
                          'regularMarketPrice': 1000,
                          'chartPreviousClose': 1000,
                        },
                      },
                    ],
                  },
                }),
                200,
              );
            }
            if (request.url.host == 'qt.gtimg.cn') {
              expect([
                '沪A',
                '深A',
                'HK',
                'NASDAQ',
                'NYSE',
                'AMEX',
              ], contains(entry.key));
              return http.Response('v_test="1~company~$code~10~0";', 200);
            }
            if (request.url.host == 'logos.stocktwits-cdn.com' ||
                request.url.host == 'images.financialmodelingprep.com') {
              return http.Response('', 404);
            }
            final Object response;
            if (request.url.host == 'searchapi.eastmoney.com') {
              response = {
                'QuotationCodeTable': {
                  'Data': [
                    {
                      'Code': code,
                      'Name': 'Global company',
                      'SecurityTypeName':
                          {
                            'NASDAQ': '美股',
                            'NYSE': '美股',
                            'AMEX': '美股',
                            'HK': '港股',
                            'JPX': '日股',
                            'KRX': '韩股',
                            'LSE': '英股',
                            'OTCBB': '粉单',
                          }[entry.key] ??
                          entry.key,
                      'JYS': entry.key,
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
                      'f2': entry.key == 'LSE' ? 100000 : 1000,
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
        for (final item in dropdown.items.where((item) => item.value != null)) {
          expect(
            (item.child as Text).style!.color,
            StockStyle.marketColor(item.value),
          );
        }
        final row = find.byType(DividendFilterRow);
        for (final market in ['JPX', 'KRX', 'LSE', 'OTCBB']) {
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
          await tester.pumpAndSettle();
          await tester.tap(pill);
          expect(selected, market);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
