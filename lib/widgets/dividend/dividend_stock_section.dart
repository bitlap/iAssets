import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calculator_models.dart';
import '../../models/stock_model.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../utils/currency_util.dart';
import '../common/app_ui.dart';
import 'dividend_record_list.dart';

/// 每只股票的股息聚合区块
class DividendStockSection extends StatelessWidget {
  final GlobalDividendStockItem item;
  final bool isExpanded;
  final VoidCallback onTap;

  const DividendStockSection({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildYieldTiles(),
              _buildDetailRow(),
              const SizedBox(height: 8),
              const DashedDivider(),
              const SizedBox(height: 8),
              _buildFooter(),
              if (isExpanded)
                DividendRecordList(
                  records: item.records,
                  currency: item.currency,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.companyName,
                  style: TextStyles.subtitle.copyWith(height: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.symbol} · ${item.recordCount} ${StockConfig.dividendRecordCount}',
                  style: TextStyles.bodySmall,
                ),
              ],
            ),
          ),
          MarketAndCurrencyBadges(
            market: item.marketType,
            currency: item.currency,
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  Widget _buildYieldTiles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: YieldTile(
              label: StockConfig.dividendCostYield,
              value: '${item.costDividendYield.toStringAsFixed(2)}%',
              valueColor: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: YieldTile(
              label: StockConfig.dividendMarketYield,
              value: '${item.marketDividendYield.toStringAsFixed(2)}%',
              valueColor: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow() {
    final sym = CurrencyUtil.getSymbol(item.currency);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildDetailCell(
              StockConfig.dividendTotalAfterTax,
              '$sym${CurrencyUtil.formatCompact(item.totalAfterTaxDividends)}',
            ),
          ),
          Expanded(
            child: _buildDetailCell(
              StockConfig.dividendCurrentCost,
              '$sym${CurrencyUtil.formatCompact(item.currentCost)}',
            ),
          ),
          Expanded(
            child: _buildDetailCell(
              StockConfig.dividendCurrentValue,
              '$sym${CurrencyUtil.formatCompact(item.currentMarketValue)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyles.label),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyles.valueSmallMono,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${StockConfig.dividendLatestDate} ${item.latestDividendDate != null ? DateFormat(StockConfig.recordsDatePattern).format(item.latestDividendDate!) : '-'}',
              style: TextStyles.caption,
            ),
          ),
          Text(StockConfig.dividendExpandAll, style: TextStyles.accentLink),
        ],
      ),
    );
  }
}
