import 'package:flutter/material.dart';

class StockConfig {
  StockConfig._();

  // 底部 Tab 图标
  static const IconData iconTabStock = Icons.show_chart;
  static const IconData iconTabAsset = Icons.account_balance_wallet;
  static const IconData iconAdd = Icons.add;

  // StockHeaderCard 文案
  static const String assetTotalAssets = '总资产';
  static const String assetTodayProfit = '今日盈亏';
  static const String assetTodayProfitHelp =
      '当前总盈亏 − 基线总盈亏。基线为美股市场（美东时间）每天早上9点（日界线，即昨收）的总盈亏；自动适配夏令时与本地时区，覆盖美股开盘时段';
  static const String assetTotalCost = '持仓市值';
  static const String assetTotalProfit = '总盈亏';
  static const String assetTotalDividends = '总股息';
  static const String assetExchangeRate = '汇率';
  static const String assetSelectCurrency = '选择货币';
  static const String assetTotalCostHelp = '每股现价 × 持仓股数';
  static const String assetTotalRealizedPL = '已实现盈亏';
  static const String assetTotalProfitHelp = '持仓总浮盈 + 已实现盈亏';
  static const String assetTotalAssetsHelp = '持仓市值 + 已平仓总额';
  static const String assetTotalDividendsHelp = '税后总股息 / 总资产';
  static const String assetTotalSellAmount = '已平仓总额';
  static const String assetCostDetailLabel = '持仓总成本';
  static const String assetFloatProfitLabel = '持仓总浮盈';
  static const String assetAfterTaxDividendsLabel = '税后总股息';
  static const String assetDividendRateLabel = '总股息率';
  static const String assetPositionRatioLabel = '资产分布';
  static const String assetPositionRatioHelp = '持仓市值 / 总资产';

  // 首页 文案
  static const String homeTitle = '股票';
  static const String homeSubtitle = '共 {count} 只 · 实时更新';
  static const String homeSubtitleRefresh = '最近更新：{time}';
  static const String homeEmptyTitle = '暂无股票持仓';
  static const String homeEmptySubtitle = '点击右上角 + 添加股票开始投资';
  static const String homeStockHeader = '股票';
  static const String homeHoldingHeader = '持仓';
  static const String homeProfitHeader = '盈亏';

  // 底部 Tab 文案
  static const String tabStock = '股票';
  static const String tabAsset = '资产';
  static const String assetComingSoon = '资产页面正在开发中';
  static const String assetComingSoonDesc = '敬请期待';

  // StockCard 文案
  static const String stockTotalValue = '总市值';
  static const String stockRecord = '记录';
  static const String stockMore = '更多';
  static const String stockSharesSuffix = '股';
  static const String stockDetailTotalCost = '总成本';
  static const String stockDetailAvgPrice = '持仓均价';
  static const String stockDetailMaxPrice = '最高购买价';
  static const String stockDetailMinPrice = '最低购买价';
  static const String stockDetailBuyCount = '加仓次数';
  static const String stockDetailSellCount = '减仓次数';

  // 操作/记录 文案
  static const String opBuy = '买入';
  static const String opSell = '卖出';
  static const String opAddPosition = '加仓';
  static const String opReducePosition = '减仓';
  static const String opClosePosition = '平仓';
  static const String opOpenPosition = '开仓';
  static const String opDeleteStock = '删除股票';
  static const String opDividend = '派息';
  static const String opMoreActions = '更多操作';
  static const String opConfirmDelete = '确认删除';

  // 编辑对话框 文案
  static const String editPriceHint = '成交价';
  static const String editPricePlaceholder = '请输入价格';
  static const String editFeeLabel = '手续费（可选）';
  static const String editFeePlaceholder = '请输入手续费';
  static const String editAddSharesLabel = '加仓股数';
  static const String editReduceSharesLabel = '减仓股数';
  static const String editAddSharesHint = '请输入加仓股数';
  static const String editReduceSharesHint = '请输入减仓股数';
  static const String editInvalidInput = '请输入有效的股数和价格';
  static const String editOverflow = '减仓股数不能超过持股数';
  static const String deleteConfirmContent = '确定要删除 {symbol} ({name}) 吗?';

  // 派息对话框 文案
  static const String dividendTitle = '派息';
  static const String dividendDateLabel = '派息日期';
  static const String dividendAmountLabel = '每股派息金额';
  static const String dividendAmountHint = '请输入每股派息金额';
  static const String dividendTaxRateLabel = '税率';
  static const String dividendConfirm = '确认派息';
  static const String dividendInvalidAmount = '请输入有效的派息金额';
  static const String dividendSuccess = '派息成功';
  static const String dividendEditTitle = '编辑派息记录';
  static const String dividendEditAmountLabel = '每股派息金额';
  static const String dividendEditSharesLabel = '持仓股数';
  static const String dividendEditDateLabel = '派息日期';

  // 搜索对话框 文案
  static const String searchTitle = '添加股票';
  static const String searchHint = '输入股票名称或代码（如 AAPL、腾讯）';
  static const String searchRateLimit = '请求过于频繁，请{secs}秒后再试';
  static const String searchRateLimitShort = '请求过于频繁，请稍后再试';
  static const String searchNotFound = '未找到相关股票';
  static const String searchNotFoundMarket = '未找到相关{market}股票';
  static const String searchFailed = '搜索失败，请重试';
  static const String searchInitHint = '输入名称或代码搜索港股/美股/A股';
  static const String searchInitExample = '如：AAPL、腾讯、00700、TSLA、600519';
  static const String searchAlreadyExists = '{code} 已在持仓中';
  static const String searchAddTitle = '添加 {code}';
  static const String searchStockName = '股票名称';
  static const String searchStockCode = '股票代码';
  static const String searchMarket = '市场';
  static const String searchRealtimePrice = '实时价格';
  static const String searchBuyPrice = '买入价格';
  static const String searchBuyPriceHint = '请输入买入价格';
  static const String searchShares = '持股数量';
  static const String searchSharesHint = '请输入持股数量';
  static const String searchInvalidPrice = '请输入有效的买入价格';
  static const String searchInvalidShares = '请输入有效的持股数量';
  static const String searchQuoteUnavailable = '暂无法获取';

  // 记录对话框 文案
  static const String recordsOpTab = '操作';
  static const String recordsDivTab = '派息';
  static const String recordsEmptyOp = '暂无操作记录';
  static const String recordsEmptyOpHint = '点击"记录"按钮添加第一次操作';
  static const String recordsEmptyDiv = '暂无派息记录';
  static const String recordsEmptyDivHint = '点击更多菜单中的"派息"添加记录';
  static const String profitNoData = '暂无数据';
  static const String filterMarketTitle = '筛选市场';
  static const String dragBetweenCategoriesHint = '请在分类标题之间拖拽';

  static const String recordsDivAmountPerShare = '每股';
  static const String recordsDivShares = '持仓股数';
  static const String recordsDivTotal = '总派息';
  static const String recordsOperationTime = '更新时间';
  static const String recordsDateLabel = '创建时间';
  static const String recordsOpTotalValue = '总市值';
  static const String recordsOpTotalCost = '总成本';
  static const String recordsDeleteOpConfirm = '确定删除此条操作记录？';
  static const String recordsDeleteDivConfirm = '确定删除此条派息记录？';
  static const String recordsDeleteHint = '左滑可删除，删除后不可恢复，持仓数据将自动重算，请谨慎操作';
  static const String recordsDivDeleteHint = '左滑可删除，删除后不可恢复，资产数据将自动重算，请谨慎操作';
  static const String recordsFormulaLabel = '计算公式';
  static const String recordsOpLabel = '市值';
  static const String recordsDivLabel = '股息';
  static const String recordsEditTitle = '编辑{desc}';
  static const String recordsEditPrice = '价格';
  static const String recordsEditShares = '股数';
  static const String recordsDatePattern = 'yyyy-MM-dd';
  static const String recordsDateTimePattern = 'yyyy-MM-dd HH:mm';
  static const String recordsTimesSign = ' × ';

  // 操作结果 文案
  static const String resultCloseSuccess = '平仓成功';
  static const String resultOpenSuccess = '开仓成功';
  static const String resultAddSuccess = '加仓成功';
  static const String resultReduceSuccess = '减仓成功';
  static const String resultDeleteSuccess = '删除成功';
  static const String resultAddStockSuccess = '添加成功';

  // 收益曲线 文案
  static const String profitChartTitle = '盈亏曲线';
  static const String profitRangeToday = '今天';
  static const String profitRange7d = '7天';
  static const String profitRange30d = '30天';
  static const String profitRange180d = '180天';
  static const String profitRange360d = '360天';

  // 全局股息页 文案
  static const String dividendOverviewTitle = '股息记录';
  static const String dividendOverviewEmpty = '暂无派息记录';
  static const String dividendOverviewEmptyHint = '在股票卡片更多菜单中添加派息';
  static const String dividendTabByStock = '按股票';
  static const String dividendTabByRecord = '按记录';
  static const String dividendCostYield = '成本股息率';
  static const String dividendMarketYield = '现价股息率';
  static const String dividendTotalAfterTax = '税后总股息';
  static const String dividendTrailing12m = '近12月股息';
  static const String dividendCurrentCost = '当前成本';
  static const String dividendCurrentValue = '当前市值';
  static const String dividendRecordCount = '条派息记录';
  static const String dividendExpandAll = '展开全部记录';
  static const String dividendLatestDate = '最新派息';
  static const String dividendSortYield = '按现价股息率';
  static const String dividendSortCostYield = '按成本股息率';
  static const String dividendSortAmount = '按税后总股息';
  static const String dividendSortDate = '按最近派息';
  static const String dividendSortName = '按名称';
  static const String dividendRecords = '派息记录';
  static const String dividendAllMarkets = '全部市场';
}
