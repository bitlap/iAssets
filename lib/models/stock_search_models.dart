/// 股票搜索结果模型
class StockSearchResult {
  final String code; // 股票代码，如 AAPL, 00700
  final String name; // 股票名称
  final String market; // 市场标识：美股、港股
  final String secid; // 东方财富 secid，如 105.AAPL, 116.00700

  StockSearchResult({
    required this.code,
    required this.name,
    required this.market,
    required this.secid,
  });
}

/// 股票实时行情
class StockQuote {
  final String code;
  final String name;
  final double currentPrice;
  final double changePercent;
  final String market;
  final String? logoUrl;

  StockQuote({
    required this.code,
    required this.name,
    required this.currentPrice,
    required this.changePercent,
    required this.market,
    this.logoUrl,
  });
}
