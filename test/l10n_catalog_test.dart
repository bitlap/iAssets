import 'package:assets/l10n/l10n.dart';
import 'package:assets/utils/currency_util.dart';
import 'package:assets/widgets/common/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:assets/widgets/asset/asset_card.dart';
import 'package:assets/widgets/stock/stock_header_card.dart';
import 'package:assets/widgets/stock/stock_card.dart';
import 'support/core_fixtures.dart';
import 'package:assets/widgets/common/app_number_field.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  tearDown(() => L10n.applyLanguage(L10n.langZh));

  test('all 33 catalogs have every key and preserve dynamic arguments', () {
    expect(L10n.languages.length, 33);
    expect(L10n.translations.keys, unorderedEquals(L10n.languages.keys));
    final english = L10n.translations[L10n.langEn]!;
    final arguments = RegExp(r'\{\w+\}');
    for (final language in L10n.languages.keys) {
      final table = L10n.translations[language]!;
      expect(table.keys, unorderedEquals(english.keys), reason: language);
      for (final entry in english.entries) {
        final text = table[entry.key]!;
        if (entry.value.isNotEmpty) {
          expect(text.trim(), isNotEmpty, reason: '$language/${entry.key}');
        }
        expect(
          arguments.allMatches(text).map((m) => m.group(0)),
          unorderedEquals(
            arguments.allMatches(entry.value).map((m) => m.group(0)),
          ),
          reason: '$language/${entry.key}',
        );
        expect(text, isNot(contains('ZXQ')), reason: '$language/${entry.key}');
      }
    }
  });

  test(
    'every language resolves from system locale and explicit preference',
    () {
      for (final entry in L10n.languages.entries) {
        expect(L10n.resolveSystemLang(entry.value.locale), entry.key);
        L10n.deviceLocale = const Locale('zz');
        L10n.applyLanguage(entry.key);
        expect(L10n.currentLang, entry.key);
        expect(L10n.currentLocale, entry.value.locale);
        expect(Intl.defaultLocale, entry.value.locale.toString());
        L10n.deviceLocale = entry.value.locale;
        L10n.applyLanguage(L10n.langSystem);
        expect(L10n.currentLang, entry.key);
      }
      L10n.applyLanguage('unknown');
      expect(L10n.currentLang, L10n.langEn);
    },
  );

  test(
    'Portuguese regions and legacy language aliases resolve consistently',
    () {
      for (final region in ['BR', 'AO', 'MZ']) {
        expect(L10n.resolveSystemLang(Locale('pt', region)), 'pt_BR');
      }
      expect(L10n.resolveSystemLang(const Locale('pt')), 'pt_BR');
      expect(L10n.resolveSystemLang(const Locale('pt', 'PT')), 'pt_PT');
      for (final entry in {
        'no': 'nb',
        'tl': 'fil',
        'iw': 'he',
        'in': 'id',
      }.entries) {
        expect(L10n.resolveSystemLang(Locale(entry.key)), entry.value);
      }
    },
  );

  test('localized amount and date formatting works for every new locale', () {
    for (final language in L10n.languages.keys.skip(3)) {
      L10n.applyLanguage(language);
      expect(CurrencyUtil.formatCompact(1500000), isNotEmpty, reason: language);
      expect(
        CurrencyUtil.formatDecimal(-1234.56),
        isNotEmpty,
        reason: language,
      );
      expect(
        formatRefreshTime(DateTime(2026, 11, 8, 9, 7)),
        DateFormat.yMd(
          L10n.intlLocale,
        ).add_Hm().format(DateTime(2026, 11, 8, 9, 7)),
      );
    }
    L10n.applyLanguage('de');
    expect(CurrencyUtil.formatDecimal(1234.56), '1234,56');
    expect(CurrencyUtil.formatRate(1.2345), '1,2345');
    L10n.applyLanguage('fr');
    expect(formatRefreshTime(DateTime(2026, 11, 8, 9, 7)), '08/11/2026 09:07');
  });

  test(
    'decimal keyboards accept commas and Arabic/Persian digits without changing stored format',
    () {
      const formatter = LocalizedDecimalInputFormatter();
      for (final text in [
        '12,34',
        '١٢٫٣٤',
        '۱۲٫۳۴',
        '१२.३४',
        '১২.৩৪',
        '๑๒.๓๔',
        '１２.３４',
        '12.34',
      ]) {
        final value = TextEditingValue(
          text: text,
          selection: const TextSelection.collapsed(offset: 5),
        );
        final result = formatter.formatEditUpdate(
          TextEditingValue.empty,
          value,
        );
        expect(result.text, '12.34');
        expect(result.selection.baseOffset, 5);
        expect(double.parse(result.text), 12.34);
      }
      const previous = TextEditingValue(text: '12.34');
      expect(
        formatter.formatEditUpdate(
          previous,
          const TextEditingValue(text: '12,3,4'),
        ),
        previous,
      );
    },
  );

  testWidgets('portfolio cards fit a narrow screen in every language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in L10n.languages.keys) {
      L10n.applyLanguage(language);
      await tester.pumpWidget(
        MaterialApp(
          locale: L10n.currentLocale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  StockHeaderCard(
                    selectedCurrency: 'USD',
                    totalAssets: 100,
                    totalMarketValue: 100,
                    totalCost: 80,
                    totalProfit: 20,
                    totalRealizedPL: 0,
                    totalProfitPercent: 25,
                    todayProfit: 10,
                    todayProfitPercent: 10,
                    totalAfterTaxDividends: 0,
                    totalSellAmount: 0,
                    onCurrencyChanged: (_) {},
                  ),
                  StockCard(
                    stock: stock(),
                    isExpanded: true,
                    onExpandTap: () {},
                    onRecordTap: () {},
                    onMoreTap: () {},
                  ),
                  AssetCardFrame(
                    icon: Icons.savings,
                    name: 'Savings',
                    colorSeed: 'Savings',
                    currency: 'USD',
                    amount: CurrencyUtil.formatCompact(1234567),
                    detail: L10n.t('daysRemaining').replaceAll('{days}', '186'),
                    createdAt: DateTime(2026, 11, 8),
                    updatedAt: DateTime(2026, 11, 8),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: language);
    }
  });

  testWidgets(
    'Flutter delegates support all locales and choose RTL correctly',
    (tester) async {
      for (final entry in L10n.languages.entries) {
        L10n.applyLanguage(entry.key);
        await tester.pumpWidget(
          MaterialApp(
            locale: L10n.currentLocale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                expect(
                  Localizations.localeOf(context).languageCode,
                  L10n.currentLocale.languageCode,
                  reason: entry.key,
                );
                expect(
                  Directionality.of(context),
                  L10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
                  reason: entry.key,
                );
                return Scaffold(
                  body: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    },
  );
}
