import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../common/app_colors.dart';
import '../../utils/currency_util.dart';
import '../../utils/profit_util.dart';
import '../common/profit_chart.dart';
import '../common/dialog_utils.dart';
import '../common/currency_selector.dart';
import '../common/app_ui.dart';
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
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        ProfitChartWidget.footerSpacing,
      ),
      gradient: StockStyle.summaryGradient,
      borderColor: StockStyle.summaryBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Keep the heading height independent of daily profit values.
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
          Text(
            '${CurrencyUtil.getSymbol(widget.selectedCurrency)}${CurrencyUtil.formatCompact(widget.totalAssets)}',
            style: TextStyles.amountLarge,
          ),
          const SizedBox(height: 8),
          // 总成本、总盈亏和总股息
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTotalCostSummaryCard()),
                const SizedBox(width: 8),
                Expanded(child: _buildProfitSummaryCard()),
                const SizedBox(width: 8),
                Expanded(child: _buildDividendSummaryCard()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: .5, color: AppColors.border),
          const SizedBox(height: 8),
          _buildTodayProfitRow(),
          const SizedBox(height: 6),
          ProfitChartWidget(
            totalProfit: widget.totalProfit,
            targetCurrency: widget.selectedCurrency,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyButton() => CurrencySelectorButton(
    currency: widget.selectedCurrency,
    onTap: _toggleDropdown,
  );

  /// Daily performance sits with the chart rather than above the asset total.
  Widget _buildTodayProfitRow() {
    final color = ProfitUtil.colorOf(widget.todayProfit);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  StockConfig.assetTodayProfit,
                  style: TextStyles.body13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _showTodayProfitHelpDialog,
                child: Icon(
                  Icons.help_outline,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                ProfitUtil.amount(widget.todayProfit),
                style: TextStyles.body13.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ProfitUtil.percent(widget.todayProfitPercent),
                style: TextStyles.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCostSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance, size: 10, color: AppColors.accent),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                StockConfig.assetTotalCost,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.caption,
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: _showTotalCostHelpDialog,
              child: Icon(
                Icons.help_outline,
                size: 10,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildTotalMarketText(),
        const SizedBox(height: 1),
        _buildTotalMarketPercent(),
      ],
    );
  }

  void _showTodayProfitHelpDialog() {
    _helpDialogFrame(
      title: StockConfig.assetTodayProfit,
      icon: Icons.today,
      iconColor: AppColors.warning,
      children: [
        Text(
          StockConfig.assetTodayProfitHelp,
          style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showTotalAssetsHelpDialog() {
    final sellText = '${CurrencyUtil.formatCompact(widget.totalSellAmount)}';
    _helpDialogFrame(
      title: StockConfig.assetTotalAssets,
      icon: Icons.account_balance_wallet,
      iconColor: AppColors.warning,
      children: [
        _helpLine(
          StockConfig.assetTotalSellAmount,
          sellText,
          AppColors.textPrimary,
        ),
      ],
    );
  }

  void _showTotalCostHelpDialog() {
    final costText = '${CurrencyUtil.formatCompact(widget.totalCost)}';
    final floatPL = widget.totalMarketValue - widget.totalCost;
    final floatText = ProfitUtil.amount(floatPL);
    _helpDialogFrame(
      title: StockConfig.assetTotalCost,
      icon: Icons.account_balance,
      iconColor: AppColors.accent,
      children: [
        _helpLine(
          StockConfig.assetCostDetailLabel,
          costText,
          AppColors.textPrimary,
        ),
        const SizedBox(height: 6),
        _helpLine(
          StockConfig.assetFloatProfitLabel,
          floatText,
          ProfitUtil.colorOf(floatPL),
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
            GestureDetector(
              onTap: _showProfitHelpDialog,
              child: Icon(
                Icons.help_outline,
                size: 10,
                color: ProfitUtil.colorOf(widget.totalProfit),
              ),
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
    _helpDialogFrame(
      title: StockConfig.assetTotalProfit,
      icon: Icons.trending_up,
      iconColor: ProfitUtil.colorOf(widget.totalProfit),
      children: [
        _helpLine(
          StockConfig.assetTotalRealizedPL,
          realizedText,
          ProfitUtil.colorOf(widget.totalRealizedPL),
        ),
      ],
    );
  }

  Widget _buildTotalMarketText() {
    return Text(
      '${CurrencyUtil.formatCompact(widget.totalMarketValue)}',
      style: TextStyles.valueMedium,
    );
  }

  Widget _buildTotalMarketPercent() {
    final percent = widget.totalAssets > 0
        ? (widget.totalMarketValue / widget.totalAssets * 100)
        : 0.0;
    return Text(
      '${percent.toStringAsFixed(2)}%',
      style: TextStyles.caption.copyWith(fontWeight: FontWeight.w500),
    );
  }

  Widget _buildProfitText() {
    return Text(
      ProfitUtil.amount(widget.totalProfit),
      style: TextStyles.valueMedium.copyWith(
        color: ProfitUtil.colorOf(widget.totalProfit),
      ),
    );
  }

  Widget _buildProfitPercent() {
    return Text(
      ProfitUtil.percent(widget.totalProfitPercent),
      style: TextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: ProfitUtil.colorOf(widget.totalProfit),
      ),
    );
  }

  Widget _buildDividendSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monetization_on, size: 10, color: AppColors.warning),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                StockConfig.assetTotalDividends,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.caption,
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
        const SizedBox(height: 4),
        _buildDividendText(),
        const SizedBox(height: 1),
        _buildDividendPercent(),
      ],
    );
  }

  Widget _helpLine(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyles.valueMedium.copyWith(
            color: valueColor ?? AppColors.textPrimary,
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

  Widget _buildDividendPercent() {
    final percent = widget.totalAssets > 0
        ? (widget.totalAfterTaxDividends / widget.totalAssets * 100)
        : 0.0;
    return Text(
      '${percent.toStringAsFixed(2)}%',
      style: TextStyles.caption.copyWith(fontWeight: FontWeight.w500),
    );
  }

  Widget _buildDividendText() {
    return Text(
      '${CurrencyUtil.formatCompact(widget.totalAfterTaxDividends)}',
      style: TextStyles.valueMedium,
    );
  }
}
