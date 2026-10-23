import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/stock_search_models.dart';
import '../utils/market_util.dart';
import 'circuit_breaker.dart';
import 'tencent_quote_service.dart';
import 'east_money_quote_service.dart';
import 'yahoo_quote_service.dart';

class StockQuoteService {
  static final StockQuoteService _instance = StockQuoteService._internal();
  factory StockQuoteService() => _instance;
  StockQuoteService._internal();

  final TencentQuoteService _tencent = TencentQuoteService();
  final EastMoneyQuoteService _eastMoney = EastMoneyQuoteService();
  final YahooQuoteService _yahoo = YahooQuoteService();

  final Map<String, DateTime> _cacheTime = {};
  final Map<String, StockQuote?> _cacheValue = {};
  static const Duration _cacheTTL = Duration(
    minutes: AppConfig.quoteCacheTTLMin,
  );

  int get cooldownRemainingSeconds => CircuitBreaker().cooldownRemainingSeconds;

  Future<Map<String, StockQuote?>> getStockQuotesBatch(
    List<StockSearchResult> stocks,
  ) async {
    final result = <String, StockQuote?>{};
    final needFetch = <StockSearchResult>[];
    final seenSecids = <String>{};
    final now = DateTime.now();

    for (final stock in stocks) {
      if (seenSecids.contains(stock.secid)) continue;
      seenSecids.add(stock.secid);
      final cachedTime = _cacheTime[stock.secid];
      final cachedValue = _cacheValue[stock.secid];
      if (cachedTime != null && now.difference(cachedTime) < _cacheTTL) {
        result[stock.secid] = cachedValue;
      } else {
        needFetch.add(stock);
      }
    }

    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][行情] ===> 批量获取: ${stocks.length}只, 缓存命中${stocks.length - needFetch.length}只, 需请求${needFetch.length}只',
    );

    if (needFetch.isEmpty) return result;
    // 腾讯逐个查
    final tencentFailed = <StockSearchResult>[];
    for (final stock in needFetch) {
      final quote = await _tencent.fetchQuote(stock);
      if (quote != null) {
        _setCache(stock.secid, quote);
        result[stock.secid] = quote;
      } else {
        tencentFailed.add(stock);
      }
    }

    // 腾讯未查到的，批量查东方财富
    if (tencentFailed.isNotEmpty && !CircuitBreaker().isInCooldown) {
      await _eastMoney.fetchBatch(tencentFailed, (secid, quote) {
        _setCache(secid, quote);
        result[secid] = quote;
      });
    }

    // 备用源独立于国内数据源的熔断，避免东方财富连接失败后一起被跳过。
    await Future.wait(
      needFetch
          .where(
            (stock) =>
                !result.containsKey(stock.secid) &&
                _yahoo.supports(stock.market),
          )
          .map((stock) async {
            final quote = await _yahoo.fetchQuote(stock);
            if (quote != null) {
              _setCache(stock.secid, quote);
              result[stock.secid] = quote;
            }
          }),
    );

    // 国内数据源的空结果保持缓存；冷却期间不把跳过的请求当作空结果。
    // 全球备用源短暂失败时允许下次刷新重试。
    for (final stock in needFetch) {
      if (!result.containsKey(stock.secid) &&
          !_yahoo.supports(stock.market) &&
          !CircuitBreaker().isInCooldown) {
        _cacheTime[stock.secid] = DateTime.now();
        _cacheValue[stock.secid] = null;
      }
    }

    return result;
  }

  StockQuote? getCachedQuote(String secid) {
    final cachedTime = _cacheTime[secid];
    if (cachedTime != null &&
        DateTime.now().difference(cachedTime) < _cacheTTL) {
      return _cacheValue[secid];
    }
    return null;
  }

  static String? getLogoUrl(String code, String market) {
    if (MarketUtil.isUSMarket(market)) {
      return 'https://logos.stocktwits-cdn.com/${code.toUpperCase()}.png?w=64';
    } else if (market == MarketUtil.searchMarketHK) {
      return null;
    }
    return null;
  }

  void _setCache(String secid, StockQuote? quote) {
    _cacheTime[secid] = DateTime.now();
    _cacheValue[secid] = quote;
  }
}
