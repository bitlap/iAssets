import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/config/stock_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/app_theme.dart';
import 'package:assets/widgets/common/profit_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp/iassets-tests',
        );
  });

  for (final brightness in Brightness.values) {
    for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
      testWidgets(
        'chart arrow stays centered below the chart in $language / $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          L10n.applyLanguage(language);
          AppColors.applyBrightness(brightness);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
              home: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(28),
                  child: ProfitChartWidget(
                    totalProfit: 10,
                    targetCurrency: 'USD',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byType(TextButton);
          final rect = tester.getRect(button);
          expect(rect.width, 264);
          expect(rect.height, 14);
          final style = tester.widget<TextButton>(button).style!;
          expect(
            style.overlayColor!.resolve({WidgetState.pressed}),
            Colors.transparent,
          );
          expect(style.splashFactory, NoSplash.splashFactory);
          expect(style.enableFeedback, isFalse);
          expect(
            tester.getCenter(find.byIcon(Icons.expand_more)).dy,
            rect.center.dy,
          );
          expect(find.text(StockConfig.profitChartTitle), findsNothing);
          expect(find.text(StockConfig.profitExpand), findsNothing);
          expect(
            tester.getCenter(find.byIcon(Icons.expand_more)).dx,
            rect.center.dx,
          );
          expect(
            rect.bottom,
            tester.getRect(find.byType(ProfitChartWidget)).bottom,
          );
          // Both ends and the center of the invisible touch area remain usable.
          await tester.tapAt(Offset(rect.right - 4, rect.center.dy));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.expand_less), findsOneWidget);
          expect(find.text(StockConfig.profitRange7d), findsOneWidget);
          final expandedRect = tester.getRect(button);
          expect(expandedRect.top, greaterThan(rect.top));
          expect(
            expandedRect.bottom,
            tester.getRect(find.byType(ProfitChartWidget)).bottom,
          );
          expect(
            tester.getCenter(find.byIcon(Icons.expand_less)).dx,
            expandedRect.center.dx,
          );
          await tester.tapAt(expandedRect.center);
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(find.text(StockConfig.profitRange7d), findsNothing);
          await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.expand_less), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
