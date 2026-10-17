import 'package:flutter/material.dart';
import '../../utils/market_util.dart';
import '../common/app_colors.dart';
import '../common/app_ui.dart';
import 'stock_style.dart';

/// 股票市场标签。
class MarketBadge extends StatelessWidget {
  final String market;
  final double fontSize;

  const MarketBadge(this.market, {super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final color = StockStyle.marketColor(market);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        MarketUtil.marketLabel(market),
        style: TextStyles.smallBold.copyWith(fontSize: fontSize, color: color),
      ),
    );
  }
}

/// 股票币种标签。
class CurrencyBadge extends StatelessWidget {
  final String currency;
  final double fontSize;

  const CurrencyBadge(this.currency, {super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        currency,
        style: TextStyles.smallBold.copyWith(
          fontSize: fontSize,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 股票市场与币种组合标签。
class MarketAndCurrencyBadges extends StatelessWidget {
  final String market;
  final String currency;
  final double fontSize;

  const MarketAndCurrencyBadges({
    super.key,
    required this.market,
    required this.currency,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CurrencyBadge(currency, fontSize: fontSize),
        const SizedBox(width: 4),
        MarketBadge(market, fontSize: fontSize),
      ],
    );
  }
}
