import 'package:flutter/material.dart';

class MarketUtil {
  MarketUtil._();

  static const String searchAll = '全部';
  static const String searchMarketUS = '美股';
  static const String searchMarketHK = '港股';
  static const String searchMarketCN = 'A股';

  static const String exchangeSH = '沪A';
  static const String exchangeSZ = '深A';

  static const String secidUS = '105';
  static const String secidUSAlt = '106';
  static const String secidUS107 = '107';
  static const String secidHK = '116';
  static const String secidSH = '1';
  static const String secidSZ = '0';

  static Color marketColor(String? market) {
    switch (market) {
      case searchMarketHK:
        return const Color(0xFF34C759);
      case searchMarketCN:
      case exchangeSH:
      case exchangeSZ:
        return const Color(0xFFFF9500);
      case searchMarketUS:
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFF636366);
    }
  }

  static IconData marketIcon(String? market) {
    switch (market) {
      case searchMarketUS:
        return Icons.language;
      case searchMarketHK:
        return Icons.location_city;
      case searchMarketCN:
      case exchangeSH:
      case exchangeSZ:
        return Icons.flag;
      default:
        return Icons.all_inclusive;
    }
  }

  static String tencentPrefix(String market) {
    if (market == searchMarketUS) return 'us';
    if (market == exchangeSH || market == exchangeSZ) {
      return market == exchangeSH ? 'sh' : 'sz';
    }
    return 'hk';
  }

  static String secidForMarket(String marketType, String symbol) {
    if (marketType == searchMarketUS) {
      return '$secidUS.$symbol';
    } else if (marketType == searchMarketCN ||
        marketType == exchangeSH ||
        marketType == exchangeSZ) {
      return '${symbol.startsWith('6') ? secidSH : secidSZ}.$symbol';
    }
    return '$secidHK.$symbol';
  }

  /// 判断 stockMarket 是否匹配筛选 filter（"A股" 模糊匹配 "沪A"/"深A"）
  static bool matchesFilter(String? filter, String stockMarket) {
    if (filter == null) return true;
    if (filter == searchMarketCN) {
      return stockMarket == exchangeSH || stockMarket == exchangeSZ;
    }
    return stockMarket == filter;
  }

  // 市场 → 币种 映射
  static String currencyForMarket(String marketType) {
    switch (marketType) {
      case searchMarketHK:
        return 'HKD';
      case searchMarketUS:
        return 'USD';
      case searchMarketCN:
      case exchangeSH:
      case exchangeSZ:
        return 'CNY';
      default:
        return 'USD';
    }
  }
}
