import 'dart:convert';
import 'dart:io';

import 'package:assets/models/stock_search_models.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/stock_data_manager.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:assets/services/exchange_rate_service.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/yahoo_quote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));
  setUp(() => CircuitBreaker().onSuccess());
  tearDown(() => CircuitBreaker().onSuccess());

  StockSearchResult stock(String code) => StockSearchResult(
    code: code,
    name: code,
    market: 'LSE',
    secid: '155.$code',
  );
  String fixture(String code) =>
      File('test/fixtures/global_quotes/$code.L.json').readAsStringSync();
  final fx = {
    'USD': 1.0,
    'GBP': .8,
    'CHF': .9,
    'SEK': 10.0,
    'EUR': 1.1,
    'BAD': 0.0,
  };

  test(
    'uq result UQLT keeps pence normalization without requesting FX',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          final quote = await YahooQuoteService().fetchQuote(stock('UQLT'));
          expect(quote!.currentPrice, 40.315);
          expect(requests, 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.host, 'query1.finance.yahoo.com');
          return http.Response(fixture('UQLT'), 200);
        }),
      );
    },
  );

  test(
    'foreign quotes with unavailable FX stay unavailable rather than assuming 1:1',
    () async {
      await http.runWithClient(
        () async {
          expect(await YahooQuoteService().fetchQuote(stock('0HCX')), isNull);
        },
        () => MockClient((request) async {
          if (request.url.host == 'open.er-api.com') {
            return http.Response('', 503);
          }
          return http.Response(fixture('0HCX'), 200);
        }),
      );
    },
  );

  test(
    'uq CHF and SEK quotes use actual rates and share the concurrent FX request',
    () async {
      var fxRequests = 0;
      await http.runWithClient(
        () async {
          final quotes = await StockQuoteService().getStockQuotesBatch([
            stock('0HCX'),
            stock('0RUQ'),
          ]);
          expect(
            quotes['155.0HCX']!.currentPrice,
            closeTo(24.565 / .9 * .8, 1e-9),
          );
          expect(
            quotes['155.0RUQ']!.currentPrice,
            closeTo(.16 / 10 * .8, 1e-9),
          );
          expect(
            quotes['155.0HCX']!.changePercent,
            closeTo((24.565 / 24.7995 - 1) * 100, 1e-9),
          );
          expect(
            quotes['155.0RUQ']!.changePercent,
            closeTo((.16 / .146 - 1) * 100, 1e-9),
          );
          expect(quotes['155.0RUQ']!.market, 'LSE');
          final holding = StockModel(
            symbol: '0HCX',
            companyName: 'Existing holding',
            currentPrice: 10,
            shares: 10,
            totalValue: 100,
            profitLossPercent: 0,
            profitLossAmount: 0,
            isPositive: true,
            marketType: 'LSE',
            currency: 'GBP',
            secid: '155.0HCX',
          );
          final purchase = trade(price: 10, shares: 10);
          final updated = StockDataManager.applyQuotes(
            [holding],
            quotes,
            {
              '0HCX': [purchase],
            },
          ).single;
          expect(updated.currency, 'GBP');
          expect(
            updated.profitLossAmount,
            closeTo(quotes['155.0HCX']!.currentPrice * 10 - 100, 1e-8),
          );
          expect(purchase.amount, 10);

          expect(fxRequests, 1);
          await StockQuoteService().getStockQuotesBatch([
            stock('0HCX'),
            stock('0RUQ'),
          ]);
          expect(fxRequests, 1);
        },
        () => MockClient((request) async {
          if (request.url.host == 'open.er-api.com') {
            fxRequests++;
            return http.Response(jsonEncode({'rates': fx}), 200);
          }
          expect(request.url.host, 'query1.finance.yahoo.com');
          expect(request.url.queryParameters['range'], '1d');
          return http.Response(
            fixture(request.url.pathSegments.last.replaceAll('.L', '')),
            200,
          );
        }),
      );
    },
  );

  test(
    'London major currencies are converted rather than divided as pence',
    () async {
      for (final currency in ['USD', 'EUR']) {
        final body = jsonDecode(fixture('0HCX'));
        body['chart']['result'][0]['meta']['currency'] = currency;
        await http.runWithClient(() async {
          final quote = await YahooQuoteService().fetchQuote(stock('0HCX'));
          expect(
            quote!.currentPrice,
            closeTo(24.565 / fx[currency]! * fx['GBP']!, 1e-9),
          );
        }, () => MockClient((_) async => http.Response(jsonEncode(body), 200)));
      }
      expect(await ExchangeRateService().conversionRate('BAD', 'GBP'), isNull);
    },
  );

  test(
    'unknown currencies and missing symbols never turn into a zero or guessed quote',
    () async {
      await http.runWithClient(
        () async {
          expect(
            await StockQuoteService().getStockQuotesBatch([stock('0NUQ')]),
            isEmpty,
          );
          final body = jsonDecode(fixture('0HCX'));
          body['chart']['result'][0]['meta']['currency'] = 'ZZZ';
          await http.runWithClient(
            () async {
              expect(
                await YahooQuoteService().fetchQuote(stock('0HCX')),
                isNull,
              );
            },
            () => MockClient((_) async => http.Response(jsonEncode(body), 200)),
          );
          expect(
            await ExchangeRateService().conversionRate('ZZZ', 'GBP'),
            isNull,
          );
        },
        () => MockClient((request) async {
          expect(request.url.host, 'query1.finance.yahoo.com');
          expect(request.url.pathSegments.last, '0NUQ.L');
          return http.Response(
            '{"chart":{"result":null,"error":{"code":"Not Found"}}}',
            404,
          );
        }),
      );
    },
  );
}
