import 'package:flutter/material.dart';
import 'strings_zh.dart';
import 'strings_en.dart';
import 'strings_zh_hant.dart';

/// 全局本地化管理器
///
/// 语言偏好存储于 SettingsService（'preferred_language'），值为
/// 语言代码（'zh' / 'zh_Hant' / 'en'），或 'system' 表示跟随系统。
class L10n {
  L10n._();

  static const String langSystem = 'system';
  static const String langZh = 'zh';
  static const String langZhHant = 'zh_Hant';
  static const String langEn = 'en';

  /// 当前生效的语言代码（zh / zh_Hant / en），已解析系统语言
  static String currentLang = langZh;

  /// 当前生效的 Locale（用于 MaterialApp.locale）
  static Locale currentLocale = const Locale('zh', 'CN');

  /// 是否跟随系统语言
  static bool followSystem = false;

  /// 设备系统语言（main 启动时记录），用于跟随系统时解析生效语言
  static Locale deviceLocale = const Locale('zh', 'CN');

  /// 语言变更通知（全局重建用）
  static final ValueNotifier<String> notifier = ValueNotifier(langZh);

  /// 应用语言偏好并触发全局重建
  ///
  /// [preferred] 为设置项值（'system' / 'zh' / 'zh_Hant' / 'en'）。
  static void applyLanguage(String preferred) {
    followSystem = preferred == langSystem;
    final lang = followSystem
        ? resolveSystemLang(deviceLocale)
        : switch (preferred) {
            langEn => langEn,
            langZhHant => langZhHant,
            _ => langZh,
          };
    currentLang = lang;
    currentLocale = localeOf(lang);
    notifier.value = lang;
  }

  /// 支持的 Locale 列表
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
    Locale('zh', 'TW'),
    Locale('zh', 'HK'),
  ];

  /// 查找文案：按当前语言从字符串表读取，缺省回退到简体中文
  static String t(String key) {
    final table = switch (currentLang) {
      langEn => stringsEn,
      langZhHant => stringsZhHant,
      _ => stringsZh,
    };
    return table[key] ?? stringsZh[key] ?? key;
  }

  /// 根据设备系统语言解析生效语言代码
  static String resolveSystemLang(Locale deviceLocale) {
    if (deviceLocale.languageCode == 'en') return langEn;
    if (deviceLocale.languageCode == 'zh') {
      final country = deviceLocale.countryCode;
      if (country == 'TW' || country == 'HK' || country == 'MO') {
        return langZhHant;
      }
      return langZh;
    }
    return langZh;
  }

  /// 将语言代码解析为生效的 Locale
  static Locale localeOf(String lang) {
    return switch (lang) {
      langEn => const Locale('en', 'US'),
      langZhHant => const Locale('zh', 'TW'),
      _ => const Locale('zh', 'CN'),
    };
  }
}
