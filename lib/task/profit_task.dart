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
import '../services/asset_data_manager.dart';
import '../services/crypto/crypto_store.dart';
import '../services/privacy_service.dart';
import '../services/pro_service.dart';
import '../services/widget_snapshot_service.dart';
import '../l10n/l10n.dart';
import '../utils/asset_calculator.dart';
import '../utils/currency_util.dart';
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
                secid: s.secid,
              ),
            )
            .toList();
        final quotes = await StockQuoteService().getStockQuotesBatch(
          searchResults,
        );
        for (final stock in stocks) {
          final secid = stock.secid;
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
      await _refreshWidgetSnapshot(summary.totalAssets, currency);
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

Future<void> _refreshWidgetSnapshot(double stocks, String currency) async {
  // A headless Workmanager engine has its own Dart singletons. Re-read the
  // user's presentation and verified entitlement before accessing exchanges.
  await PrivacyService.instance.initialize();
  L10n.deviceLocale = PlatformDispatcher.instance.locale;
  L10n.applyLanguage(await SettingsService.getPreferredLanguage());
  await ProService.instance.refresh();
  final pro = ProService.instance;
  // A headless StoreKit check can temporarily report Free while the foreground
  // app still has verified Pro access. Preserve the last widget balance rather
  // than publishing an apparent zero crypto allocation in that case.
  if (!pro.isPro) return;
  final crypto = CryptoStore();
  await crypto.refresh();
  if (!WidgetSnapshotService.isBackgroundPortfolioReady(
    entitlementLoading: pro.loading,
    entitlementFailed: pro.error != null,
    isPro: pro.isPro,
    cryptoInitialized: crypto.initialized,
    cryptoSyncing: crypto.syncing,
    cryptoIncomplete: crypto.incomplete,
    cryptoConnectionCount: crypto.connections.length,
  )) {
    return;
  }

  final (assets, _, _) = await AssetDataManager.loadCategoryState();
  final other = AssetCalculator.calculateTotalAssets(assets, 0, currency);
  final cryptoValue = CurrencyUtil.convertCurrency(
    crypto.totalUsd.toDouble(),
    'USD',
    currency,
  );
  final updatedAt = crypto.oldestUpdate;
  await WidgetSnapshotService.publish(
    total: stocks + cryptoValue + other,
    stocks: stocks,
    crypto: cryptoValue,
    other: other,
    currency: currency,
    updatedAt: updatedAt != null && updatedAt.isBefore(DateTime.now())
        ? updatedAt
        : DateTime.now(),
    incomplete: crypto.incomplete,
  );
}

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
