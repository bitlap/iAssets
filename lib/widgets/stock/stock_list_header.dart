import 'package:flutter/material.dart';
import '../common/app_colors.dart';
import '../../config/app_config.dart';
import '../common/app_ui.dart';
import '../common/sort_indicator.dart';
import '../../utils/market_util.dart';
import '../common/app_filter_dropdown.dart';
import 'stock_columns.dart';

class StockListHeader extends StatelessWidget {
  final String sortColumn;
  final bool sortAscending;
  final ValueChanged<String> onColumnTap;
  final String? filterMarket;
  final ValueChanged<String?> onMarketChanged;
  final int stockCount;

  const StockListHeader({
    super.key,
    required this.sortColumn,
    required this.sortAscending,
    required this.onColumnTap,
    required this.filterMarket,
    required this.onMarketChanged,
    this.stockCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(StockConfig.stockMarketTitle, style: TextStyles.bodyMedium),
          const SizedBox(height: 8),
          AppFilterDropdown<String>(
            value: filterMarket,
            items: [
              for (final market in <String?>[
                null,
                MarketUtil.searchMarketUS,
                MarketUtil.searchMarketHK,
                MarketUtil.searchMarketCN,
                MarketUtil.customMarket,
              ])
                DropdownMenuItem(
                  value: market,
                  child: Text(
                    MarketUtil.marketLabel(market ?? MarketUtil.searchAll),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onMarketChanged,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.5),
            child: StockColumns(
              name: GestureDetector(
                onTap: () => onColumnTap('name'),
                behavior: HitTestBehavior.opaque,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        StockConfig.homeStockHeader,
                        style: TextStyles.body13.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (stockCount > 0)
                        Text(
                          '($stockCount)',
                          style: TextStyles.body13.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      SortIndicator(
                        isActive: sortColumn == 'name',
                        isAscending: sortAscending,
                      ),
                    ],
                  ),
                ),
              ),
              holdings: GestureDetector(
                onTap: () => onColumnTap('holdings'),
                behavior: HitTestBehavior.opaque,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        StockConfig.homeHoldingHeader,
                        style: TextStyles.subtitleRegular.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SortIndicator(
                        isActive: sortColumn == 'holdings',
                        isAscending: sortAscending,
                      ),
                    ],
                  ),
                ),
              ),
              profit: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => onColumnTap('profit'),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SortIndicator(
                        isActive: sortColumn == 'profit',
                        isAscending: sortAscending,
                      ),
                      Text(
                        StockConfig.homeProfitHeader,
                        style: TextStyles.body13.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
