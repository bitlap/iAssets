import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_util.dart';
import '../../utils/market_util.dart';
import '../../utils/stock_calculator.dart';
import '../../utils/logo_cacher.dart';
import '../common/app_ui.dart';

/// 股票卡片组件（纯UI展示）
class StockCard extends StatelessWidget {
  final StockModel stock;
  final bool isExpanded;
  final VoidCallback onExpandTap;
  final VoidCallback onRecordTap;
  final VoidCallback onMoreTap;
  final List<OperationRecord> operationRecords;

  const StockCard({
    super.key,
    required this.stock,
    required this.isExpanded,
    required this.onExpandTap,
    required this.onRecordTap,
    required this.onMoreTap,
    this.operationRecords = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C1E), width: 0.5),
      ),
      child: Column(
        children: [
          // 头部可点击区域：点击展开/收缩
          GestureDetector(
            onTap: onExpandTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Row(
                  children: [
                    MarketAndCurrencyBadges(
                      market: stock.marketType,
                      currency: stock.currency,
                    ),
                    const Spacer(),
                    Text(
                      StockConfig.stockTotalValue,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${CurrencyUtil.getSymbol(stock.currency)}${CurrencyUtil.formatCompact(stock.totalValue)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildCompanyInfo()),
                    Expanded(flex: 2, child: _buildSharesAndPrice()),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildProfitLoss(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 非点击区域：分割线 + 展开详情 + 底部按钮行
          const SizedBox(height: 4),
          Divider(thickness: 0.5, color: const Color(0xFF1C1C1E)),
          const SizedBox(height: 4),
          if (isExpanded) ..._buildExpandedDetails(),
          if (isExpanded) const SizedBox(height: 4),
          if (isExpanded)
            Divider(thickness: 0.5, color: const Color(0xFF1C1C1E)),
          if (isExpanded) const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _buildRecordButton()),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onExpandTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: isExpanded
                          ? Colors.white
                          : const Color(0xFF636366),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: _buildMoreButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final fallbackChar = stock.companyName.isNotEmpty
        ? stock.companyName[0]
        : stock.symbol[0];
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            stock.isPositive
                ? const Color(0xFFFF3B30).withOpacity(0.7)
                : const Color(0xFF34C759).withOpacity(0.7),
            stock.isPositive
                ? const Color(0xFFFF3B30).withOpacity(0.4)
                : const Color(0xFF34C759).withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _buildLogoContent(fallbackChar),
      ),
    );
  }

  Widget _buildLogoContent(String fallbackChar) {
    if (stock.logoUrl == null) return _buildFallbackChar(fallbackChar);

    final cached = LogoCacher.syncCached(stock.symbol);
    if (cached != null) {
      return Image(
        image: cached,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackChar(fallbackChar),
      );
    }
    final logoFuture = LogoCacher.getLogo(stock.symbol, stock.logoUrl!);
    return FutureBuilder<ImageProvider>(
      future: logoFuture,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            return Image(
              image: snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackChar(fallbackChar),
            );
          }
          return _buildFallbackChar(fallbackChar);
        }
        return Container(color: const Color(0xFF2C2C2E));
      },
    );
  }

  Widget _buildFallbackChar(String char) {
    return Center(
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(stock.companyName, style: TextStyles.caption),
        const SizedBox(height: 2),
        Text(
          stock.symbol,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSharesAndPrice() {
    final changeColor = stock.changePercent >= 0
        ? const Color(0xFFFF3B30)
        : const Color(0xFF34C759);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${CurrencyUtil.formatRate(stock.shares)}${StockConfig.stockSharesSuffix}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${CurrencyUtil.formatRate(stock.currentPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${stock.changePercent >= 0 ? '+' : '-'}${stock.changePercent.abs().toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: changeColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLoss() {
    final isZero = stock.profitLossAmount.abs() < 0.0001;
    final profitColor = isZero
        ? const Color(0xFF636366)
        : (stock.isPositive
              ? const Color(0xFFFF3B30)
              : const Color(0xFF34C759));
    final isPositive = isZero ? '' : (stock.isPositive ? '+' : '-');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${isPositive}${CurrencyUtil.formatCompact(stock.profitLossAmount.abs())}',
            style: TextStyle(
              fontSize: 12,
              color: profitColor,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${isPositive}${stock.profitLossPercent.abs().toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: profitColor,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: onRecordTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF2C2C2E),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 14, color: Color(0xFF5B9CF6)),
            SizedBox(width: 4),
            Text(
              StockConfig.stockRecord,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: onMoreTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF2C2C2E),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, size: 14, color: Color(0xFFFF9F0A)),
            const SizedBox(width: 4),
            Text(
              StockConfig.stockMore,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建展开详情区域（每行2个，标题和值同一行）
  List<Widget> _buildExpandedDetails() {
    final stats = StockCalculator.calculateRecordStats(operationRecords);
    final totalCost = stats.totalBuyAmount - stats.totalSellAmount;

    final items = [
      _DetailItem(
        StockConfig.stockDetailTotalCost,
        CurrencyUtil.formatCompact(totalCost),
      ),
      _DetailItem(
        StockConfig.stockDetailAvgPrice,
        CurrencyUtil.formatRate(stats.avgBuyPrice),
      ),
      _DetailItem(
        StockConfig.stockDetailMaxPrice,
        CurrencyUtil.formatRate(stats.maxBuyPrice),
      ),
      _DetailItem(
        StockConfig.stockDetailMinPrice,
        CurrencyUtil.formatRate(stats.minBuyPrice),
      ),
      _DetailItem(
        StockConfig.stockDetailBuyCount,
        '${stats.buyCount} ${AppConfig.suffixCount}',
      ),
      _DetailItem(
        StockConfig.stockDetailSellCount,
        '${stats.sellCount} ${AppConfig.suffixCount}',
      ),
    ];

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final rowItems = items.skip(i).take(2).toList();
      rows.add(
        Row(
          children: [
            Expanded(child: _buildDetailCell(rowItems[0], alignRight: false)),
            const SizedBox(width: 16),
            if (rowItems.length > 1)
              Expanded(child: _buildDetailCell(rowItems[1], alignRight: true))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (i + 2 < items.length) rows.add(const SizedBox(height: 8));
    }
    return rows;
  }

  Widget _buildDetailCell(_DetailItem item, {required bool alignRight}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          children: alignRight
              ? [
                  TextSpan(
                    text: item.value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: '${item.label}: ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                      height: 1.2,
                    ),
                  ),
                ]
              : [
                  TextSpan(
                    text: '${item.label}: ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: item.value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  _DetailItem(this.label, this.value);
}
