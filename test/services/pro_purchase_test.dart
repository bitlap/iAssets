import 'dart:async';

import 'package:assets/services/pro_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late ProService service;
  late Map<String, Object?> status;
  late List<MethodCall> calls;
  late DateTime now;
  Future<Object?> Function(MethodCall)? intercept;

  setUp(() {
    now = DateTime.utc(2026, 11);
    calls = [];
    intercept = null;
    status = {
      'kind': 'free',
      'legacyVerified': true,
      'products': <Object>[
        {'id': ProService.monthly, 'price': r'US$1.49'},
        {'id': ProService.yearly, 'price': '€12,99'},
        {'id': ProService.lifetime, 'price': r'HK$ 328.00'},
      ],
    };
    service = ProService(
      legacyCutoffDate: '2026-11-01T00:00:00Z',
      clock: () => now,
    );
    messenger.setMockMethodCallHandler(ProService.channel, (call) async {
      calls.add(call);
      if (intercept != null) return intercept!(call);
      return call.method == 'status' ? Map.of(status) : 'cancelled';
    });
  });

  tearDown(() {
    service.dispose();
    ProService.channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(ProService.channel, null);
  });

  List<MethodCall> purchases() =>
      calls.where((c) => c.method == 'purchase').toList();

  void subscribe(Duration remaining) {
    status['kind'] = 'subscription';
    status['expiresAt'] = now.add(remaining).toIso8601String();
  }

  for (final result in ['cancelled', 'pending', 'unavailable', 'success']) {
    test('$result alone cannot grant Pro without verified ownership', () async {
      intercept = (call) async => call.method == 'status' ? status : result;
      await service.refresh();
      expect(await service.purchase(ProService.yearly), result);
      expect(purchases().single.arguments, {'id': ProService.yearly});
      expect(service.isPro, isFalse);
      expect(service.busy, isFalse);
      expect(service.canPurchase, isTrue);
    });
  }

  for (final id in ProService.productIds) {
    test('verified purchase of $id unlocks correct entitlement', () async {
      intercept = (call) async {
        if (call.method == 'purchase') {
          if (id == ProService.lifetime) {
            status['kind'] = 'lifetime';
          } else {
            subscribe(Duration(days: id == ProService.monthly ? 30 : 365));
          }
          return 'success';
        }
        return status;
      };
      await service.refresh();
      expect(await service.purchase(id), 'success');
      expect(service.isPro, isTrue);
      expect(
        service.kind,
        id == ProService.lifetime ? 'lifetime' : 'subscription',
      );
      expect(purchases().single.arguments, {'id': id});
      expect(service.access.canAddStock(100), isTrue);
    });
  }

  test(
    'double tap and restore during purchase cannot start another operation',
    () async {
      final payment = Completer<String>();
      final paymentStarted = Completer<void>();
      intercept = (call) async {
        if (call.method == 'status') return status;
        if (call.method == 'purchase') {
          paymentStarted.complete();
          return payment.future;
        }
        return null;
      };
      await service.refresh();
      final first = service.purchase(ProService.yearly);
      await paymentStarted.future;
      expect(service.busy, isTrue);
      expect(await service.purchase(ProService.lifetime), 'unavailable');
      await service.restore();
      expect(purchases(), hasLength(1));
      expect(calls.where((c) => c.method == 'restore'), isEmpty);
      payment.complete('cancelled');
      expect(await first, 'cancelled');
      expect(service.busy, isFalse);
    },
  );

  test(
    'active subscriber cannot buy a second subscription but can buy lifetime',
    () async {
      subscribe(const Duration(days: 1));
      await service.refresh();
      for (final id in [ProService.monthly, ProService.yearly]) {
        expect(await service.purchase(id), 'owned');
      }
      expect(purchases(), isEmpty);
      expect(await service.purchase(ProService.lifetime), 'cancelled');
      expect(purchases().single.arguments, {'id': ProService.lifetime});
    },
  );

  test(
    'purchase preflight failure prevents charging despite cached eligibility',
    () async {
      await service.refresh();
      intercept = (_) async => throw PlatformException(code: 'offline');
      expect(await service.purchase(ProService.monthly), 'unavailable');
      expect(purchases(), isEmpty);
      expect(service.busy, isFalse);
      expect(service.isPro, isFalse);
    },
  );

  test(
    'lost acquisition verification prevents charging after preflight',
    () async {
      await service.refresh();
      status['legacyVerified'] = false;
      expect(await service.purchase(ProService.monthly), 'unavailable');
      expect(purchases(), isEmpty);
    },
  );

  test('native purchase exception releases lock and permits retry', () async {
    intercept = (call) async {
      if (call.method == 'status') return status;
      throw PlatformException(code: 'storekit');
    };
    await service.refresh();
    expect(await service.purchase(ProService.monthly), 'error');
    expect(service.busy, isFalse);
    expect(service.isPro, isFalse);
    intercept = null;
    expect(await service.purchase(ProService.monthly), 'cancelled');
    expect(purchases(), hasLength(2));
  });

  test(
    'restore failure preserves valid entitlement and always releases lock',
    () async {
      subscribe(const Duration(days: 1));
      await service.refresh();
      intercept = (call) async {
        if (call.method == 'restore') throw PlatformException(code: 'offline');
        return status;
      };
      await service.restore();
      expect(service.error, 'proVerificationError');
      expect(service.busy, isFalse);
      expect(service.isPro, isTrue);
      intercept = null;
      status['kind'] = 'free';
      status.remove('expiresAt');
      await service.restore();
      expect(service.isPro, isFalse);
      expect(service.error, isNull);
    },
  );

  test(
    'offline subscription retains access only before exact expiry',
    () async {
      subscribe(const Duration(hours: 1));
      await service.refresh();
      intercept = (_) async => throw PlatformException(code: 'offline');
      await service.refresh();
      expect(service.isPro, isTrue);
      now = now.add(const Duration(hours: 1));
      expect(service.isPro, isFalse);
      expect(service.kind, 'free');
      expect(service.hasSubscription, isFalse);
      expect(() => service.requirePro(), throwsA(isA<ProRequiredException>()));
    },
  );

  test(
    'renewal replaces expiry timer instead of locking at previous expiry',
    () async {
      subscribe(const Duration(hours: 1));
      await service.refresh();
      subscribe(const Duration(days: 31));
      await service.refresh();
      now = now.add(const Duration(hours: 2));
      expect(service.isPro, isTrue);
      now = now.add(const Duration(days: 32));
      expect(service.isPro, isFalse);
    },
  );

  test(
    'unknown entitlement and invalid subscription date never unlock Pro',
    () async {
      for (final kind in ['premium', 'subscription']) {
        status['kind'] = kind;
        status['expiresAt'] = 'not-a-date';
        await service.refresh();
        expect(service.isPro, isFalse);
      }
      expect(await service.purchase('unknown.product'), 'unavailable');
      expect(purchases(), isEmpty);
    },
  );

  test(
    'catalog accepts known products only and preserves localized price strings',
    () async {
      (status['products'] as List).addAll(<Object>[
        {'id': 'unknown.product', 'price': '¥1'},
        {'id': ProService.monthly, 'price': 10},
        'malformed',
      ]);
      await service.refresh();
      expect(service.products.map((p) => p.id), ProService.productIds);
      expect(service.products.map((p) => p.price), [
        r'US$1.49',
        '€12,99',
        r'HK$ 328.00',
      ]);
      expect(calls.first.arguments, {'legacyCutoff': '2026-11-01T00:00:00Z'});
    },
  );

  test('invalid cutoff or privacy URL never reaches native purchase', () async {
    for (final cutoff in ['', 'invalid', '2026-11-01T00:00:00']) {
      final invalid = ProService(legacyCutoffDate: cutoff);
      await invalid.refresh();
      expect(await invalid.purchase(ProService.yearly), 'unavailable');
      invalid.dispose();
    }
    for (final url in ['', 'http://example.com/privacy', 'https:///privacy']) {
      final invalid = ProService(
        legacyCutoffDate: '2026-11-01T00:00:00Z',
        privacyPolicyUrl: url,
      );
      await invalid.refresh();
      expect(await invalid.purchase(ProService.yearly), 'unavailable');
      invalid.dispose();
    }
    expect(purchases(), isEmpty);
  });

  test(
    'transaction update queued during refresh fetches the newer entitlement',
    () async {
      await service.initialize();
      final stale = Completer<Map<String, Object?>>();
      var statusCalls = 0;
      intercept = (call) async {
        if (call.method != 'status') return null;
        statusCalls++;
        return statusCalls == 1 ? stale.future : status;
      };
      final refresh = service.refresh();
      final event = Completer<void>();
      messenger.handlePlatformMessage(
        ProService.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('changed'),
        ),
        (_) => event.complete(),
      );
      status['kind'] = 'lifetime';
      stale.complete({'kind': 'free', 'legacyVerified': true});
      await refresh;
      await event.future;
      expect(statusCalls, 2);
      expect(service.kind, 'lifetime');
    },
  );
}
