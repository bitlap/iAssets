import 'package:assets/l10n/l10n.dart';
import 'package:assets/services/pro_service.dart';
import 'package:assets/widgets/pro/pro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProService service;
  late Map<String, Object?> status;
  late List<String> purchased;
  var disposed = false;
  final purchaseButton = find.byKey(const ValueKey('pro-purchase'));

  setUp(() {
    disposed = false;
    L10n.applyLanguage(L10n.langEn);
    service = ProService(legacyCutoffDate: '2026-11-01T00:00:00Z');
    purchased = [];
    status = {
      'kind': 'free',
      'legacyVerified': true,
      'products': [
        {'id': ProService.monthly, 'price': r'US$1.49'},
        {'id': ProService.yearly, 'price': r'US$14.99'},
        {'id': ProService.lifetime, 'price': r'US$44.99'},
      ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProService.channel, (call) async {
          if (call.method == 'status') return status;
          if (call.method == 'purchase') {
            purchased.add((call.arguments as Map)['id'] as String);
            return 'cancelled';
          }
          return null;
        });
  });

  tearDown(() {
    if (!disposed) service.dispose();
    L10n.applyLanguage(L10n.langZh);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProService.channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: ProPage(service: service)));
    await tester.pumpAndSettle();
  }

  testWidgets('default yearly CTA purchases the displayed yearly product', (
    tester,
  ) async {
    await open(tester);
    final bar = find.ancestor(
      of: purchaseButton,
      matching: find.byType(SafeArea),
    );
    expect(
      find.descendant(of: bar, matching: find.textContaining(r'US$14.99')),
      findsOneWidget,
    );
    await tester.tap(purchaseButton);
    await tester.pumpAndSettle();
    expect(purchased, [ProService.yearly]);
    expect(service.isPro, isFalse);
  });

  for (final id in [ProService.monthly, ProService.lifetime]) {
    testWidgets('selecting $id changes the product actually purchased', (
      tester,
    ) async {
      await open(tester);
      final plan = find.byKey(ValueKey('pro-plan-$id'));
      await tester.scrollUntilVisible(plan, 250);
      await tester.tap(plan);
      await tester.pumpAndSettle();
      await tester.tap(purchaseButton);
      await tester.pumpAndSettle();
      expect(purchased, [id]);
    });
  }

  testWidgets('missing selected store product disables checkout', (
    tester,
  ) async {
    status['products'] = [
      {'id': ProService.monthly, 'price': r'US$1.49'},
    ];
    await open(tester);
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);
    expect(purchased, isEmpty);
    final monthly = find.byKey(
      const ValueKey('pro-plan-${ProService.monthly}'),
    );
    await tester.scrollUntilVisible(monthly, 250);
    await tester.tap(monthly);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNotNull);
  });

  testWidgets(
    'unverified acquisition disables checkout despite available products',
    (tester) async {
      status['legacyVerified'] = false;
      await open(tester);
      expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);
      expect(purchased, isEmpty);
    },
  );

  for (final confirm in [false, true]) {
    testWidgets('subscription to lifetime requires confirmation: $confirm', (
      tester,
    ) async {
      status['kind'] = 'subscription';
      status['expiresAt'] = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String();
      await open(tester);
      final upgrade = find.text(L10n.t('proUpgradeLifetime'));
      await tester.scrollUntilVisible(upgrade, 250);
      await tester.tap(upgrade);
      await tester.pumpAndSettle();
      await tester.tap(purchaseButton);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(purchased, isEmpty);
      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.text(L10n.t(confirm ? 'btnConfirm' : 'btnCancel')),
        ),
      );
      await tester.pumpAndSettle();
      expect(purchased, confirm ? [ProService.lifetime] : isEmpty);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      disposed = true;
    });
  }
}
