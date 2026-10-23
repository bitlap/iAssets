import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/config/stock_config.dart';
import 'package:assets/utils/market_util.dart';
import 'package:assets/widgets/common/app_ui.dart';
import 'package:assets/widgets/stock/stock_style.dart';
import 'package:assets/widgets/stock/stock_list_header.dart';
import 'package:assets/widgets/stock/stock_card.dart';
import 'package:assets/models/stock_model.dart';

void main() {
  for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
    testWidgets(
      'horizontal market pills select and reset on a narrow screen in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        L10n.applyLanguage(language);
        String? market;
        String? sort;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => StockListHeader(
                  sortColumn: 'holdings',
                  sortAscending: false,
                  onColumnTap: (column) => sort = column,
                  filterMarket: market,
                  onMarketChanged: (value) => setState(() => market = value),
                  stockCount: 5,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final filters = find.descendant(
          of: find.byType(StockListHeader),
          matching: find.byType(ListView),
        );
        final filtersRect = tester.getRect(filters);
        expect(filtersRect.width, 288);
        expect(filtersRect.height, 32);
        expect(
          tester.widget<ListView>(filters).scrollDirection,
          Axis.horizontal,
        );
        expect(
          tester.getRect(find.text(StockConfig.stockMarketTitle)).bottom,
          lessThan(filtersRect.top),
        );
        expect(
          tester.getRect(find.text(StockConfig.homeHoldingHeader)).top,
          greaterThan(filtersRect.bottom),
        );
        for (final target in [
          MarketUtil.exchangeNASDAQ,
          MarketUtil.exchangeNYSE,
          MarketUtil.exchangeAMEX,
          MarketUtil.exchangeHK,
          MarketUtil.exchangeSH,
          MarketUtil.exchangeSZ,
          MarketUtil.exchangeBJ,
          MarketUtil.exchangeOTC,
          MarketUtil.exchangeBond,
          MarketUtil.exchangeIndex,
          MarketUtil.exchangeNEEQ,
          MarketUtil.exchangeJPX,
          MarketUtil.exchangeKRX,
          MarketUtil.exchangeLSE,
          MarketUtil.exchangeOTCBB,
          MarketUtil.customMarket,
        ]) {
          final option = find.text(MarketUtil.marketLabel(target));
          await tester.scrollUntilVisible(
            option,
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          final pill = tester.widget<FilterPill>(
            find.widgetWithText(FilterPill, MarketUtil.marketLabel(target)),
          );
          expect(pill.color, StockStyle.marketColor(target));
          await tester.tap(option.last);
          await tester.pumpAndSettle();
          expect(market, target);
          expect(
            tester
                .widget<FilterPill>(
                  find.widgetWithText(
                    FilterPill,
                    MarketUtil.marketLabel(target),
                  ),
                )
                .selected,
            isTrue,
          );
        }
        final allOption = find.text(
          MarketUtil.marketLabel(MarketUtil.searchAll),
        );
        await tester.scrollUntilVisible(
          allOption,
          -100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(allOption.last);
        await tester.pumpAndSettle();
        expect(market, isNull);
        await tester.tap(find.text(StockConfig.homeHoldingHeader));
        expect(sort, 'holdings');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('holdings header aligns with card contents at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      L10n.applyLanguage(L10n.langZh);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StockListHeader(
                  sortColumn: 'holdings',
                  sortAscending: false,
                  onColumnTap: (_) {},
                  filterMarket: null,
                  onMarketChanged: (_) {},
                  stockCount: 1,
                ),
                StockCard(
                  stock: StockModel(
                    symbol: 'GOOG',
                    companyName: '谷歌',
                    currentPrice: 336.91,
                    shares: 2,
                    totalValue: 673.82,
                    profitLossPercent: -3.32,
                    profitLossAmount: -23.17,
                    isPositive: false,
                    secid: '105.GOOG',
                  ),
                  isExpanded: false,
                  onExpandTap: () {},
                  onRecordTap: () {},
                  onMoreTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final headerLeft = tester
          .getTopLeft(find.text(StockConfig.homeHoldingHeader))
          .dx;
      expect(
        tester.getTopLeft(find.text('2.0000股')).dx,
        closeTo(headerLeft, .01),
      );
      expect(
        tester.getTopLeft(find.text('336.9100')).dx,
        closeTo(headerLeft, .01),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
