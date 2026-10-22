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
    'A股': 'CNY',
    '日股': 'JPY',
    '韩股': 'KRW',
    '英股': 'GBP',
    '粉单': 'USD',
  };
  tearDown(() => L10n.applyLanguage(L10n.langZh));
  test(
    'all market groups, including A-share submarkets, filter and map currencies',
    () {
      expect(MarketUtil.searchMarkets.toSet(), currencies.keys.toSet());
      expect(MarketUtil.holdingMarkets, contains(MarketUtil.customMarket));
      for (final group in MarketUtil.marketGroups.entries) {
        for (final submarket in group.value) {
          expect(MarketUtil.supportMarket(submarket), isTrue);
          expect(MarketUtil.normalizeMarket(submarket), group.key);
          expect(
            MarketUtil.currencyForMarket(submarket),
            currencies[group.key],
          );
          expect(MarketUtil.matchesFilter(group.key, submarket), isTrue);
          expect(MarketUtil.matchesFilter(null, submarket), isTrue);
          expect(
            MarketUtil.matchesFilter(MarketUtil.searchAll, submarket),
            isTrue,
          );
          expect(
            StockStyle.marketColor(submarket),
            StockStyle.marketColor(group.key),
          );
          for (final other in currencies.keys.where((m) => m != group.key)) {
            expect(MarketUtil.matchesFilter(other, submarket), isFalse);
          }
        }
      }
      expect(MarketUtil.matchesFilter('A股', 'A股'), isTrue);
      expect(MarketUtil.matchesFilter('沪A', '沪A'), isTrue);
      expect(MarketUtil.matchesFilter('沪A', '深A'), isFalse);
      expect(MarketUtil.supportMarket('外汇'), isFalse);
      expect(MarketUtil.tencentPrefix('unknown', '999.ABC'), isNull);
      for (final market in ['日股', '韩股', '英股', '粉单']) {
        expect(MarketUtil.tencentPrefix(market, ''), isNull);
        // Foreign market labels must not be mistaken for US even with a bad secid.
        expect(MarketUtil.tencentPrefix(market, '105.ABC'), isNull);
      }
    },
  );

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
    final labels = {
      L10n.langZh: ['日股', '韩股', '英股', '粉单'],
      L10n.langZhHant: ['日股', '韓股', '英股', '粉單'],
      L10n.langEn: ['JP', 'KR', 'UK', 'Pink Sheets'],
    };
    for (final entry in labels.entries) {
      L10n.applyLanguage(entry.key);
      expect(['日股', '韩股', '英股', '粉单'].map(MarketUtil.marketLabel), entry.value);
      expect(MarketUtil.marketLabel('沪A'), MarketUtil.marketLabel('A股'));
      expect(MarketUtil.marketLabel('深A'), MarketUtil.marketLabel('A股'));
    }
  });
}
