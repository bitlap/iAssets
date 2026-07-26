import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../utils/market_util.dart';
import '../common/app_ui.dart';
import '../common/sort_indicator.dart';

class StockListHeader extends StatelessWidget {
  final String sortColumn;
  final bool sortAscending;
  final ValueChanged<String> onColumnTap;
  final String? filterMarket;
  final VoidCallback onFilterTap;
  final int stockCount;

  const StockListHeader({
    super.key,
    required this.sortColumn,
    required this.sortAscending,
    required this.onColumnTap,
    required this.filterMarket,
    required this.onFilterTap,
    this.stockCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 2, 26, 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: GestureDetector(
              onTap: onFilterTap,
              child: Icon(
                filterMarket != null
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                size: 18,
                color: MarketUtil.marketColor(filterMarket),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => onColumnTap('name'),
              behavior: HitTestBehavior.opaque,
              child: Row(
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
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => onColumnTap('holdings'),
              behavior: HitTestBehavior.opaque,
              child: Align(
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
          ),
          Expanded(
            flex: 1,
            child: Align(
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
        ],
      ),
    );
  }
}
