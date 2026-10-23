import 'dart:convert';
import 'dart:io';

import 'package:assets/models/stock_search_models.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/stock_search_service.dart';
import 'package:assets/services/tencent_quote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Search and Tencent fixtures were captured from public endpoints on 2026-10-23.
void main() {
  final searchFixture = File(
    'test/fixtures/stock_search_berkshire.json',
  ).readAsStringSync();
  String tencentFixture(String share) =>
      File('test/fixtures/tencent_berkshire_$share.txt').readAsStringSync();
  setUp(() => CircuitBreaker().onSuccess());
  tearDown(() => CircuitBreaker().onSuccess());

  test(
    'BRK.B searches the provider spelling and queries Tencent with a dot',
    () async {
      final requests = <String>[];
      await http.runWithClient(
        () async {
          final results = await StockSearchService().searchStocks('BRK.B');
          final stock = results.single;
          expect(stock.code, 'BRK.B');
          expect(stock.market, 'NYSE');
          expect(stock.secid, '106.BRK_B');
          final quote = await TencentQuoteService().fetchQuote(stock);
          expect(quote!.code, 'BRK.B');
          expect(quote.market, 'NYSE');
          expect(quote.currentPrice, 549.19);
          expect(quote.changePercent, 1.89);
          expect(
            await StockSearchService().searchStocks('BRK.B'),
            same(results),
          );
          expect(requests, ['BRK.B', 'BRK_B', '/q=usBRK.B']);
        },
        () => MockClient((request) async {
          if (request.url.host == 'searchapi.eastmoney.com') {
            final input = request.url.queryParameters['input']!;
            requests.add(input);
            return http.Response(
              input == 'BRK_B'
                  ? searchFixture
                  : '{"QuotationCodeTable":{"Data":null}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.host, 'qt.gtimg.cn');
          requests.add(request.url.path);
          return http.Response(
            tencentFixture('b'),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );

  test(
    'BRK.A retains its share class in the Tencent request and result',
    () async {
      await http.runWithClient(
        () async {
          final quote = await TencentQuoteService().fetchQuote(
            StockSearchResult(
              code: 'BRK.A',
              name: 'Berkshire A',
              market: 'NYSE',
              secid: '106.BRK_A',
            ),
          );
          expect(quote!.code, 'BRK.A');
          expect(quote.currentPrice, 823534.83);
          expect(quote.changePercent, 1.51);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/q=usBRK.A');
          return http.Response(
            tencentFixture('a'),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );

  test(
    'BRK.B fallback sends the original EastMoney secid with underscore',
    () async {
      final hosts = <String>[];
      await http.runWithClient(
        () async {
          final quotes = await StockQuoteService().getStockQuotesBatch([
            StockSearchResult(
              code: 'BRK.B',
              name: 'Berkshire B',
              market: 'NYSE',
              secid: '106.BRK_B',
            ),
          ]);
          expect(quotes.keys, ['106.BRK_B']);
          expect(quotes['106.BRK_B']!.code, 'BRK.B');
          expect(quotes['106.BRK_B']!.currentPrice, 549.19);
          expect(hosts, ['qt.gtimg.cn', 'push2.eastmoney.com']);
        },
        () => MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host == 'qt.gtimg.cn') {
            expect(request.url.path, '/q=usBRK.B');
            return http.Response('v_pv_none_match="1";', 200);
          }
          expect(request.url.queryParameters['secids'], '106.BRK_B');
          // Simulated fallback: the live EastMoney quote endpoint was unavailable.
          return http.Response(
            jsonEncode({
              'data': {
                'diff': [
                  {'f12': 'BRK_B', 'f13': 106, 'f1': 2, 'f2': 54919, 'f3': 189},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );

  test(
    'a native dotted search result is kept without a spelling retry',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          final stock = (await StockSearchService().searchStocks(
            'BT.A',
          )).single;
          expect(stock.code, 'BT.A');
          expect(stock.secid, '155.BT.A');
          expect(requests, 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['input'], 'BT.A');
          return http.Response(
            jsonEncode({
              'QuotationCodeTable': {
                'Data': [
                  {
                    'Code': 'BT.A',
                    'Name': 'BT',
                    'SecurityTypeName': '英股',
                    'JYS': 'LSE',
                    'QuoteID': '155.BT.A',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );

  test(
    'unknown dotted symbols retry once and cache the empty result',
    () async {
      final inputs = <String>[];
      await http.runWithClient(
        () async {
          final search = StockSearchService();
          expect(await search.searchStocks('BKB.B'), isEmpty);
          expect(await search.searchStocks('BKB.B'), isEmpty);
          expect(inputs, ['BKB.B', 'BKB_B']);
        },
        () => MockClient((request) async {
          inputs.add(request.url.queryParameters['input']!);
          return http.Response('{"QuotationCodeTable":{"Data":null}}', 200);
        }),
      );
    },
  );
}
