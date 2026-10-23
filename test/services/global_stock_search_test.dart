import '../support/source_breakers.dart';
import 'dart:convert';
import 'dart:io';

import 'package:assets/models/stock_search_models.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:assets/services/east_money_quote_service.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/stock_search_service.dart';
import 'package:assets/services/tencent_quote_service.dart';
import 'package:assets/utils/market_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final fixture = File(
    'test/fixtures/stock_search_global.json',
  ).readAsStringSync();
  final breaker = CircuitBreaker.tencent;
  setUp(resetSourceBreakers);
  tearDown(resetSourceBreakers);

  test('search preserves global markets and deduplicates by secid', () async {
    final data = jsonDecode(fixture) as Map<String, dynamic>;
    final rows = data['QuotationCodeTable']['Data'] as List;
    rows.addAll([
      rows.first,
      {'Code': 'INVALID', 'SecurityTypeName': '日股'},
      {'Code': '', 'QuoteID': '176.', 'SecurityTypeName': '日股'},
      {'Code': 'EURUSD', 'QuoteID': '119.EURUSD', 'SecurityTypeName': '外汇'},
      {
        'Code': 'BRK_B',
        'Name': 'Berkshire',
        'QuoteID': '106.BRK_B',
        'SecurityTypeName': '美股',
      },
    ]);
    var requests = 0;
    await http.runWithClient(
      () async {
        final service = StockSearchService();
        final results = await service.searchStocks('global-fixture');
        expect(
          results.map((s) => s.market),
          containsAll([
            'NASDAQ',
            'NYSE',
            'AMEX',
            'JPX',
            'KRX',
            'LSE',
            'OTCBB',
            '沪A',
            '深A',
            '京A',
            'HK',
          ]),
        );
        expect(results.singleWhere((s) => s.code == 'AAPL').market, 'NASDAQ');
        expect(results.singleWhere((s) => s.code == 'KO').market, 'NYSE');
        expect(results.singleWhere((s) => s.code == 'SPY').market, 'AMEX');
        expect(results.singleWhere((s) => s.code == '00700').market, 'HK');
        expect(results.singleWhere((s) => s.code == '920002').market, '京A');
        for (final region in ['美股', '港股', '日股', '韩股', '英股', '粉单']) {
          expect(results.map((s) => s.market), isNot(contains(region)));
        }
        expect(results.where((s) => s.code == 'AZN').map((s) => s.secid), [
          '106.AZN',
          '155.AZN',
        ]);
        expect(results.where((s) => s.code == '005930').map((s) => s.secid), [
          '177.005930',
          '150.005930',
        ]);
        expect(results.where((s) => s.secid == '176.7203'), hasLength(1));
        expect(results.map((s) => s.code), isNot(contains('INVALID')));
        expect(results.map((s) => s.market), isNot(contains('外汇')));
        expect(
          results.singleWhere((s) => s.code == 'BRK.B').secid,
          '106.BRK_B',
        );
        expect(await service.searchStocks('global-fixture'), same(results));
        expect(await service.searchStocks('  '), isEmpty);
        expect(requests, 1);
      },
      () => MockClient((request) async {
        requests++;
        expect(request.url.queryParameters['input'], 'global-fixture');
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  test(
    'US exchanges retain logos and route to Tencent with USD quotes',
    () async {
      final exchanges = {
        'NASDAQ': ('105', 'AAPL'),
        'NYSE': ('106', 'KO'),
        'AMEX': ('107', 'SPY'),
      };
      var requests = 0;
      await http.runWithClient(
        () async {
          for (final entry in exchanges.entries) {
            final (id, code) = entry.value;
            final stock = StockSearchResult(
              code: code,
              name: code,
              market: entry.key,
              secid: '$id.$code',
            );
            final quotes = await StockQuoteService().getStockQuotesBatch([
              stock,
            ]);
            final quote = quotes[stock.secid]!;
            expect(quote.market, entry.key);
            expect(quote.currentPrice, 10);
            expect(
              quote.logoUrl,
              StockQuoteService.getLogoUrl(code, entry.key),
            );
            expect(quote.logoUrl, contains('/$code.png'));
          }
          expect(requests, 3);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.host, 'qt.gtimg.cn');
          expect(request.url.path, startsWith('/q=us'));
          return http.Response('v_test="1~company~code~10~0";', 200);
        }),
      );
    },
  );

  test('missing provider data produces an empty search result', () async {
    await http.runWithClient(() async {
      expect(await StockSearchService().searchStocks('empty-fixture'), isEmpty);
    }, () => MockClient((_) async => http.Response('{}', 200)));
  });

  final stocks = [
    StockSearchResult(
      code: '7203',
      name: 'Toyota',
      market: 'JPX',
      secid: '176.7203',
    ),
    StockSearchResult(
      code: '005930',
      name: 'Samsung',
      market: 'KRX',
      secid: '177.005930',
    ),
    StockSearchResult(
      code: 'HSBA',
      name: 'HSBC',
      market: 'LSE',
      secid: '155.HSBA',
    ),
    StockSearchResult(
      code: 'NSRGY',
      name: 'Nestle',
      market: 'OTCBB',
      secid: '153.NSRGY',
    ),
    StockSearchResult(
      code: 'AZN',
      name: 'AstraZeneca US',
      market: 'NYSE',
      secid: '106.AZN',
    ),
    StockSearchResult(
      code: 'AZN',
      name: 'AstraZeneca UK',
      market: 'LSE',
      secid: '155.AZN',
    ),
  ];
  final quotes = [
    {'f12': '7203', 'f13': 176, 'f1': 1, 'f2': 30840, 'f3': -32},
    {'f12': '005930', 'f13': 177, 'f1': 0, 'f2': 214500, 'f3': -403},
    {'f12': 'HSBA', 'f13': 155, 'f1': 3, 'f2': 1368400, 'f3': -216},
    {'f12': 'NSRGY', 'f13': 153, 'f1': 3, 'f2': 102830, 'f3': 193},
    {'f12': 'AZN', 'f13': 106, 'f1': 3, 'f2': 172585, 'f3': 245},
    {'f12': 'AZN', 'f13': 155, 'f1': 3, 'f2': 12926000, 'f3': 247},
  ];
  http.Response quoteResponse() => http.Response(
    jsonEncode({
      'data': {'diff': quotes},
    }),
    200,
  );

  test('new markets skip Tencent without making a request', () async {
    await http.runWithClient(
      () async {
        for (final stock in stocks.where(
          (s) => !MarketUtil.isUSMarket(s.market),
        )) {
          expect(await TencentQuoteService().fetchQuote(stock), isNull);
        }
        expect(breaker.isInCooldown, isFalse);
      },
      () => MockClient((_) async => fail('Unsupported market sent to Tencent')),
    );
  });

  test(
    'batch quotes match exchange and code without guessing London currency',
    () async {
      final result = <String, StockQuote>{};
      await http.runWithClient(
        () async {
          await EastMoneyQuoteService().fetchBatch(
            stocks,
            (id, quote) => result[id] = quote,
          );
        },
        () => MockClient((request) async {
          expect(
            request.url.queryParameters['fields']!.split(','),
            contains('f13'),
          );
          expect(
            request.url.queryParameters['secids']!.split(','),
            stocks
                .where((s) => !MarketUtil.isUKMarket(s.market))
                .map((s) => s.secid),
          );
          return quoteResponse();
        }),
      );
      expect(
        result.keys,
        containsAll(
          stocks
              .where((s) => !MarketUtil.isUKMarket(s.market))
              .map((s) => s.secid),
        ),
      );
      expect(result['176.7203']!.currentPrice, 3084);
      expect(result['177.005930']!.currentPrice, 214500);
      expect(result['155.HSBA'], isNull);
      expect(result['153.NSRGY']!.currentPrice, 102.83);
      expect(result['106.AZN']!.currentPrice, 172.585);
      expect(result['155.AZN'], isNull);
      expect(result['106.AZN']!.market, 'NYSE');
      expect(result['176.7203']!.changePercent, -.32);
      expect(result['153.NSRGY']!.changePercent, 1.93);
    },
  );

  test(
    'quote service routes London to currency-aware quotes and caches by secid',
    () async {
      var requests = 0;
      final newMarkets = stocks
          .where((s) => !MarketUtil.isUSMarket(s.market))
          .toList();
      await http.runWithClient(
        () async {
          final service = StockQuoteService();
          final result = await service.getStockQuotesBatch(newMarkets);
          expect(result.keys, containsAll(newMarkets.map((s) => s.secid)));
          expect(service.getCachedQuote('155.AZN')!.currentPrice, 129.26);
          await service.getStockQuotesBatch(newMarkets);
          expect(requests, 3);
        },
        () => MockClient((request) async {
          requests++;
          if (request.url.host == 'query1.finance.yahoo.com') {
            final symbol = request.url.pathSegments.last;
            return http.Response(
              jsonEncode({
                'chart': {
                  'result': [
                    {
                      'meta': {
                        'symbol': symbol,
                        'currency': 'GBP',
                        'regularMarketPrice': symbol == 'AZN.L'
                            ? 129.26
                            : 13.684,
                        'chartPreviousClose': 130,
                      },
                    },
                  ],
                },
              }),
              200,
            );
          }
          expect(request.url.host, 'push2.eastmoney.com');
          expect(
            request.url.queryParameters['secids'],
            isNot(contains('155.')),
          );
          return quoteResponse();
        }),
      );
    },
  );
}
