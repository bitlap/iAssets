import 'package:assets/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => L10n.applyLanguage(L10n.langZh));

  test('unsupported system languages fall back to English', () {
    for (final code in ['zz', 'eo', 'sw']) {
      expect(L10n.resolveSystemLang(Locale(code)), L10n.langEn);
    }
  });

  test('Chinese script takes priority over region, then region is used', () {
    expect(
      L10n.resolveSystemLang(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      L10n.langZhHant,
    );
    expect(
      L10n.resolveSystemLang(
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'TW',
        ),
      ),
      L10n.langZh,
    );
    for (final region in ['TW', 'HK', 'MO']) {
      expect(L10n.resolveSystemLang(Locale('zh', region)), L10n.langZhHant);
    }
    expect(L10n.resolveSystemLang(const Locale('zh', 'CN')), L10n.langZh);
  });

  test('explicit preference is preserved regardless of device locale', () {
    L10n.deviceLocale = const Locale('de', 'DE');
    L10n.applyLanguage(L10n.langZhHant);
    expect(L10n.currentLang, L10n.langZhHant);
    expect(L10n.t('assetTotalAssets'), isNotEmpty);
    L10n.applyLanguage(L10n.langSystem);
    expect(L10n.currentLang, 'de');
  });
}
