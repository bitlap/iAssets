import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/app_theme.dart';
import 'package:assets/widgets/stock/stock_card.dart';

void main() {
  final stock = StockModel(
    symbol: 'GOOG',
    companyName: '谷歌-C',
    currentPrice: 336.91,
    shares: 2,
    totalValue: 673.82,
    profitLossPercent: -3.32,
    profitLossAmount: -23.17,
    isPositive: false,
    secid: '105.GOOG',
  );
  final records = [
    for (final price in [348.0, 355.0, 342.0])
      OperationRecord(
        date: DateTime(2026, 10, 1),
        type: StockConfig.opBuyType,
        description: '',
        amount: price,
        shares: 1,
      ),
    OperationRecord(
      date: DateTime(2026, 10, 2),
      type: StockConfig.opSellType,
      description: '',
      amount: 348.01,
      shares: 1,
    ),
  ];
  for (final brightness in Brightness.values) {
    for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
      testWidgets(
        'grouped stock details fit a narrow $language / $brightness card',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          L10n.applyLanguage(language);
          AppColors.applyBrightness(brightness);
          var expanded = true;
          var recordsTapped = false;
          var moreTapped = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setState) => SingleChildScrollView(
                      child: StockCard(
                        stock: stock,
                        isExpanded: expanded,
                        operationRecords: records,
                        onExpandTap: () => setState(() => expanded = !expanded),
                        onRecordTap: () => recordsTapped = true,
                        onMoreTap: () => moreTapped = true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('696.99'), findsOneWidget);
          expect(find.text(StockConfig.stockDetailTotalCost), findsOneWidget);
          expect(tester.widget<Text>(find.text('696.99')).style!.fontSize, 16);
          expect(
            tester.widget<Text>(find.text('348.4950')).style!.fontSize,
            16,
          );

          expect(find.text('348.4950'), findsOneWidget);
          expect(find.text('342.0000'), findsOneWidget);
          expect(find.text('355.0000'), findsOneWidget);
          expect(
            find.text('${StockConfig.opBuy} 3 ${AppConfig.suffixCount}'),
            findsOneWidget,
          );
          expect(
            find.text('${StockConfig.opSell} 1 ${AppConfig.suffixCount}'),
            findsOneWidget,
          );
          final cost = tester.getRect(find.text('696.99'));
          final average = tester.getRect(find.text('348.4950'));
          final low = tester.getRect(find.text('342.0000'));
          final high = tester.getRect(find.text('355.0000'));
          expect(cost.top, closeTo(average.top, .01));
          expect(low.top, closeTo(high.top, .01));
          expect(low.top, greaterThan(cost.bottom));
          expect(cost.left, closeTo(low.left, .01));
          expect(average.left, closeTo(high.left, .01));
          expect(
            tester.getRect(find.text(StockConfig.stockDetailTotalCost)).left,
            closeTo(
              tester.getRect(find.text(StockConfig.stockDetailMinPrice)).left,
              .01,
            ),
          );
          expect(
            tester.getRect(find.text(StockConfig.stockDetailAvgPrice)).left,
            closeTo(
              tester.getRect(find.text(StockConfig.stockDetailMaxPrice)).left,
              .01,
            ),
          );
          expect(
            tester
                .getRect(find.text(StockConfig.stockDetailTradingActivity))
                .top,
            greaterThan(low.bottom),
          );
          expect(
            tester.widget<Text>(find.text('696.99')).style!.color,
            AppColors.textPrimary,
          );
          final background = find
              .ancestor(
                of: find.text('342.0000'),
                matching: find.byType(Container),
              )
              .first;
          expect(
            (tester.widget<Container>(background).decoration as BoxDecoration)
                .color,
            AppColors.surfaceMuted,
          );
          expect(
            tester
                .getRect(
                  find.text('${StockConfig.opSell} 1 ${AppConfig.suffixCount}'),
                )
                .right,
            closeTo(tester.getRect(background).right, .01),
          );
          expect(
            tester
                .getRect(find.text(StockConfig.stockDetailTradingActivity))
                .left,
            closeTo(tester.getRect(background).left, .01),
          );
          final labelLuminance = AppColors.textSecondary.computeLuminance();
          final backgroundLuminance = AppColors.surfaceMuted.computeLuminance();
          final contrast = labelLuminance > backgroundLuminance
              ? (labelLuminance + .05) / (backgroundLuminance + .05)
              : (backgroundLuminance + .05) / (labelLuminance + .05);
          expect(contrast, greaterThanOrEqualTo(4.5));
          await tester.tap(find.text(StockConfig.stockRecord));
          await tester.tap(find.text(StockConfig.stockMore));
          expect(recordsTapped, isTrue);
          expect(moreTapped, isTrue);
          await tester.tap(find.text('GOOG'));
          await tester.pumpAndSettle();
          expect(
            find.text(StockConfig.stockDetailTradingActivity),
            findsNothing,
          );
          await tester.tap(find.text('GOOG'));
          await tester.pumpAndSettle();
          expect(find.text('696.99'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
