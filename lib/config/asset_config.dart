import '../models/asset_account.dart';
import '../l10n/l10n.dart';

/// 资产模块配置 - 集中管理资产相关的文案和常量
class AssetConfig {
  AssetConfig._();

  // 分类显示名称
  static String get cash => L10n.t('cash');
  static String get timeDeposit => L10n.t('timeDeposit');
  static String get wealthProduct => L10n.t('wealthProduct');
  static String get current => L10n.t('current');
  static String get providentFund => L10n.t('providentFund');

  // 对话框标题
  static String get titleAddAsset => L10n.t('titleAddAsset');
  static String get titleEditCash => L10n.t('titleEditCash');
  static String get titleAddCash => L10n.t('titleAddCash');
  static String get titleEditTD => L10n.t('titleEditTD');
  static String get titleAddTD => L10n.t('titleAddTD');
  static String get titleEditWP => L10n.t('titleEditWP');
  static String get titleAddWP => L10n.t('titleAddWP');
  static String get titleEditCurrent => L10n.t('titleEditCurrent');
  static String get titleAddCurrent => L10n.t('titleAddCurrent');
  static String get titleEditProvidentFund => L10n.t('titleEditProvidentFund');
  static String get titleAddProvidentFund => L10n.t('titleAddProvidentFund');

  // 字段标签
  static String get fieldName => L10n.t('fieldName');
  static String get fieldBalance => L10n.t('fieldBalance');
  static String get fieldPrincipal => L10n.t('fieldPrincipal');
  static String get fieldAnnualRate => L10n.t('fieldAnnualRate');
  static String get fieldStartDate => L10n.t('fieldStartDate');
  static String get fieldDuration => L10n.t('fieldDuration');
  static String get fieldShares => L10n.t('fieldShares');
  static String get fieldNav => L10n.t('fieldNav');

  // 输入提示
  static String get hintCashName => L10n.t('hintCashName');
  static String get hintCurrentName => L10n.t('hintCurrentName');
  static String get hintProvidentFundName => L10n.t('hintProvidentFundName');
  static String get hintTDName => L10n.t('hintTDName');
  static String get hintWPName => L10n.t('hintWPName');

  // 验证提示
  static String get toastInvalidBalance => L10n.t('toastInvalidBalance');
  static String get toastInvalidPrincipal => L10n.t('toastInvalidPrincipal');
  static String get toastInvalidRate => L10n.t('toastInvalidRate');
  static String get toastInvalidShares => L10n.t('toastInvalidShares');
  static String get toastInvalidNav => L10n.t('toastInvalidNav');

  // 操作提示
  static String get toastDeleted => L10n.t('toastDeleted');
  static String get toastSaved => L10n.t('toastSaved');
  static String get toastCrossSection => L10n.t('toastCrossSection');

  // 空状态
  static String get emptyTitle => L10n.t('emptyTitle');
  static String get emptySubtitle => L10n.t('emptySubtitle');

  // 默认名称
  static String get defaultNameFallback => L10n.t('defaultNameFallback');
  static String get defaultNameCash => L10n.t('defaultNameCash');
  static String get defaultNameCurrent => L10n.t('defaultNameCurrent');
  static String get defaultNameProvidentFund =>
      L10n.t('defaultNameProvidentFund');
  static String get defaultNameTD => L10n.t('defaultNameTD');
  static String get defaultNameWP => L10n.t('defaultNameWP');

  // 删除确认
  static String get deleteConfirm => L10n.t('deleteConfirm');

  // 定期存款
  static String get daysRemaining => L10n.t('daysRemaining');
  static String get expired => L10n.t('expired');
  static String get durationMonths => L10n.t('durationMonths');

  // 头部/卡片
  static String get assetCountLabel => L10n.t('assetCountLabel');
  static String get assetSubtitleRefresh => L10n.t('assetSubtitleRefresh');
  static String get depositWealthLabel => L10n.t('depositWealthLabel');
  static String get createdLabel => L10n.t('createdLabel');
  static String get updatedLabel => L10n.t('updatedLabel');

  // 辅助方法
  static String labelForType(AssetType type) {
    return switch (type) {
      AssetType.cash => cash,
      AssetType.timeDeposit => timeDeposit,
      AssetType.wealthProduct => wealthProduct,
      AssetType.current => current,
      AssetType.providentFund => providentFund,
    };
  }
}
