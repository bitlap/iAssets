import 'dart:convert';
import 'dart:io';

import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/crypto/crypto_models.dart';
import 'package:assets/services/crypto/crypto_store.dart';
import 'package:assets/services/crypto/exchange_client.dart';
import 'package:assets/services/privacy_service.dart';
import 'package:assets/services/pro_service.dart';
import 'package:assets/services/widget_snapshot_service.dart';
import 'package:assets/utils/currency_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'crypto/crypto_store_test.dart' as fixtures;
import 'support/core_fixtures.dart';
import 'support/pro_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.bitlap.assets/widget-snapshot');
  Map<Object?, Object?>? captured;

  setUp(() {
    captured = null;
    L10n.applyLanguage(L10n.langEn);
    PrivacyService.instance.hideAmounts.value = false;
    PrivacyService.instance.biometricLock.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'publish');
          captured = call.arguments as Map<Object?, Object?>;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PrivacyService.instance.hideAmounts.value = false;
    PrivacyService.instance.biometricLock.value = false;
  });

  Future<void> publish({double total = 150, bool incomplete = false}) =>
      WidgetSnapshotService.publish(
        total: total,
        stocks: 50,
        crypto: 20,
        other: 80,
        currency: 'USD',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1234567890000),
        incomplete: incomplete,
      );

  test('snapshot matches the asset summary values and data time', () async {
    await publish();
    expect(captured?['total'], '\$150.00');
    expect(captured?['stocks'], '\$50.00');
    expect(captured?['crypto'], '\$20.00');
    expect(captured?['other'], '\$80.00');
    expect(captured?['updatedAtMillis'], 1234567890000);
    expect(captured?['incomplete'], false);
  });

  test(
    'all 33 languages publish localized amounts and their language',
    () async {
      final previousLocale = L10n.deviceLocale;
      addTearDown(() {
        L10n.deviceLocale = previousLocale;
        L10n.applyLanguage(L10n.langZh);
      });
      for (final entry in L10n.languages.entries) {
        for (final followSystem in [false, true]) {
          L10n.deviceLocale = entry.value.locale;
          L10n.applyLanguage(followSystem ? L10n.langSystem : entry.key);
          await publish();
          expect(captured?['language'], entry.key);
          expect(captured?['total'], '\$${CurrencyUtil.formatCompact(150)}');
          expect(captured?['updatedAtMillis'], 1234567890000);
        }
      }
    },
  );

  test('privacy modes never send amounts to the widget extension', () async {
    for (final mode in ['hidden', 'locked']) {
      PrivacyService.instance.hideAmounts.value = mode == 'hidden';
      PrivacyService.instance.biometricLock.value = mode == 'locked';
      await publish();
      expect(captured?['hidden'], true);
      for (final key in ['total', 'stocks', 'crypto', 'other']) {
        expect(captured?[key], isNull);
      }
    }
  });

  test('missing conversion marks the total incomplete', () async {
    await publish(total: double.nan);
    expect(captured?['total'], isNull);
    expect(captured?['incomplete'], true);
    expect(captured?['stocks'], '\$50.00');
  });

  test(
    'a partial portfolio keeps available crypto and marks it incomplete',
    () async {
      await publish(incomplete: true);
      expect(captured?['crypto'], '\$20.00');
      expect(captured?['incomplete'], true);
    },
  );

  group('portfolio publication preserves cached crypto', () {
    late Directory directory;
    late DateTime clock;
    late fixtures.MemoryPersistence persistence;
    late fixtures.FakeReader reader;
    late CryptoStore store;

    setUpAll(() async {
      directory = await initializeTestStorage();
    });
    tearDownAll(() => directory.deleteSync(recursive: true));
    setUp(() async {
      await setTestPro();
      clock = DateTime.utc(2026, 11, 6, 12);
      persistence = fixtures.MemoryPersistence();
      reader = fixtures.FakeReader(fixtures.sample(clock));
      store = CryptoStore(
        reader: reader,
        persistence: persistence,
        clock: () => clock,
      );
    });
    tearDown(() => store.dispose());

    Future<void> publishPortfolio({
      CryptoStore? source,
      ProService? pro,
      String currency = 'USD',
    }) => WidgetSnapshotService.publishPortfolio(
      stocks: 50,
      other: 80,
      currency: currency,
      stockUpdatedAt: clock,
      cryptoStore: source ?? store,
      pro: pro ?? ProService.instance,
    );

    test(
      'network failure keeps crypto, total and the last success time',
      () async {
        await store.add(await store.test(fixtures.connection()));
        await publishPortfolio();
        final updatedAt = captured!['updatedAtMillis'];
        clock = clock.add(const Duration(minutes: 5));
        reader.fail = true;
        await store.refresh();
        await publishPortfolio();

        expect(captured!['crypto'], r'$1050.00');
        expect(captured!['total'], r'$1180.00');
        expect(captured!['updatedAtMillis'], updatedAt);
        expect(captured!['incomplete'], true);
      },
    );

    test(
      'public quote failures cannot replace a Binance valuation with zero',
      () async {
        var failQuotes = false;
        final client = ExchangeClient(
          clock: () => clock,
          client: MockClient((request) async {
            if (failQuotes &&
                [
                  '/v2/exchange-rates',
                  '/api/v3/ticker/price',
                ].contains(request.url.path)) {
              return http.Response('{}', 503);
            }
            final Object response = switch (request.url.path) {
              '/sapi/v1/account/apiRestrictions' => {'enableReading': true},
              '/api/v3/account' => {
                'uid': '123',
                'balances': [
                  {'asset': 'USDT', 'free': '1000', 'locked': '0'},
                ],
              },
              '/v2/exchange-rates' => {
                'data': {
                  'rates': {'USDT': '1'},
                },
              },
              '/api/v3/ticker/price' => [],
              '/fapi/v3/account' || '/dapi/v1/account' => {'assets': []},
              '/fapi/v3/balance' ||
              '/dapi/v1/balance' ||
              '/fapi/v3/positionRisk' ||
              '/dapi/v1/positionRisk' => [],
              _ => throw StateError('Unexpected request: ${request.url.path}'),
            };
            return http.Response(jsonEncode(response), 200);
          }),
        );
        final liveStore = CryptoStore(
          reader: client,
          persistence: persistence,
          clock: () => clock,
        );
        addTearDown(liveStore.dispose);
        await liveStore.add(await liveStore.test(fixtures.connection()));
        await publishPortfolio(source: liveStore);
        final updatedAt = captured!['updatedAtMillis'];

        clock = clock.add(const Duration(minutes: 5));
        failQuotes = true;
        await liveStore.refresh();
        expect(liveStore.totalUsd, amount('0'));
        expect(liveStore.incomplete, true);
        await publishPortfolio(source: liveStore);
        expect(captured!['crypto'], r'$1000.00');
        expect(captured!['total'], r'$1130.00');
        expect(captured!['updatedAtMillis'], updatedAt);
        expect(captured!['incomplete'], true);

        await publishPortfolio(source: liveStore, currency: 'CNY');
        expect(captured!['currency'], 'CNY');
        expect(captured!['crypto'], '¥7000.00');
        expect(captured!['total'], '¥7130.00');

        failQuotes = false;
        clock = clock.add(const Duration(minutes: 5));
        await liveStore.refresh();
        await publishPortfolio(source: liveStore);
        expect(captured!['updatedAtMillis'], clock.millisecondsSinceEpoch);
        expect(captured!['incomplete'], false);
      },
    );

    test(
      'losing only some quotes also retains the previous valuation',
      () async {
        await store.add(await store.test(fixtures.connection()));
        final updatedAt = clock.millisecondsSinceEpoch;
        clock = clock.add(const Duration(minutes: 5));
        reader.snapshot = CryptoSnapshot(
          accountId: '123',
          updatedAt: clock,
          balances: [
            CryptoBalance(
              asset: 'USDT',
              wallet: 'unified',
              quantity: amount('1000'),
            ),
            CryptoBalance(
              asset: 'USD',
              wallet: 'unified',
              quantity: amount('50'),
              priceUsd: amount('1'),
            ),
          ],
          positions: [],
          wallets: [
            CryptoWallet(
              name: 'unified',
              kind: CryptoWalletKind.unified,
              equityUsd: amount('50'),
            ),
          ],
        );
        await store.refresh();
        expect(store.totalUsd, amount('50'));
        await publishPortfolio();
        expect(captured!['crypto'], r'$1050.00');
        expect(captured!['total'], r'$1180.00');
        expect(captured!['updatedAtMillis'], updatedAt);
      },
    );

    test(
      'each connection retains its own value and oldest success time',
      () async {
        await store.add(await store.test(fixtures.connection()));
        reader.snapshot = fixtures.sample(clock, uid: '456', equity: '250');
        await store.add(
          await store.test(fixtures.connection(id: 'b', key: 'second-key')),
        );
        final updatedAt = clock.millisecondsSinceEpoch;
        clock = clock.add(const Duration(minutes: 5));
        reader.snapshot = fixtures.sample(clock, equity: '1100');
        await store.refresh();
        await publishPortfolio();
        expect(captured!['crypto'], r'$1350.00');
        expect(captured!['total'], r'$1480.00');
        expect(captured!['updatedAtMillis'], updatedAt);
        expect(captured!['incomplete'], true);
      },
    );

    test(
      'a confirmed empty account replaces the cached value with zero',
      () async {
        await store.add(await store.test(fixtures.connection()));
        clock = clock.add(const Duration(minutes: 5));
        reader.snapshot = CryptoSnapshot(
          accountId: '123',
          updatedAt: clock,
          balances: [],
          positions: [],
          wallets: [
            CryptoWallet(
              name: 'unified',
              kind: CryptoWalletKind.unified,
              equityUsd: amount('0'),
            ),
          ],
        );
        await store.refresh();
        await publishPortfolio();

        expect(captured!['crypto'], r'$0.00');
        expect(captured!['total'], r'$130.00');
        expect(captured!['updatedAtMillis'], clock.millisecondsSinceEpoch);
        expect(captured!['incomplete'], false);
      },
    );

    test(
      'relaunch without an account result leaves the shared snapshot untouched',
      () async {
        await store.add(await store.test(fixtures.connection()));
        await publishPortfolio();
        final previous = captured;
        final restored = CryptoStore(
          reader: reader,
          persistence: persistence,
          clock: () => clock,
        );
        addTearDown(restored.dispose);
        await publishPortfolio(source: restored);
        expect(identical(captured, previous), true);
        await restored.initialize();
        reader.fail = true;
        await restored.refresh();
        await publishPortfolio(source: restored);
        expect(identical(captured, previous), true);
      },
    );

    test(
      'unpriced holdings without a previous valuation are never published as zero',
      () async {
        reader.snapshot = CryptoSnapshot(
          accountId: '123',
          updatedAt: clock,
          balances: [
            CryptoBalance(
              asset: 'USDT',
              wallet: 'Spot',
              quantity: amount('1000'),
            ),
          ],
          positions: [],
          wallets: [
            CryptoWallet(
              name: 'Spot',
              kind: CryptoWalletKind.spot,
              equityUsd: amount('0'),
            ),
          ],
        );
        await store.add(await store.test(fixtures.connection()));
        await publishPortfolio();
        expect(captured, isNull);
      },
    );

    test(
      'a consistently unpriced token does not block new available values',
      () async {
        CryptoSnapshot partial(String value) => CryptoSnapshot(
          accountId: '123',
          updatedAt: clock,
          balances: [
            CryptoBalance(
              asset: 'USDT',
              wallet: 'Spot',
              quantity: amount(value),
              priceUsd: amount('1'),
            ),
            CryptoBalance(
              asset: 'UNKNOWN',
              wallet: 'Spot',
              quantity: amount('1'),
            ),
          ],
          positions: [],
          wallets: [
            CryptoWallet(
              name: 'Spot',
              kind: CryptoWalletKind.spot,
              equityUsd: amount(value),
            ),
          ],
        );
        reader.snapshot = partial('100');
        await store.add(await store.test(fixtures.connection()));
        await publishPortfolio();
        expect(captured!['crypto'], r'$100.00');

        clock = clock.add(const Duration(minutes: 5));
        reader.snapshot = partial('120');
        await store.refresh();
        await publishPortfolio();
        expect(captured!['crypto'], r'$120.00');
        expect(captured!['updatedAtMillis'], clock.millisecondsSinceEpoch);
        expect(captured!['incomplete'], true);
      },
    );

    test('removing a connection also removes its cached valuation', () async {
      await store.add(await store.test(fixtures.connection()));
      await store.remove('a');
      await publishPortfolio();
      expect(captured!['crypto'], r'$0.00');
      expect(captured!['total'], r'$130.00');
    });

    test(
      'pending or failed entitlement checks cannot publish a free zero balance',
      () async {
        final pending = ProService();
        addTearDown(pending.dispose);
        await publishPortfolio(pro: pending);
        expect(captured, isNull);
        pending.loading = false;
        pending.error = 'proVerificationError';
        await publishPortfolio(pro: pending);
        expect(captured, isNull);
        pending.error = null;
        await publishPortfolio(pro: pending);
        expect(captured, isNull);
      },
    );
  });
}
