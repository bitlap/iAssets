import 'package:flutter/material.dart';
import '../../utils/currency_util.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../config/asset_config.dart';
import '../common/app_ui.dart';

// Header (Summary Card)

class AssetHeader extends StatelessWidget {
  final double totalAssets;
  final double stockTotalValue;
  final String currency;
  final VoidCallback onCurrencyTap;

  const AssetHeader({
    super.key,
    required this.totalAssets,
    required this.stockTotalValue,
    required this.currency,
    required this.onCurrencyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                StockConfig.assetTotalAssets,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
              GestureDetector(
                onTap: onCurrencyTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyUtil.getSymbol(currency)}${CurrencyUtil.formatCompact(totalAssets)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryChip(
                Icons.show_chart,
                StockConfig.tabStock,
                CurrencyUtil.formatCompact(stockTotalValue),
                iconColor: AppColors.accent,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                Icons.account_balance,
                AssetConfig.depositWealthLabel,
                CurrencyUtil.formatCompact(totalAssets - stockTotalValue),
                iconColor: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _summaryChip(
  IconData icon,
  String label,
  String value, {
  Color iconColor = AppColors.textSecondary,
}) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyles.bodyRegular.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    ),
  );
}
