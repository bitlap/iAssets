import '../../config/app_config.dart';
import '../../models/stock_model.dart';
import '../../models/stock_search_models.dart';
import '../../models/calculator_models.dart';
import '../../services/stock_quote_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../utils/stock_calculator.dart';
import '../../utils/currency_helper.dart';

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
          '${stock.marketType == StockConfig.searchMarketUS ? StockConfig.secidUS : StockConfig.secidHK}.${stock.symbol}';
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
                '${stock.marketType == StockConfig.searchMarketUS ? StockConfig.secidUS : StockConfig.secidHK}.${stock.symbol}',
          ),
        )
        .toList();
  }

  /// 拉取汇率并更新缓存
  static Future<void> fetchExchangeRates(ExchangeRateService service) async {
    final rates = await service.fetchRates();
    if (rates != null) CurrencyHelper.updateRates(rates);
  }

  /// 拉取行情
  static Future<Map<String, StockQuote?>> fetchQuotes(
    StockQuoteService quoteService,
    List<StockModel> stocks,
  ) async {
    final searchResults = buildSearchResults(stocks);
    return await quoteService.getStockQuotesBatch(searchResults);
  }

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
