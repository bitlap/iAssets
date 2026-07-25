import '../../config/app_config.dart';
import '../../models/stock_model.dart';
import '../../models/stock_search_models.dart';
import '../../models/calculator_models.dart';
import '../../services/stock_quote_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/icloud_storage.dart';
import '../../utils/market_util.dart';
import '../../utils/stock_calculator.dart';

class StockDataManager {
  /// 根据操作记录重算单只股票的股数、总金额、盈亏
  static StockModel recalculateStock(
    StockModel stock,
    List<OperationRecord>? records,
  ) {
    if (records == null || records.isEmpty) {
      return stock.copyWith(
        shares: 0,
        totalValue: 0,
        profitLossAmount: 0,
        profitLossPercent: 0,
        isPositive: true,
      );
    }
    return StockCalculator.recalculateFromRecords(stock, records);
  }

  /// 将行情数据应用到股票列表，返回更新后的列表（非可变）
  static List<StockModel> applyQuotes(
    List<StockModel> stocks,
    Map<String, StockQuote?> quotes,
    Map<String, List<OperationRecord>> operationRecords,
  ) {
    final result = List<StockModel>.from(stocks);
    for (final stock in result) {
      final secid =
          stock.secid ??
          MarketUtil.secidForMarket(stock.marketType, stock.symbol);
      final quote = quotes[secid];
      if (quote != null) {
        final index = result.indexWhere((s) => s.symbol == stock.symbol);
        if (index != -1) {
          result[index] = stock.copyWith(
            currentPrice: quote.currentPrice,
            changePercent: quote.changePercent,
          );
          result[index] = recalculateStock(
            result[index],
            operationRecords[stock.symbol],
          );
        }
      }
    }
    return result;
  }

  /// 构建行情查询参数列表
  static List<StockSearchResult> buildSearchResults(List<StockModel> stocks) {
    return stocks
        .map(
          (stock) => StockSearchResult(
            code: stock.symbol,
            name: stock.companyName,
            market: stock.marketType,
            secid:
                stock.secid ??
                MarketUtil.secidForMarket(stock.marketType, stock.symbol),
          ),
        )
        .toList();
  }

  /// 拉取汇率并更新缓存
  static Future<void> fetchExchangeRates(ExchangeRateService service) async {
    await service.fetchRates();
  }

  /// 拉取行情
  static Future<Map<String, StockQuote?>> fetchQuotes(
    StockQuoteService quoteService,
    List<StockModel> stocks,
  ) async {
    final searchResults = buildSearchResults(stocks);
    return await quoteService.getStockQuotesBatch(searchResults);
  }

  /// 拉取行情 → 应用 → 存盘，返回更新后的股票列表
  static Future<List<StockModel>> fetchQuotesAndSave(
    StockQuoteService quoteService,
    List<StockModel> stocks,
    Map<String, List<OperationRecord>> operationRecords,
    Map<String, List<DividendRecord>> dividendRecords,
  ) async {
    if (stocks.isEmpty) return stocks;
    final quotes = await fetchQuotes(quoteService, stocks);
    if (quotes.isEmpty) return stocks;
    final updated = applyQuotes(stocks, quotes, operationRecords);
    await IcloudStorage.saveStocks(updated, operationRecords, dividendRecords);
    return updated;
  }

  /// 从本地加载设置
  static Future<void> loadSettings() => IcloudStorage.loadSettings();

  /// 从本地加载股票 + 操作记录 + 派息记录
  static Future<
    (
      List<StockModel>,
      Map<String, List<OperationRecord>>,
      Map<String, List<DividendRecord>>,
    )
  >
  loadStocks() => IcloudStorage.loadStocks();

  /// 保存股票 + 操作记录 + 派息记录 + 设置到本地
  static Future<void> saveAll(
    List<StockModel> stocks,
    Map<String, List<OperationRecord>> operationRecords,
    Map<String, List<DividendRecord>> dividendRecords,
  ) async {
    await Future.wait([
      IcloudStorage.saveStocks(stocks, operationRecords, dividendRecords),
      IcloudStorage.saveSettings(),
    ]);
  }

  /// 记录收益快照（自动同步到 iCloud）
  static Future<void> recordProfitIfNeeded(
    double totalProfit,
    String currency,
  ) => IcloudStorage.recordProfitIfNeeded(totalProfit, currency);

  /// 仅保存设置（给设置页回调用）
  static Future<void> saveSettings() => IcloudStorage.saveSettings();

  /// 加载天级收益快照历史
  static Future<List<ProfitSnapshot>> loadDailyProfitHistory({
    String targetCurrency = AppConfig.defaultCurrency,
  }) => IcloudStorage.loadDailyProfitHistory(targetCurrency: targetCurrency);

  /// 加载日内收益快照历史
  static Future<List<ProfitSnapshot>> loadIntradayProfitHistory({
    String targetCurrency = AppConfig.defaultCurrency,
  }) => IcloudStorage.loadIntradayProfitHistory(targetCurrency: targetCurrency);

  /// 计算资产汇总
  static AssetSummary calculateAssetSummary(
    List<StockModel> stocks,
    Map<String, List<OperationRecord>> operationRecords,
    Map<String, List<DividendRecord>> dividendRecords,
    String targetCurrency,
  ) {
    return StockCalculator.calculateAssetSummary(
      stocks,
      operationRecords,
      dividendRecords,
      targetCurrency,
    );
  }

  /// 排序股票列表
  static List<StockModel> sortStocks(
    List<StockModel> stocks,
    String sortColumn,
    bool sortAscending,
    String targetCurrency,
  ) {
    return StockCalculator.sortStocks(
      stocks,
      sortColumn,
      sortAscending,
      targetCurrency,
    );
  }
}
