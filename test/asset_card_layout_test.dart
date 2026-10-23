import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assets/config/asset_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/widgets/asset/asset_card.dart';
import 'package:assets/widgets/asset/asset_style.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:assets/widgets/common/app_theme.dart';

void main() {
  test('asset name color stays stable across sorting and language changes', () {
    AppColors.applyBrightness(Brightness.light);
    final color = AssetStyle.nameColor('日常备用金');
    for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
      L10n.applyLanguage(language);
      AssetStyle.nameColor('旅行基金');
      expect(AssetStyle.nameColor(' 日常备用金 '), color);
      expect(AssetStyle.nameColor('Salary'), AssetStyle.nameColor('salary'));
    }
    expect(color, const Color(0xFF2B7B71));
    AppColors.applyBrightness(Brightness.dark);
    expect(AssetStyle.nameColor('日常备用金'), const Color(0xFF84C8B9));
  });

  for (final brightness in Brightness.values) {
    for (final language in [L10n.langZh, L10n.langEn, L10n.langZhHant]) {
      testWidgets(
        'asset card fits long names and amounts in $language / $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          L10n.applyLanguage(language);
          AppColors.applyBrightness(brightness);
          var edits = 0;
          final date = DateTime(2026, 10, 23, 15, 40);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.data(brightness),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AssetCardFrame(
                        icon: Icons.savings,
                        name: language == L10n.langEn
                            ? 'Long-term savings account for family travel and education'
                            : '招商银行家庭教育与旅行三年定期存款账户',
                        colorSeed: '家庭储蓄',
                        currency: 'CHF',
                        amount: 'CHF 123,456,789.00',
                        detail: AssetConfig.daysRemaining.replaceAll(
                          '{days}',
                          '186',
                        ),
                        createdAt: date,
                        updatedAt: date,
                        onTap: () => edits++,
                        leading: const SizedBox(
                          width: 28,
                          child: Icon(Icons.drag_indicator),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              AssetConfig.createdLabel.replaceAll('{date}', '2026-10-23 15:40'),
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              AssetConfig.updatedLabel.replaceAll('{date}', '2026-10-23 15:40'),
            ),
            findsOneWidget,
          );
          final amount = tester.getRect(find.text('CHF 123,456,789.00'));
          final card = tester.getRect(find.byType(AssetCardFrame));
          expect(amount.left, greaterThanOrEqualTo(card.left));
          expect(amount.right, lessThanOrEqualTo(card.right));
          await tester.tap(find.text('CHF 123,456,789.00'));
          expect(edits, 1);
        },
      );
    }
  }
}
