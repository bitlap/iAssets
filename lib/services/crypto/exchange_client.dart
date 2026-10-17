import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import '../../models/crypto/crypto_models.dart';

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
      throw const CryptoSyncException('timeout');
    } catch (_) {
      throw const CryptoSyncException('network');
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

  Future<dynamic> binance(
    ExchangeConnection c,
    String host,
    String path, [
    Map<String, String> params = const {},
  ]) {
    final q = {
      ...params,
      'timestamp': '${now().millisecondsSinceEpoch}',
      'recvWindow': '10000',
    };
    final encoded = Uri(queryParameters: q).query;
    return get(
      host,
      path,
      query: {...q, 'signature': _hmac(c.secret, encoded)},
      headers: {'X-MBX-APIKEY': c.apiKey},
    );
  }

  String okxHost(ExchangeConnection c) => switch (c.region) {
    'us' => 'us.okx.com',
    'eu' => 'eea.okx.com',
    _ => 'openapi.okx.com',
  };
  Future<List<Map<String, dynamic>>> okx(
    ExchangeConnection c,
    String path, [
    Map<String, String> params = const {},
  ]) async {
    final stamp = DateTime.fromMillisecondsSinceEpoch(
      now().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final data = object(
      await get(
        okxHost(c),
        path,
        query: params,
        headers: {
          'OK-ACCESS-KEY': c.apiKey,
          'OK-ACCESS-PASSPHRASE': c.passphrase,
          'OK-ACCESS-TIMESTAMP': stamp,
          'OK-ACCESS-SIGN': _hmac(
            c.secret,
            '${stamp}GET$path$query',
            base64Output: true,
          ),
        },
      ),
    );
    return rows(data['data']);
  }

  Future<Map<String, dynamic>> bybit(
    ExchangeConnection c,
    String path, [
    Map<String, String> params = const {},
  ]) async {
    final stamp = '${now().millisecondsSinceEpoch}';
    final query = Uri(queryParameters: params).query;
    return object(
      object(
        await get(
          'api.bybit.com',
          path,
          query: params,
          headers: {
            'X-BAPI-API-KEY': c.apiKey,
            'X-BAPI-TIMESTAMP': stamp,
            'X-BAPI-RECV-WINDOW': '10000',
            'X-BAPI-SIGN': _hmac(c.secret, '$stamp${c.apiKey}10000$query'),
          },
        ),
      )['result'],
    );
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

  Future<CryptoSnapshot> _binance(ExchangeConnection c) async {
    if (c.role == CryptoAccountRole.copy) {
      throw const CryptoSyncException('copyUnsupported');
    }
    if (c.role == CryptoAccountRole.lead) {
      return c.leadMarket == CryptoLeadMarket.spot
          ? _binanceSpotLead(c)
          : _binanceLead(c);
    }
    final permissionNotices = _binancePermissionNotices(
      object(
        await binance(c, 'api.binance.com', '/sapi/v1/account/apiRestrictions'),
      ),
    );
    final account = object(
      await binance(c, 'api.binance.com', '/api/v3/account'),
    );
    var uid = textField(account, 'uid');
    if (uid.isEmpty) {
      uid = textField(
        object(await binance(c, 'api.binance.com', '/sapi/v1/account/info')),
        'uid',
      );
    }
    if (uid.isEmpty) throw const CryptoSyncException('response');
    final rates = await usdRates();
    Map<String, Decimal> prices = rates;
    try {
      prices = spotPrices(
        rows(await get('api.binance.com', '/api/v3/ticker/price')),
        rates,
        okxStyle: false,
      );
    } catch (_) {
      /* Private account testing remains valid if public quotes fail. */
    }
    final balances = <CryptoBalance>[];
    for (final row in rows(account['balances'])) {
      final free = requiredAmount(row['free']);
      final locked = requiredAmount(row['locked']);
      if (free + locked == Decimal.zero) continue;
      final asset = textField(row, 'asset');
      balances.add(
        CryptoBalance(
          asset: asset,
          wallet: 'Spot',
          quantity: free + locked,
          available: free,
          frozen: locked,
          priceUsd: prices[asset],
        ),
      );
    }
    final wallets = <CryptoWallet>[
      CryptoWallet(
        name: 'Spot',
        kind: CryptoWalletKind.spot,
        equityUsd: balances.fold<Decimal>(
          Decimal.zero,
          (v, b) => v + (b.valueUsd ?? Decimal.zero),
        ),
      ),
    ];
    final positions = <CryptoPosition>[];
    final notices = <String>[...permissionNotices];
    final references = <String>['spot:$uid'];
    for (final coinM in [false, true]) {
      final host = coinM ? 'dapi.binance.com' : 'fapi.binance.com';
      final name = coinM ? 'COIN-M' : 'USDⓈ-M';
      final path = coinM ? '/dapi/v1/account' : '/fapi/v3/account';
      try {
        final futures = object(await binance(c, host, path));
        final aliases = rows(
          await binance(
            c,
            host,
            coinM ? '/dapi/v1/balance' : '/fapi/v3/balance',
          ),
        );
        for (final row in aliases) {
          final alias = textField(row, 'accountAlias');
          if (alias.isNotEmpty) {
            references.add('${coinM ? 'coinm' : 'usdm'}:$alias');
          }
        }
        Decimal equity = Decimal.zero;
        var complete = true;
        for (final row in rows(futures['assets'])) {
          final value = requiredAmount(row['marginBalance']);
          if (value == Decimal.zero) continue;
          final price = prices[textField(row, 'asset')];
          if (price == null) {
            complete = false;
          } else {
            equity += value * price;
          }
        }
        wallets.add(
          CryptoWallet(
            name: name,
            kind: CryptoWalletKind.futures,
            equityUsd: complete ? equity : null,
          ),
        );
        final risk = rows(
          await binance(
            c,
            host,
            coinM ? '/dapi/v1/positionRisk' : '/fapi/v3/positionRisk',
          ),
        );
        for (final p in risk) {
          final qty = requiredAmount(p['positionAmt']);
          if (qty == Decimal.zero) continue;
          final symbol = textField(p, 'symbol');
          final settle = coinM
              ? symbol.split('USD').first
              : (symbol.endsWith('USDC') ? 'USDC' : 'USDT');
          positions.add(
            CryptoPosition(
              symbol: symbol,
              wallet: name,
              isLong:
                  textField(p, 'positionSide') == 'LONG' ||
                  (textField(p, 'positionSide') == 'BOTH' &&
                      qty > Decimal.zero),
              quantity: qty.abs(),
              unit: coinM
                  ? 'contracts'
                  : symbol.replaceFirst(RegExp(r'(USDT|USDC)(_|$).*'), ''),
              settlement: settle,
              markPrice: optionalAmount(p['markPrice']),
              unrealizedPnl: optionalAmount(p['unRealizedProfit']),
              leverage: optionalAmount(p['leverage']),
              liquidationPrice: optionalAmount(p['liquidationPrice']),
            ),
          );
        }
      } on CryptoSyncException catch (e) {
        // Never interpret permission, IP or network failures as an empty wallet.
        if (e.detail == '-2015') {
          throw const CryptoSyncException('futuresUnavailable');
        }
        rethrow;
      }
    }
    return CryptoSnapshot(
      accountId: uid,
      updatedAt: now(),
      balances: balances,
      positions: positions,
      wallets: wallets,
      notices: notices,
      accountReferences: references.toSet().toList(),
    );
  }

  List<String> _binancePermissionNotices(Map<String, dynamic> permission) {
    const transfers = [
      'enableWithdrawals',
      'enableInternalTransfer',
      'permitsUniversalTransfer',
    ];
    const trading = [
      'enableSpotAndMarginTrading',
      'enableMargin',
      'enableFutures',
      'enableVanillaOptions',
      'enablePortfolioMarginTrading',
      'enableFixApiTrade',
    ];
    if (permission['enableReading'] != true ||
        transfers.any((key) => permission[key] == true)) {
      throw const CryptoSyncException('readOnly');
    }
    return [
      if (trading.any((key) => permission[key] == true)) 'tradingPermission',
    ];
  }

  Future<List<String>> _binanceLeadPermissions(
    ExchangeConnection c, {
    required bool spot,
  }) async {
    final notices = <String>[
      spot ? 'binanceSpotLeadScope' : 'binanceLeadScope',
    ];
    try {
      final permission = object(
        await binance(c, 'api.binance.com', '/sapi/v1/account/apiRestrictions'),
      );
      notices.addAll(_binancePermissionNotices(permission));
    } on CryptoSyncException catch (e) {
      if (!['-2015', '-2014', '-2008'].contains(e.detail)) rethrow;
      throw const CryptoSyncException('permissionUnverified');
    }
    return notices;
  }

  Future<CryptoSnapshot> _binanceSpotLead(ExchangeConnection c) async {
    final account = object(
      await binance(c, 'api.binance.com', '/api/v3/account'),
    );
    final uid = textField(account, 'uid');
    if (uid.isEmpty) throw const CryptoSyncException('response');
    final notices = await _binanceLeadPermissions(c, spot: true);
    final rates = await usdRates();
    Map<String, Decimal> prices = rates;
    try {
      prices = spotPrices(
        rows(await get('api.binance.com', '/api/v3/ticker/price')),
        rates,
        okxStyle: false,
      );
    } catch (_) {
      /* Unknown prices are retained as unknown, never set to zero. */
    }
    final balances = <CryptoBalance>[];
    for (final row in rows(account['balances'])) {
      final free = requiredAmount(row['free']);
      final locked = requiredAmount(row['locked']);
      final quantity = free + locked;
      if (quantity == Decimal.zero) continue;
      final asset = textField(row, 'asset');
      balances.add(
        CryptoBalance(
          asset: asset,
          wallet: 'Binance · Spot Lead',
          quantity: quantity,
          available: free,
          frozen: locked,
          priceUsd: prices[asset],
        ),
      );
    }
    final equity = balances.fold<Decimal>(
      Decimal.zero,
      (v, b) => v + (b.valueUsd ?? Decimal.zero),
    );
    final reference = 'spot:$uid';
    return CryptoSnapshot(
      accountId: reference,
      accountReferences: [reference],
      updatedAt: now(),
      balances: balances,
      positions: [],
      wallets: [
        CryptoWallet(
          name: 'Binance · Spot Lead',
          kind: CryptoWalletKind.lead,
          equityUsd: equity,
        ),
      ],
      notices: notices,
    );
  }

  Future<CryptoSnapshot> _binanceLead(ExchangeConnection c) async {
    // A lead portfolio key addresses its own USD-M account, not the main Spot/COIN-M wallets.
    final account = object(
      await binance(c, 'fapi.binance.com', '/fapi/v2/account'),
    );
    final walletBalance = requiredAmount(account['totalWalletBalance']);
    final pnl = requiredAmount(account['totalUnrealizedProfit']);
    final equity = requiredAmount(account['totalMarginBalance']);
    final aliases = rows(
      await binance(c, 'fapi.binance.com', '/fapi/v2/balance'),
    );
    final identifiers = aliases
        .map((r) => textField(r, 'accountAlias'))
        .where((v) => v.isNotEmpty)
        .toSet();
    if (identifiers.length != 1) throw const CryptoSyncException('response');
    final reference = 'usdm:${identifiers.single}';
    final notices = await _binanceLeadPermissions(c, spot: false);
    final risk = rows(
      await binance(c, 'fapi.binance.com', '/fapi/v2/positionRisk'),
    );
    final rates = await usdRates();
    final price = rates['USDT'];
    final positions = <CryptoPosition>[];
    for (final p in risk) {
      final quantity = requiredAmount(p['positionAmt']);
      if (quantity == Decimal.zero) continue;
      final symbol = textField(p, 'symbol');
      final side = textField(p, 'positionSide');
      positions.add(
        CryptoPosition(
          symbol: symbol,
          wallet: 'Binance · Lead',
          isLong: side == 'LONG' || (side == 'BOTH' && quantity > Decimal.zero),
          quantity: quantity.abs(),
          unit: symbol.replaceFirst(RegExp(r'USDT(_|$).*'), ''),
          settlement: 'USDT',
          markPrice: optionalAmount(p['markPrice']),
          unrealizedPnl: optionalAmount(p['unRealizedProfit']),
          leverage: optionalAmount(p['leverage']),
          liquidationPrice: optionalAmount(p['liquidationPrice']),
        ),
      );
    }
    return CryptoSnapshot(
      accountId: reference,
      accountReferences: [reference],
      updatedAt: now(),
      balances: [
        if (walletBalance != Decimal.zero)
          CryptoBalance(
            asset: 'USDT',
            wallet: 'Binance · Lead',
            quantity: walletBalance,
            available: optionalAmount(account['availableBalance']),
            priceUsd: price,
          ),
      ],
      positions: positions,
      wallets: [
        CryptoWallet(
          name: 'Binance · Lead',
          kind: CryptoWalletKind.lead,
          equityUsd: price == null ? null : equity * price,
          walletBalance: walletBalance,
          unrealizedPnl: pnl,
          settlement: 'USDT',
        ),
      ],
      notices: notices,
    );
  }

  Future<CryptoSnapshot> _okx(ExchangeConnection c) async {
    final configs = await okx(c, '/api/v5/account/config');
    if (configs.length != 1) throw const CryptoSyncException('response');
    final config = configs.single;
    final permissions = textField(config, 'perm').split(',');
    if (!permissions.contains('read_only') ||
        permissions.any((p) => p != 'read_only')) {
      throw const CryptoSyncException('readOnly');
    }
    final uid = textField(config, 'uid');
    if (uid.isEmpty) throw const CryptoSyncException('response');
    final data = await okx(c, '/api/v5/account/balance');
    if (data.length != 1) throw const CryptoSyncException('response');
    final trading = data.single;
    final allPositions = await okx(c, '/api/v5/account/positions');
    final rates = await usdRates();
    Map<String, Decimal> prices = rates;
    try {
      final ticker = object(
        await get(
          okxHost(c),
          '/api/v5/market/tickers',
          query: {'instType': 'SPOT'},
        ),
      );
      prices = spotPrices(rows(ticker['data']), rates, okxStyle: true);
    } catch (_) {
      /* Keep unknown values explicit. */
    }
    final balances = <CryptoBalance>[];
    final role = textField(config, 'spotRoleType');
    final walletName = role == '1'
        ? 'OKX · Lead'
        : role == '2'
        ? 'OKX · Copy'
        : 'OKX · Trading';
    for (final row in rows(trading['details'])) {
      final qty = requiredAmount(row['cashBal']);
      final isolated = amount(row['spotIsoBal']);
      final asset = textField(row, 'ccy');
      // cashBal and spotIsoBal remain separate informational rows. Account equity is authoritative.
      if (qty != Decimal.zero) {
        balances.add(
          CryptoBalance(
            asset: asset,
            wallet: 'OKX · Trading',
            quantity: qty,
            available: optionalAmount(row['availBal']),
            frozen: optionalAmount(row['frozenBal']),
            priceUsd: prices[asset],
          ),
        );
      }
      if (isolated != Decimal.zero) {
        balances.add(
          CryptoBalance(
            asset: asset,
            wallet: walletName,
            quantity: isolated,
            priceUsd: prices[asset],
          ),
        );
      }
    }
    final positions = <CryptoPosition>[];
    final posRole = textField(config, 'roleType');
    for (final p in allPositions) {
      if (!['SWAP', 'FUTURES'].contains(textField(p, 'instType'))) continue;
      final qty = requiredAmount(p['pos']);
      if (qty == Decimal.zero) continue;
      positions.add(
        CryptoPosition(
          symbol: textField(p, 'instId'),
          wallet: posRole == '1'
              ? 'OKX · Lead / Trading'
              : posRole == '2'
              ? 'OKX · Copy / Trading'
              : 'OKX · Trading',
          isLong:
              textField(p, 'posSide') == 'long' ||
              (textField(p, 'posSide') == 'net' && qty > Decimal.zero),
          quantity: qty.abs(),
          unit: 'contracts',
          settlement: textField(p, 'ccy'),
          markPrice: optionalAmount(p['markPx']),
          unrealizedPnl: optionalAmount(p['upl']),
          leverage: optionalAmount(p['lever']),
          liquidationPrice: optionalAmount(p['liqPx']),
        ),
      );
    }
    return CryptoSnapshot(
      accountId: uid,
      updatedAt: now(),
      balances: balances,
      positions: positions,
      wallets: [
        CryptoWallet(
          name: 'OKX · Trading',
          kind: CryptoWalletKind.unified,
          equityUsd: optionalAmount(trading['totalEq']),
        ),
      ],
      notices: ['okxScope', 'unifiedEquity', 'okxCopyScope'],
    );
  }

  Future<CryptoSnapshot> _bybit(ExchangeConnection c) async {
    final key = await bybit(c, '/v5/user/query-api');
    if (key['readOnly'].toString() != '1') {
      throw const CryptoSyncException('readOnly');
    }
    final uid = textField(key, 'userID');
    if (uid.isEmpty) throw const CryptoSyncException('response');
    final data = await bybit(c, '/v5/account/wallet-balance', {
      'accountType': 'UNIFIED',
    });
    final accounts = rows(data['list']);
    if (accounts.length != 1) throw const CryptoSyncException('response');
    final wallet = accounts.single;
    final rates = await usdRates();
    Map<String, Decimal> prices = rates;
    try {
      final ticker = object(
        await get(
          'api.bybit.com',
          '/v5/market/tickers',
          query: {'category': 'spot'},
        ),
      );
      final list = rows(object(ticker['result'])['list'])
          .map(
            (p) => <String, dynamic>{
              'symbol': p['symbol'],
              'price': p['lastPrice'],
            },
          )
          .toList();
      prices = spotPrices(list, rates, okxStyle: false);
    } catch (_) {
      /* Preserve account data when public quotes fail. */
    }
    final balances = <CryptoBalance>[];
    Decimal equityFallback = Decimal.zero;
    var equityComplete = true;
    for (final row in rows(wallet['coin'])) {
      final qty =
          requiredAmount(row['walletBalance']) - amount(row['spotBorrow']);
      final asset = textField(row, 'coin');
      if (qty != Decimal.zero) {
        balances.add(
          CryptoBalance(
            asset: asset,
            wallet: 'Bybit · UNIFIED',
            quantity: qty,
            frozen: optionalAmount(row['locked']),
            priceUsd: prices[asset],
          ),
        );
      }
      final eq = optionalAmount(row['usdValue']);
      if (eq == null) {
        equityComplete = false;
      } else {
        equityFallback += eq;
      }
    }
    final wallets = <CryptoWallet>[
      CryptoWallet(
        name: 'Bybit · UNIFIED',
        kind: c.role == CryptoAccountRole.lead
            ? CryptoWalletKind.lead
            : CryptoWalletKind.unified,
        equityUsd:
            optionalAmount(wallet['totalEquity']) ??
            (equityComplete ? equityFallback : null),
      ),
    ];
    final positions = <CryptoPosition>[];
    for (final params in [
      {'category': 'linear', 'settleCoin': 'USDT'},
      {'category': 'linear', 'settleCoin': 'USDC'},
      {'category': 'inverse'},
    ]) {
      String cursor = '';
      final visited = <String>{};
      do {
        final result = await bybit(c, '/v5/position/list', {
          ...params,
          'limit': '200',
          if (cursor.isNotEmpty) 'cursor': cursor,
        });
        for (final p in rows(result['list'])) {
          final qty = requiredAmount(p['size']);
          if (qty == Decimal.zero) continue;
          final symbol = textField(p, 'symbol');
          positions.add(
            CryptoPosition(
              symbol: symbol,
              wallet: 'Bybit · UNIFIED',
              isLong: textField(p, 'side') == 'Buy',
              quantity: qty,
              unit: params['category'] == 'inverse'
                  ? 'contracts'
                  : symbol.replaceFirst(RegExp(r'(USDT|USDC)(-|$).*'), ''),
              settlement: params['settleCoin'] ?? symbol.split('USD').first,
              markPrice: optionalAmount(p['markPrice']),
              unrealizedPnl: optionalAmount(p['unrealisedPnl']),
              leverage: optionalAmount(p['leverage']),
              liquidationPrice: optionalAmount(p['liqPrice']),
            ),
          );
        }
        cursor = textField(result, 'nextPageCursor');
        if (cursor.isNotEmpty && !visited.add(cursor)) {
          throw const CryptoSyncException('response');
        }
      } while (cursor.isNotEmpty);
    }
    final notices = <String>['unifiedEquity', 'bybitScope'];
    try {
      final overview = await bybit(c, '/v5/asset/asset-overview', {
        'valuationCurrency': 'USD',
        'accountType': 'CopyTrading',
      });
      for (final account in rows(overview['list'])) {
        if (textField(account, 'accountType') != 'CopyTrading') continue;
        final categories = rows(account['categories']);
        // Categories partition the account. Do not also add its parent totalEquity.
        for (final category in categories) {
          final label = 'Bybit · ${textField(category, 'category')}';
          wallets.add(
            CryptoWallet(
              name: label,
              kind: CryptoWalletKind.copy,
              equityUsd: optionalAmount(category['equity']),
            ),
          );
          for (final coin in rows(category['coinDetail'])) {
            final qty = requiredAmount(coin['equity']);
            if (qty == Decimal.zero) continue;
            final asset = textField(coin, 'coin');
            balances.add(
              CryptoBalance(
                asset: asset,
                wallet: label,
                quantity: qty,
                priceUsd: prices[asset],
              ),
            );
          }
        }
      }
      notices.add('bybitCopyPositions');
    } on CryptoSyncException {
      throw const CryptoSyncException('copyUnavailable');
    }
    return CryptoSnapshot(
      accountId: uid,
      updatedAt: now(),
      balances: balances,
      positions: positions,
      wallets: wallets,
      notices: notices,
      coverageComplete: true,
    );
  }
}
