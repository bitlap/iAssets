import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/calculator_models.dart';
import 'package:assets/widgets/dividend/dividend_header.dart';
import 'package:assets/widgets/dividend/dividend_stock_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in [L10n.langZh, L10n.langZhHant, L10n.langEn]) {
    for (final brightness in Brightness.values) {
      testWidgets('dividend copy fits narrow $language / $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        L10n.applyLanguage(language);
        GlobalDividendStockItem item(int recordCount) =>
            GlobalDividendStockItem(
              symbol: 'ABC',
              companyName: 'Example Company',
              marketType: 'US',
              currency: 'USD',
              currentShares: 10,
              currentCost: 100,
              currentMarketValue: 120,
              totalAfterTaxDividends: 9,
              trailingAfterTaxDividends: 9,
              costDividendYield: 9,
              marketDividendYield: 7.5,
              latestDividendDate: DateTime(2026, 10, 1),
              recordCount: recordCount,
              records: const [],
            );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DividendHeader(
                        overview: const GlobalDividendOverview(
                          totalAfterTaxDividends: 9,
                          trailingAfterTaxDividends: 9,
                          totalCurrentCost: 100,
                          totalCurrentMarketValue: 120,
                          costDividendYield: 9,
                          marketDividendYield: 7.5,
                        ),
                        currency: 'USD',
                      ),
                      DividendStockSection(
                        item: item(1),
                        isExpanded: false,
                        onTap: () {},
                      ),
                      DividendStockSection(
                        item: item(2),
                        isExpanded: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        if (language == L10n.langEn) {
          expect(find.text('ABC · 1 dividend record'), findsOneWidget);
          expect(find.text('ABC · 2 dividend records'), findsOneWidget);
          expect(find.text('Yield on Cost'), findsNWidgets(3));
          expect(find.text('Trailing Dividend Yield'), findsNWidgets(3));
        }
      });
    }
  }
}
