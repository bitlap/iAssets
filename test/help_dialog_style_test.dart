import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('help dialog uses the primary action in $brightness', (
      tester,
    ) async {
      final previousBrightness = AppColors.isDark
          ? Brightness.dark
          : Brightness.light;
      AppColors.applyBrightness(brightness);
      addTearDown(() => AppColors.applyBrightness(previousBrightness));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => InfoDialog.show(
                  context,
                  title: const Text('Help'),
                  content: const Text('Details'),
                  closeText: 'OK',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final actionContainers = tester.widgetList<Container>(
        find.ancestor(of: find.text('OK'), matching: find.byType(Container)),
      );
      expect(
        actionContainers.any(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).gradient != null,
        ),
        isTrue,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Help'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
