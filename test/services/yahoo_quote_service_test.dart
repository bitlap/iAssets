import '../support/source_breakers.dart';
import 'dart:convert';
import 'dart:io';

import 'package:assets/models/stock_search_models.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/yahoo_quote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
  ];
  final symbols = ['7203.T', '005930.KS', 'HSBA.L', 'NSRGY'];
  // Public chart metadata captured on 2026-10-23; prices may be delayed.
  String fixture(String symbol) =>
      File('test/fixtures/global_quotes/$symbol.json').readAsStringSync();
  http.Response response(String symbol) => http.Response(fixture(symbol), 200);
  setUp(resetSourceBreakers);
  tearDown(resetSourceBreakers);

  test(
    'real metadata preserves identifiers, daily changes and native currencies',
    () async {
      final prices = [3105.0, 215500.0, 13.518, 104.0];
      final previous = [3084.0, 214500.0, 1366.6, 101.01];
      final nativePrices = [3105.0, 215500.0, 1351.8, 104.0];
      var requests = 0;
      await http.runWithClient(
        () async {
          for (var i = 0; i < stocks.length; i++) {
            final quote = await YahooQuoteService().fetchQuote(stocks[i]);
            expect(quote!.currentPrice, closeTo(prices[i], 1e-9));
            expect(
              quote.changePercent,
              closeTo((nativePrices[i] / previous[i] - 1) * 100, 1e-9),
            );
            expect(quote.currency, ['JPY', 'KRW', 'GBP', 'USD'][i]);
            expect(quote.code, stocks[i].code);
            expect(quote.market, stocks[i].market);
            expect(quote.name, stocks[i].name);
          }
          expect(requests, 4);
        },
        () => MockClient((request) async {
          final symbol = symbols[requests++];
          expect(request.url.path, '/v8/finance/chart/$symbol');
          expect(request.url.queryParameters, {
            'interval': '1d',
            'range': '1d',
          });
          return response(symbol);
        }),
      );
    },
  );

  test('KOSDAQ retries only when KOSPI symbol is absent', () async {
    final stock = StockSearchResult(
      code: '247540',
      name: 'Ecopro BM',
      market: 'KRX',
      secid: '177.247540',
    );
    final requested = <String>[];
    await http.runWithClient(
      () async {
        final quote = await YahooQuoteService().fetchQuote(stock);
        expect(quote!.currentPrice, 100000);
        expect(requested, ['247540.KS', '247540.KQ']);
      },
      () => MockClient((request) async {
        final symbol = request.url.pathSegments.last;
        requested.add(symbol);
        if (symbol.endsWith('.KS')) return http.Response('{}', 404);
        return http.Response(
          jsonEncode({
            'chart': {
              'result': [
                {
                  'meta': {
                    'symbol': symbol,
                    'currency': 'KRW',
                    'regularMarketPrice': 100000,
                    'chartPreviousClose': 99000,
                  },
                },
              ],
              'error': null,
            },
          }),
          200,
        );
      }),
    );
  });

  test(
    'rejects wrong currency, mismatched symbols and invalid prices',
    () async {
      for (final patch in [
        {'currency': 'USD'},
        {'symbol': 'OTHER.T'},
        {'regularMarketPrice': 0},
        {'regularMarketPrice': null},
        {'chartPreviousClose': 0},
      ]) {
        final body = jsonDecode(fixture('7203.T'));
        (body['chart']['result'][0]['meta'] as Map).addAll(patch);
        await http.runWithClient(() async {
          expect(await YahooQuoteService().fetchQuote(stocks.first), isNull);
        }, () => MockClient((_) async => http.Response(jsonEncode(body), 200)));
      }
    },
  );

  test(
    'GBP is not divided again and dotted London symbols use Yahoo spelling',
    () async {
      final stock = StockSearchResult(
        code: 'BT.A',
        name: 'BT',
        market: 'LSE',
        secid: '155.BT.A',
      );
      await http.runWithClient(
        () async {
          expect(
            (await YahooQuoteService().fetchQuote(stock))!.currentPrice,
            2,
          );
        },
        () => MockClient((request) async {
          expect(request.url.pathSegments.last, 'BT-A.L');
          return http.Response(
            jsonEncode({
              'chart': {
                'result': [
                  {
                    'meta': {
                      'symbol': 'BT-A.L',
                      'currency': 'GBP',
                      'regularMarketPrice': 2,
                      'chartPreviousClose': 1.9,
                    },
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'rate limits, missing data and malformed responses do not produce quotes',
    () async {
      for (final r in [
        http.Response('{}', 429),
        http.Response('invalid', 200),
        http.Response(
          '{"chart":{"result":null,"error":{"code":"Not Found"}}}',
          200,
        ),
      ]) {
        var count = 0;
        await http.runWithClient(
          () async {
            expect(await YahooQuoteService().fetchQuote(stocks[1]), isNull);
            expect(count, lessThanOrEqualTo(2));
            if (r.statusCode == 429) expect(count, 1);
          },
          () => MockClient((_) async {
            count++;
            return r;
          }),
        );
      }
    },
  );

  test(
    'real fallback survives EastMoney failure and its circuit breaker, then caches by secid',
    () async {
      var domesticRequests = 0;
      var yahooRequests = 0;
      await http.runWithClient(
        () async {
          final service = StockQuoteService();
          // Enter domestic cooldown: the independent fallback must still run.
          for (var i = 0; i < 3; i++) {
            CircuitBreaker.eastMoney.onFailure();
          }
          final first = await service.getStockQuotesBatch(stocks);
          expect(first.keys, containsAll(stocks.map((s) => s.secid)));
          expect(first['155.HSBA']!.currentPrice, closeTo(13.518, 1e-9));
          expect(domesticRequests, 0);
          expect(yahooRequests, 4);
          expect(CircuitBreaker.eastMoney.isInCooldown, isTrue);
          await service.getStockQuotesBatch(stocks);
          expect(yahooRequests, 4);
          CircuitBreaker.eastMoney.onSuccess();
          // Distinct secid avoids the singleton cache, and forces EastMoney failure.
          final other = StockSearchResult(
            code: '7203',
            name: 'Toyota',
            market: 'JPX',
            secid: 'test.7203',
          );
          expect(
            (await service.getStockQuotesBatch([
              other,
            ]))[other.secid]!.currentPrice,
            3105,
          );
          expect(domesticRequests, 1);
        },
        () => MockClient((request) async {
          if (request.url.host == 'push2.eastmoney.com') {
            domesticRequests++;
            throw const SocketException('connection closed');
          }
          expect(request.url.host, 'query1.finance.yahoo.com');
          yahooRequests++;
          return response(request.url.pathSegments.last);
        }),
      );
    },
  );

  test(
    'temporary failure is retried on the next refresh rather than cached for 15 minutes',
    () async {
      var succeed = false;
      final stock = StockSearchResult(
        code: 'NSRGY',
        name: 'Nestle',
        market: 'OTCBB',
        secid: 'retry.NSRGY',
      );
      await http.runWithClient(
        () async {
          final service = StockQuoteService();
          expect(await service.getStockQuotesBatch([stock]), isEmpty);
          succeed = true;
          expect(
            (await service.getStockQuotesBatch([
              stock,
            ]))[stock.secid]!.currentPrice,
            104,
          );
        },
        () => MockClient((request) async {
          if (request.url.host == 'push2.eastmoney.com') {
            return http.Response('{}', 200);
          }
          return succeed ? response('NSRGY') : http.Response('{}', 503);
        }),
      );
    },
  );
}
