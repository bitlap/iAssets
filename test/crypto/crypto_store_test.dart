import 'package:assets/services/pro_service.dart';
import '../support/pro_fixtures.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/models/crypto/crypto_models.dart';
import 'package:assets/services/crypto/crypto_store.dart';
import 'package:assets/services/crypto/exchange_client.dart';
import 'package:assets/utils/asset_calculator.dart';
import 'package:assets/models/asset_account.dart';

class MemoryPersistence implements CryptoPersistence {
  String? connections;
  String? legacyCache;
  int legacyCleanupCalls = 0;
  bool fail = false;
  @override
  Future<String?> readConnections() async {
    if (fail) throw Exception('locked');
    return connections;
  }

  @override
  Future<void> writeConnections(String value) async => connections = value;
  @override
  Future<void> clearLegacyCache() async {
    legacyCache = null;
    legacyCleanupCalls++;
  }
}

class FakeReader implements ExchangeReader {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  CryptoSnapshot snapshot;
  FakeReader(this.snapshot);
  @override
  Future<CryptoSnapshot> read(ExchangeConnection c) async {
    calls++;
    if (fail) throw const CryptoSyncException('network');
    await gate?.future;
    return snapshot;
  }
}

ExchangeConnection connection({String id = 'a', String key = 'key'}) =>
    ExchangeConnection(
      id: id,
      exchange: CryptoExchange.binance,
      name: 'Account',
      apiKey: key,
      secret: 'sensitive-secret',
      passphrase: 'sensitive-pass',
    );
CryptoSnapshot sample(
  DateTime time, {
  String uid = '123',
  String equity = '1050',
  List<String> notices = const [],
}) => CryptoSnapshot(
  accountId: uid,
  notices: notices,
  updatedAt: time,
  balances: [
    CryptoBalance(
      asset: 'USDT',
      wallet: 'unified',
      quantity: amount('1000'),
      priceUsd: amount('1'),
    ),
  ],
  positions: [
    CryptoPosition(
      symbol: 'BTCUSDT',
      wallet: 'unified',
      isLong: true,
      quantity: amount('.1'),
      unit: 'BTC',
      settlement: 'USDT',
      unrealizedPnl: amount('50'),
    ),
  ],
  wallets: [
    CryptoWallet(
      name: 'unified',
      kind: CryptoWalletKind.unified,
      equityUsd: amount(equity),
    ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp/iassets-tests',
      );
  late DateTime clock;
  late MemoryPersistence persistence;
  late FakeReader reader;
  late CryptoStore store;
  test(
    'free crypto neither loads credentials nor makes exchange requests',
    () async {
      final persistence = MemoryPersistence();
      final reader = FakeReader(sample(DateTime.now()));
      final locked = CryptoStore(
        reader: reader,
        persistence: persistence,
        canAccess: () => false,
      );
      await locked.refresh();
      expect(locked.initialized, isFalse);
      expect(reader.calls, 0);
      await expectLater(
        locked.test(connection()),
        throwsA(isA<ProRequiredException>()),
      );
      expect(reader.calls, 0);
      locked.dispose();
    },
  );

  test(
    'expiry during crypto request discards its result and blocks save',
    () async {
      var allowed = true;
      final persistence = MemoryPersistence();
      final reader = FakeReader(sample(DateTime.now()));
      final guarded = CryptoStore(
        reader: reader,
        persistence: persistence,
        canAccess: () => allowed,
      );
      final tested = await guarded.test(connection());
      await guarded.add(tested);
      reader.snapshot = sample(DateTime.now(), equity: '9999');
      reader.gate = Completer<void>();
      final refresh = guarded.refresh();
      while (reader.calls < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      allowed = false;
      reader.gate!.complete();
      await refresh;
      expect(guarded.totalUsd.toString(), '1050');
      await expectLater(
        guarded.add(tested),
        throwsA(isA<ProRequiredException>()),
      );
      expect(guarded.connections.length, 1);
      guarded.dispose();
    },
  );

  setUp(() async {
    await setTestPro();
    clock = DateTime.utc(2026, 10, 17, 12);
    persistence = MemoryPersistence();
    reader = FakeReader(sample(clock));
    store = CryptoStore(
      reader: reader,
      persistence: persistence,
      clock: () => clock,
    );
  });
  tearDown(() => store.dispose());
  test('non-Binance connections cannot be tested or refreshed', () async {
    final legacy = ExchangeConnection(
      id: 'legacy',
      exchange: CryptoExchange.okx,
      name: 'Legacy',
      apiKey: 'fake-key',
      secret: 'fake-secret',
      accountId: '123',
    );
    persistence.connections = jsonEncode([legacy.toSecureJson()]);
    persistence.legacyCache = jsonEncode({'legacy': sample(clock).toJson()});
    await expectLater(
      store.test(legacy),
      throwsA(
        isA<CryptoSyncException>().having(
          (e) => e.code,
          'code',
          'unsupportedExchange',
        ),
      ),
    );
    await store.refresh();
    expect(reader.calls, 0);
    expect(store.snapshot('legacy'), isNull);
    expect(store.totalUsd, Decimal.zero);
    expect(store.errors['legacy']?.code, 'unsupportedExchange');
    expect(store.connections.single.id, 'legacy');
  });
  test(
    'unified account equity counts once, not balances plus notional plus PnL',
    () async {
      await store.add(await store.test(connection()));
      expect(store.totalUsd, amount('1050'));
      expect(store.subtotal(CryptoWalletKind.unified), amount('1050'));
    },
  );
  test(
    'every refresh requests live data, including consecutive pull refreshes',
    () async {
      await store.add(await store.test(connection()));
      await store.refresh();
      expect(reader.calls, 2);
      reader.snapshot = sample(clock, equity: '1100');
      await store.refresh();
      expect(reader.calls, 3);
      expect(store.totalUsd, amount('1100'));
      clock = clock.add(const Duration(minutes: 5));
      await store.refresh();
      expect(reader.calls, 4);
      expect(persistence.legacyCache, isNull);
    },
  );
  test('overlapping refreshes share the in-flight request', () async {
    await store.add(await store.test(connection()));
    reader.gate = Completer<void>();
    final first = store.refresh();
    final second = store.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(reader.calls, 2);
    reader.gate!.complete();
    await Future.wait([first, second]);
    expect(reader.calls, 2);
    expect(store.syncing, false);
  });
  test(
    'failed refresh preserves last snapshot and marks total incomplete',
    () async {
      await store.add(await store.test(connection()));
      clock = clock.add(const Duration(minutes: 5));
      reader.fail = true;
      await store.refresh();
      expect(store.oldestUpdate, reader.snapshot.updatedAt);
      expect(store.totalUsd, amount('1050'));
      expect(store.incomplete, true);
      expect(store.errors['a']?.code, 'network');
    },
  );
  test('startup clears legacy cache and never restores its balances', () async {
    persistence.connections = jsonEncode([
      connection().identified('123').toSecureJson(),
    ]);
    persistence.legacyCache = jsonEncode({
      'a': sample(clock, equity: '999999').toJson(),
    });
    await store.initialize();
    expect(persistence.legacyCache, isNull);
    expect(persistence.legacyCleanupCalls, 1);
    expect(store.snapshot('a'), isNull);
    expect(store.oldestUpdate, isNull);
    expect(store.totalUsd, Decimal.zero);
    expect(store.incomplete, true);
    await store.refresh();
    expect(reader.calls, 1);
    expect(store.totalUsd, amount('1050'));
  });
  test('API validation failure never persists connection', () async {
    reader.fail = true;
    await expectLater(
      store.test(connection()),
      throwsA(isA<CryptoSyncException>()),
    );
    expect(store.connections, isEmpty);
    expect(persistence.connections, null);
  });
  test('test token expires before save', () async {
    final tested = await store.test(connection());
    clock = clock.add(const Duration(minutes: 5));
    await expectLater(
      store.add(tested),
      throwsA(
        isA<CryptoSyncException>().having((e) => e.code, 'code', 'retest'),
      ),
    );
    expect(store.connections, isEmpty);
  });
  test(
    'same API Key and Secret are rejected before another network test',
    () async {
      await store.add(await store.test(connection()));
      expect(reader.calls, 1);
      final duplicate = ExchangeConnection(
        id: 'b',
        exchange: CryptoExchange.binance,
        name: 'Other name and role',
        apiKey: 'key',
        secret: 'sensitive-secret',
        role: CryptoAccountRole.lead,
      );
      await expectLater(
        store.test(duplicate),
        throwsA(
          isA<CryptoSyncException>().having(
            (e) => e.code,
            'code',
            'duplicateCredentials',
          ),
        ),
      );
      expect(reader.calls, 1);
      expect(store.connections, hasLength(1));
    },
  );
  test('save rechecks credentials after another test succeeds', () async {
    final first = await store.test(connection());
    final second = await store.test(connection(id: 'b'));
    await store.add(first);
    await expectLater(
      store.add(second),
      throwsA(
        isA<CryptoSyncException>().having(
          (e) => e.code,
          'code',
          'duplicateCredentials',
        ),
      ),
    );
    expect(store.connections, hasLength(1));
  });
  test('same account cannot be added with another API key', () async {
    await store.add(await store.test(connection()));
    await expectLater(
      store.test(connection(id: 'b', key: 'second-key')),
      throwsA(
        isA<CryptoSyncException>().having((e) => e.code, 'code', 'duplicate'),
      ),
    );
  });
  test(
    'removal deletes credentials and session data without saving asset data',
    () async {
      await store.add(await store.test(connection()));
      expect(persistence.legacyCache, isNull);
      final saved = jsonDecode(persistence.connections!) as List;
      expect(saved.single.containsKey('balances'), false);
      expect(saved.single.containsKey('wallets'), false);
      await store.remove('a');
      expect(jsonDecode(persistence.connections!), isEmpty);
      expect(store.snapshot('a'), isNull);
      expect(store.totalUsd, Decimal.zero);
    },
  );
  test(
    'relaunch restores only connections and must request balances again',
    () async {
      await store.add(await store.test(connection()));
      final restored = CryptoStore(
        reader: reader,
        persistence: persistence,
        clock: () => clock,
      );
      await restored.initialize();
      expect(restored.totalUsd, Decimal.zero);
      expect(restored.oldestUpdate, isNull);
      expect(restored.connections.single.accountId, '123');
      await restored.refresh();
      expect(restored.totalUsd, amount('1050'));
      expect(reader.calls, 2);
      restored.dispose();
    },
  );
  test(
    'locked Keychain blocks adding and leaves saved entries untouched',
    () async {
      persistence.connections = 'do not overwrite';
      persistence.fail = true;
      await expectLater(
        store.test(connection()),
        throwsA(isA<CryptoSyncException>()),
      );
      expect(store.initialized, false);
      expect(persistence.connections, 'do not overwrite');
    },
  );
  test('account identity change preserves old result', () async {
    await store.add(await store.test(connection()));
    reader.snapshot = sample(clock, uid: 'different', equity: '9999');
    await store.refresh();
    expect(store.totalUsd, amount('1050'));
    expect(store.errors['a']?.code, 'accountChanged');
  });
  test('sub-satoshi quantity retains decimal precision', () {
    final b = CryptoBalance(
      asset: 'TOKEN',
      wallet: 'spot',
      quantity: amount('0.000000000000000001'),
      priceUsd: amount('0.0000000123456789'),
    );
    final roundTrip = CryptoBalance.fromJson(
      jsonDecode(jsonEncode(b.toJson())),
    );
    expect(roundTrip.quantity, b.quantity);
    expect(roundTrip.valueUsd, b.valueUsd);
  });
  test(
    'asset total adds crypto to stocks and ordinary assets exactly once',
    () {
      final value = AssetCalculator.calculateTotalAssets(
        [CashAccount(id: 'cash', currency: 'USD', balance: 100)],
        200,
        'USD',
        cryptoTotalValue: 1050,
      );
      expect(value, 1350);
    },
  );
  test(
    'overlapping wallet references prevent regular/lead double-counting',
    () async {
      reader.snapshot = CryptoSnapshot(
        accountId: 'main-uid',
        updatedAt: clock,
        accountReferences: ['usdm:shared-wallet'],
        balances: [],
        positions: [],
        wallets: [],
      );
      await store.add(await store.test(connection()));
      reader.snapshot = CryptoSnapshot(
        accountId: 'usdm:shared-wallet',
        updatedAt: clock,
        accountReferences: ['usdm:shared-wallet'],
        balances: [],
        positions: [],
        wallets: [],
      );
      await expectLater(
        store.test(connection(id: 'lead', key: 'other-key')),
        throwsA(
          isA<CryptoSyncException>().having((e) => e.code, 'code', 'duplicate'),
        ),
      );
    },
  );
  test(
    'lead market survives identification and secure storage; legacy lead defaults to Futures',
    () {
      const c = ExchangeConnection(
        id: 'spot',
        exchange: CryptoExchange.binance,
        name: 'Spot',
        apiKey: 'key',
        secret: 'secret',
        role: CryptoAccountRole.lead,
        leadMarket: CryptoLeadMarket.spot,
      );
      final identified = c.identified('spot:project-A', ['spot:project-A']);
      expect(identified.leadMarket, CryptoLeadMarket.spot);
      expect(
        ExchangeConnection.fromSecureJson(identified.toSecureJson()).leadMarket,
        CryptoLeadMarket.spot,
      );
      final legacy = identified.toSecureJson()..remove('leadMarket');
      expect(
        ExchangeConnection.fromSecureJson(legacy).leadMarket,
        CryptoLeadMarket.futures,
      );
    },
  );
}
