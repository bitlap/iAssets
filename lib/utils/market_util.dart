import '../l10n/l10n.dart';

class MarketUtil {
  MarketUtil._();

  static const String searchAll = '全部';
  static const String searchMarketUS = '美股';
  static const String exchangeNASDAQ = 'NASDAQ';
  static const String exchangeNYSE = 'NYSE';
  static const String exchangeAMEX = 'AMEX';
  static const String exchangeHK = 'HK';
  static const String exchangeJPX = 'JPX';
  static const String exchangeKRX = 'KRX';
  static const String exchangeLSE = 'LSE';
  static const String exchangeOTCBB = 'OTCBB';
  static const String exchangeBJ = '京A';
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
      case exchangeNASDAQ:
        return L10n.t('marketNASDAQ');
      case exchangeNYSE:
        return L10n.t('marketNYSE');
      case exchangeAMEX:
        return L10n.t('marketAMEX');
      case exchangeHK:
        return L10n.t('marketHKEX');
      case exchangeJPX:
        return L10n.t('marketJPX');
      case exchangeKRX:
        return L10n.t('marketKRX');
      case exchangeLSE:
        return L10n.t('marketLSE');
      case exchangeOTCBB:
        return L10n.t('marketOTCBB');
      case exchangeBJ:
        return L10n.t('marketBJ');
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
    exchangeNASDAQ,
    exchangeNYSE,
    exchangeAMEX,
    exchangeHK,
    exchangeSH,
    exchangeSZ,
    exchangeBJ,
    exchangeOTC,
    exchangeBond,
    exchangeIndex,
    exchangeNEEQ,
    exchangeJPX,
    exchangeKRX,
    exchangeLSE,
    exchangeOTCBB,
  ];

  static Iterable<String> get holdingMarkets => [
    ...searchMarkets,
    customMarket,
  ];

  static const _usExchanges = {
    secidUS: exchangeNASDAQ,
    secidUSAlt: exchangeNYSE,
    secidUS107: exchangeAMEX,
  };

  static const _legacyExchanges = {
    searchMarketHK: exchangeHK,
    searchMarketJP: exchangeJPX,
    searchMarketKR: exchangeKRX,
    searchMarketUK: exchangeLSE,
    searchMarketPink: exchangeOTCBB,
  };

  /// 使用接口的具体交易所。国内数字 JYS 不是名称，保留沪A、深A、京A等原值。
  /// 历史地区名称只在读取时恢复交易所，不作为搜索或筛选分组。
  static String marketFromProvider(
    String market, {
    String exchange = '',
    String secid = '',
  }) {
    if (market == searchMarketCN) {
      final id = secid.split('.').first;
      if (id == secidSH) return exchangeSH;
      if (id == secidSZ) {
        return secid.startsWith('0.92') ? exchangeBJ : exchangeSZ;
      }
      return market;
    }
    if (market == searchMarketUS) {
      if (exchange.isNotEmpty && int.tryParse(exchange) == null) {
        return exchange;
      }
      return _usExchanges[secid.split('.').first] ?? market;
    }
    final legacyExchange = _legacyExchanges[market];
    if (legacyExchange == null) return market;
    return exchange.isNotEmpty && int.tryParse(exchange) == null
        ? exchange
        : legacyExchange;
  }

  static bool isUKMarket(String market) =>
      market == exchangeLSE || market == searchMarketUK;

  static bool isUSMarket(String market) =>
      market == searchMarketUS || _usExchanges.containsValue(market);

  /// 腾讯仅支持已知交易所；其他市场交由东方财富，不能回退为美股。
  static String? tencentPrefix(String market, String secid) {
    final exchange = secid.split('.')[0];
    if ({
      searchMarketJP,
      searchMarketKR,
      searchMarketUK,
      searchMarketPink,
      exchangeJPX,
      exchangeKRX,
      exchangeLSE,
      exchangeOTCBB,
      exchangeBJ,
    }.contains(market)) {
      return null;
    }
    if (isUSMarket(market) ||
        exchange == secidUS ||
        exchange == secidUSAlt ||
        exchange == secidUS107) {
      return 'us';
    }
    if (market == exchangeHK ||
        market == searchMarketHK ||
        exchange == secidHK) {
      return 'hk';
    }
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
      exchangeBJ,
      exchangeOTC,
      exchangeBond,
      exchangeIndex,
      exchangeNEEQ,
    }.contains(marketType);
  }

  static bool supportMarket(String marketType) {
    return searchMarkets.contains(marketType) ||
        marketType == searchMarketCN ||
        marketType == searchMarketUS ||
        _legacyExchanges.containsKey(marketType) ||
        marketType == customMarket;
  }

  static String currencyForMarket(String marketType) {
    if (isChineseMarket(marketType)) {
      return 'CNY';
    }
    switch (marketType) {
      case searchMarketHK:
      case exchangeHK:
        return 'HKD';
      case searchMarketJP:
      case exchangeJPX:
        return 'JPY';
      case searchMarketKR:
      case exchangeKRX:
        return 'KRW';
      case searchMarketUK:
      case exchangeLSE:
        return 'GBP';
      case searchMarketUS:
      case exchangeNASDAQ:
      case exchangeNYSE:
      case exchangeAMEX:
      case searchMarketPink:
      case exchangeOTCBB:
        return 'USD';
      default:
        return 'USD';
    }
  }
}
