import 'package:assets/utils/trading_day_util.dart';
import 'package:assets/utils/market_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DST starts at 07:00 UTC on the second Sunday in March', () {
    expect(
      TradingDayUtil.isEasternDST(DateTime.utc(2026, 3, 8, 6, 59, 59)),
      isFalse,
    );
    expect(TradingDayUtil.isEasternDST(DateTime.utc(2026, 3, 8, 7)), isTrue);
    expect(
      TradingDayUtil.toEastern(DateTime.utc(2026, 3, 8, 6, 59)),
      DateTime.utc(2026, 3, 8, 1, 59),
    );
    expect(
      TradingDayUtil.toEastern(DateTime.utc(2026, 3, 8, 7)),
      DateTime.utc(2026, 3, 8, 3),
    );
  });
  test('DST ends at 06:00 UTC on the first Sunday in November', () {
    expect(
      TradingDayUtil.isEasternDST(DateTime.utc(2026, 11, 1, 5, 59, 59)),
      isTrue,
    );
    expect(TradingDayUtil.isEasternDST(DateTime.utc(2026, 11, 1, 6)), isFalse);
    expect(
      TradingDayUtil.toEastern(DateTime.utc(2026, 11, 1, 5, 59)),
      DateTime.utc(2026, 11, 1, 1, 59),
    );
    expect(
      TradingDayUtil.toEastern(DateTime.utc(2026, 11, 1, 6)),
      DateTime.utc(2026, 11, 1, 1),
    );
  });
  for (final month in [1, 7]) {
    test('9 AM Eastern day boundary in month $month', () {
      final hour = month == 1 ? 14 : 13;
      expect(
        TradingDayUtil.tradingDayKey(
          DateTime.utc(2026, month, 2, hour - 1, 59, 59),
        ),
        '2026-${month.toString().padLeft(2, '0')}-01',
      );
      expect(
        TradingDayUtil.tradingDayKey(DateTime.utc(2026, month, 2, hour)),
        '2026-${month.toString().padLeft(2, '0')}-02',
      );
    });
  }
  test('day key crosses year and leap day boundaries', () {
    expect(
      TradingDayUtil.tradingDayKey(DateTime.utc(2026, 1, 1, 13)),
      '2025-12-31',
    );
    expect(
      TradingDayUtil.tradingDayKey(DateTime.utc(2024, 3, 1, 13)),
      '2024-02-29',
    );
    expect(
      TradingDayUtil.tradingDayKey(DateTime.utc(2026, 3, 1, 13)),
      '2026-02-28',
    );
  });
  test('local and UTC representations produce the same day key', () {
    final utc = DateTime.utc(2026, 7, 1, 13);
    expect(
      TradingDayUtil.tradingDayKey(utc.toLocal()),
      TradingDayUtil.tradingDayKey(utc),
    );
  });
  test('A-share exchanges all map to CNY and match the A-share filter', () {
    for (final market in MarketUtil.cnMarkets) {
      expect(MarketUtil.isChineseMarket(market), isTrue);
      expect(MarketUtil.currencyForMarket(market), 'CNY');
      expect(
        MarketUtil.matchesFilter(MarketUtil.searchMarketCN, market),
        isTrue,
      );
      expect(MarketUtil.supportMarket(market), isTrue);
    }
    expect(
      MarketUtil.matchesFilter(
        MarketUtil.searchMarketCN,
        MarketUtil.searchMarketHK,
      ),
      isFalse,
    );
    expect(MarketUtil.matchesFilter(null, MarketUtil.searchMarketUS), isTrue);
    expect(
      MarketUtil.matchesFilter(
        MarketUtil.searchMarketUS,
        MarketUtil.searchMarketHK,
      ),
      isFalse,
    );
  });
  for (final entry in {
    '105.AAPL': 'us',
    '106.TEST': 'us',
    '107.TEST': 'us',
    '116.00700': 'hk',
    '1.600519': 'sh',
    '0.000001': 'sz',
  }.entries) {
    test(
      'Tencent exchange prefix for ${entry.key}',
      () => expect(MarketUtil.tencentPrefix('unknown', entry.key), entry.value),
    );
  }
  test('explicit exchanges and currency fallbacks', () {
    expect(MarketUtil.tencentPrefix(MarketUtil.exchangeSH, ''), 'sh');
    expect(MarketUtil.tencentPrefix(MarketUtil.exchangeSZ, ''), 'sz');
    expect(MarketUtil.currencyForMarket(MarketUtil.searchMarketHK), 'HKD');
    expect(MarketUtil.currencyForMarket(MarketUtil.searchMarketUS), 'USD');
    expect(MarketUtil.currencyForMarket(MarketUtil.customMarket), 'USD');
    expect(MarketUtil.supportMarket('unknown'), isFalse);
  });
}
