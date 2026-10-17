part of 'exchange_client.dart';

extension BybitExchangeClient on ExchangeClient {
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
