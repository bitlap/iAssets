import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../utils/currency_util.dart';
import '../../models/calculator_models.dart';
import '../common/app_ui.dart';

/// 全局股息页汇总指标卡片
class DividendHeader extends StatelessWidget {
  final GlobalDividendOverview overview;
  final String currency;

  const DividendHeader({
    super.key,
    required this.overview,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final sym = CurrencyUtil.getSymbol(currency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendTotalAfterTax,
                  value:
                      '$sym${CurrencyUtil.formatCompact(overview.totalAfterTaxDividends)}',
                  valueColor: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendTrailing12m,
                  value:
                      '$sym${CurrencyUtil.formatCompact(overview.trailingAfterTaxDividends)}',
                  valueColor: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendCostYield,
                  value: '${overview.costDividendYield.toStringAsFixed(2)}%',
                  valueColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendMarketYield,
                  value: '${overview.marketDividendYield.toStringAsFixed(2)}%',
                  valueColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
