import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException;
import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import '../../models/crypto/crypto_models.dart';

part 'binance_client.dart';
part 'okx_client.dart';
part 'bybit_client.dart';

Map<String, dynamic> object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const CryptoSyncException('response');
  }
  return value;
}

List<Map<String, dynamic>> rows(Object? value) {
  if (value is! List) throw const CryptoSyncException('response');
  return value.map(object).toList();
}

String textField(Map<String, dynamic> row, String key) =>
    row[key]?.toString() ?? '';
Decimal requiredAmount(Object? v) {
  if (v == null || v.toString().isEmpty) {
    throw const CryptoSyncException('response');
  }
  return amount(v);
}

Decimal divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

abstract interface class ExchangeReader {
  Future<CryptoSnapshot> read(ExchangeConnection connection);
}

/// All exchange requests are GETs to fixed HTTPS origins. No trading API exists here.
class ExchangeClient implements ExchangeReader {
  final http.Client _http;
  final DateTime Function() now;
  ExchangeClient({http.Client? client, DateTime Function()? clock})
    : _http = client ?? http.Client(),
      now = clock ?? DateTime.now;

  Future<dynamic> get(
    String host,
    String path, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) async {
    final request =
        http.Request('GET', Uri.https(host, path, query.isEmpty ? null : query))
          ..followRedirects = false
          ..headers.addAll(headers);
    try {
      final response = await _http
          .send(request)
          .timeout(const Duration(seconds: 15));
      final body = await response.stream.bytesToString().timeout(
        const Duration(seconds: 15),
      );
      dynamic data;
      try {
        data = jsonDecode(body);
      } catch (_) {
        throw CryptoSyncException('network', 'HTTP ${response.statusCode}');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = data is Map ? (data['code'] ?? data['retCode']) : null;
        throw CryptoSyncException(
          'network',
          _safeCode(code, response.statusCode),
        );
      }
      if (data is Map &&
          ((data.containsKey('retCode') && data['retCode'].toString() != '0') ||
              (data.containsKey('code') && data['code'].toString() != '0'))) {
        throw CryptoSyncException(
          'api',
          _safeCode(data['code'] ?? data['retCode'], response.statusCode),
        );
      }
      return data;
    } on CryptoSyncException {
      rethrow;
    } on TimeoutException {
      throw CryptoSyncException('timeout', host);
    } on HandshakeException {
      throw CryptoSyncException('networkTls', host);
    } on SocketException {
      throw CryptoSyncException('networkConnection', host);
    } catch (_) {
      throw CryptoSyncException('networkConnection', host);
    }
  }

  String _safeCode(Object? code, int status) =>
      code != null && RegExp(r'^-?\d+$').hasMatch('$code')
      ? '$code'
      : 'HTTP $status';

  String _hmac(String secret, String value, {bool base64Output = false}) {
    final bytes = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(value));
    return base64Output ? base64Encode(bytes.bytes) : bytes.toString();
  }

  // Public fiat conversion, queried without sending any account identifiers.
  // A missing quote stays missing; stablecoins are never silently valued at $1.
  Future<Map<String, Decimal>> usdRates() async {
    try {
      final data = object(
        object(
          await get(
            'api.coinbase.com',
            '/v2/exchange-rates',
            query: {'currency': 'USD'},
          ),
        )['data'],
      );
      final rates = object(data['rates']);
      return {
        for (final e in rates.entries)
          if (amount(e.value) > Decimal.zero)
            e.key: divide(Decimal.one, amount(e.value)),
        'USD': Decimal.one,
      };
    } catch (_) {
      return {'USD': Decimal.one};
    }
  }

  Map<String, Decimal> spotPrices(
    List<Map<String, dynamic>> tickers,
    Map<String, Decimal> usd, {
    required bool okxStyle,
  }) {
    final result = {...usd};
    for (final quote in ['USDT', 'USDC', 'BTC', 'ETH']) {
      final rate = result[quote];
      if (rate == null) continue;
      for (final row in tickers) {
        final symbol = textField(row, okxStyle ? 'instId' : 'symbol');
        final suffix = okxStyle ? '-$quote' : quote;
        if (!symbol.endsWith(suffix)) continue;
        final base = symbol.substring(0, symbol.length - suffix.length);
        final price = optionalAmount(row[okxStyle ? 'last' : 'price']);
        if (price != null && price > Decimal.zero) result[base] = price * rate;
      }
    }
    return result;
  }

  @override
  Future<CryptoSnapshot> read(ExchangeConnection c) async {
    try {
      return await switch (c.exchange) {
        CryptoExchange.binance => _binance(c),
        CryptoExchange.okx => _okx(c),
        CryptoExchange.bybit => _bybit(c),
      };
    } on CryptoSyncException {
      rethrow;
    } catch (_) {
      throw const CryptoSyncException('response');
    }
  }
}
