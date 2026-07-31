import '../models/asset_account.dart';

/// 资产模块配置 - 集中管理资产相关的文案和常量
class AssetConfig {
  AssetConfig._();

  // 分类显示名称
  static const String cash = '现金';
  static const String timeDeposit = '定期存款';
  static const String wealthProduct = '理财';
  static const String current = '活期存款';
  static const String providentFund = '公积金';

  // 对话框标题
  static const String titleAddAsset = '添加资产';
  static const String titleEditCash = '编辑现金';
  static const String titleAddCash = '添加现金';
  static const String titleEditTD = '编辑定期存款';
  static const String titleAddTD = '添加定期存款';
  static const String titleEditWP = '编辑理财';
  static const String titleAddWP = '添加理财';
  static const String titleEditCurrent = '编辑活期';
  static const String titleAddCurrent = '添加活期';
  static const String titleEditProvidentFund = '编辑公积金';
  static const String titleAddProvidentFund = '添加公积金';

  // 字段标签
  static const String fieldName = '名称';
  static const String fieldBalance = '余额';
  static const String fieldPrincipal = '本金';
  static const String fieldAnnualRate = '年利率 (%)';
  static const String fieldStartDate = '存入日期';
  static const String fieldDuration = '期限 (月)';
  static const String fieldShares = '持有份额';
  static const String fieldNav = '最新净值';

  // 输入提示
  static const String hintCashName = '例：钱包、储蓄卡';
  static const String hintCurrentName = '例：活期存款';
  static const String hintProvidentFundName = '例：住房公积金';
  static const String hintTDName = '例：一年定期';
  static const String hintWPName = '例：余额宝、某某基金';

  // 验证提示
  static const String toastInvalidBalance = '请输入有效金额';
  static const String toastInvalidPrincipal = '请输入有效本金';
  static const String toastInvalidRate = '请输入有效利率';
  static const String toastInvalidShares = '请输入有效份额';
  static const String toastInvalidNav = '请输入有效净值';

  // 操作提示
  static const String toastDeleted = '已删除 {name}';
  static const String toastSaved = '已保存';
  static const String toastCrossSection = '不能移动到其他分类';

  // 空状态
  static const String emptyTitle = '还没有资产';
  static const String emptySubtitle = '点击右下角 + 添加现金、存款或理财';

  // 默认名称
  static const String defaultNameFallback = '此项';
  static const String defaultNameCash = '现金 ({currency})';
  static const String defaultNameCurrent = '活期 ({currency})';
  static const String defaultNameProvidentFund = '公积金 ({currency})';
  static const String defaultNameTD = '定期存款';
  static const String defaultNameWP = '理财产品';

  // 删除确认
  static const String deleteConfirm = '确定要删除 {name} 吗？';

  // 定期存款
  static const String daysRemaining = '还剩 {days}天';
  static const String expired = '已到期';
  static const String durationMonths = '{m}个月';

  // 头部/卡片
  static const String assetCountLabel = '共 {count} 项资产';
  static const String assetSubtitleRefresh = '最近更新：{time}';
  static const String depositWealthLabel = '存款理财';
  static const String createdLabel = '创建:{date}';
  static const String updatedLabel = '更新:{date}';

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
