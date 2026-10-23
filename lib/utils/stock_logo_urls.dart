import 'market_util.dart';

/// 图标提供商使用交易所后缀，与持仓中保存的代码、市场名称分开处理。
class StockLogoUrls {
  StockLogoUrls._();

  static List<String> forStock(
    String code,
    String market, {
    String secid = '',
  }) {
    final symbol = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9][A-Z0-9.\-]*$').hasMatch(symbol)) return [];
    final exchange = MarketUtil.marketFromProvider(market, secid: secid);
    String image(String ticker) =>
        'https://images.financialmodelingprep.com/symbol/$ticker.png';
    if (MarketUtil.isUSMarket(exchange)) {
      return [
        'https://logos.stocktwits-cdn.com/$symbol.png?w=64',
        image(symbol.replaceAll('.', '-')),
      ];
    }
    switch (exchange) {
      case MarketUtil.exchangeSH:
        return [image('$symbol.SS')];
      case MarketUtil.exchangeSZ:
        return [image('$symbol.SZ')];
      case MarketUtil.exchangeBJ:
        return [image('$symbol.BJ')];
      case MarketUtil.exchangeHK:
        if (!RegExp(r'^\d{1,5}$').hasMatch(symbol)) return [];
        // 东方财富为五位代码，图标源使用至少四位的港股代码。
        final hkCode = int.parse(symbol).toString().padLeft(4, '0');
        return [image('$hkCode.HK')];
      case MarketUtil.exchangeJPX:
        return [image('$symbol.T')];
      case MarketUtil.exchangeKRX:
        return [image('$symbol.KS'), image('$symbol.KQ')];
      case MarketUtil.exchangeLSE:
        return [image('${symbol.replaceAll('.', '-')}.L')];
      case MarketUtil.exchangeOTCBB:
        return [image(symbol)];
      default:
        // 基金、债券、指数及未知市场不能按股票代码猜测公司图标。
        return [];
    }
  }

  static String cacheKey(String code, String market) => '$market:$code';
}
