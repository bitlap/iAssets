import 'package:assets/l10n/l10n.dart';
import 'package:assets/services/serde/converters.dart';
import 'package:assets/utils/market_util.dart';
import 'package:assets/widgets/stock/stock_style.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/core_fixtures.dart';

void main() {
  final currencies = {
    'NASDAQ': 'USD',
    'NYSE': 'USD',
    'AMEX': 'USD',
    'HK': 'HKD',
    '沪A': 'CNY',
    '深A': 'CNY',
    '京A': 'CNY',
    '基金': 'CNY',
    '债券': 'CNY',
    '指数': 'CNY',
    '三板': 'CNY',
    'JPX': 'JPY',
    'KRX': 'KRW',
    'LSE': 'GBP',
    'OTCBB': 'USD',
  };
  tearDown(() => L10n.applyLanguage(L10n.langZh));
  test('provider markets filter independently and map to their currencies', () {
    expect(MarketUtil.searchMarkets.toSet(), currencies.keys.toSet());
    expect(MarketUtil.searchMarkets, isNot(contains('A股')));
    expect(MarketUtil.holdingMarkets, contains(MarketUtil.customMarket));
    for (final market in currencies.keys) {
      expect(MarketUtil.supportMarket(market), isTrue);
      expect(MarketUtil.currencyForMarket(market), currencies[market]);
      expect(MarketUtil.matchesFilter(market, market), isTrue);
      expect(MarketUtil.matchesFilter(null, market), isTrue);
      expect(MarketUtil.matchesFilter(MarketUtil.searchAll, market), isTrue);
      for (final other in currencies.keys.where((m) => m != market)) {
        expect(MarketUtil.matchesFilter(other, market), isFalse);
      }
    }
    expect(MarketUtil.matchesFilter('A股', '沪A'), isFalse);
    expect(MarketUtil.matchesFilter('A股', '深A'), isFalse);
    expect(MarketUtil.matchesFilter('A股', 'A股'), isTrue);
    expect(MarketUtil.currencyForMarket('A股'), 'CNY');
    expect(MarketUtil.supportMarket('外汇'), isFalse);
    expect(MarketUtil.tencentPrefix('unknown', '999.ABC'), isNull);
    for (final market in ['日股', '韩股', '英股', '粉单']) {
      expect(MarketUtil.tencentPrefix(market, ''), isNull);
      expect(MarketUtil.tencentPrefix(market, '105.ABC'), isNull);
    }
    expect(StockStyle.marketColor('沪A'), StockStyle.marketA);
    expect(StockStyle.marketColor('深A'), StockStyle.marketA);
  });

  test(
    'legacy stock records infer the new market currency without explicit currency',
    () {
      for (final market in currencies.keys) {
        final json = stocksToJson([stock()]).single..remove('currency');
        json['marketType'] = market;
        final inferred = stocksFromJson([json]).single;
        expect(inferred.currency, currencies[market]);
      }
    },
  );

  test(
    'legacy US holdings recover the exchange without changing custom records',
    () {
      for (final entry in {
        '105': 'NASDAQ',
        '106': 'NYSE',
        '107': 'AMEX',
      }.entries) {
        final json = stocksToJson([stock()]).single;
        json['marketType'] = '美股';
        json['secid'] = '${entry.key}.TEST';
        final restored = stocksFromJson([json]).single;
        expect(restored.marketType, entry.value);
        expect(restored.currency, 'USD');
        expect(
          stocksFromJson(stocksToJson([restored])).single.marketType,
          entry.value,
        );
        expect(
          MarketUtil.matchesFilter(entry.value, restored.marketType),
          isTrue,
        );
        expect(StockStyle.marketColor(entry.value), StockStyle.marketUS);
        json['isCustom'] = true;
        expect(stocksFromJson([json]).single.marketType, '美股');
      }
      expect(
        MarketUtil.marketFromProvider(
          '美股',
          exchange: 'NYSE',
          secid: '105.TEST',
        ),
        'NYSE',
      );
      expect(MarketUtil.marketFromProvider('美股', secid: '999.TEST'), '美股');
      expect(
        MarketUtil.marketFromProvider(
          '粉单',
          exchange: 'OTCBB',
          secid: '153.TEST',
        ),
        'OTCBB',
      );
      expect(
        MarketUtil.marketFromProvider('指数', exchange: 'QQZS', secid: '100.NDX'),
        '指数',
      );
      expect(MarketUtil.matchesFilter('NASDAQ', 'NYSE'), isFalse);
      expect(MarketUtil.matchesFilter('美股', 'NASDAQ'), isFalse);
    },
  );

  test('exchange labels are localized without regional market names', () {
    final markets = [
      'NASDAQ',
      'NYSE',
      'AMEX',
      'HK',
      'JPX',
      'KRX',
      'LSE',
      'OTCBB',
      '沪A',
      '深A',
      '京A',
      '基金',
      '债券',
      '指数',
      '三板',
    ];
    final labels = {
      L10n.langZh: [
        '纳斯达克',
        '纽交所',
        '美交所',
        '港交所',
        '日本交易所',
        '韩国交易所',
        '伦交所',
        '场外交易板',
        '沪A',
        '深A',
        '京A',
        '基金',
        '债券',
        '指数',
        '三板',
      ],
      L10n.langZhHant: [
        '納斯達克',
        '紐交所',
        '美交所',
        '港交所',
        '日本交易所',
        '韓國交易所',
        '倫交所',
        '場外交易板',
        '滬A',
        '深A',
        '京A',
        '基金',
        '債券',
        '指數',
        '三板',
      ],
      L10n.langEn: [
        'NASDAQ',
        'NYSE',
        'AMEX',
        'HKEX',
        'JPX',
        'KRX',
        'LSE',
        'OTCBB',
        'Shanghai A',
        'Shenzhen A',
        'Beijing A',
        'Funds',
        'Bonds',
        'Indices',
        'NEEQ',
      ],
    };
    for (final entry in labels.entries) {
      L10n.applyLanguage(entry.key);
      expect(markets.map(MarketUtil.marketLabel), entry.value);
      expect(MarketUtil.marketLabel('沪A'), isNot(MarketUtil.marketLabel('深A')));
      expect(MarketUtil.marketLabel('沪A'), isNot(MarketUtil.marketLabel('A股')));
    }
  });

  test('every historical regional market restores an independent exchange', () {
    final cases = {
      'A股': ('沪A', '1.600519', 'CNY'),
      '港股': ('HK', '116.00700', 'HKD'),
      '日股': ('JPX', '176.7203', 'JPY'),
      '韩股': ('KRX', '177.005930', 'KRW'),
      '英股': ('LSE', '155.HSBA', 'GBP'),
      '粉单': ('OTCBB', '153.NSRGY', 'USD'),
    };
    for (final entry in cases.entries) {
      final (exchange, secid, currency) = entry.value;
      expect(MarketUtil.searchMarkets, isNot(contains(entry.key)));
      expect(
        MarketUtil.marketFromProvider(
          entry.key,
          exchange: exchange,
          secid: secid,
        ),
        exchange,
      );
      final json = stocksToJson([stock()]).single..remove('currency');
      json['marketType'] = entry.key;
      json['secid'] = secid;
      final restored = stocksFromJson([json]).single;
      expect(restored.marketType, exchange);
      expect(restored.currency, currency);
      expect(
        stocksFromJson(stocksToJson([restored])).single.marketType,
        exchange,
      );
      expect(MarketUtil.matchesFilter(exchange, restored.marketType), isTrue);
      expect(MarketUtil.matchesFilter(entry.key, restored.marketType), isFalse);
      json['isCustom'] = true;
      expect(stocksFromJson([json]).single.marketType, entry.key);
    }
    expect(MarketUtil.marketFromProvider('A股', secid: '0.000001'), '深A');
    expect(MarketUtil.marketFromProvider('A股', secid: '0.920002'), '京A');
    expect(
      MarketUtil.marketFromProvider('日股', exchange: 'OTHER_JP'),
      'OTHER_JP',
    );
    expect(
      MarketUtil.marketFromProvider(
        '美股',
        exchange: 'OTHER_US',
        secid: '105.TEST',
      ),
      'OTHER_US',
    );
    expect(MarketUtil.tencentPrefix('HK', '116.00700'), 'hk');
    expect(MarketUtil.tencentPrefix('京A', '0.920002'), isNull);
    for (final exchange in ['JPX', 'KRX', 'LSE', 'OTCBB']) {
      expect(MarketUtil.tencentPrefix(exchange, '105.TEST'), isNull);
    }
  });
}
