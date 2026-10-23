import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

import '../config/app_config.dart';
import '../models/stock_search_models.dart';
import '../utils/market_util.dart';
import '../utils/stock_logo_urls.dart';
import 'exchange_rate_service.dart';

/// 为伦敦证券提供带币种的报价，并作为日、韩和场外市场的备用源。
class YahooQuoteService {
  bool supports(String market) => const {
    MarketUtil.exchangeJPX,
    MarketUtil.exchangeKRX,
    MarketUtil.exchangeLSE,
    MarketUtil.exchangeOTCBB,
    MarketUtil.searchMarketJP,
    MarketUtil.searchMarketKR,
    MarketUtil.searchMarketUK,
    MarketUtil.searchMarketPink,
  }.contains(market);

  List<String> _symbols(StockSearchResult stock) {
    switch (stock.market) {
      case MarketUtil.exchangeJPX:
      case MarketUtil.searchMarketJP:
        return ['${stock.code}.T'];
      case MarketUtil.exchangeKRX:
      case MarketUtil.searchMarketKR:
        // KRX 包含 KOSPI 和 KOSDAQ；保留数字代码前导零。
        return ['${stock.code}.KS', '${stock.code}.KQ'];
      case MarketUtil.exchangeLSE:
      case MarketUtil.searchMarketUK:
        return ['${stock.code.replaceAll('.', '-')}.L'];
      case MarketUtil.exchangeOTCBB:
      case MarketUtil.searchMarketPink:
        return [stock.code];
      default:
        return [];
    }
  }

  Future<StockQuote?> fetchQuote(StockSearchResult stock) async {
    final symbols = _symbols(stock);
    if (symbols.isEmpty) return null;
    final client = Client();
    try {
      for (final symbol in symbols) {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v8/finance/chart/$symbol',
          {'interval': '1d', 'range': '1d'},
        );
        final response = await client
            .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: AppConfig.httpTimeoutSec));
        // 仅代码不存在时尝试同一市场的另一交易所，不在限流时重试。
        if (response.statusCode == 404) continue;
        if (response.statusCode != 200) return null;
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final chart = body['chart'] as Map<String, dynamic>?;
        if (chart?['error'] != null) continue;
        final results = chart?['result'] as List?;
        if (results == null || results.isEmpty) continue;
        final meta = results.first['meta'] as Map<String, dynamic>?;
        if (meta == null || meta['symbol'] != symbol) continue;
        final currency = meta['currency'];
        final expectedCurrency = MarketUtil.currencyForMarket(stock.market);
        final inPence = currency == 'GBp' || currency == 'GBX';
        final foreignLondonCurrency =
            MarketUtil.isUKMarket(stock.market) &&
            currency is String &&
            RegExp(r'^[A-Z]{3}$').hasMatch(currency);
        if (currency != expectedCurrency &&
            !(expectedCurrency == 'GBP' && inPence) &&
            !foreignLondonCurrency) {
          continue;
        }
        final price = (meta['regularMarketPrice'] as num?)?.toDouble();
        // range=1d 的 chartPreviousClose 才是前一交易日收盘价。
        final previous =
            (meta['previousClose'] as num? ??
                    meta['chartPreviousClose'] as num?)
                ?.toDouble();
        if (price == null ||
            !price.isFinite ||
            price <= 0 ||
            previous == null ||
            !previous.isFinite ||
            previous <= 0) {
          continue;
        }
        var holdingPrice = inPence ? price / 100 : price;
        if (currency != expectedCurrency && !inPence) {
          final rate = await ExchangeRateService().conversionRate(
            currency as String,
            expectedCurrency,
          );
          if (rate == null) continue;
          holdingPrice *= rate;
        }
        if (!holdingPrice.isFinite || holdingPrice <= 0) continue;
        return StockQuote(
          code: stock.code,
          name: stock.name,
          market: stock.market,
          logoUrl: StockLogoUrls.forStock(
            stock.code,
            stock.market,
            secid: stock.secid,
          ).firstOrNull,
          currentPrice: holdingPrice,
          changePercent: (price / previous - 1) * 100,
        );
      }
    } catch (e) {
      debugPrint('[Yahoo] ===> 获取失败 ${stock.code}: $e');
    } finally {
      client.close();
    }
    return null;
  }
}
