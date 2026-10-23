import 'dart:convert';
import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/models/stock_search_models.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:assets/services/east_money_quote_service.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/stock_search_service.dart';
import 'package:assets/services/tencent_quote_service.dart';
import 'package:assets/services/yahoo_quote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/source_breakers.dart';

void main() {
  setUp(resetSourceBreakers);
  tearDown(resetSourceBreakers);
  StockSearchResult stock(
    String code, {
    String market = '三板',
    String id = '0',
  }) => StockSearchResult(
    code: code,
    name: code,
    market: market,
    secid: '$id.$code',
  );
  String em(StockSearchResult s, {Object price = 86}) => jsonEncode({
    'data': {
      'diff': [
        {
          'f12': s.code,
          'f13': int.parse(s.secid.split('.').first),
          'f1': 2,
          'f2': price,
          'f3': 0,
        },
      ],
    },
  });

  for (final (index, mode) in [
    'empty',
    'zero',
    'exception',
    'http503',
  ].indexed) {
    test(
      'domestic $mode quotes retry next refresh and cache only the recovered price',
      () async {
        final s = stock('83595$index');
        var recovered = false;
        var tencentCalls = 0;
        var emCalls = 0;
        await http.runWithClient(
          () async {
            final service = StockQuoteService();
            expect(await service.getStockQuotesBatch([s]), isEmpty);
            expect(service.getCachedQuote(s.secid), isNull);
            recovered = true;
            final result = await service.getStockQuotesBatch([s]);
            expect(result[s.secid]!.currentPrice, .86);
            expect(tencentCalls, 2);
            expect(emCalls, 2);
            expect(service.getCachedQuote(s.secid)!.currentPrice, .86);
            await service.getStockQuotesBatch([s]);
            expect(tencentCalls, 2);
            expect(emCalls, 2);
          },
          () => MockClient((request) async {
            if (request.url.host == 'qt.gtimg.cn') {
              tencentCalls++;
              return http.Response('v_pv_none_match="1";', 200);
            }
            expect(request.url.host, 'push2.eastmoney.com');
            emCalls++;
            if (recovered) return http.Response(em(s), 200);
            return switch (mode) {
              'exception' => throw const SocketException('offline'),
              'http503' => http.Response('', 503),
              'zero' => http.Response(em(s, price: 0), 200),
              _ => http.Response('{"data":null}', 200),
            };
          }),
        );
      },
    );
  }

  test(
    'EastMoney cooldown does not block Tencent, Yahoo, or search and their success does not clear it',
    () async {
      final unsupported = stock('931009', market: '指数', id: '2');
      final index = stock('399235', market: '指数');
      final london = stock('TESTLSE', market: 'LSE', id: '155');
      var emCalls = 0;
      var tencentCalls = 0;
      var yahooCalls = 0;
      var searchCalls = 0;
      await http.runWithClient(
        () async {
          for (var i = 0; i < AppConfig.failureThreshold; i++) {
            await EastMoneyQuoteService().fetchBatch([
              unsupported,
            ], (_, _) => fail('no quote expected'));
          }
          expect(CircuitBreaker.eastMoney.isInCooldown, isTrue);
          expect(CircuitBreaker.tencent.isInCooldown, isFalse);
          final result = await StockQuoteService().getStockQuotesBatch([
            index,
            london,
          ]);
          expect(result[index.secid]!.currentPrice, 879.57);
          expect(result[london.secid]!.currentPrice, 10);
          expect(
            await StockSearchService().searchStocks('isolation-search'),
            isEmpty,
          );
          expect(CircuitBreaker.eastMoney.isInCooldown, isTrue);
          expect(CircuitBreaker.stockSearch.isInCooldown, isFalse);
          expect(emCalls, AppConfig.failureThreshold);
          expect(tencentCalls, 1);
          expect(yahooCalls, 1);
          expect(searchCalls, 1);
        },
        () => MockClient((request) async {
          switch (request.url.host) {
            case 'push2.eastmoney.com':
              emCalls++;
              throw const SocketException('EastMoney disconnected');
            case 'qt.gtimg.cn':
              tencentCalls++;
              return http.Response(
                'v_sz399235="51~index~399235~879.57~873.42";',
                200,
              );
            case 'query1.finance.yahoo.com':
              yahooCalls++;
              return http.Response(
                jsonEncode({
                  'chart': {
                    'result': [
                      {
                        'meta': {
                          'symbol': 'TESTLSE.L',
                          'currency': 'GBP',
                          'regularMarketPrice': 10,
                          'chartPreviousClose': 10,
                        },
                      },
                    ],
                  },
                }),
                200,
              );
            default:
              expect(request.url.host, 'searchapi.eastmoney.com');
              searchCalls++;
              return http.Response('{"QuotationCodeTable":{"Data":[]}}', 200);
          }
        }),
      );
    },
  );

  test(
    'Tencent HTTP failure cooldown still permits EastMoney fallback',
    () async {
      final s = stock('ISOLATED', market: 'NASDAQ', id: '105');
      var tencentCalls = 0;
      var emCalls = 0;
      await http.runWithClient(
        () async {
          for (var i = 0; i < AppConfig.failureThreshold; i++) {
            expect(await TencentQuoteService().fetchQuote(s), isNull);
          }
          expect(CircuitBreaker.tencent.isInCooldown, isTrue);
          final quotes = await StockQuoteService().getStockQuotesBatch([s]);
          expect(quotes[s.secid]!.currentPrice, .86);
          expect(tencentCalls, AppConfig.failureThreshold);
          expect(emCalls, 1);
          expect(CircuitBreaker.tencent.isInCooldown, isTrue);
          expect(CircuitBreaker.eastMoney.isInCooldown, isFalse);
          expect(CircuitBreaker.yahoo.isInCooldown, isFalse);
          expect(CircuitBreaker.stockSearch.isInCooldown, isFalse);
        },
        () => MockClient((request) async {
          if (request.url.host == 'qt.gtimg.cn') {
            tencentCalls++;
            return http.Response('', 503);
          }
          expect(request.url.host, 'push2.eastmoney.com');
          emCalls++;
          return http.Response(em(s), 200);
        }),
      );
    },
  );

  test(
    'Yahoo rate limiting cools only Yahoo and never caches a missing quote',
    () async {
      final s = stock('ISOLATEDJP', market: 'JPX', id: '176');
      var yahooCalls = 0;
      await http.runWithClient(
        () async {
          for (var i = 0; i < AppConfig.failureThreshold; i++) {
            expect(await YahooQuoteService().fetchQuote(s), isNull);
          }
          expect(CircuitBreaker.yahoo.isInCooldown, isTrue);
          expect(CircuitBreaker.eastMoney.isInCooldown, isFalse);
          final quotes = await StockQuoteService().getStockQuotesBatch([s]);
          expect(quotes[s.secid]!.currentPrice, .86);
          expect(yahooCalls, AppConfig.failureThreshold);
          expect(CircuitBreaker.yahoo.isInCooldown, isTrue);
        },
        () => MockClient((request) async {
          if (request.url.host == 'query1.finance.yahoo.com') {
            yahooCalls++;
            return http.Response('', 429);
          }
          expect(request.url.host, 'push2.eastmoney.com');
          return http.Response(em(s), 200);
        }),
      );
    },
  );
}
