import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../common/app_colors.dart';
import '../../utils/currency_util.dart';
import '../../utils/profit_util.dart';
import '../common/profit_chart.dart';
import '../common/dialog_utils.dart';
import '../common/currency_selector.dart';
import '../common/app_ui.dart';
import '../common/exchange_rate_notice.dart';
import '../common/sensitive_text.dart';
import '../../services/privacy_service.dart';
import 'stock_style.dart';

class StockHeaderCard extends StatefulWidget {
  final String selectedCurrency;
  final double totalAssets;
  final double totalMarketValue;
  final double totalCost;
  final double totalProfit;
  final double totalRealizedPL;
  final double totalProfitPercent;
  final double todayProfit;
  final double todayProfitPercent;
  final double totalAfterTaxDividends;
  final double totalSellAmount;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback? onCollapse;

  const StockHeaderCard({
    super.key,
    required this.selectedCurrency,
    required this.totalAssets,
    required this.totalMarketValue,
    required this.totalCost,
    required this.totalProfit,
    required this.totalRealizedPL,
    required this.totalProfitPercent,
    required this.todayProfit,
    required this.todayProfitPercent,
    required this.totalAfterTaxDividends,
    required this.totalSellAmount,
    required this.onCurrencyChanged,
    this.onCollapse,
  });

  @override
  State<StockHeaderCard> createState() => _StockHeaderCardState();
}

class _StockHeaderCardState extends State<StockHeaderCard> {
  void _toggleDropdown() {
    CurrencySelector.show(
      context: context,
      selectedCurrency: widget.selectedCurrency,
      onCurrencyChanged: widget.onCurrencyChanged,
      onOpen: widget.onCollapse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SummaryCardFrame(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      gradient: StockStyle.summaryGradient,
      borderColor: StockStyle.summaryBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题高度不随今日盈亏的数值变化。
          Row(
            children: [
              Text(StockConfig.assetTotalAssets, style: TextStyles.body13),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _showTotalAssetsHelpDialog,
                child: Icon(
                  Icons.help_outline,
                  size: 13,
                  color: AppColors.warning,
                ),
              ),
              const Spacer(),
              _buildCurrencyButton(),
            ],
          ),
          const SizedBox(height: 4),
          // 总金额（已经是目标币种，直接格式化）
          SensitiveText(
            widget.totalAssets.isFinite
                ? '${CurrencyUtil.getSymbol(widget.selectedCurrency)}${CurrencyUtil.formatCompact(widget.totalAssets)}'
                : L10n.t('exchangeRateCannotValue'),
            style: TextStyles.amountLarge,
          ),
          const SizedBox(height: 8),
          // 资产金额已等于当前股票持仓市值；保留今日和累计盈亏，
          // 其余汇总统计移至帮助说明。
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildProfitSummaryCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildTodayProfitSummaryCard()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyService.instance.hideAmounts,
            builder: (context, hidden, _) => hidden
                ? const SizedBox(
                    height: 44,
                    child: Center(child: Icon(Icons.shield_outlined)),
                  )
                : ProfitChartWidget(
                    totalProfit: widget.totalProfit,
                    targetCurrency: widget.selectedCurrency,
                  ),
          ),
          ExchangeRateNotice(incomplete: !widget.totalAssets.isFinite),
        ],
      ),
    );
  }

  Widget _buildCurrencyButton() => CurrencySelectorButton(
    currency: widget.selectedCurrency,
    onTap: _toggleDropdown,
  );

  Widget _buildTodayProfitSummaryCard() {
    final color = ProfitUtil.colorOf(widget.todayProfit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.today, size: 10, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                StockConfig.assetTodayProfit,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.caption,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: _showTodayProfitHelpDialog,
              tooltip: StockConfig.assetTodayProfitHelp,
              icon: Icon(Icons.help_outline, color: color),
              iconSize: 14,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        SensitiveText(
          ProfitUtil.amount(widget.todayProfit),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyles.valueMedium.copyWith(color: color),
        ),
        SensitiveText(
          ProfitUtil.percent(widget.todayProfitPercent),
          style: TextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showTodayProfitHelpDialog() {
    _helpDialogFrame(
      title: StockConfig.assetTodayProfit,
      icon: Icons.today,
      iconColor: ProfitUtil.colorOf(widget.todayProfit),
      children: [
        Text(
          StockConfig.assetTodayProfitHelp,
          style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showTotalAssetsHelpDialog() {
    final sellText = CurrencyUtil.formatCompact(widget.totalSellAmount);
    _helpDialogFrame(
      title: StockConfig.assetTotalAssets,
      icon: Icons.account_balance_wallet,
      iconColor: AppColors.warning,
      children: [
        Text(
          StockConfig.assetTotalAssetsHelp,
          style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        _helpLine(
          StockConfig.assetTotalCost,
          CurrencyUtil.formatCompact(widget.totalMarketValue),
        ),
        const SizedBox(height: 6),
        _helpLine(
          StockConfig.assetTotalDividends,
          CurrencyUtil.formatCompact(widget.totalAfterTaxDividends),
        ),
        const SizedBox(height: 6),
        _helpLine(
          StockConfig.assetTotalSellAmount,
          sellText,
          AppColors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildProfitSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up,
              size: 10,
              color: ProfitUtil.colorOf(widget.totalProfit),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                StockConfig.assetTotalProfit,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.caption,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: _showProfitHelpDialog,
              tooltip: StockConfig.assetTotalProfitHelp,
              icon: Icon(
                Icons.help_outline,
                color: ProfitUtil.colorOf(widget.totalProfit),
              ),
              iconSize: 14,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildProfitText(),
        const SizedBox(height: 1),
        _buildProfitPercent(),
      ],
    );
  }

  void _showProfitHelpDialog() {
    final realizedText = ProfitUtil.amount(widget.totalRealizedPL);
    final openPL = widget.totalMarketValue - widget.totalCost;
    _helpDialogFrame(
      title: StockConfig.assetTotalProfit,
      icon: Icons.trending_up,
      iconColor: ProfitUtil.colorOf(widget.totalProfit),
      children: [
        Text(
          StockConfig.assetTotalProfitHelp,
          style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        _helpLine(
          StockConfig.assetCostDetailLabel,
          CurrencyUtil.formatCompact(widget.totalCost),
        ),
        const SizedBox(height: 6),
        _helpLine(
          StockConfig.assetFloatProfitLabel,
          ProfitUtil.amount(openPL),
          ProfitUtil.colorOf(openPL),
        ),
        const SizedBox(height: 6),
        _helpLine(
          StockConfig.assetTotalRealizedPL,
          realizedText,
          ProfitUtil.colorOf(widget.totalRealizedPL),
        ),
      ],
    );
  }

  Widget _buildProfitText() {
    return SensitiveText(
      ProfitUtil.amount(widget.totalProfit),
      style: TextStyles.valueMedium.copyWith(
        color: ProfitUtil.colorOf(widget.totalProfit),
      ),
    );
  }

  Widget _buildProfitPercent() {
    return SensitiveText(
      ProfitUtil.percent(widget.totalProfitPercent),
      style: TextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: ProfitUtil.colorOf(widget.totalProfit),
      ),
    );
  }

  Widget _helpLine(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: SensitiveText(
            value,
            textAlign: TextAlign.right,
            style: TextStyles.valueMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _helpDialogFrame({
    required String title,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    showHelpDialog(
      context,
      title: title,
      icon: icon,
      iconColor: iconColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(color: AppColors.border, thickness: 0.5),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
