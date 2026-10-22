import 'package:assets/l10n/l10n.dart';
import 'package:assets/services/serde/converters.dart';
import 'package:assets/utils/market_util.dart';
import 'package:assets/widgets/stock/stock_style.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/core_fixtures.dart';

void main() {
  final currencies = {
    '美股': 'USD',
    '港股': 'HKD',
    '沪A': 'CNY',
    '深A': 'CNY',
    '基金': 'CNY',
    '债券': 'CNY',
    '指数': 'CNY',
    '三板': 'CNY',
    '日股': 'JPY',
    '韩股': 'KRW',
    '英股': 'GBP',
    '粉单': 'USD',
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

  test('market labels are localized in all three languages', () {
    final markets = [
      '日股',
      '韩股',
      '英股',
      '粉单',
      '沪A',
      '深A',
      '基金',
      '债券',
      '指数',
      '三板',
    ];
    final labels = {
      L10n.langZh: markets,
      L10n.langZhHant: [
        '日股',
        '韓股',
        '英股',
        '粉單',
        '滬A',
        '深A',
        '基金',
        '債券',
        '指數',
        '三板',
      ],
      L10n.langEn: [
        'JP',
        'KR',
        'UK',
        'Pink Sheets',
        'Shanghai A',
        'Shenzhen A',
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
}
