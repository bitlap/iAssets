import 'package:flutter/material.dart';

class MarketUtil {
  MarketUtil._();

  static const String searchAll = '全部';
  static const String searchMarketUS = '美股';
  static const String searchMarketHK = '港股';
  static const String searchMarketCN = 'A股';

  static const String exchangeSH = '沪A';
  static const String exchangeSZ = '深A';
  static const String exchangeOTC = '基金';
  static const String exchangeBond = '债券';
  static const String exchangeIndex = '指数';
  static const String exchangeNEEQ = '三板';

  static const String secidUS = '105';
  static const String secidUSAlt = '106';
  static const String secidUS107 = '107';
  static const String secidHK = '116';
  static const String secidSH = '1';
  static const String secidSZ = '0';

  static const cnMarkets = {
    exchangeSH,
    exchangeSZ,
    exchangeOTC,
    exchangeBond,
    exchangeIndex,
    exchangeNEEQ,
  };

  static Color marketColor(String? market) {
    if (isChineseMarket(market ?? '')) {
      return const Color(0xFFFF9500);
    }
    switch (market) {
      case searchMarketHK:
        return const Color(0xFF34C759);
      case searchMarketUS:
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFF636366);
    }
  }

  static IconData marketIcon(String? market) {
    if (isChineseMarket(market ?? '')) {
      return Icons.flag;
    }
    switch (market) {
      case searchMarketUS:
        return Icons.language;
      case searchMarketHK:
        return Icons.location_city;
      default:
        return Icons.all_inclusive;
    }
  }

  static String tencentPrefix(String market, String secid) {
    final exchange = secid.split('.')[0];
    if (market == searchMarketUS ||
        exchange == secidUS ||
        exchange == secidUSAlt ||
        exchange == secidUS107) {
      return 'us';
    }
    if (market == searchMarketHK || exchange == secidHK) return 'hk';
    if (market == exchangeSH) return 'sh';
    if (market == exchangeSZ) return 'sz';
    if (exchange == secidSH) return 'sh';
    if (exchange == secidSZ) return 'sz';
    return 'us';
  }

  /// 判断 stockMarket 是否匹配筛选 filter（"A股" 模糊匹配 "沪A"/"深A"）
  static bool matchesFilter(String? filter, String stockMarket) {
    if (filter == null) return true;
    if (filter == searchMarketCN) {
      return cnMarkets.contains(stockMarket);
    }
    return stockMarket == filter;
  }

  // 市场 → 币种 映射
  static bool isChineseMarket(String marketType) {
    return searchMarketCN == marketType || cnMarkets.contains(marketType);
  }

  static String currencyForMarket(String marketType) {
    if (isChineseMarket(marketType)) {
      return 'CNY';
    }
    switch (marketType) {
      case searchMarketHK:
        return 'HKD';
      case searchMarketUS:
        return 'USD';
      default:
        return 'USD';
    }
  }
}
