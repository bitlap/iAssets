part of 'exchange_client.dart';

extension OkxExchangeClient on ExchangeClient {
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
}
