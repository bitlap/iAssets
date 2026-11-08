import '../models/asset_account.dart';
import '../models/asset_category.dart';
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
  static String get depositAutoRenew => L10n.t('depositAutoRenew');
  static String get depositAutoRenewHint => L10n.t('depositAutoRenewHint');
  static String get depositMaturityDate => L10n.t('depositMaturityDate');
  static String get depositRollover => L10n.t('depositRollover');
  static String get depositRolloverHint => L10n.t('depositRolloverHint');
  static String get assetActions => L10n.t('assetActions');
  static String get assetSaveFailed => L10n.t('assetSaveFailed');

  // 头部/卡片
  static String get assetCountLabel => L10n.t('assetCountLabel');
  static String get assetSubtitleRefresh => L10n.t('assetSubtitleRefresh');
  static String get depositWealthLabel => L10n.t('depositWealthLabel');
  static String get createdLabel => L10n.t('createdLabel');
  static String get updatedLabel => L10n.t('updatedLabel');

  // 展示分类
  static String get categoryChoose => L10n.t('assetCategoryChoose');
  static String get categoryManage => L10n.t('assetCategoryManage');
  static String get categoryMove => L10n.t('assetCategoryMove');
  static String get categoryTemplates => L10n.t('assetCategoryTemplates');
  static String get categoryCustom => L10n.t('assetCategoryCustom');
  static String get categoryRename => L10n.t('assetCategoryRename');
  static String get categoryDelete => L10n.t('assetCategoryDelete');
  static String get categoryName => L10n.t('assetCategoryName');
  static String get categoryCalculation => L10n.t('assetCategoryCalculation');
  static String get categoryRegion => L10n.t('assetCategoryRegion');
  static String get categoryValueBalance => L10n.t('assetCategoryValueBalance');
  static String get categoryValueDeposit => L10n.t('assetCategoryValueDeposit');
  static String get categoryValueNav => L10n.t('assetCategoryValueNav');
  static String get categoryCancel => L10n.t('assetCategoryCancel');
  static String get categoryCreate => L10n.t('assetCategoryCreate');
  static String get categorySave => L10n.t('assetCategorySave');
  static String get categoryAlreadyExists => L10n.t('assetCategoryExists');
  static String get categoryNameInvalid => L10n.t('assetCategoryInvalidName');
  static String get categoryDeleteBlocked =>
      L10n.t('assetCategoryDeleteBlocked');
  static String regionLabel(String region) => L10n.t('assetRegion$region');

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

  static String labelForCategory(AssetCategory category) {
    final name = category.customName?.trim();
    return name != null && name.isNotEmpty ? name : L10n.t(category.labelKey);
  }
}
