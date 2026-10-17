import 'package:decimal/decimal.dart';

Decimal amount(Object? value) {
  if (value == null || value.toString().isEmpty) return Decimal.zero;
  return Decimal.parse(value.toString());
}

Decimal? optionalAmount(Object? value) =>
    value == null || value.toString().isEmpty ? null : amount(value);

String numberText(Decimal value) => value.toString();

enum CryptoExchange { binance, okx, bybit }

enum CryptoAccountRole { regular, lead, copy }

enum CryptoLeadMarket { spot, futures }

enum CryptoWalletKind { spot, futures, unified, lead, copy }

class ExchangeConnection {
  final String id;
  final CryptoExchange exchange;
  final String name;
  final String region;
  final String apiKey;
  final String secret;
  final String passphrase;
  final String accountId;
  final CryptoAccountRole role;
  final CryptoLeadMarket leadMarket;
  final List<String> accountReferences;

  const ExchangeConnection({
    required this.id,
    required this.exchange,
    required this.name,
    this.region = 'global',
    required this.apiKey,
    required this.secret,
    this.passphrase = '',
    this.accountId = '',
    this.role = CryptoAccountRole.regular,
    this.leadMarket = CryptoLeadMarket.futures,
    this.accountReferences = const [],
  });

  ExchangeConnection identified(
    String uid, [
    List<String> references = const [],
  ]) => ExchangeConnection(
    id: id,
    exchange: exchange,
    name: name,
    region: region,
    apiKey: apiKey,
    secret: secret,
    passphrase: passphrase,
    accountId: uid,
    role: role,
    leadMarket: leadMarket,
    accountReferences: List.unmodifiable(references),
  );

  // Only persist this representation in the device-only Keychain.
  Map<String, dynamic> toSecureJson() => {
    'id': id,
    'exchange': exchange.name,
    'name': name,
    'region': region,
    'apiKey': apiKey,
    'secret': secret,
    'passphrase': passphrase,
    'accountId': accountId,
    'role': role.name,
    'leadMarket': leadMarket.name,
    'accountReferences': accountReferences,
  };

  factory ExchangeConnection.fromSecureJson(
    Map<String, dynamic> j,
  ) => ExchangeConnection(
    id: j['id'] as String,
    exchange: CryptoExchange.values.byName(j['exchange'] as String),
    name: j['name'] as String,
    region: j['region'] as String,
    accountReferences: (j['accountReferences'] as List?)?.cast<String>() ?? [],
    apiKey: j['apiKey'] as String,
    secret: j['secret'] as String,
    passphrase: j['passphrase'] as String? ?? '',
    accountId: j['accountId'] as String? ?? '',
    role: CryptoAccountRole.values.byName(j['role'] as String? ?? 'regular'),
    leadMarket: CryptoLeadMarket.values.byName(
      j['leadMarket'] as String? ?? 'futures',
    ),
  );
}

class CryptoBalance {
  final String asset;
  final String wallet;
  final Decimal quantity;
  final Decimal? available;
  final Decimal? frozen;
  final Decimal? priceUsd;
  const CryptoBalance({
    required this.asset,
    required this.wallet,
    required this.quantity,
    this.available,
    this.frozen,
    this.priceUsd,
  });
  Decimal? get valueUsd => priceUsd == null ? null : quantity * priceUsd!;
  Map<String, dynamic> toJson() => {
    'asset': asset,
    'wallet': wallet,
    'quantity': '$quantity',
    'available': available?.toString(),
    'frozen': frozen?.toString(),
    'priceUsd': priceUsd?.toString(),
  };
  factory CryptoBalance.fromJson(Map<String, dynamic> j) => CryptoBalance(
    asset: j['asset'] as String,
    wallet: j['wallet'] as String,
    quantity: amount(j['quantity']),
    available: optionalAmount(j['available']),
    frozen: optionalAmount(j['frozen']),
    priceUsd: optionalAmount(j['priceUsd']),
  );
}

class CryptoPosition {
  final String symbol;
  final String wallet;
  final bool isLong;
  final Decimal quantity;
  final String unit;
  final String settlement;
  final Decimal? markPrice;
  final Decimal? unrealizedPnl;
  final Decimal? leverage;
  final Decimal? liquidationPrice;
  const CryptoPosition({
    required this.symbol,
    required this.wallet,
    required this.isLong,
    required this.quantity,
    required this.unit,
    required this.settlement,
    this.markPrice,
    this.unrealizedPnl,
    this.leverage,
    this.liquidationPrice,
  });
  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'wallet': wallet,
    'isLong': isLong,
    'quantity': '$quantity',
    'unit': unit,
    'settlement': settlement,
    'markPrice': markPrice?.toString(),
    'unrealizedPnl': unrealizedPnl?.toString(),
    'leverage': leverage?.toString(),
    'liquidationPrice': liquidationPrice?.toString(),
  };
  factory CryptoPosition.fromJson(Map<String, dynamic> j) => CryptoPosition(
    symbol: j['symbol'] as String,
    wallet: j['wallet'] as String,
    isLong: j['isLong'] as bool,
    quantity: amount(j['quantity']),
    unit: j['unit'] as String,
    settlement: j['settlement'] as String,
    markPrice: optionalAmount(j['markPrice']),
    unrealizedPnl: optionalAmount(j['unrealizedPnl']),
    leverage: optionalAmount(j['leverage']),
    liquidationPrice: optionalAmount(j['liquidationPrice']),
  );
}

class CryptoWallet {
  final String name;
  final CryptoWalletKind kind;
  final Decimal? equityUsd;
  final Decimal? walletBalance;
  final Decimal? unrealizedPnl;
  final String? settlement;
  const CryptoWallet({
    required this.name,
    required this.kind,
    this.equityUsd,
    this.walletBalance,
    this.unrealizedPnl,
    this.settlement,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind.name,
    'equityUsd': equityUsd?.toString(),
    'walletBalance': walletBalance?.toString(),
    'unrealizedPnl': unrealizedPnl?.toString(),
    'settlement': settlement,
  };
  factory CryptoWallet.fromJson(Map<String, dynamic> j) => CryptoWallet(
    name: j['name'] as String,
    kind: CryptoWalletKind.values.byName(j['kind'] as String),
    equityUsd: optionalAmount(j['equityUsd']),
    walletBalance: optionalAmount(j['walletBalance']),
    unrealizedPnl: optionalAmount(j['unrealizedPnl']),
    settlement: j['settlement'] as String?,
  );
}

class CryptoSnapshot {
  final String accountId;
  final DateTime updatedAt;
  final List<CryptoBalance> balances;
  final List<CryptoPosition> positions;
  final List<CryptoWallet> wallets;
  final List<String> notices;
  final bool coverageComplete;
  final List<String> accountReferences;
  const CryptoSnapshot({
    required this.accountId,
    required this.updatedAt,
    required this.balances,
    required this.positions,
    required this.wallets,
    this.notices = const [],
    this.coverageComplete = true,
    this.accountReferences = const [],
  });

  bool get complete =>
      coverageComplete &&
      wallets.every((w) => w.equityUsd != null) &&
      balances.every((b) => b.priceUsd != null);
  // Account equity already includes collateral and P&L. Never sum positions here.
  Decimal get totalUsd =>
      wallets.fold(Decimal.zero, (v, w) => v + (w.equityUsd ?? Decimal.zero));
  Decimal subtotal(CryptoWalletKind kind) => wallets
      .where((w) => w.kind == kind)
      .fold(Decimal.zero, (v, w) => v + (w.equityUsd ?? Decimal.zero));
  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'updatedAt': updatedAt.toIso8601String(),
    'balances': balances.map((v) => v.toJson()).toList(),
    'positions': positions.map((v) => v.toJson()).toList(),
    'wallets': wallets.map((v) => v.toJson()).toList(),
    'notices': notices,
    'coverageComplete': coverageComplete,
    'accountReferences': accountReferences,
  };
  factory CryptoSnapshot.fromJson(Map<String, dynamic> j) => CryptoSnapshot(
    accountId: j['accountId'] as String,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    balances: (j['balances'] as List)
        .map((v) => CryptoBalance.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
    positions: (j['positions'] as List)
        .map((v) => CryptoPosition.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
    wallets: (j['wallets'] as List)
        .map((v) => CryptoWallet.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
    notices: (j['notices'] as List?)?.cast<String>() ?? [],
    coverageComplete: j['coverageComplete'] as bool? ?? true,
    accountReferences: (j['accountReferences'] as List?)?.cast<String>() ?? [],
  );
}

class CryptoSyncException implements Exception {
  final String code;
  final String? detail;
  const CryptoSyncException(this.code, [this.detail]);
  // Never include server response bodies, signed URLs or credentials in errors.
  @override
  String toString() =>
      'CryptoSyncException($code${detail == null ? '' : ': $detail'})';
}
