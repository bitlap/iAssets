import 'package:assets/l10n/l10n.dart';
import 'package:assets/services/privacy_service.dart';
import 'package:assets/services/widget_snapshot_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('preserves the last balance until crypto and entitlement are ready', () {
    bool ready({
      bool entitlementLoading = false,
      bool entitlementFailed = false,
      bool isPro = true,
      bool cryptoInitialized = true,
      bool cryptoSyncing = false,
      bool cryptoIncomplete = false,
    }) => WidgetSnapshotService.isPortfolioReady(
      entitlementLoading: entitlementLoading,
      entitlementFailed: entitlementFailed,
      isPro: isPro,
      cryptoInitialized: cryptoInitialized,
      cryptoSyncing: cryptoSyncing,
      cryptoIncomplete: cryptoIncomplete,
    );

    expect(ready(entitlementLoading: true), isFalse);
    expect(ready(entitlementFailed: true), isFalse);
    expect(ready(cryptoInitialized: false), isFalse);
    expect(ready(cryptoSyncing: true), isFalse);
    expect(ready(cryptoIncomplete: true), isFalse);
    expect(ready(), isTrue);
    expect(ready(isPro: false, cryptoInitialized: false), isTrue);
  });

  test(
    'headless refresh cannot replace crypto with an empty connection list',
    () {
      bool ready(int count, {bool incomplete = false}) =>
          WidgetSnapshotService.isBackgroundPortfolioReady(
            entitlementLoading: false,
            entitlementFailed: false,
            isPro: true,
            cryptoInitialized: true,
            cryptoSyncing: false,
            cryptoIncomplete: incomplete,
            cryptoConnectionCount: count,
          );

      expect(ready(0), isFalse);
      expect(ready(1, incomplete: true), isFalse);
      expect(ready(1), isTrue);
    },
  );
}
