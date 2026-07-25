import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../utils/currency_util.dart';
import '../common/profit_chart.dart';
import '../common/dialog_utils.dart';
import '../common/currency_selector.dart';

class StockHeaderCard extends StatefulWidget {
  final String selectedCurrency;
  final double totalAssets;
  final double totalMarketValue;
  final double totalCost;
  final double totalProfit;
  final double totalRealizedPL;
  final double totalProfitPercent;
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Color(0xFF1C1C1E), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 总资产和货币选择
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    StockConfig.assetTotalAssets,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showTotalAssetsHelpDialog,
                    child: const Icon(
                      Icons.help_outline,
                      size: 14,
                      color: Color(0xFFFF9F0A),
                    ),
                  ),
                ],
              ),
              _buildCurrencyButton(),
            ],
          ),
          const SizedBox(height: 4),
          // 总金额（已经是目标币种，直接格式化）
          Text(
            '${CurrencyUtil.getSymbol(widget.selectedCurrency)}${CurrencyUtil.formatCompact(widget.totalAssets)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
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
          const SizedBox(height: 6),
          ProfitChartWidget(
            totalProfit: widget.totalProfit,
            targetCurrency: widget.selectedCurrency,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyButton() {
    return GestureDetector(
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.selectedCurrency,
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
    );
  }

  Widget _buildTotalCostSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance, size: 10, color: Color(0xFF5B9CF6)),
            const SizedBox(width: 4),
            Text(
              StockConfig.assetTotalCost,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
                height: 1.2,
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: _showTotalCostHelpDialog,
              child: const Icon(
                Icons.help_outline,
                size: 10,
                color: Color(0xFF5B9CF6),
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

  void _showTotalAssetsHelpDialog() {
    final sellText = '${CurrencyUtil.formatCompact(widget.totalSellAmount)}';
    _helpDialogFrame(
      title: StockConfig.assetTotalAssets,
      icon: Icons.account_balance_wallet,
      iconColor: const Color(0xFFFF9F0A),
      children: [
        _helpLine(StockConfig.assetTotalSellAmount, sellText, Colors.white),
      ],
    );
  }

  void _showTotalCostHelpDialog() {
    final costText = '${CurrencyUtil.formatCompact(widget.totalCost)}';
    final floatPL = widget.totalMarketValue - widget.totalCost;
    final floatText =
        '${floatPL >= 0 ? '+' : ''}${CurrencyUtil.formatCompact(floatPL)}';
    _helpDialogFrame(
      title: StockConfig.assetTotalCost,
      icon: Icons.account_balance,
      iconColor: const Color(0xFF5B9CF6),
      children: [
        _helpLine(StockConfig.assetCostDetailLabel, costText, Colors.white),
        const SizedBox(height: 6),
        _helpLine(
          StockConfig.assetFloatProfitLabel,
          floatText,
          floatPL >= 0 ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
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
            Icon(Icons.trending_up, size: 10, color: Color(0xFFFF3B30)),
            const SizedBox(width: 4),
            Text(
              StockConfig.assetTotalProfit,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
                height: 1.2,
              ),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: _showProfitHelpDialog,
              child: const Icon(
                Icons.help_outline,
                size: 10,
                color: Color(0xFFFF3B30),
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
    final realizedText =
        '${widget.totalRealizedPL >= 0 ? '+' : ''}${CurrencyUtil.formatCompact(widget.totalRealizedPL)}';
    _helpDialogFrame(
      title: StockConfig.assetTotalProfit,
      icon: Icons.trending_up,
      iconColor: const Color(0xFFFF3B30),
      children: [
        _helpLine(
          StockConfig.assetTotalRealizedPL,
          realizedText,
          widget.totalRealizedPL >= 0
              ? const Color(0xFFFF3B30)
              : const Color(0xFF34C759),
        ),
      ],
    );
  }

  Widget _buildTotalMarketText() {
    return Text(
      '${CurrencyUtil.formatCompact(widget.totalMarketValue)}',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
      ),
    );
  }

  Widget _buildTotalMarketPercent() {
    final percent = widget.totalAssets > 0
        ? (widget.totalMarketValue / widget.totalAssets * 100)
        : 0.0;
    return Text(
      '${percent.toStringAsFixed(2)}%',
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF8E8E93),
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }

  Widget _buildProfitText() {
    return Text(
      '${widget.totalProfit >= 0 ? '+' : ''}${CurrencyUtil.formatCompact(widget.totalProfit)}',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: widget.totalProfit >= 0
            ? const Color(0xFFFF3B30)
            : const Color(0xFF34C759),
        height: 1.1,
      ),
    );
  }

  Widget _buildProfitPercent() {
    return Text(
      '${widget.totalProfit >= 0 ? '+' : '-'}${widget.totalProfitPercent.abs().toStringAsFixed(2)}%',
      style: TextStyle(
        fontSize: 11,
        color: widget.totalProfit >= 0
            ? const Color(0xFFFF3B30)
            : const Color(0xFF34C759),
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }

  Widget _buildDividendSummaryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.monetization_on,
              size: 10,
              color: Color(0xFFFF9F0A),
            ),
            const SizedBox(width: 4),
            const Text(
              StockConfig.assetTotalDividends,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
                height: 1.2,
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
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
          const Divider(color: Color(0xFF1C1C1E), thickness: 0.5),
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
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF8E8E93),
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }

  Widget _buildDividendText() {
    return Text(
      '${CurrencyUtil.formatCompact(widget.totalAfterTaxDividends)}',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
      ),
    );
  }
}
