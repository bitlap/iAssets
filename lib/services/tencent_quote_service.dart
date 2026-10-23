import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

import '../config/app_config.dart';
import '../models/stock_search_models.dart';
import '../utils/market_util.dart';
import '../utils/stock_logo_urls.dart';
import 'circuit_breaker.dart';

class TencentQuoteService {
  static final TencentQuoteService _instance = TencentQuoteService._internal();
  factory TencentQuoteService() => _instance;
  TencentQuoteService._internal();

  final CircuitBreaker _breaker = CircuitBreaker.tencent;
  static const String _baseUrl = 'https://qt.gtimg.cn/q=';

  Future<StockQuote?> fetchQuote(StockSearchResult stock) async {
    if (_breaker.isInCooldown) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][腾讯] ===> 冷却中，跳过: ${stock.code}',
      );
      return null;
    }

    final prefix = MarketUtil.tencentPrefix(stock.market, stock.secid);
    if (prefix == null) return null;

    final client = Client();
    try {
      final symbol = '$prefix${stock.code}';

      final uri = Uri.parse('$_baseUrl$symbol');

      final response = await client
          .get(uri)
          .timeout(Duration(seconds: AppConfig.httpTimeoutSec));
      if (response.statusCode == 200) {
        _breaker.onSuccess();
        final quote = _parseQuote(response.body, stock);
        if (quote != null) {
          debugPrint(
            '[${DateTime.now().toString().substring(11, 19)}][腾讯] ===> ${stock.code}: ${quote.currentPrice} (${quote.changePercent}%)',
          );
        }
        return quote;
      }
      if (response.statusCode == 429 || response.statusCode >= 500) {
        _breaker.onFailure();
      }
      return null;
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][腾讯] ===> 获取失败 ${stock.code}: $e',
      );
      _breaker.onFailure();
      return null;
    } finally {
      client.close();
    }
  }

  StockQuote? _parseQuote(String responseBody, StockSearchResult stock) {
    try {
      final match = RegExp(r'"([^"]+)"').firstMatch(responseBody);
      if (match == null) return null;

      final content = match.group(1)!;
      final parts = content.split('~');

      if (parts.length < 5) return null;

      final currentPrice = double.tryParse(parts[3]) ?? 0.0;
      if (!currentPrice.isFinite || currentPrice <= 0) return null;

      double changePercent = 0.0;
      if (parts.length > 32) {
        changePercent = double.tryParse(parts[32]) ?? 0.0;
      }

      final logoUrl = StockLogoUrls.forStock(
        stock.code,
        stock.market,
        secid: stock.secid,
      ).firstOrNull;

      return StockQuote(
        code: stock.code,
        name: stock.name,
        currentPrice: currentPrice,
        changePercent: changePercent,
        market: stock.market,
        logoUrl: logoUrl,
      );
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][腾讯] ===> 解析失败 ${stock.code}: $e',
      );
      return null;
    }
  }
}
