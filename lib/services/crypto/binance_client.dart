part of 'exchange_client.dart';

extension BinanceExchangeClient on ExchangeClient {
  Future<dynamic> binance(
    ExchangeConnection c,
    String host,
    String path, [
    Map<String, String> params = const {},
  ]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      // A dropped keep-alive connection can fail before Binance responds.
      // Re-sign the read-only GET for the retry so its timestamp stays fresh.
      final q = {
        ...params,
        'timestamp': '${now().millisecondsSinceEpoch}',
        'recvWindow': '10000',
      };
      final encoded = Uri(queryParameters: q).query;
      try {
        return await get(
          host,
          path,
          query: {...q, 'signature': _hmac(c.secret, encoded)},
          headers: {'X-MBX-APIKEY': c.apiKey},
        );
      } on CryptoSyncException catch (error) {
        if (attempt == 0 && error.code == 'networkConnection') continue;
        throw CryptoSyncException(error.code, error.detail, switch (host) {
          'fapi.binance.com' => 'cryptoStageUsdm',
          'dapi.binance.com' => 'cryptoStageCoinm',
          _ =>
            path == '/sapi/v1/account/apiRestrictions'
                ? 'cryptoStagePermissions'
                : 'cryptoStageSpot',
        });
      }
    }
    throw StateError('unreachable');
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
          throw CryptoSyncException('futuresUnavailable', '-2015', e.stage);
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
}
