import 'dart:io';

import 'package:assets/config/stock_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/utils/trading_day_util.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/profit_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));
  tearDown(() => AppColors.applyMarketColorPreference(true));

  for (final redUp in [true, false]) {
    for (final dailyProfit in [-10.0, 10.0, 0.0]) {
      testWidgets(
        'chart color uses displayed profit $dailyProfit with redUp=$redUp',
        (tester) async {
          L10n.applyLanguage(L10n.langZh);
          AppColors.applyMarketColorPreference(redUp);
          final now = DateTime.now();
          final baseline = dailyProfit > 0 ? -100.0 : 100.0;
          await tester.runAsync(() async {
            await IcloudStorage.saveTodayBaseline(
              TradingDayUtil.tradingDayKey(now),
              baseline,
            );
            await IcloudStorage.saveIntradayProfitHistory([
              ProfitSnapshot(time: now, totalProfit: baseline),
              ProfitSnapshot(time: now, totalProfit: baseline + dailyProfit),
            ]);
            await IcloudStorage.saveDailyProfitHistory([
              ProfitSnapshot(
                time: now.subtract(const Duration(days: 3)),
                totalProfit: 10,
              ),
              ProfitSnapshot(
                time: now.subtract(const Duration(days: 2)),
                totalProfit: -25,
              ),
            ]);
          });
          await tester.runAsync(() async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: ProfitChartWidget(
                    totalProfit: baseline + dailyProfit,
                    targetCurrency: 'USD',
                  ),
                ),
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();

          Color chartColor(String painterName) {
            final paint = tester.widget<CustomPaint>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter.runtimeType.toString() == painterName,
              ),
            );
            final dynamic painter = paint.painter;
            return painter.color as Color;
          }

          final expected = dailyProfit == 0
              ? AppColors.textTertiary
              : dailyProfit > 0
              ? AppColors.rise
              : AppColors.fall;
          expect(chartColor('_MiniChartPainter'), expected);
          await tester.runAsync(() async {
            await tester.tap(find.byType(TextButton));
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
          expect(chartColor('_ProfitChartPainter'), expected);
          await tester.tap(find.text(StockConfig.profitRange7d));
          await tester.pumpAndSettle();
          expect(chartColor('_ProfitChartPainter'), AppColors.fall);
          await tester.tap(find.text(StockConfig.profitRangeToday));
          await tester.pumpAndSettle();
          expect(chartColor('_ProfitChartPainter'), expected);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
