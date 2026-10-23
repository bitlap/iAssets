import 'dart:convert';
import 'dart:io';

import 'package:assets/models/stock_search_models.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/stock_data_manager.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:assets/services/exchange_rate_service.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/yahoo_quote_service.dart';
import 'package:assets/utils/currency_util.dart';
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
  StockModel holding(String code, String currency) => StockModel(
    symbol: code,
    companyName: code,
    currentPrice: 10,
    shares: 10,
    totalValue: 100,
    profitLossPercent: 0,
    profitLossAmount: 0,
    isPositive: true,
    marketType: 'LSE',
    currency: currency,
    secid: '155.$code',
  );

  test(
    'uq GBp CHF SEK quotes preserve native prices without any FX request',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          for (final row in [
            ('UQLT', 'GBp', 4031.5),
            ('0HCX', 'CHF', 24.565),
            ('0RUQ', 'SEK', .16),
          ]) {
            final quote = await YahooQuoteService().fetchQuote(stock(row.$1));
            expect(quote!.currentPrice, row.$3);
            expect(quote.currency, row.$2);
          }
          expect(requests, 3);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.host, 'query1.finance.yahoo.com');
          return http.Response(
            fixture(request.url.pathSegments.last.replaceAll('.L', '')),
            200,
          );
        }),
      );
    },
  );

  test(
    'new native holdings retain quote currency and old GBP holdings need actual FX',
    () async {
      await http.runWithClient(
        () async {
          final quotes = await StockQuoteService().getStockQuotesBatch([
            stock('0HCX'),
            stock('0RUQ'),
          ]);
          final purchase = trade(price: 10, shares: 10);
          final native = StockDataManager.applyQuotes(
            [holding('0HCX', 'CHF')],
            quotes,
            {
              '0HCX': [purchase],
            },
          ).single;
          expect(native.currency, 'CHF');
          expect(native.currentPrice, 24.565);
          expect(native.profitLossAmount, closeTo(145.65, 1e-9));
          final old = holding('0HCX', 'GBP');
          expect(
            StockDataManager.applyQuotes(
              [old],
              quotes,
              {
                '0HCX': [purchase],
              },
            ).single,
            same(old),
          );
          expect(purchase.amount, 10);
          expect(quotes['155.0RUQ']!.currentPrice, .16);
          expect(quotes['155.0RUQ']!.currency, 'SEK');
        },
        () => MockClient((request) async {
          expect(request.url.host, 'query1.finance.yahoo.com');
          return http.Response(
            fixture(request.url.pathSegments.last.replaceAll('.L', '')),
            200,
          );
        }),
      );
    },
  );

  test(
    'pence aliases are selectable and convert only for summaries or legacy holdings',
    () {
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
        expect(ExchangeRateService().effectiveRates[code], greaterThan(0));
      }
      expect(
        CurrencyUtil.convertCurrency(100, 'GBp', 'GBP'),
        closeTo(1, 1e-12),
      );
      expect(
        CurrencyUtil.convertCurrency(1, 'GBP', 'GBX'),
        closeTo(100, 1e-12),
      );
      final quote = StockQuote(
        code: 'UQLT',
        name: 'UQLT',
        currentPrice: 4031.5,
        changePercent: 0,
        market: 'LSE',
        currency: 'GBp',
      );
      final old = StockDataManager.applyQuotes(
        [holding('UQLT', 'GBP')],
        {'155.UQLT': quote},
        {
          'UQLT': [trade(price: 10)],
        },
      ).single;
      expect(old.currency, 'GBP');
      expect(old.currentPrice, 40.315);
    },
  );

  test(
    'real cached FX protects legacy GBP cost without changing native quotes',
    () async {
      var requests = 0;
      await http.runWithClient(
        () async {
          final service = ExchangeRateService();
          await Future.wait([service.fetchRates(), service.fetchRates()]);
          expect(requests, 1);
          final quote = StockQuote(
            code: '0HCX',
            name: '0HCX',
            currentPrice: 24.565,
            changePercent: 0,
            market: 'LSE',
            currency: 'CHF',
          );
          final purchase = trade(price: 10, shares: 10);
          final old = StockDataManager.applyQuotes(
            [holding('0HCX', 'GBP')],
            {'155.0HCX': quote},
            {
              '0HCX': [purchase],
            },
          ).single;
          expect(old.currentPrice, closeTo(24.565 / .9 * .8, 1e-9));
          expect(old.currency, 'GBP');
          expect(purchase.amount, 10);
          expect(quote.currentPrice, 24.565);
          expect(service.effectiveRates['GBp'], 80);
          expect(
            await service.conversionRate('GBp', 'CHF'),
            closeTo(.9 / 80, 1e-9),
          );
          expect(CurrencyUtil.convertCurrency(10, 'SEK', 'USD'), 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.host, 'open.er-api.com');
          return http.Response(
            jsonEncode({
              'rates': {'USD': 1, 'GBP': .8, 'CHF': .9, 'SEK': 10},
            }),
            200,
          );
        }),
      );
    },
  );

  test(
    'all supported London currency codes preserve the exact provider price',
    () async {
      for (final currency in ExchangeRateService.supportedCurrencies) {
        final body = jsonDecode(fixture('0HCX'));
        body['chart']['result'][0]['meta']['currency'] = currency;
        await http.runWithClient(
          () async {
            final quote = await YahooQuoteService().fetchQuote(stock('0HCX'));
            expect(quote!.currentPrice, 24.565);
            expect(quote.currency, currency);
          },
          () => MockClient((request) async {
            expect(request.url.host, 'query1.finance.yahoo.com');
            return http.Response(jsonEncode(body), 200);
          }),
        );
      }
    },
  );

  test(
    'unknown currency or a missing symbol never becomes a guessed quote',
    () async {
      final body = jsonDecode(fixture('0HCX'));
      body['chart']['result'][0]['meta']['currency'] = 'ZZZ';
      await http.runWithClient(() async {
        expect(await YahooQuoteService().fetchQuote(stock('0HCX')), isNull);
      }, () => MockClient((_) async => http.Response(jsonEncode(body), 200)));
      await http.runWithClient(() async {
        expect(
          await StockQuoteService().getStockQuotesBatch([stock('0NUQ')]),
          isEmpty,
        );
      }, () => MockClient((_) async => http.Response('{}', 404)));
    },
  );
}
