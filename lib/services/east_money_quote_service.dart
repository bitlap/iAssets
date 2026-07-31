import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

import '../config/app_config.dart';
import '../models/stock_search_models.dart';
import '../utils/market_util.dart';
import 'circuit_breaker.dart';

class EastMoneyQuoteService {
  static final EastMoneyQuoteService _instance =
      EastMoneyQuoteService._internal();
  factory EastMoneyQuoteService() => _instance;
  EastMoneyQuoteService._internal();

  final CircuitBreaker _breaker = CircuitBreaker();
  static const String _batchBaseUrl =
      'https://push2.eastmoney.com/api/qt/ulist.np/get';

  Future<void> fetchBatch(
    List<StockSearchResult> stocks,
    void Function(String secid, StockQuote quote) onQuote,
  ) async {
    if (stocks.isEmpty) return;
    if (_breaker.isInCooldown) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][东方财富] ===> 冷却中，跳过批量',
      );
      return;
    }

    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][东方财富] ===> 批量查询: ${stocks.length}只',
    );

    try {
      final secids = stocks.map((s) => s.secid).join(',');
      final client = Client();
      final uri = Uri.parse(
        '$_batchBaseUrl?secids=$secids'
        '&fields=f12,f1,f2,f3',
      );

      final response = await client
          .get(uri)
          .timeout(Duration(seconds: AppConfig.httpTimeoutSec));
      client.close();
      _breaker.onSuccess();

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>?;
        final rawData = body?['data'];
        final diffList = (rawData is Map ? rawData['diff'] : rawData) as List?;
        if (diffList != null) {
          final stockByCode = <String, StockSearchResult>{
            for (final s in stocks) s.code: s,
          };
          for (final item in diffList) {
            if (item is! Map<String, dynamic>) continue;
            final code = item['f12']?.toString() ?? '';
            final stock = stockByCode[code];
            if (stock == null) continue;

            final quote = _parseItem(item, stock);
            if (quote == null) continue;
            onQuote(stock.secid, quote);
            debugPrint(
              '[${DateTime.now().toString().substring(11, 19)}][东方财富] ===> $code: ${quote.currentPrice} (${quote.changePercent}%)',
            );
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][东方财富] ===> 批量失败: $e',
      );
      _breaker.onFailure();
    }
  }

  double _pow10(int n) {
    double result = 1.0;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  StockQuote? _parseItem(Map<String, dynamic> item, StockSearchResult? stock) {
    if (stock == null) return null;
    var decimals = _parseInt(item['f1']).toInt();
    var rawPrice = _parseInt(item['f2']);
    final price = decimals > 0 ? rawPrice / _pow10(decimals) : rawPrice;
    if (price == 0) return null;

    final changePercent = _parseDouble(item['f3']) / 100;

    final market = stock.market;

    final logoUrl = market == MarketUtil.searchMarketUS
        ? 'https://logos.stocktwits-cdn.com/${stock.code.toUpperCase()}.png?w=64'
        : null;

    return StockQuote(
      code: stock.code,
      name: stock.name,
      currentPrice: price,
      changePercent: changePercent,
      market: market,
      logoUrl: logoUrl,
    );
  }

  double _parseInt(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed ?? 0.0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed ?? 0.0;
  }
}
