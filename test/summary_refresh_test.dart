import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/app_theme.dart';
import 'package:assets/widgets/asset/asset_header.dart';
import 'package:assets/widgets/stock/stock_header_card.dart';
import 'package:assets/widgets/common/app_ui.dart';
import 'package:assets/config/stock_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/widgets/common/currency_selector.dart';
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
    testWidgets('summary cards omit internal refresh bars in $brightness', (
      tester,
    ) async {
      AppColors.applyBrightness(brightness);
      Widget page(Widget child) => MaterialApp(
        theme: AppTheme.data(brightness),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

      Widget stock() => StockHeaderCard(
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
        onCurrencyChanged: (_) {},
      );

      await tester.pumpWidget(page(stock()));
      final stockGradient =
          tester
                  .widget<SummaryCardFrame>(find.byType(SummaryCardFrame))
                  .gradient
              as LinearGradient;
      expect(
        stockGradient.colors.first.computeLuminance(),
        brightness == Brightness.light ? greaterThan(.7) : lessThan(.1),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      Widget asset() => AssetHeader(
        totalAssets: 100,
        stockTotalValue: 50,
        currency: 'USD',
        onCurrencyTap: () {},
        totalsByType: const {},
      );

      await tester.pumpWidget(page(asset()));
      expect(find.byType(LinearProgressIndicator), findsNothing);
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
  for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
    testWidgets(
      'daily performance does not shift the asset total in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        L10n.applyLanguage(language);
        Widget page(Widget child) => MaterialApp(
          theme: AppTheme.data(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );
        await tester.pumpWidget(
          page(
            StockHeaderCard(
              selectedCurrency: 'USD',
              totalAssets: 100,
              totalMarketValue: 100,
              totalCost: 80,
              totalProfit: 20,
              totalRealizedPL: 0,
              totalProfitPercent: 25,
              todayProfit: -123456.78,
              todayProfitPercent: -12.34,
              totalAfterTaxDividends: 0,
              totalSellAmount: 0,
              onCurrencyChanged: (_) {},
            ),
          ),
        );
        final stockAmount = tester.getRect(find.text(r'$100.00'));
        final currency = tester.getRect(find.byType(CurrencySelectorButton));
        expect(stockAmount.top - currency.bottom, inInclusiveRange(4, 5));
        expect(
          tester.getRect(find.text('-12.34%')).right,
          closeTo(currency.right, .01),
        );
        final today = tester.getRect(find.text(StockConfig.assetTodayProfit));
        expect(
          today.top,
          greaterThan(
            tester.getRect(find.text(StockConfig.assetTotalProfit)).bottom,
          ),
        );
        expect(
          today.bottom,
          lessThan(tester.getRect(find.byType(ProfitChartWidget)).top),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          page(
            AssetHeader(
              totalAssets: 100,
              stockTotalValue: 100,
              currency: 'USD',
              onCurrencyTap: () {},
              totalsByType: const {},
            ),
          ),
        );
        expect(
          tester.getRect(find.text(r'$100.00')).top,
          closeTo(stockAmount.top, .01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
