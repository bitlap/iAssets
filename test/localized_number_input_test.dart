import 'package:assets/l10n/l10n.dart';
import 'package:assets/utils/currency_util.dart';
import 'package:assets/widgets/common/app_number_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => L10n.applyLanguage('zh'));
  const formatter = LocalizedDecimalInputFormatter();
  TextEditingValue paste(String text) => formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );

  test(
    'all locale-independent form values round-trip in every UI language',
    () {
      for (final language in L10n.languages.keys) {
        L10n.applyLanguage(language);
        expect(CurrencyUtil.formatInput(1234.5678), '1234.5678');
        expect(
          CurrencyUtil.parseInput(CurrencyUtil.formatInput(1234.5678)),
          1234.5678,
        );
        expect(CurrencyUtil.parseInput(CurrencyUtil.formatInput(1.23)), 1.23);
      }
      expect(CurrencyUtil.parseInput('1,23'), isNull);
      expect(CurrencyUtil.parseInput('NaN'), isNull);
      expect(CurrencyUtil.parseInput('Infinity'), isNull);
    },
  );

  test(
    'decimal commas follow the selected language; grouped pastes never change scale',
    () {
      L10n.applyLanguage('en');
      for (final text in ['1,234', '1,234.56', '12,34']) {
        expect(paste(text), TextEditingValue.empty, reason: text);
      }
      expect(paste('1234.56').text, '1234.56');
      L10n.applyLanguage('de');
      expect(paste('12,34').text, '12.34');
      expect(paste('1,234').text, '1.234');
      for (final text in ['1.234', '1.234,56', '1.234.567']) {
        expect(paste(text), TextEditingValue.empty, reason: text);
      }
      L10n.applyLanguage('fr');
      expect(paste('1\u202f234,56'), TextEditingValue.empty);
      expect(paste('1234,56').text, '1234.56');
    },
  );

  test('normalizing Unicode digits retains cursor position', () {
    for (final entry in {
      'ar': '١٢٫٣٤',
      'fa': '۱۲٫۳۴',
      'hi': '१२.३४',
      'bn': '১২.৩৪',
      'th': '๑๒.๓๔',
      'ja': '１２.３４',
    }.entries) {
      L10n.applyLanguage(entry.key);
      final value = paste(entry.value);
      expect(value.text, '12.34');
      expect(value.selection.baseOffset, 5);
    }
  });

  test(
    'editing an existing canonical decimal is not mistaken for a grouped paste',
    () {
      L10n.applyLanguage('de');
      const old = TextEditingValue(
        text: '12.3400',
        selection: TextSelection.collapsed(offset: 7),
      );
      const next = TextEditingValue(
        text: '12.340',
        selection: TextSelection.collapsed(offset: 6),
      );
      expect(formatter.formatEditUpdate(old, next), next);
    },
  );
}
