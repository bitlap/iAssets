import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/config/app_colors.dart';
import 'package:assets/config/app_theme.dart';
import 'package:assets/widgets/asset/asset_header.dart';
import 'package:assets/widgets/stock/stock_header_card.dart';
import 'package:assets/widgets/common/app_ui.dart';

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
    testWidgets('summary cards show refresh progress in $brightness', (
      tester,
    ) async {
      AppColors.applyBrightness(brightness);
      Widget page(Widget child) => MaterialApp(
        theme: AppTheme.data(brightness),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

      Widget stock(bool refreshing) => StockHeaderCard(
        selectedCurrency: 'USD',
        totalAssets: 100,
        totalMarketValue: 100,
        totalCost: 80,
        totalProfit: 20,
        totalRealizedPL: 0,
        totalProfitPercent: 25,
        todayProfit: 1,
        todayProfitPercent: 1,
        totalAfterTaxDividends: 0,
        totalSellAmount: 0,
        isRefreshing: refreshing,
        onCurrencyChanged: (_) {},
      );

      await tester.pumpWidget(page(stock(false)));
      expect(find.byType(SummaryRefreshIndicator), findsNothing);
      await tester.pumpWidget(page(stock(true)));
      expect(find.byType(SummaryRefreshIndicator), findsOneWidget);
      final stockGradient =
          tester
                  .widget<SummaryCardFrame>(find.byType(SummaryCardFrame))
                  .gradient
              as LinearGradient;
      expect(
        stockGradient.colors.first.computeLuminance(),
        brightness == Brightness.light ? greaterThan(.7) : lessThan(.1),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .color,
        AppColors.accent,
      );
      expect(tester.takeException(), isNull);

      Widget asset(bool refreshing) => AssetHeader(
        totalAssets: 100,
        stockTotalValue: 50,
        currency: 'USD',
        onCurrencyTap: () {},
        totalsByType: const {},
        isRefreshing: refreshing,
      );

      await tester.pumpWidget(page(asset(false)));
      expect(find.byType(SummaryRefreshIndicator), findsNothing);
      await tester.pumpWidget(page(asset(true)));
      expect(find.byType(SummaryRefreshIndicator), findsOneWidget);
      final assetGradient =
          tester
                  .widget<SummaryCardFrame>(find.byType(SummaryCardFrame))
                  .gradient
              as LinearGradient;
      expect(
        assetGradient.colors.first.computeLuminance(),
        brightness == Brightness.light ? greaterThan(.7) : lessThan(.1),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
