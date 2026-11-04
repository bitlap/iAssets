import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 设置服务 - 文件 JSON 存储，与股票/资产同样的持久化方式
class SettingsService {
  static const String _retiredKeepStockKey = 'keep_stock_after_close';
  static const String keyDefaultCurrency = 'default_currency';
  static const String keySortColumn = 'sort_column';
  static const String keySortAscending = 'sort_ascending';
  static const String keySyncSettings = 'sync_settings';
  static const String keyDefaultFeeType = 'default_fee_type';
  static const String keyDefaultFeeValue = 'default_fee_value';
  static const String keyAssetSortColumn = 'asset_sort_column';
  static const String keyAssetSortAscending = 'asset_sort_ascending';
  static const String keyAssetSectionOrder = 'asset_section_order';
  static const String keyAssetCategories = 'asset_categories';
  static const String keyPreferredLanguage = 'preferred_language';
  static const String keyThemeMode = 'theme_mode';
  static const String keyRedUpGreenDown = 'red_up_green_down';

  static const String feeTypePercentage = 'percentage';
  static const String feeTypeFixed = 'fixed';

  /// 语言偏好可选值
  static const String languageSystem = 'system';
  static const String languageZh = 'zh';
  static const String languageZhHant = 'zh_Hant';
  static const String languageEn = 'en';

  /// 主题偏好可选值
  static const String themeSystem = 'system';
  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  static Map<String, dynamic>? _cache;
  static String? _path;

  static Future<String> _getPath() async {
    if (_path == null) {
      final dir = await getApplicationDocumentsDirectory();
      _path = dir.path;
    }
    return _path!;
  }

  static Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    final path = await _getPath();
    final file = File('$path/settings.json');
    if (await file.exists()) {
      try {
        _cache = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (_cache!.containsKey(_retiredKeepStockKey)) {
          _cache!.remove(_retiredKeepStockKey);
          await _save();
        }
        return _cache!;
      } catch (e) {
        debugPrint('[SettingsService] ===> 读取设置失败: $e');
      }
    }
    _cache = {};
    return _cache!;
  }

  static Future<void> _save() async {
    if (_cache == null) return;
    final path = await _getPath();
    final file = File('$path/settings.json');
    try {
      await file.writeAsString(jsonEncode(_cache));
    } catch (e) {
      debugPrint('[SettingsService] ===> 写入设置失败: $e');
    }
  }

  /// 强制重载文件（iCloud 同步后调用）
  static Future<void> reload() async {
    _cache = null;
    await _load();
  }

  /// 读取保存的默认货币
  static Future<String?> getDefaultCurrency() async {
    final settings = await _load();
    return settings[keyDefaultCurrency] as String?;
  }

  /// 保存默认货币
  static Future<void> setDefaultCurrency(String currency) async {
    final settings = await _load();
    settings[keyDefaultCurrency] = currency;
    await _save();
  }

  /// 读取股票排序列，默认 'holdings'
  static Future<String> getSortColumn() async {
    final settings = await _load();
    return settings[keySortColumn] as String? ?? 'holdings';
  }

  /// 保存股票排序列
  static Future<void> setSortColumn(String column) async {
    final settings = await _load();
    settings[keySortColumn] = column;
    await _save();
  }

  /// 读取股票排序方向，默认 false（降序）
  static Future<bool> getSortAscending() async {
    final settings = await _load();
    return settings[keySortAscending] as bool? ?? false;
  }

  /// 保存股票排序方向
  static Future<void> setSortAscending(bool ascending) async {
    final settings = await _load();
    settings[keySortAscending] = ascending;
    await _save();
  }

  /// 读取资产排序列，null = 手动
  static Future<String?> getAssetSortColumn() async {
    final settings = await _load();
    return settings[keyAssetSortColumn] as String?;
  }

  /// 保存资产排序列
  static Future<void> setAssetSortColumn(String? column) async {
    final settings = await _load();
    if (column != null) {
      settings[keyAssetSortColumn] = column;
    } else {
      settings.remove(keyAssetSortColumn);
    }
    await _save();
  }

  /// 读取资产排序方向，默认 false（降序）
  static Future<bool> getAssetSortAscending() async {
    final settings = await _load();
    return settings[keyAssetSortAscending] as bool? ?? false;
  }

  /// 保存资产排序方向
  static Future<void> setAssetSortAscending(bool ascending) async {
    final settings = await _load();
    settings[keyAssetSortAscending] = ascending;
    await _save();
  }

  /// 读取资产分类顺序，默认 [cash, timeDeposit, wealthProduct]
  static Future<List<String>> getAssetSectionOrder() async {
    final settings = await _load();
    final list = settings[keyAssetSectionOrder] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      return list.cast<String>();
    }
    return ['cash', 'timeDeposit', 'wealthProduct'];
  }

  /// 保存资产分类顺序
  static Future<void> setAssetSectionOrder(List<String> order) async {
    final settings = await _load();
    settings[keyAssetSectionOrder] = order;
    await _save();
  }

  static Future<List<Map<String, dynamic>>> getAssetCategories() async {
    final settings = await _load();
    final raw = settings[keyAssetCategories];
    if (raw is! List) return [];
    return [
      for (final entry in raw)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }

  static Future<void> setAssetCategories(
    List<Map<String, dynamic>> categories,
  ) async {
    final settings = await _load();
    settings[keyAssetCategories] = categories;
    await _save();
  }

  /// 读取默认手续费类型
  static Future<String> getDefaultFeeType() async {
    final settings = await _load();
    return settings[keyDefaultFeeType] as String? ?? feeTypeFixed;
  }

  /// 保存默认手续费类型
  static Future<void> setDefaultFeeType(String type) async {
    final settings = await _load();
    settings[keyDefaultFeeType] = type;
    await _save();
  }

  /// 读取默认手续费值
  static Future<double> getDefaultFeeValue() async {
    final settings = await _load();
    return (settings[keyDefaultFeeValue] as num?)?.toDouble() ?? 0.0;
  }

  /// 保存默认手续费值
  static Future<void> setDefaultFeeValue(double value) async {
    final settings = await _load();
    settings[keyDefaultFeeValue] = value;
    await _save();
  }

  /// 读取同步开关
  static Future<bool> getSyncSettings() async {
    final settings = await _load();
    return settings[keySyncSettings] as bool? ?? true;
  }

  /// 保存同步开关
  static Future<void> setSyncSettings(bool value) async {
    final settings = await _load();
    settings[keySyncSettings] = value;
    await _save();
  }

  /// 读取首选语言，默认 'system'（跟随系统）
  static Future<String> getPreferredLanguage() async {
    final settings = await _load();
    return settings[keyPreferredLanguage] as String? ?? languageSystem;
  }

  /// 保存首选语言
  static Future<void> setPreferredLanguage(String language) async {
    final settings = await _load();
    settings[keyPreferredLanguage] = language;
    await _save();
  }

  /// 读取主题偏好，默认跟随系统。
  static Future<String> getThemeMode() async {
    final settings = await _load();
    final value = settings[keyThemeMode] as String?;
    return switch (value) {
      themeLight => themeLight,
      themeDark => themeDark,
      _ => themeSystem,
    };
  }

  /// 保存主题偏好。
  static Future<void> setThemeMode(String themeMode) async {
    final settings = await _load();
    settings[keyThemeMode] = themeMode;
    await _save();
  }

  /// 首次启动按地区初始化；已有用户选择始终优先。
  static Future<bool> getRedUpGreenDown({Locale? deviceLocale}) async {
    final settings = await _load();
    final saved = settings[keyRedUpGreenDown] as bool?;
    if (saved != null) return saved;
    final initial = defaultRedUpGreenDown(
      deviceLocale ?? PlatformDispatcher.instance.locale,
    );
    settings[keyRedUpGreenDown] = initial;
    await _save();
    return initial;
  }

  /// 大中华区、日本和韩国使用红涨；其他地区（包括英语市场）使用绿涨。
  static bool defaultRedUpGreenDown(Locale locale) {
    const redUpRegions = {'CN', 'HK', 'MO', 'TW', 'JP', 'KR'};
    final region = locale.countryCode?.toUpperCase();
    if (region != null && region.isNotEmpty) {
      return redUpRegions.contains(region);
    }
    return locale.languageCode == 'zh' ||
        locale.languageCode == 'ja' ||
        locale.languageCode == 'ko';
  }

  /// 保存涨跌配色偏好。
  static Future<void> setRedUpGreenDown(bool value) async {
    final settings = await _load();
    settings[keyRedUpGreenDown] = value;
    await _save();
  }

  /// 获取完整设置 Map
  static Future<Map<String, dynamic>> getAll() async {
    return await _load();
  }

  /// 用 Map 批量更新设置
  static Future<void> applyAll(Map<String, dynamic> data) async {
    final settings = await _load();
    settings.addAll(data);
    settings.remove(_retiredKeepStockKey);
    await _save();
  }
}
