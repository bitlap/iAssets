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

  testWidgets('inactive app covers content even without biometric lock', (
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
      isTrue,
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
      isTrue,
    );

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
}
