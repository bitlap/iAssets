import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
import '../../utils/currency_util.dart';
import '../../config/app_config.dart';
import '../common/app_colors.dart';
import '../common/app_ui.dart';
import '../common/currency_selector.dart';
import '../common/dialog_utils.dart';
import '../../l10n/l10n.dart';
import 'asset_style.dart';

// Header (Summary Card)

class AssetHeader extends StatelessWidget {
  final double totalAssets;
  final double stockTotalValue;
  final double cryptoTotalValue;
  final bool cryptoIncomplete;
  final DateTime? cryptoUpdatedAt;
  final String currency;
  final VoidCallback onCurrencyTap;
  final Map<AssetType, double> totalsByType;

  const AssetHeader({
    super.key,
    required this.totalAssets,
    required this.stockTotalValue,
    this.cryptoTotalValue = 0,
    this.cryptoIncomplete = false,
    this.cryptoUpdatedAt,
    required this.currency,
    required this.onCurrencyTap,
    required this.totalsByType,
  });

  @override
  Widget build(BuildContext context) {
    return SummaryCardFrame(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      gradient: AssetStyle.summaryGradient,
      borderColor: AssetStyle.summaryBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(StockConfig.assetTotalAssets, style: TextStyles.body13),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showRatioHelpDialog(context),
                child: Icon(
                  Icons.help_outline,
                  size: 13,
                  color: AppColors.warning,
                ),
              ),
              const Spacer(),
              CurrencySelectorButton(currency: currency, onTap: onCurrencyTap),
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
                Icons.currency_bitcoin,
                L10n.t('cryptoTitle'),
                cryptoIncomplete && cryptoUpdatedAt == null
                    ? '—'
                    : CurrencyUtil.formatCompact(cryptoTotalValue),
                iconColor: AssetStyle.crypto,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                Icons.account_balance,
                AssetConfig.depositWealthLabel,
                CurrencyUtil.formatCompact(
                  totalAssets - stockTotalValue - cryptoTotalValue,
                ),
                iconColor: AssetStyle.deposit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRatioHelpDialog(BuildContext context) {
    final entries = <(IconData, Color, String, double)>[
      (
        Icons.currency_bitcoin,
        AssetStyle.crypto,
        L10n.t('cryptoTitle'),
        cryptoTotalValue,
      ),
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
              AssetStyle.cash,
              AssetConfig.cash,
              totalsByType[type]!,
            ),
            AssetType.timeDeposit => (
              Icons.savings,
              AssetStyle.deposit,
              AssetConfig.timeDeposit,
              totalsByType[type]!,
            ),
            AssetType.wealthProduct => (
              Icons.monetization_on,
              AssetStyle.wealth,
              AssetConfig.wealthProduct,
              totalsByType[type]!,
            ),
            AssetType.current => (
              Icons.account_balance,
              AssetStyle.current,
              AssetConfig.current,
              totalsByType[type]!,
            ),
            AssetType.providentFund => (
              Icons.home_work,
              AssetStyle.provident,
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
                Icon(Icons.pie_chart, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    StockConfig.assetPositionRatioLabel,
                    textAlign: TextAlign.center,
                    style: TextStyles.subtitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppColors.border, thickness: 0.5),
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
                        color: AppColors.textPrimary,
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
  Color? iconColor,
}) {
  iconColor ??= AppColors.textSecondary;
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyles.valueMedium),
      ],
    ),
  );
}
