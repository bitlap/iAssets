import 'package:flutter/material.dart';
import '../common/app_colors.dart';
import '../../utils/market_util.dart';

/// 股票页面及市场标签专用的颜色与卡片外观。
class StockStyle {
  StockStyle._();

  static const Color marketUS = Color(0xFFFF3B30);
  static const Color marketHK = Color(0xFF34C759);
  static const Color marketA = Color(0xFFFF9500);

  static Color marketColor(String? market) {
    if (MarketUtil.isChineseMarket(market ?? '')) return marketA;
    return switch (market) {
      MarketUtil.searchMarketHK => marketHK,
      MarketUtil.searchMarketUS => marketUS,
      MarketUtil.searchMarketJP => const Color(0xFFAF52DE),
      MarketUtil.searchMarketKR => const Color(0xFF007AFF),
      MarketUtil.searchMarketUK => const Color(0xFF5856D6),
      MarketUtil.searchMarketPink => const Color(0xFFFF2D55),
      MarketUtil.customMarket => AppColors.purple,
      _ => AppColors.textTertiary,
    };
  }

  static IconData marketIcon(String? market) {
    if (MarketUtil.isChineseMarket(market ?? '')) return Icons.flag;
    return switch (market) {
      MarketUtil.searchMarketUS => Icons.language,
      MarketUtil.searchMarketHK => Icons.location_city,
      MarketUtil.searchMarketJP ||
      MarketUtil.searchMarketKR ||
      MarketUtil.searchMarketUK ||
      MarketUtil.searchMarketPink => Icons.language,
      MarketUtil.customMarket => Icons.edit_outlined,
      _ => Icons.all_inclusive,
    };
  }

  static Color get imagePickerBorder =>
      AppColors.isDark ? const Color(0xFF48484A) : const Color(0xFFDCE7F7);
  static Color get imagePickerBackground =>
      AppColors.isDark ? const Color(0xFF111216) : const Color(0xFFF8FAFE);

  static Gradient get summaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xFF1B2940), Color(0xFF151E2D), Color(0xFF142B31)]
        : const [Color(0xFFEEF5FF), Color(0xFFF8FAFF), Color(0xFFF0FAFC)],
  );

  static Color get summaryBorder =>
      AppColors.accent.withValues(alpha: AppColors.isDark ? .28 : .20);
}
