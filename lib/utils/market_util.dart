import '../l10n/l10n.dart';

class MarketUtil {
  MarketUtil._();

  static const String searchAll = '全部';
  static const String searchMarketUS = '美股';
  static const String searchMarketHK = '港股';
  static const String searchMarketCN = 'A股';
  static const String searchMarketJP = '日股';
  static const String searchMarketKR = '韩股';
  static const String searchMarketUK = '英股';
  static const String searchMarketPink = '粉单';
  static const String customMarket = '自定义';

  /// 市场展示名称（内部标识保持中文，展示层本地化；A股细分统一归一为 CN）
  static String marketLabel(String market) {
    if (isChineseMarket(market)) {
      return L10n.t('marketCN');
    }
    switch (normalizeMarket(market)) {
      case searchAll:
        return L10n.t('marketAll');
      case searchMarketUS:
        return L10n.t('marketUS');
      case searchMarketHK:
        return L10n.t('marketHK');
      case searchMarketJP:
        return L10n.t('marketJP');
      case searchMarketKR:
        return L10n.t('marketKR');
      case searchMarketUK:
        return L10n.t('marketUK');
      case searchMarketPink:
        return L10n.t('marketPink');
      case customMarket:
        return L10n.t('marketCustom');
      default:
        return market;
    }
  }

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

  /// 展示层共享市场分组；持久化仍保留原始子市场，避免丢失交易所信息。
  static const marketGroups = <String, Set<String>>{
    searchMarketUS: {searchMarketUS},
    searchMarketHK: {searchMarketHK},
    searchMarketCN: {searchMarketCN, ...cnMarkets},
    searchMarketJP: {searchMarketJP},
    searchMarketKR: {searchMarketKR},
    searchMarketUK: {searchMarketUK},
    searchMarketPink: {searchMarketPink},
  };

  static Iterable<String> get searchMarkets => marketGroups.keys;
  static Iterable<String> get holdingMarkets => [
    ...searchMarkets,
    customMarket,
  ];

  static String normalizeMarket(String market) {
    for (final group in marketGroups.entries) {
      if (group.value.contains(market)) return group.key;
    }
    return market;
  }

  /// 腾讯仅支持已知交易所；其他市场交由东方财富，不能回退为美股。
  static String? tencentPrefix(String market, String secid) {
    final exchange = secid.split('.')[0];
    if ({
      searchMarketJP,
      searchMarketKR,
      searchMarketUK,
      searchMarketPink,
    }.contains(normalizeMarket(market))) {
      return null;
    }
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
    return null;
  }

  /// 判断 stockMarket 是否匹配筛选 filter（"A股" 模糊匹配 "沪A"/"深A"）
  static bool matchesFilter(String? filter, String stockMarket) {
    if (filter == null || filter == searchAll) return true;
    return stockMarket == filter ||
        marketGroups[filter]?.contains(stockMarket) == true;
  }

  // 市场 → 币种 映射
  static bool isChineseMarket(String marketType) {
    return normalizeMarket(marketType) == searchMarketCN;
  }

  static bool supportMarket(String marketType) {
    return marketGroups.containsKey(normalizeMarket(marketType)) ||
        marketType == customMarket;
  }

  static String currencyForMarket(String marketType) {
    if (isChineseMarket(marketType)) {
      return 'CNY';
    }
    switch (normalizeMarket(marketType)) {
      case searchMarketHK:
        return 'HKD';
      case searchMarketJP:
        return 'JPY';
      case searchMarketKR:
        return 'KRW';
      case searchMarketUK:
        return 'GBP';
      case searchMarketUS:
      case searchMarketPink:
        return 'USD';
      default:
        return 'USD';
    }
  }
}
