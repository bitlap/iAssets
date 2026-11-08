import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'strings_zh.dart';
import 'strings_en.dart';
import 'strings_zh_hant.dart';
import 'strings_ja.dart';
import 'strings_ko.dart';
import 'strings_fr.dart';
import 'strings_de.dart';
import 'strings_es.dart';
import 'strings_pt_br.dart';
import 'strings_it.dart';
import 'strings_ru.dart';
import 'strings_ar.dart';
import 'strings_hi.dart';
import 'strings_id.dart';
import 'strings_vi.dart';
import 'strings_th.dart';
import 'strings_tr.dart';
import 'strings_nl.dart';
import 'strings_pl.dart';
import 'strings_pt_pt.dart';
import 'strings_uk.dart';
import 'strings_ms.dart';
import 'strings_fil.dart';
import 'strings_bn.dart';
import 'strings_fa.dart';
import 'strings_he.dart';
import 'strings_sv.dart';
import 'strings_da.dart';
import 'strings_nb.dart';
import 'strings_fi.dart';
import 'strings_cs.dart';
import 'strings_ro.dart';
import 'strings_el.dart';

/// Shared language registry for preferences, Flutter locales and translations.
class L10n {
  L10n._();

  static const String langSystem = 'system';
  static const String langZh = 'zh';
  static const String langZhHant = 'zh_Hant';
  static const String langEn = 'en';

  /// Names stay in their own language so users can always find their language.
  static const languages = <String, ({String name, Locale locale})>{
    langZh: (name: '简体中文', locale: Locale('zh', 'CN')),
    langZhHant: (
      name: '繁體中文',
      locale: Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    ),
    langEn: (name: 'English', locale: Locale('en', 'US')),
    'ja': (name: '日本語', locale: Locale('ja')),
    'ko': (name: '한국어', locale: Locale('ko')),
    'fr': (name: 'Français', locale: Locale('fr')),
    'de': (name: 'Deutsch', locale: Locale('de')),
    'es': (name: 'Español', locale: Locale('es')),
    'pt_BR': (name: 'Português (Brasil)', locale: Locale('pt', 'BR')),
    'it': (name: 'Italiano', locale: Locale('it')),
    'ru': (name: 'Русский', locale: Locale('ru')),
    'ar': (name: 'العربية', locale: Locale('ar')),
    'hi': (name: 'हिन्दी', locale: Locale('hi')),
    'id': (name: 'Bahasa Indonesia', locale: Locale('id')),
    'vi': (name: 'Tiếng Việt', locale: Locale('vi')),
    'th': (name: 'ไทย', locale: Locale('th')),
    'tr': (name: 'Türkçe', locale: Locale('tr')),
    'nl': (name: 'Nederlands', locale: Locale('nl')),
    'pl': (name: 'Polski', locale: Locale('pl')),
    'pt_PT': (name: 'Português (Portugal)', locale: Locale('pt', 'PT')),
    'uk': (name: 'Українська', locale: Locale('uk')),
    'ms': (name: 'Bahasa Melayu', locale: Locale('ms')),
    'fil': (name: 'Filipino', locale: Locale('fil')),
    'bn': (name: 'বাংলা', locale: Locale('bn')),
    'fa': (name: 'فارسی', locale: Locale('fa')),
    'he': (name: 'עברית', locale: Locale('he')),
    'sv': (name: 'Svenska', locale: Locale('sv')),
    'da': (name: 'Dansk', locale: Locale('da')),
    'nb': (name: 'Norsk bokmål', locale: Locale('nb')),
    'fi': (name: 'Suomi', locale: Locale('fi')),
    'cs': (name: 'Čeština', locale: Locale('cs')),
    'ro': (name: 'Română', locale: Locale('ro')),
    'el': (name: 'Ελληνικά', locale: Locale('el')),
  };

  static const translations = <String, Map<String, String>>{
    langZh: stringsZh,
    langZhHant: stringsZhHant,
    langEn: stringsEn,
    'ja': stringsJa,
    'ko': stringsKo,
    'fr': stringsFr,
    'de': stringsDe,
    'es': stringsEs,
    'pt_BR': stringsPtBr,
    'it': stringsIt,
    'ru': stringsRu,
    'ar': stringsAr,
    'hi': stringsHi,
    'id': stringsId,
    'vi': stringsVi,
    'th': stringsTh,
    'tr': stringsTr,
    'nl': stringsNl,
    'pl': stringsPl,
    'pt_PT': stringsPtPt,
    'uk': stringsUk,
    'ms': stringsMs,
    'fil': stringsFil,
    'bn': stringsBn,
    'fa': stringsFa,
    'he': stringsHe,
    'sv': stringsSv,
    'da': stringsDa,
    'nb': stringsNb,
    'fi': stringsFi,
    'cs': stringsCs,
    'ro': stringsRo,
    'el': stringsEl,
  };

  static String currentLang = langZh;
  static Locale currentLocale = const Locale('zh', 'CN');
  static bool followSystem = false;
  static Locale deviceLocale = const Locale('zh', 'CN');
  static final ValueNotifier<String> notifier = ValueNotifier(langZh);

  static List<Locale> get supportedLocales => [
    for (final language in languages.values) language.locale,
    const Locale('zh', 'TW'),
    const Locale('zh', 'HK'),
  ];

  static bool get isRtl => const {'ar', 'fa', 'he'}.contains(currentLang);
  static String get intlLocale => currentLocale.toString();

  // Local intl symbols initialize synchronously; cache the completed future.
  static final Future<void> _dateFormatting = initializeDateFormatting();

  static void applyLanguage(String preferred) {
    unawaited(_dateFormatting);
    followSystem = preferred == langSystem;
    final lang = followSystem
        ? resolveSystemLang(deviceLocale)
        : languages.containsKey(preferred)
        ? preferred
        : langEn;
    currentLang = lang;
    currentLocale = localeOf(lang);
    Intl.defaultLocale = intlLocale;
    notifier.value = lang;
  }

  static String t(String key) =>
      translations[currentLang]?[key] ??
      stringsEn[key] ??
      stringsZh[key] ??
      key;

  static String resolveSystemLang(Locale locale) {
    final code = switch (locale.languageCode) {
      'tl' => 'fil',
      'no' => 'nb',
      'iw' => 'he',
      'in' => 'id',
      _ => locale.languageCode,
    };
    if (code == 'zh') {
      if (locale.scriptCode == 'Hant') return langZhHant;
      if (locale.scriptCode == 'Hans') return langZh;
      return const {'TW', 'HK', 'MO'}.contains(locale.countryCode)
          ? langZhHant
          : langZh;
    }
    if (code == 'pt') return locale.countryCode == 'PT' ? 'pt_PT' : 'pt_BR';
    return languages.containsKey(code) ? code : langEn;
  }

  static Locale localeOf(String lang) =>
      languages[lang]?.locale ?? languages[langEn]!.locale;
}
