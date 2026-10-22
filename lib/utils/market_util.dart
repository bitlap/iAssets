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

  /// 按接口原始市场名称本地化，不合并或归一化市场。
  static String marketLabel(String market) {
    switch (market) {
      case searchAll:
        return L10n.t('marketAll');
      case searchMarketUS:
        return L10n.t('marketUS');
      case searchMarketHK:
        return L10n.t('marketHK');
      case searchMarketCN:
        return L10n.t('marketCN'); // 兼容历史数据中的 A股 名称。
      case exchangeSH:
        return L10n.t('marketSH');
      case exchangeSZ:
        return L10n.t('marketSZ');
      case exchangeOTC:
        return L10n.t('marketFund');
      case exchangeBond:
        return L10n.t('marketBond');
      case exchangeIndex:
        return L10n.t('marketIndex');
      case exchangeNEEQ:
        return L10n.t('marketNEEQ');
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

  /// 搜索、持仓和股息筛选共享接口返回的市场名称。
  static const searchMarkets = [
    searchMarketUS,
    searchMarketHK,
    exchangeSH,
    exchangeSZ,
    exchangeOTC,
    exchangeBond,
    exchangeIndex,
    exchangeNEEQ,
    searchMarketJP,
    searchMarketKR,
    searchMarketUK,
    searchMarketPink,
  ];

  static Iterable<String> get holdingMarkets => [
    ...searchMarkets,
    customMarket,
  ];

  /// 腾讯仅支持已知交易所；其他市场交由东方财富，不能回退为美股。
  static String? tencentPrefix(String market, String secid) {
    final exchange = secid.split('.')[0];
    if ({
      searchMarketJP,
      searchMarketKR,
      searchMarketUK,
      searchMarketPink,
    }.contains(market)) {
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

  /// 按接口原始市场名称精确筛选。
  static bool matchesFilter(String? filter, String stockMarket) {
    if (filter == null || filter == searchAll) return true;
    return stockMarket == filter;
  }

  // 市场 → 币种 映射
  static bool isChineseMarket(String marketType) {
    return const {
      searchMarketCN, // 仅兼容历史数据，不作为接口市场的父级。
      exchangeSH,
      exchangeSZ,
      exchangeOTC,
      exchangeBond,
      exchangeIndex,
      exchangeNEEQ,
    }.contains(marketType);
  }

  static bool supportMarket(String marketType) {
    return searchMarkets.contains(marketType) ||
        marketType == searchMarketCN ||
        marketType == customMarket;
  }

  static String currencyForMarket(String marketType) {
    if (isChineseMarket(marketType)) {
      return 'CNY';
    }
    switch (marketType) {
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
