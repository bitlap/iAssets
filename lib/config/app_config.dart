/// 开发者配置信息 - 集中管理全局常量
library app_config;

export 'settings_config.dart';
export 'stock_config.dart';
export 'asset_config.dart';

import 'stock_config.dart';

class AppConfig {
  AppConfig._();

  // 应用信息
  static const String appName = '股票';
  static String appVersion = '1.0.0';

  // 默认币种和语言
  static const String defaultCurrency = 'USD';
  static const String defaultLocaleLanguage = 'zh';
  static const String defaultLocaleCountry = 'CN';

  // UI 布局
  static const double dialogWidthRatio = 0.75;

  // 开发者信息
  static const String developerName = 'LI GUOBIN';
  static const String developerEmail = 'dreamylost@outlook.com';
  static const String developerWechat = 'naive_dddd';

  // 通用按钮
  static const String btnClose = '确定';
  static const String btnCancel = '取消';
  static const String btnDelete = '删除';
  static const String btnConfirm = '确认删除';
  static const String btnAdd = '添加';
  static const String btnAdded = '已添加';
  static const String btnConfirmAdd = '确认添加';
  static const String btnConfirmBuy = '确认加仓';
  static const String btnConfirmSell = '确认减仓';

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
  static const String toastEmailCopied = '邮箱地址';
  static const String toastWechatCopied = '微信号';
  static const String toastClipboardSuffix = '已复制到剪贴板';

  // 通用后缀
  static const String suffixCount = '次';
  static const String suffixWan = '万';
  static const String suffixYi = '亿';

  // 市场 → 币种 映射
  static String currencyForMarket(String marketType) {
    switch (marketType) {
      case StockConfig.searchMarketHK:
        return 'HKD';
      default:
        return 'USD';
    }
  }
}
