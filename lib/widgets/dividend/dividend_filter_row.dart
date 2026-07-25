import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../utils/market_util.dart';
import '../common/app_ui.dart';

/// 全局股息页筛选 + 排序行
class DividendFilterRow extends StatelessWidget {
  final String? filterMarket;
  final String sortKey;
  final bool sortAscending;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<String> onSortChanged;

  const DividendFilterRow({
    super.key,
    required this.filterMarket,
    required this.sortKey,
    required this.sortAscending,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final markets = <String?>[
      null,
      MarketUtil.searchMarketUS,
      MarketUtil.searchMarketHK,
      MarketUtil.searchMarketCN,
    ];
    final marketLabels = [
      StockConfig.dividendAllMarkets,
      MarketUtil.searchMarketUS,
      MarketUtil.searchMarketHK,
      MarketUtil.searchMarketCN,
    ];
    final sortOptions = [
      StockConfig.dividendSortYield,
      StockConfig.dividendSortCostYield,
      StockConfig.dividendSortAmount,
      StockConfig.dividendSortDate,
      StockConfig.dividendSortName,
    ];
    final sortKeys = [
      'marketYield',
      'costYield',
      'totalAmount',
      'latestDate',
      'name',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(marketLabels.length, (i) {
                final selected = filterMarket == markets[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < marketLabels.length - 1 ? 8 : 0,
                  ),
                  child: FilterPill(
                    label: marketLabels[i],
                    selected: selected,
                    onTap: () => onFilterChanged(markets[i]),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(sortOptions.length, (i) {
                final selected = sortKey == sortKeys[i];
                final icon = selected
                    ? (sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                    : null;
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < sortOptions.length - 1 ? 8 : 0,
                  ),
                  child: FilterPill(
                    label: sortOptions[i],
                    selected: selected,
                    onTap: () => onSortChanged(sortKeys[i]),
                    trailingIcon: icon,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
