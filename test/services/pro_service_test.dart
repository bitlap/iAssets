import 'package:assets/models/asset_account.dart';
import 'package:assets/services/pro_service.dart';
import 'package:assets/services/backup_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/pro_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, Object?> snapshot;
  late List<String> calls;
  late ProService service;
  var failStatus = false;

  setUp(() {
    failStatus = false;
    calls = [];
    snapshot = {
      'kind': 'free',
      'legacyVerified': true,
      'products': [
        {'id': ProService.monthly, 'price': '¥10.00'},
        {'id': ProService.yearly, 'price': '¥99.00'},
        {'id': ProService.lifetime, 'price': '¥299.00'},
      ],
    };
    messenger.setMockMethodCallHandler(ProService.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'status') {
        if (failStatus) throw PlatformException(code: 'offline');
        return snapshot;
      }
      if (call.method == 'purchase') {
        snapshot['kind'] = 'lifetime';
        return 'success';
      }
      return null;
    });
    service = ProService(
      legacyCutoffDate: '2026-11-01T00:00:00Z',
      privacyPolicyUrl: 'https://example.com/privacy',
    );
  });
  tearDown(() => service.dispose());

  test('free stock limit counts all holdings, Pro has no limit', () {
    const free = ProAccess();
    expect(free.canAddStock(2), isTrue);
    expect(free.canAddStock(3), isFalse);
    expect(free.canAddStock(8), isFalse);
    expect(const ProAccess(isPro: true).canAddStock(100), isTrue);
  });

  test(
    'free assets allow three types with three records each independently',
    () {
      final assets = <AssetBase>[
        CashAccount(id: 'c1'),
        CashAccount(id: 'c2'),
        CashAccount(id: 'c3'),
        CurrentAccount(id: 'b1'),
        TimeDeposit(id: 't1'),
      ];
      const free = ProAccess();
      expect(free.canAddAsset(assets, AssetType.cash), isFalse);
      expect(free.canAddAsset(assets, AssetType.current), isTrue);
      expect(free.canAddAsset(assets, AssetType.wealthProduct), isFalse);
      expect(
        free.canAddAsset(
          assets.where((a) => a.type != AssetType.timeDeposit),
          AssetType.wealthProduct,
        ),
        isTrue,
      );
      expect(
        const ProAccess(isPro: true).canAddAsset(assets, AssetType.cash),
        isTrue,
      );
      expect(assets.length, 5, reason: 'Quota checks do not truncate data');
    },
  );

  test('verified legacy owner is lifetime Pro without a purchase', () async {
    snapshot['kind'] = 'legacy';
    await service.refresh();
    expect(service.isPro, isTrue);
    expect(service.kind, 'legacy');
    expect(service.canPurchase, isFalse);
    await service.purchase(ProService.lifetime);
    expect(calls, isNot(contains('purchase')));
  });

  test(
    'unverified acquisition or missing release config prevents charging',
    () async {
      snapshot['legacyVerified'] = false;
      await service.refresh();
      expect(await service.purchase(ProService.monthly), 'unavailable');
      expect(calls, isNot(contains('purchase')));
      final unconfigured = ProService();
      await unconfigured.refresh();
      expect(unconfigured.canPurchase, isFalse);
      unconfigured.dispose();
    },
  );

  test(
    'store prices are used; purchase and restore refresh ownership',
    () async {
      await service.refresh();
      expect(service.products.map((p) => p.price), [
        '¥10.00',
        '¥99.00',
        '¥299.00',
      ]);
      expect(await service.purchase(ProService.lifetime), 'success');
      expect(service.kind, 'lifetime');
      snapshot['kind'] =
          'free'; // Refund/revocation reflected in verified snapshot.
      await service.restore();
      expect(calls, contains('restore'));
      expect(service.isPro, isFalse);
    },
  );

  test('rechecks ownership immediately before purchase', () async {
    await service.refresh();
    snapshot['kind'] = 'legacy';
    expect(await service.purchase(ProService.yearly), 'owned');
    expect(calls, isNot(contains('purchase')));
  });

  test('subscription expiry and revoked access do not grant Pro', () async {
    snapshot['kind'] = 'subscription';
    snapshot['expiresAt'] = DateTime.now()
        .subtract(const Duration(seconds: 1))
        .toIso8601String();
    await service.refresh();
    expect(service.isPro, isFalse);
    snapshot['expiresAt'] = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String();
    await service.refresh();
    expect(service.isPro, isTrue);
    snapshot['kind'] = 'free';
    snapshot.remove('expiresAt');
    await service.refresh();
    expect(service.isPro, isFalse);
  });

  testWidgets('subscription timer locks features when paid period ends', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11);
    service.dispose();
    service = ProService(clock: () => now);
    snapshot['kind'] = 'subscription';
    snapshot['expiresAt'] = now
        .add(const Duration(seconds: 2))
        .toIso8601String();
    await service.refresh();
    expect(service.isPro, isTrue);
    var notifications = 0;
    service.addListener(() => notifications++);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(service.isPro, isFalse);
    expect(notifications, greaterThan(0));
  });

  test(
    'offline verification cannot create Pro or trigger a purchase',
    () async {
      failStatus = true;
      await service.refresh();
      expect(service.isPro, isFalse);
      expect(service.error, 'proVerificationError');
      expect(await service.purchase(ProService.monthly), 'unavailable');
      expect(calls, isNot(contains('purchase')));
    },
  );

  test('free import/export is denied before touching storage', () async {
    await setTestPro(enabled: false);
    await expectLater(
      BackupService.exportAll(),
      throwsA(isA<ProRequiredException>()),
    );
    await expectLater(
      BackupService.exportToFile('/not-written.json'),
      throwsA(isA<ProRequiredException>()),
    );
    await expectLater(
      BackupService.importAll({
        'version': 1,
        'settings': {'pro': true},
      }),
      throwsA(isA<ProRequiredException>()),
    );
    await expectLater(
      BackupService.rollbackFromBackup(),
      throwsA(isA<ProRequiredException>()),
    );
  });
}
