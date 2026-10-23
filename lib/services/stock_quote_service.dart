import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/stock_search_models.dart';
import '../utils/stock_logo_urls.dart';
import '../utils/market_util.dart';
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
  final Map<String, StockQuote> _cacheValue = {};
  static const Duration _cacheTTL = Duration(
    minutes: AppConfig.quoteCacheTTLMin,
  );

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
      if (cachedValue != null &&
          cachedTime != null &&
          now.difference(cachedTime) < _cacheTTL) {
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
    // 伦敦证券可能以 CHF、SEK、USD 等报价；该批量接口不含可靠币种，
    // 交由带币种信息的备用源，不能一律按便士除以 100。
    final eastMoneyStocks = tencentFailed
        .where((stock) => !MarketUtil.isUKMarket(stock.market))
        .toList();
    if (eastMoneyStocks.isNotEmpty) {
      await _eastMoney.fetchBatch(eastMoneyStocks, (secid, quote) {
        _setCache(secid, quote);
        result[secid] = quote;
      });
    }

    // 各数据源自行判断冷却，不阻断其他来源的回退。
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

    // 只缓存有效报价；无行情、请求失败或处于冷却期，下次刷新仍可重试。
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

  static String? getLogoUrl(String code, String market, {String secid = ''}) {
    final urls = StockLogoUrls.forStock(code, market, secid: secid);
    return urls.isEmpty ? null : urls.first;
  }

  void _setCache(String secid, StockQuote quote) {
    _cacheTime[secid] = DateTime.now();
    _cacheValue[secid] = quote;
  }
}
