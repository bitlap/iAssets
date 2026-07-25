import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import '../config/app_config.dart';
import '../models/stock_search_models.dart';
import '../services/settings_service.dart';
import '../services/stock_data_manager.dart';
import '../services/stock_quote_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/market_util.dart';
import '../utils/stock_calculator.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final data = await StockDataManager.loadStocks();
      final stocks = data.$1;
      final records = data.$2;
      final dividendRecords = data.$3;

      // 获取最新行情，再计算盈亏
      if (stocks.isNotEmpty) {
        final searchResults = stocks
            .map(
              (s) => StockSearchResult(
                code: s.symbol,
                name: s.companyName,
                market: s.marketType,
                secid: s.secid ?? _secidForMarket(s.marketType, s.symbol),
              ),
            )
            .toList();
        final quotes = await StockQuoteService().getStockQuotesBatch(
          searchResults,
        );
        for (final stock in stocks) {
          final secid =
              stock.secid ?? _secidForMarket(stock.marketType, stock.symbol);
          final quote = quotes[secid];
          if (quote != null) {
            final idx = stocks.indexWhere((s) => s.symbol == stock.symbol);
            if (idx != -1) {
              stocks[idx] = stock.copyWith(
                currentPrice: quote.currentPrice,
                changePercent: quote.changePercent,
              );
              stocks[idx] = StockCalculator.recalculateFromRecords(
                stocks[idx],
                records[stock.symbol] ?? [],
              );
            }
          }
        }
      }

      await ExchangeRateService().fetchRates();
      final currency = await _readCurrency();
      final summary = StockCalculator.calculateAssetSummary(
        stocks,
        records,
        dividendRecords,
        currency,
      );
      await StockDataManager.recordProfitIfNeeded(
        summary.totalProfit,
        currency,
      );
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][WorkManager] ===> 后台任务执行成功 totalProfit: ${summary.totalProfit} ($currency)',
      );
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][WorkManager] ===> 后台任务失败: $e',
      );
    }
    return Future.value(true);
  });
}

String _secidForMarket(String marketType, String symbol) =>
    MarketUtil.secidForMarket(marketType, symbol);

Future<String> _readCurrency() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/settings.json');
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      return json[SettingsService.keyDefaultCurrency] as String? ??
          AppConfig.defaultCurrency;
    }
  } catch (_) {}
  return AppConfig.defaultCurrency;
}
