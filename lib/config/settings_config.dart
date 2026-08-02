import '../l10n/l10n.dart';

class SettingsConfig {
  SettingsConfig._();

  // 设置页 分区标题
  static String get settingsTitle => L10n.t('settingsTitle');
  static String get sectionLanguage => L10n.t('sectionLanguage');
  static String get languageAuto => L10n.t('languageAuto');
  static String get languageZh => L10n.t('languageZh');
  static String get languageZhHant => L10n.t('languageZhHant');
  static String get languageEn => L10n.t('languageEn');
  static String get sectionCurrency => L10n.t('sectionCurrency');
  static String get sectionStock => L10n.t('sectionStock');
  static String get sectionSync => L10n.t('sectionSync');
  static String get sectionOther => L10n.t('sectionOther');

  // 股票设置 文案
  static String get keepStockLabel => L10n.t('keepStockLabel');
  static String get syncSettingsLabel => L10n.t('syncSettingsLabel');
  static String get syncItemSettings => L10n.t('syncItemSettings');
  static String get syncItemStocks => L10n.t('syncItemStocks');
  static String get syncItemRecords => L10n.t('syncItemRecords');
  static String get syncHelpSettingsDesc => L10n.t('syncHelpSettingsDesc');
  static String get syncHelpStocksDesc => L10n.t('syncHelpStocksDesc');
  static String get syncHelpRecordsDesc => L10n.t('syncHelpRecordsDesc');
  static String get syncPrivacyNote => L10n.t('syncPrivacyNote');
  static String get keepStockOnLabel => L10n.t('keepStockOnLabel');
  static String get keepStockOnDesc => L10n.t('keepStockOnDesc');
  static String get keepStockOffLabel => L10n.t('keepStockOffLabel');
  static String get keepStockOffDesc => L10n.t('keepStockOffDesc');
  static String get sortLabel => L10n.t('sortLabel');
  static String get sortByProfit => L10n.t('sortByProfit');
  static String get sortByHoldings => L10n.t('sortByHoldings');
  static String get sortByName => L10n.t('sortByName');
  static String get sortByManual => L10n.t('sortByManual');
  static String get sortByAssetName => L10n.t('sortByAssetName');
  static String get sortByAssetAmount => L10n.t('sortByAssetAmount');
  static String get sortDirectionLabel => L10n.t('sortDirectionLabel');
  static String get sortAscending => L10n.t('sortAscending');
  static String get sortDescending => L10n.t('sortDescending');

  // 其他设置 文案
  static String get feedbackLabel => L10n.t('feedbackLabel');
  static String get openSourceLabel => L10n.t('openSourceLabel');
  static String get versionLabel => L10n.t('versionLabel');

  // 反馈提示
  static String get feedbackTitle => L10n.t('feedbackTitle');
  static String get feedbackHint => L10n.t('feedbackHint');
  static String get contactEmail => L10n.t('contactEmail');
  static String get contactWechat => L10n.t('contactWechat');

  // 开源说明
  static String get openSourceTitle => L10n.t('openSourceTitle');
  static String get openSourceDesc => L10n.t('openSourceDesc');
  static String get licenseSectionLibs => L10n.t('licenseSectionLibs');
  static String get licenseSectionData => L10n.t('licenseSectionData');

  // 手续费设置 文案
  static String get sectionFee => L10n.t('sectionFee');
  static String get feeTypeLabel => L10n.t('feeTypeLabel');
  static String get feeTypePercentage => L10n.t('feeTypePercentage');
  static String get feeTypeFixed => L10n.t('feeTypeFixed');
  static String get feeValueLabel => L10n.t('feeValueLabel');
  static String get feeValueHint => L10n.t('feeValueHint');
  static String get feeAmountLabel => L10n.t('feeAmountLabel');
  static String get feeAmountHint => L10n.t('feeAmountHint');
  static String get feeHelpTitle => L10n.t('feeHelpTitle');
  static String get feeHelpDesc => L10n.t('feeHelpDesc');
  static String get feeHelpRate => L10n.t('feeHelpRate');
  static String get feeHelpFixed => L10n.t('feeHelpFixed');

  // 公式
  static String get sectionFormula => L10n.t('sectionFormula');
  static String get formulaDialogSubtitle => L10n.t('formulaDialogSubtitle');

  // 开源软件 / 数据来源 文案
  static String get licenseDescFlutter => L10n.t('licenseDescFlutter');
  static String get licenseDescDart => L10n.t('licenseDescDart');
  static String get licenseDescCupertino => L10n.t('licenseDescCupertino');
  static String get licenseDescIntl => L10n.t('licenseDescIntl');
  static String get licenseDescHttp => L10n.t('licenseDescHttp');
  static String get licenseDescSharedPrefs => L10n.t('licenseDescSharedPrefs');
  static String get licenseDescUrlLauncher => L10n.t('licenseDescUrlLauncher');
  static String get licenseDescPathProvider =>
      L10n.t('licenseDescPathProvider');
  static String get licenseDescPackageInfo => L10n.t('licenseDescPackageInfo');
  static String get licenseDescWorkmanager => L10n.t('licenseDescWorkmanager');
  static String get dataSourceDescEastMoney =>
      L10n.t('dataSourceDescEastMoney');
  static String get dataSourceDescTencent => L10n.t('dataSourceDescTencent');
  static String get dataSourceDescExchangeRate =>
      L10n.t('dataSourceDescExchangeRate');

  // 数据来源显示名称
  static String get dataSourceNameEastMoney =>
      L10n.t('dataSourceNameEastMoney');
  static String get dataSourceAuthorEastMoney =>
      L10n.t('dataSourceAuthorEastMoney');
  static String get dataSourceNameTencent => L10n.t('dataSourceNameTencent');
  static String get dataSourceAuthorTencent =>
      L10n.t('dataSourceAuthorTencent');
}
