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
      expect(
        tester
            .getRect(
              find.textContaining('${L10n.t('exchangeRateStatus')}:').first,
            )
            .top,
        greaterThan(tester.getRect(find.byType(ProfitChartWidget)).bottom),
      );
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
      expect(
        tester
            .getRect(
              find.textContaining('${L10n.t('exchangeRateStatus')}:').first,
            )
            .top,
        greaterThan(tester.getRect(find.text(StockConfig.tabStock)).bottom),
      );
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

  testWidgets('today profit icons and amount follow the market color setting', (
    tester,
  ) async {
    AppColors.applyBrightness(Brightness.light);
    AppColors.applyMarketColorPreference(true);
    addTearDown(() => AppColors.applyMarketColorPreference(true));

    double todayProfit = 10;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: AppColors.marketColorNotifier,
            builder: (context, _, _) => StockHeaderCard(
              selectedCurrency: 'USD',
              totalAssets: 100,
              totalMarketValue: 100,
              totalCost: 80,
              totalProfit: 20,
              totalRealizedPL: 0,
              totalProfitPercent: 25,
              todayProfit: todayProfit,
              todayProfitPercent: todayProfit,
              totalAfterTaxDividends: 0,
              totalSellAmount: 0,
              onCurrencyChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    Color? todayIconColor() =>
        tester.widget<Icon>(find.byIcon(Icons.today)).color;
    Color? todayHelpColor() => tester
        .widget<Icon>(
          find.descendant(
            of: find.byTooltip(StockConfig.assetTodayProfitHelp),
            matching: find.byIcon(Icons.help_outline),
          ),
        )
        .color;

    expect(todayIconColor(), AppColors.danger);
    expect(todayHelpColor(), AppColors.danger);
    expect(
      tester.widget<Text>(find.text('+10.00')).style?.color,
      AppColors.danger,
    );

    AppColors.applyMarketColorPreference(false);
    await tester.pump();
    expect(todayIconColor(), AppColors.success);
    expect(todayHelpColor(), AppColors.success);
    expect(
      tester.widget<Text>(find.text('+10.00')).style?.color,
      AppColors.success,
    );

    todayProfit = -10;
    AppColors.applyMarketColorPreference(true);
    await tester.pump();
    expect(todayIconColor(), AppColors.success);
    expect(todayHelpColor(), AppColors.success);
    expect(
      tester.widget<Text>(find.text('-10.00')).style?.color,
      AppColors.success,
    );
  });

  for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
    testWidgets('asset formulas fit a narrow screen in $language', (
      tester,
    ) async {
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
            totalAssets: 90,
            totalMarketValue: 90,
            totalCost: 40,
            totalProfit: 50,
            totalRealizedPL: 0,
            totalProfitPercent: 50,
            todayProfit: 0,
            todayProfitPercent: 0,
            totalAfterTaxDividends: 0,
            totalSellAmount: 60,
            onCurrencyChanged: (_) {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.help_outline).first);
      await tester.pumpAndSettle();
      expect(find.text(StockConfig.assetTotalAssetsHelp), findsOneWidget);
      expect(find.text(StockConfig.assetTotalSellAmount), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(
        tester.element(find.text(StockConfig.assetTotalAssetsHelp)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.help_outline).at(1));
      await tester.pumpAndSettle();
      expect(find.text(StockConfig.assetTotalProfitHelp), findsOneWidget);
      expect(find.text(StockConfig.assetFloatProfitLabel), findsOneWidget);
      expect(find.text(StockConfig.assetTotalRealizedPL), findsOneWidget);
      Navigator.of(
        tester.element(find.text(StockConfig.assetTotalProfitHelp)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        page(
          AssetHeader(
            totalAssets: 150,
            stockTotalValue: 90,
            currency: 'USD',
            onCurrencyTap: () {},
            totalsByType: const {},
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.help_outline).first);
      await tester.pumpAndSettle();
      expect(find.text(StockConfig.assetOverallAssetsHelp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

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
          tester.getRect(find.text('-12.34%')).left,
          closeTo(tester.getRect(find.byIcon(Icons.today)).left, .01),
        );
        final today = tester.getRect(find.text(StockConfig.assetTodayProfit));
        expect(
          today.top,
          closeTo(
            tester.getRect(find.text(StockConfig.assetTotalProfit)).top,
            .01,
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

  test('refresh subtitle omits seconds', () {
    expect(
      formatRefreshTime(DateTime(2026, 11, 4, 9, 7, 59)),
      '2026-11-04 09:07',
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('stock summary stays readable on iPad / $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      L10n.applyLanguage(L10n.langEn);
      AppColors.applyBrightness(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.data(brightness),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: StockHeaderCard(
                  selectedCurrency: 'USD',
                  totalAssets: 1000,
                  totalMarketValue: 1000,
                  totalCost: 700,
                  totalProfit: 300,
                  totalRealizedPL: 100,
                  totalProfitPercent: 30,
                  todayProfit: -12,
                  todayProfitPercent: -1.2,
                  totalAfterTaxDividends: 20,
                  totalSellAmount: 300,
                  onCurrencyChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(StockConfig.assetTotalAssets), findsOneWidget);
      expect(find.text(StockConfig.assetTotalProfit), findsOneWidget);
      expect(find.text(StockConfig.assetTodayProfit), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
