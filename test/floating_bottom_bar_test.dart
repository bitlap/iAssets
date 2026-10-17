import 'package:assets/widgets/common/app_theme.dart';
import 'package:assets/widgets/common/floating_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'floating tabs work on a narrow phone: $brightness / $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0;
          var additions = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => Align(
                      alignment: Alignment.bottomCenter,
                      child: FloatingBottomBar(
                        selectedIndex: selected,
                        labels: const ['Stocks', 'Crypto', 'Assets', 'Add'],
                        onSelected: (index) => setState(() => selected = index),
                        onAdd: () => additions++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          if (scale == 1) {
            // Match the reference's compact 56-point capsule (plus bottom gap).
            expect(tester.getSize(find.byType(FloatingBottomBar)).height, 64);
            expect(tester.getSize(find.byType(ClipRRect).first).width, 216);
          }
          await tester.tap(find.text('Crypto'));
          await tester.pumpAndSettle();
          expect(selected, 1);
          final cryptoColor = tester
              .widget<Icon>(find.byIcon(Icons.currency_bitcoin_rounded))
              .color;
          expect(
            cryptoColor,
            brightness == Brightness.dark
                ? const Color(0xFF5B9CF6)
                : const Color(0xFF007AFF),
          );
          await tester.tap(find.byTooltip('Add'));
          await tester.pumpAndSettle();
          expect(additions, 1);
          expect(selected, 1);
          expect(find.byIcon(Icons.search), findsNothing);
          expect(tester.getSize(find.byTooltip('Add')), const Size(56, 56));
          expect(
            tester.getRect(find.byType(ClipRRect).first).right,
            lessThan(tester.getRect(find.byTooltip('Add')).left),
          );
          expect(
            tester.getCenter(find.byTooltip('Add')).dx,
            greaterThan(tester.getCenter(find.text('Assets')).dx),
          );
          for (final label in ['Stocks', 'Crypto', 'Assets']) {
            expect(
              tester.getSize(find.widgetWithText(InkWell, label)).height,
              greaterThanOrEqualTo(44),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
