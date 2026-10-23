import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../config/app_config.dart';
import '../common/app_colors.dart';
import '../../utils/currency_util.dart';
import '../../utils/stock_calculator.dart';
import '../../utils/profit_util.dart';
import '../../utils/logo_cacher.dart';
import '../../utils/market_util.dart';
import '../../utils/stock_logo_urls.dart';
import '../common/app_ui.dart';
import 'market_badges.dart';
import 'stock_columns.dart';

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppColors.accent.withValues(alpha: AppColors.isDark ? .38 : .25)
              : AppColors.border,
          width: 0.5,
        ),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          Text(
                            StockConfig.stockTotalValue,
                            style: TextStyles.body13.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${CurrencyUtil.getSymbol(stock.currency)}${CurrencyUtil.formatCompact(stock.totalValue)}',
                            style: TextStyles.valueSmall.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                StockColumns(
                  name: Row(
                    children: [
                      _buildLogo(),
                      const SizedBox(width: StockColumns.logoGap),
                      Expanded(child: _buildCompanyInfo()),
                    ],
                  ),
                  holdings: _buildSharesAndPrice(),
                  profit: Align(
                    alignment: Alignment.centerRight,
                    child: _buildProfitLoss(),
                  ),
                ),
              ],
            ),
          ),
          // 非点击区域：分割线 + 展开详情 + 底部按钮行
          const SizedBox(height: 4),
          Divider(thickness: 0.5, color: AppColors.border),
          const SizedBox(height: 4),
          if (isExpanded) ..._buildExpandedDetails(),
          if (isExpanded) const SizedBox(height: 4),
          if (isExpanded) Divider(thickness: 0.5, color: AppColors.border),
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
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
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
    final fallbackChar = StockLogoUrls.fallbackText(
      stock.companyName,
      stock.symbol,
    );
    return Container(
      width: StockColumns.logoWidth,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            stock.isPositive
                ? AppColors.rise.withValues(alpha: 0.7)
                : AppColors.fall.withValues(alpha: 0.7),
            stock.isPositive
                ? AppColors.rise.withValues(alpha: 0.4)
                : AppColors.fall.withValues(alpha: 0.4),
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
    final key = stock.isCustom
        ? stock.symbol
        : StockLogoUrls.cacheKey(stock.symbol, stock.marketType);
    // 旧版本只下载美股公司图标，已有美股缓存仍可离线使用。
    final cached =
        LogoCacher.syncCached(key) ??
        (!stock.isCustom && MarketUtil.isUSMarket(stock.marketType)
            ? LogoCacher.syncCached(stock.symbol)
            : null);
    if (cached != null) {
      return Image(
        image: cached,
        fit: stock.isCustom ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackChar(fallbackChar),
      );
    }
    if (stock.isCustom) return _buildFallbackChar(fallbackChar);
    final urls = StockLogoUrls.forStock(
      stock.symbol,
      stock.marketType,
      secid: stock.secid,
    );
    if (urls.isEmpty) return _buildFallbackChar(fallbackChar);
    final logoFuture = LogoCacher.getStockLogo(
      stock.symbol,
      stock.marketType,
      secid: stock.secid,
    );
    return FutureBuilder<ImageProvider?>(
      future: logoFuture,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            return Image(
              image: snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackChar(fallbackChar),
            );
          }
          return _buildFallbackChar(fallbackChar);
        }
        return Container(color: AppColors.surfaceElevated);
      },
    );
  }

  Widget _buildFallbackChar(String char) {
    return Center(child: Text(char, style: TextStyles.dialogTitle));
  }

  Widget _buildCompanyInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stock.companyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyles.caption,
        ),
        const SizedBox(height: 2),
        Text(
          stock.symbol,
          style: TextStyles.smallBold.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSharesAndPrice() {
    final changeColor = ProfitUtil.colorOf(stock.changePercent);
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
              style: TextStyles.smallBold.copyWith(fontWeight: FontWeight.bold),
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
                  style: TextStyles.smallBold.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  ProfitUtil.percent(stock.changePercent),
                  style: TextStyles.label.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w500,
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
    final profitColor = ProfitUtil.colorOf(stock.profitLossAmount);
    final sign = ProfitUtil.signOf(stock.profitLossAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '$sign${CurrencyUtil.formatCompact(stock.profitLossAmount.abs())}',
            style: TextStyles.smallBold.copyWith(color: profitColor),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '$sign${stock.profitLossPercent.abs().toStringAsFixed(2)}%',
            style: TextStyles.smallBold.copyWith(color: profitColor),
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
          color: AppColors.accent.withValues(
            alpha: AppColors.isDark ? .18 : .08,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                StockConfig.stockRecord,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.smallBold,
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
          color: AppColors.warning.withValues(
            alpha: AppColors.isDark ? .17 : .09,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                StockConfig.stockMore,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.whiteBold12.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costs are primary; entry prices and trading activity provide context.
  List<Widget> _buildExpandedDetails() {
    final stats = StockCalculator.calculateRecordStats(operationRecords);
    final totalCost = stats.totalBuyAmount - stats.totalSellAmount;
    return [
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDetailMetric(
                label: StockConfig.stockDetailTotalCost,
                value: CurrencyUtil.formatCompact(totalCost),
                prominent: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDetailMetric(
                label: StockConfig.stockDetailAvgPrice,
                value: CurrencyUtil.formatRate(stats.avgBuyPrice),
                prominent: true,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDetailMetric(
                label: StockConfig.stockDetailMinPrice,
                value: CurrencyUtil.formatRate(stats.minBuyPrice),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDetailMetric(
                label: StockConfig.stockDetailMaxPrice,
                value: CurrencyUtil.formatRate(stats.maxBuyPrice),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              StockConfig.stockDetailTradingActivity,
              style: TextStyles.caption,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                _buildTradeCount(StockConfig.opBuy, stats.buyCount),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('·', style: TextStyles.caption),
                    const SizedBox(width: 8),
                    _buildTradeCount(StockConfig.opSell, stats.sellCount),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
    ];
  }

  Widget _buildDetailMetric({
    required String label,
    required String value,
    bool prominent = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyles.caption),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyles.valueMedium.copyWith(
              fontSize: prominent ? 16 : 14,
              fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTradeCount(String label, int count) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        children: [
          TextSpan(
            text: '$count',
            style: TextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: ' ${AppConfig.suffixCount}'),
        ],
      ),
      style: TextStyles.caption,
    );
  }
}
