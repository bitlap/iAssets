import 'dart:io';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/utils/currency_util.dart';
import 'package:assets/utils/profit_util.dart';
import 'package:assets/widgets/common/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(() {
    L10n.applyLanguage(L10n.langEn);
    AppColors.applyBrightness(Brightness.light);
    AppColors.applyMarketColorPreference(true);
  });

  test('currency conversion uses USD as bridge in both directions', () {
    expect(CurrencyUtil.convertCurrency(700, 'CNY', 'USD'), 100);
    expect(CurrencyUtil.convertCurrency(700, 'CNY', 'HKD'), 800);
    expect(CurrencyUtil.convertCurrency(800, 'HKD', 'CNY'), 700);
    expect(CurrencyUtil.convertCurrency(-100, 'USD', 'CNY'), -700);
    expect(CurrencyUtil.convertCurrency(0, 'USD', 'HKD'), 0);
    expect(CurrencyUtil.convertCurrency(123.456, 'EUR', 'EUR'), 123.456);
  });
  test('conversion round trip preserves fractional amounts', () {
    final converted = CurrencyUtil.convertCurrency(.12345678, 'EUR', 'HKD');
    expect(converted, closeTo(1.97530848, 1e-12));
    expect(
      CurrencyUtil.convertCurrency(converted, 'HKD', 'EUR'),
      closeTo(.12345678, 1e-12),
    );
  });
  test('currency symbols and unknown currency labels', () {
    expect(
      [
        for (final c in ['USD', 'CNY', 'CNH', 'HKD', 'EUR', 'GBP', 'JPY'])
          CurrencyUtil.getSymbol(c),
      ],
      [r'$', '¥', '¥', r'HK$', '€', '£', 'JPY'],
    );
  });
  for (final entry in <double, String>{
    99999: '99999.00',
    100000: '100K',
    150000: '150K',
    1000000: '1M',
    1500000: '1.5M',
    1000000000: '1B',
    -1500000: '-1.5M',
  }.entries) {
    test(
      'English compact amount ${entry.key}',
      () => expect(CurrencyUtil.formatCompact(entry.key), entry.value),
    );
  }
  test('simplified Chinese switches to 万 and 亿 at configured thresholds', () {
    L10n.applyLanguage(L10n.langZh);
    expect(CurrencyUtil.formatCompact(999999), '999999.00');
    expect(CurrencyUtil.formatCompact(1000000), '100万');
    expect(CurrencyUtil.formatCompact(1500000), '150万');
    expect(CurrencyUtil.formatCompact(100000000), '1亿');
    expect(CurrencyUtil.formatCompact(-150000000), '-1.5亿');
  });
  test('custom formatting applies to base and abbreviated amounts', () {
    expect(
      CurrencyUtil.formatCompact(
        123.456,
        formatBase: (v) => v.toStringAsFixed(1),
      ),
      '123.5',
    );
    expect(
      CurrencyUtil.formatCompact(
        123456,
        formatBase: (v) => v.toStringAsFixed(1),
      ),
      '123.5K',
    );
    expect(CurrencyUtil.formatRate(1.23456), '1.2346');
  });
  test(
    'profit threshold suppresses signs for tiny positive and negative values',
    () {
      for (final v in [0.0, .000099, -.000099]) {
        expect(ProfitUtil.isZero(v), isTrue);
        expect(ProfitUtil.signOf(v), '');
        expect(ProfitUtil.colorOf(v), AppColors.textTertiary);
      }
      expect(ProfitUtil.isZero(.0001), isFalse);
      expect(ProfitUtil.signOf(.0001), '+');
      expect(ProfitUtil.signOf(-.0001), '-');
    },
  );
  test('profit display has a single sign and configurable percent digits', () {
    expect(ProfitUtil.amount(-123.45), '-123.45');
    expect(ProfitUtil.amount(123.45), '+123.45');
    expect(ProfitUtil.amount(-.000001), '0.00');
    expect(ProfitUtil.percent(-1.234), '-1.23%');
    expect(ProfitUtil.percent(1.234, digits: 3), '+1.234%');
  });
  test('profit colors follow market preference in both themes', () {
    for (final brightness in Brightness.values) {
      AppColors.applyBrightness(brightness);
      AppColors.applyMarketColorPreference(true);
      expect(ProfitUtil.colorOf(1), AppColors.danger);
      expect(ProfitUtil.colorOf(-1), AppColors.success);
      AppColors.applyMarketColorPreference(false);
      expect(ProfitUtil.colorOf(1), AppColors.success);
      expect(ProfitUtil.colorOf(-1), AppColors.danger);
      expect(ProfitUtil.colorOf(0), AppColors.textTertiary);
    }
  });
}
