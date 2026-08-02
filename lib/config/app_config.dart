/// 开发者配置信息 - 集中管理全局常量
library app_config;

export 'settings_config.dart';
export 'stock_config.dart';
export 'asset_config.dart';

import '../l10n/l10n.dart';

class AppConfig {
  AppConfig._();

  // 应用信息
  static String get appName => L10n.t('appName');
  static String appVersion = '1.0.0';

  // 默认币种
  static const String defaultCurrency = 'USD';

  // UI 布局
  static const double appBarHeight = 44.0;
  static const double dialogWidthRatio = 0.75;

  // 开发者信息
  static const String developerName = 'LI GUOBIN';
  static const String developerEmail = 'dreamylost@outlook.com';
  static const String developerWechat = 'naive_dddd';

  // 通用按钮
  static String get btnClose => L10n.t('btnClose');
  static String get btnCancel => L10n.t('btnCancel');
  static String get btnDelete => L10n.t('btnDelete');
  static String get btnConfirm => L10n.t('btnConfirm');
  static String get btnAdd => L10n.t('btnAdd');
  static String get btnAdded => L10n.t('btnAdded');
  static String get btnConfirmAdd => L10n.t('btnConfirmAdd');
  static String get btnConfirmBuy => L10n.t('btnConfirmBuy');
  static String get btnConfirmSell => L10n.t('btnConfirmSell');

  // 定时器 / 缓存 / 超时
  static const int refreshInitialDelaySec = 3;
  static const int refreshIntervalSec = 60;
  static const int quoteCacheTTLMin = 15;
  static const int searchCacheTTLMin = 5;
  static const int exchangeRateCacheTTLMin = 24 * 60;
  static const int cooldownDurationMin = 5;
  static const int failureThreshold = 3;
  static const int httpTimeoutSec = 15;
  static const int searchDebounceMs = 1000;

  // Toast 文案
  static String get toastEmailCopied => L10n.t('toastEmailCopied');
  static String get toastWechatCopied => L10n.t('toastWechatCopied');
  static String get toastClipboardSuffix => L10n.t('toastClipboardSuffix');

  // 通用后缀
  static String get suffixCount => L10n.t('suffixCount');
  static String get suffixWan => L10n.t('suffixWan');
  static String get suffixYi => L10n.t('suffixYi');
}
