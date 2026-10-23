import 'dart:io';

import 'package:assets/models/stock_search_models.dart';
import 'package:assets/services/stock_quote_service.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/stock_data_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/core_fixtures.dart';

class StubQuoteService implements StockQuoteService {
  final Map<String, StockQuote?> quotes;
  List<StockSearchResult> requested = [];
  StubQuoteService(this.quotes);
  @override
  Future<Map<String, StockQuote?>> getStockQuotesBatch(
    List<StockSearchResult> stocks,
  ) async {
    requested = stocks;
    return quotes;
  }

  @override
  int get cooldownRemainingSeconds => 0;
  @override
  StockQuote? getCachedQuote(String secid) => quotes[secid];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));

  test(
    'quote application matches secid and recalculates holdings from trades',
    () {
      final original = stock();
      final result = StockDataManager.applyQuotes(
        [original],
        {
          original.secid: StockQuote(
            code: original.symbol,
            name: 'renamed',
            currentPrice: 15,
            changePercent: -2,
            market: '美股',
          ),
        },
        {
          original.symbol: [trade(fee: 1)],
        },
      );
      expect(result.single.currentPrice, 15);
      expect(result.single.changePercent, -2);
      expect(result.single.totalValue, 150);
      expect(result.single.profitLossAmount, 49);
      expect(result.single.companyName, original.companyName);
      expect(original.currentPrice, 12);
      expect(original.profitLossAmount, 20);
    },
  );
  test('missing or failed quotes retain last known values', () {
    final first = stock(symbol: 'A');
    final second = stock(symbol: 'B');
    final source = [first, second];
    final result = StockDataManager.applyQuotes(source, {
      first.secid: null,
    }, {});
    expect(result, [first, second]);
    expect(identical(result, source), isFalse);
    expect(result.first.currentPrice, 12);
  });
  test('no trade history clears stale holdings while preserving quote', () {
    final original = stock();
    for (final records in <List<OperationRecord>?>[null, []]) {
      final result = StockDataManager.recalculateStock(original, records);
      expect(result.shares, 0);
      expect(result.totalValue, 0);
      expect(result.profitLossAmount, 0);
      expect(result.profitLossPercent, 0);
      expect(result.currentPrice, original.currentPrice);
      expect(result.isPositive, isTrue);
    }
  });
  test('custom stocks are excluded from remote quote queries', () {
    final result = StockDataManager.buildSearchResults([
      stock(symbol: 'REMOTE'),
      stock(symbol: 'CUSTOM', custom: true),
    ]);
    expect(result.length, 1);
    expect(result.single.code, 'REMOTE');
    expect(result.single.secid, '105.REMOTE');
    expect(result.single.name, 'REMOTE company');
    expect(result.single.market, 'NASDAQ');
    expect(StockDataManager.buildSearchResults([]), isEmpty);
  });
  test(
    'quote refresh recalculates and persists portfolio with its histories',
    () async {
      final original = stock();
      final service = StubQuoteService({
        original.secid: StockQuote(
          code: original.symbol,
          name: original.companyName,
          currentPrice: 15,
          changePercent: 2,
          market: original.marketType,
        ),
      });
      final records = {
        original.symbol: [trade(fee: 1)],
      };
      final dividends = {
        original.symbol: [dividend()],
      };
      final result = await StockDataManager.fetchQuotesAndSave(
        service,
        [original, stock(symbol: 'LOCAL', custom: true)],
        records,
        dividends,
      );
      expect(result.first.totalValue, 150);
      expect(result.first.profitLossAmount, 49);
      expect(service.requested.map((s) => s.code), ['TEST']);
      final saved = await IcloudStorage.loadStocks();
      expect(saved.$1.first.currentPrice, 15);
      expect(saved.$1.first.profitLossAmount, 49);
      expect(saved.$2[original.symbol]!.single.fee, 1);
      expect(saved.$3[original.symbol]!.single.afterTaxAmount, 9);
      expect(original.currentPrice, 12);
    },
  );
  test(
    'empty quote response retains portfolio and previously saved data',
    () async {
      final original = stock();
      await IcloudStorage.saveStocks([original], {}, {});
      final source = [original];
      final service = StubQuoteService({});
      final result = await StockDataManager.fetchQuotesAndSave(
        service,
        source,
        {},
        {},
      );
      expect(result, source);
      expect((await IcloudStorage.loadStocks()).$1.single.currentPrice, 12);
      expect(
        await StockDataManager.fetchQuotesAndSave(service, [], {}, {}),
        isEmpty,
      );
    },
  );
}
