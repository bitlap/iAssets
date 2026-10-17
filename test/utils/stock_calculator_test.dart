import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/utils/stock_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));

  group('trade accounting', () {
    test('empty history has finite zero statistics', () {
      final stats = StockCalculator.calculateRecordStats([]);
      expect(stats.currentShares, 0);
      expect(stats.totalBuyAmount, 0);
      expect(stats.totalSellAmount, 0);
      expect(stats.minBuyPrice, 0);
      expect(stats.maxBuyPrice, 0);
      expect(stats.avgBuyPrice, 0);
      expect(stats.buyCount, 0);
      expect(stats.sellCount, 0);
      expect(StockCalculator.calculateAvgBuyPrice([]), 0);
    });

    test('multiple buys and partial sale include fees in net cost', () {
      final records = [
        trade(price: 10, shares: 10, fee: 2),
        trade(price: 20, shares: 5, fee: 1),
        trade(type: StockConfig.opSellType, price: 30, shares: 4, fee: 3),
      ];
      final stats = StockCalculator.calculateRecordStats(records);
      expect(stats.currentShares, 11);
      expect(stats.totalBuyAmount, 203);
      expect(stats.totalSellAmount, 117);
      expect(stats.avgBuyPrice, closeTo(86 / 11, 1e-10));
      expect(
        StockCalculator.calculateAvgBuyPrice(records),
        closeTo(86 / 11, 1e-10),
      );
      expect(stats.buyCount, 2);
      expect(stats.sellCount, 1);
      expect(stats.minBuyPrice, 10);
      expect(stats.maxBuyPrice, 20);
    });

    test('unrecognized operations do not change holdings or cost', () {
      final stats = StockCalculator.calculateRecordStats([
        trade(),
        trade(type: 'note', price: 999, shares: 999),
      ]);
      expect(stats.currentShares, 10);
      expect(stats.totalBuyAmount, 100);
      expect(stats.buyCount, 1);
      expect(stats.sellCount, 0);
    });

    test(
      'fractional shares preserve value within floating point tolerance',
      () {
        final result =
            StockCalculator.recalculateFromRecords(stock(price: 100), [
              trade(price: 80, shares: .3),
              trade(type: StockConfig.opSellType, price: 90, shares: .1),
            ]);
        expect(result.shares, closeTo(.2, 1e-12));
        expect(result.totalValue, closeTo(20, 1e-12));
        expect(result.profitLossAmount, closeTo(5, 1e-12));
      },
    );

    test('negative rounding residue after full sale clamps shares to zero', () {
      final stats = StockCalculator.calculateRecordStats([
        trade(shares: .3),
        trade(type: StockConfig.opSellType, shares: .1),
        trade(type: StockConfig.opSellType, shares: .2),
      ]);
      expect(stats.currentShares, 0);
      expect(stats.avgBuyPrice, 0);
    });

    test('recalculation returns a copy and includes buy and sell fees', () {
      final original = stock(price: 15);
      final result = StockCalculator.recalculateFromRecords(original, [
        trade(fee: 2),
        trade(type: StockConfig.opSellType, price: 12, shares: 4, fee: 1),
      ]);
      expect(result.shares, 6);
      expect(result.totalValue, 90);
      expect(result.profitLossAmount, 35);
      expect(result.profitLossPercent, closeTo(35 / 55 * 100, 1e-10));
      expect(result.isPositive, isTrue);
      expect(original.shares, 10);
      expect(original.currentPrice, result.currentPrice);
      expect(original.symbol, result.symbol);
    });

    for (final proceeds in [8.0, 12.0]) {
      test('closing at $proceeds records realized profit after fees', () {
        final result = StockCalculator.recalculateFromRecords(stock(), [
          trade(fee: 2),
          trade(type: StockConfig.opSellType, price: proceeds, fee: 1),
        ]);
        final expected = proceeds == 8 ? -23 : 17;
        expect(result.shares, 0);
        expect(result.totalValue, 0);
        expect(result.profitLossAmount, expected);
        expect(result.profitLossPercent, 0);
        expect(result.isPositive, expected >= 0);
      });
    }

    test(
      'sale exceeding cost leaves negative net cost without infinite returns',
      () {
        final result = StockCalculator.recalculateFromRecords(
          stock(price: 20),
          [trade(), trade(type: StockConfig.opSellType, price: 30, shares: 5)],
        );
        expect(result.totalValue, 100);
        expect(result.profitLossAmount, 150);
        expect(result.profitLossPercent, 0);
        expect(result.isPositive, isTrue);
      },
    );

    test('no records leaves existing calculated model untouched', () {
      final original = stock();
      expect(
        identical(
          StockCalculator.recalculateFromRecords(original, []),
          original,
        ),
        isTrue,
      );
    });
  });

  group('portfolio totals', () {
    test('empty portfolio returns zero totals without division by zero', () {
      final result = StockCalculator.calculateAssetSummary([], {}, {}, 'USD');
      expect(result.totalAssets, 0);
      expect(result.totalMarketValue, 0);
      expect(result.totalCost, 0);
      expect(result.totalProfit, 0);
      expect(result.totalRealizedPL, 0);
      expect(result.totalProfitPercent, 0);
      expect(result.totalSellAmount, 0);
      expect(result.totalAfterTaxDividends, 0);
    });

    test(
      'open and closed positions convert once and keep dividends separate',
      () {
        final result = StockCalculator.calculateAssetSummary(
          [
            stock(symbol: 'OPEN'),
            stock(symbol: 'CLOSED', currency: 'HKD', shares: 0, profit: 80),
          ],
          {
            'OPEN': [trade()],
            'CLOSED': [
              trade(price: 80),
              trade(type: StockConfig.opSellType, price: 88),
            ],
          },
          {
            'OPEN': [dividend()],
            'CLOSED': [dividend(amount: 8, currency: 'HKD')],
          },
          'USD',
        );
        expect(result.totalMarketValue, 120);
        expect(result.totalSellAmount, 110);
        expect(result.totalAssets, 230);
        expect(result.totalCost, 100);
        expect(result.totalRealizedPL, 10);
        expect(result.totalProfit, 30);
        expect(result.totalProfitPercent, 15);
        expect(result.totalAfterTaxDividends, 18);
      },
    );

    test('missing histories produce finite totals', () {
      final result = StockCalculator.calculateAssetSummary(
        [stock()],
        {},
        null,
        'USD',
      );
      expect(result.totalProfit, 20);
      expect(result.totalProfitPercent, 0);
      expect(result.totalCost, 0);
      expect(result.totalAfterTaxDividends, 0);
    });
  });

  group('dividend aggregation', () {
    test('trailing year includes cutoff and excludes older dividends', () {
      final now = DateTime.now();
      final cutoff = DateTime(now.year - 1, now.month, now.day);
      final result = StockCalculator.calculateDividendItem(
        stock(),
        [trade()],
        [
          dividend(date: cutoff.subtract(const Duration(days: 1)), amount: 2),
          dividend(date: cutoff),
          dividend(date: DateTime(now.year, now.month, now.day), amount: 3),
        ],
      );
      expect(result.totalAfterTaxDividends, 54);
      expect(result.trailingAfterTaxDividends, 36);
      expect(result.currentCost, 100);
      expect(result.currentMarketValue, 120);
      expect(result.costDividendYield, 36);
      expect(result.marketDividendYield, 30);
      expect(result.latestDividendDate, DateTime(now.year, now.month, now.day));
      expect(result.recordCount, 3);
    });

    test('closed position retains dividend history with zero yields', () {
      final result = StockCalculator.calculateDividendItem(
        stock(shares: 0),
        [],
        [dividend()],
      );
      expect(result.totalAfterTaxDividends, 9);
      expect(result.costDividendYield, 0);
      expect(result.marketDividendYield, 0);
    });

    test(
      'global overview weights yields by converted cost and market value',
      () {
        final recent = DateTime.now().subtract(const Duration(days: 1));
        final result = StockCalculator.calculateGlobalDividendOverview(
          [
            stock(symbol: 'US'),
            stock(symbol: 'HK', currency: 'HKD', price: 160),
            stock(symbol: 'NONE'),
          ],
          {
            'US': [trade()],
            'HK': [trade(price: 80)],
          },
          {
            'US': [dividend(date: recent)],
            'HK': [dividend(date: recent, amount: 16, currency: 'HKD')],
          },
          'USD',
        );
        expect(result.items.map((i) => i.symbol), ['US', 'HK']);
        expect(result.totalAfterTaxDividends, 27);
        expect(result.trailingAfterTaxDividends, 27);
        expect(result.totalCurrentCost, 200);
        expect(result.totalCurrentMarketValue, 320);
        expect(result.costDividendYield, 13.5);
        expect(result.marketDividendYield, 8.4375);
      },
    );

    test('empty global dividend overview has no NaN yields', () {
      final result = StockCalculator.calculateGlobalDividendOverview(
        [],
        {},
        {},
        'USD',
      );
      expect(result.items, isEmpty);
      expect(result.costDividendYield, 0);
      expect(result.marketDividendYield, 0);
      expect(result.totalAfterTaxDividends, 0);
    });
  });

  group('sorting', () {
    test('market value order uses converted currency and preserves input', () {
      final source = [
        stock(symbol: 'HK', currency: 'HKD', price: 80),
        stock(symbol: 'US', price: 20),
      ];
      expect(
        StockCalculator.sortStocks(
          source,
          'holdings',
          false,
          'USD',
        ).map((s) => s.symbol),
        ['US', 'HK'],
      );
      expect(source.map((s) => s.symbol), ['HK', 'US']);
      expect(
        StockCalculator.sortStocks(
          source,
          'holdings',
          true,
          'USD',
        ).map((s) => s.symbol),
        ['HK', 'US'],
      );
    });
    test('equal market values use share count to break ties', () {
      final source = [
        stock(symbol: 'A', price: 20, shares: 5),
        stock(symbol: 'B', price: 10, shares: 10),
      ];
      expect(
        StockCalculator.sortStocks(
          source,
          'holdings',
          false,
          'USD',
        ).first.symbol,
        'B',
      );
    });
    test(
      'equal converted profits use converted market value to break ties',
      () {
        final source = [
          stock(symbol: 'HK', currency: 'HKD', profit: 80, price: 80),
          stock(symbol: 'US', profit: 10, price: 20),
        ];
        expect(
          StockCalculator.sortStocks(
            source,
            'profit',
            false,
            'USD',
          ).map((s) => s.symbol),
          ['US', 'HK'],
        );
      },
    );
    test('name sorting supports both directions', () {
      final source = [stock(symbol: 'B'), stock(symbol: 'A')];
      expect(
        StockCalculator.sortStocks(source, 'name', true, 'USD').first.symbol,
        'A',
      );
      expect(
        StockCalculator.sortStocks(source, 'name', false, 'USD').first.symbol,
        'B',
      );
    });
  });
}
