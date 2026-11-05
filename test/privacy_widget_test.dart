import 'dart:async';

import 'package:assets/l10n/l10n.dart';
import 'package:assets/services/privacy_service.dart';
import 'package:assets/widgets/common/privacy_gate.dart';
import 'package:assets/widgets/common/sensitive_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    L10n.applyLanguage(L10n.langEn);
    PrivacyService.instance.hideAmounts.value = false;
    PrivacyService.instance.biometricLock.value = false;
  });

  tearDown(() {
    PrivacyService.instance.hideAmounts.value = false;
    PrivacyService.instance.biometricLock.value = false;
  });

  testWidgets('amount masking updates immediately across visible widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SensitiveText('\$12,345.67'),
              SensitiveText('+\$987.65'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('\$12,345.67'), findsOneWidget);
    expect(find.text('+\$987.65'), findsOneWidget);

    PrivacyService.instance.hideAmounts.value = true;
    await tester.pump();
    expect(find.text('••••'), findsNWidgets(2));
    expect(find.text('\$12,345.67'), findsNothing);
    expect(find.text('+\$987.65'), findsNothing);
  });

  testWidgets('inactive app keeps preview visible without biometric lock', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyGate(key: Key('gate'), child: Text('private balance')),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .descendant(
                  of: find.byKey(const Key('gate')),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isFalse,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byKey(const Key('gate')),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isFalse,
    );
    expect(find.text('private balance'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .descendant(
                  of: find.byKey(const Key('gate')),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isFalse,
    );
  });

  testWidgets('amount hiding alone keeps the app preview visible', (
    tester,
  ) async {
    PrivacyService.instance.hideAmounts.value = true;
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyGate(child: SensitiveText('\$12,345.67'))),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('••••'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
  });

  testWidgets('failed authentication leaves the app locked with retry', (
    tester,
  ) async {
    PrivacyService.instance.biometricLock.value = true;
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyGate(child: Text('private balance'))),
    );
    await tester.pump();
    expect(find.text('iAssets is locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('iAssets is locked'), findsOneWidget);
  });

  testWidgets('Face ID success before resumed unlocks on return', (
    tester,
  ) async {
    PrivacyService.instance.biometricLock.value = true;
    final authentication = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyGate(
          authenticate: (_) {
            calls++;
            return authentication.future;
          },
          child: const Text('private balance'),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    authentication.complete(true);
    await tester.pump();
    expect(find.text('iAssets is locked'), findsNothing);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('private balance'), findsOneWidget);
    expect(find.text('iAssets is locked'), findsNothing);
    expect(calls, 1);
  });

  testWidgets('Face ID result after resumed does not prompt again', (
    tester,
  ) async {
    PrivacyService.instance.biometricLock.value = true;
    final authentication = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyGate(
          authenticate: (_) {
            calls++;
            return authentication.future;
          },
          child: const Text('private balance'),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    authentication.complete(true);
    await tester.pump();
    expect(find.text('private balance'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('returning from background accepts Face ID before resumed', (
    tester,
  ) async {
    PrivacyService.instance.biometricLock.value = true;
    final first = Completer<bool>();
    final second = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyGate(
          authenticate: (_) => ++calls == 1 ? first.future : second.future,
          child: const Text('private balance'),
        ),
      ),
    );
    await tester.pump();
    first.complete(true);
    await tester.pump();
    expect(find.text('private balance'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    second.complete(true);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('private balance'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('backgrounding during Face ID invalidates that result', (
    tester,
  ) async {
    PrivacyService.instance.biometricLock.value = true;
    final interrupted = Completer<bool>();
    final retry = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyGate(
          authenticate: (_) => ++calls == 1 ? interrupted.future : retry.future,
          child: const Text('private balance'),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    interrupted.complete(true);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('iAssets is locked'), findsOneWidget);
    expect(calls, 2);

    retry.complete(true);
    await tester.pump();
    expect(find.text('private balance'), findsOneWidget);
  });
}
