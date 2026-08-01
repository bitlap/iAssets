import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
import '../../utils/currency_util.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../common/app_ui.dart';
import '../common/dialog_utils.dart';

// Header (Summary Card)

class AssetHeader extends StatelessWidget {
  final double totalAssets;
  final double stockTotalValue;
  final String currency;
  final VoidCallback onCurrencyTap;
  final Map<AssetType, double> totalsByType;

  const AssetHeader({
    super.key,
    required this.totalAssets,
    required this.stockTotalValue,
    required this.currency,
    required this.onCurrencyTap,
    required this.totalsByType,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(StockConfig.assetTotalAssets, style: TextStyles.body13),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onCurrencyTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currency,
                            style: TextStyles.body13.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildStockRatioColumn(context),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyUtil.getSymbol(currency)}${CurrencyUtil.formatCompact(totalAssets)}',
            style: TextStyles.amountLarge,
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

  Widget _buildStockRatioColumn(BuildContext context) {
    final ratio = totalAssets > 0 ? stockTotalValue / totalAssets : 0.0;
    final percent = '${(ratio * 100).toStringAsFixed(1)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              StockConfig.assetPositionRatioLabel,
              style: TextStyles.body13.copyWith(
                color: AppColors.textSecondary,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () => _showRatioHelpDialog(context),
              child: const Icon(
                Icons.help_outline,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          percent,
          style: TextStyles.body13.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showRatioHelpDialog(BuildContext context) {
    final entries = <(IconData, Color, String, double)>[
      (
        Icons.show_chart,
        AppColors.accent,
        StockConfig.tabStock,
        stockTotalValue,
      ),
      for (final type in AssetType.values)
        if ((totalsByType[type] ?? 0) > 0)
          switch (type) {
            AssetType.cash => (
              Icons.payments,
              AppColors.success,
              AssetConfig.cash,
              totalsByType[type]!,
            ),
            AssetType.timeDeposit => (
              Icons.savings,
              AppColors.warning,
              AssetConfig.timeDeposit,
              totalsByType[type]!,
            ),
            AssetType.wealthProduct => (
              Icons.monetization_on,
              AppColors.accent,
              AssetConfig.wealthProduct,
              totalsByType[type]!,
            ),
            AssetType.current => (
              Icons.account_balance,
              AppColors.cyan,
              AssetConfig.current,
              totalsByType[type]!,
            ),
            AssetType.providentFund => (
              Icons.home_work,
              AppColors.purple,
              AssetConfig.providentFund,
              totalsByType[type]!,
            ),
          },
    ];
    entries.sort((a, b) => b.$4.compareTo(a.$4));

    showDialog(
      context: context,
      builder: (ctx) => dialogFrame(
        context: ctx,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pie_chart, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  StockConfig.assetPositionRatioLabel,
                  style: TextStyles.subtitle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, thickness: 0.5),
            const SizedBox(height: 8),
            for (final (icon, color, label, value) in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: TextStyles.body13)),
                    Text(
                      _formatRatio(value),
                      style: TextStyles.body13.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            confirmButton(
              onTap: () => Navigator.of(ctx).pop(),
              text: AppConfig.btnClose,
              gradient: const LinearGradient(
                colors: [AppColors.blueDark, AppColors.blueAccent],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRatio(double value) {
    if (totalAssets <= 0) return '0.0%';
    return '${(value / totalAssets * 100).toStringAsFixed(1)}%';
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
            Text(label, style: TextStyles.caption),
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
