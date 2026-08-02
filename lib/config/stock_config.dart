import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

class StockConfig {
  StockConfig._();

  // 底部 Tab 图标
  static const IconData iconTabStock = Icons.show_chart;
  static const IconData iconTabAsset = Icons.account_balance_wallet;
  static const IconData iconAdd = Icons.add;

  // StockHeaderCard 文案
  static String get assetTotalAssets => L10n.t('assetTotalAssets');
  static String get assetTodayProfit => L10n.t('assetTodayProfit');
  static String get assetTodayProfitHelp => L10n.t('assetTodayProfitHelp');
  static String get assetTotalCost => L10n.t('assetTotalCost');
  static String get assetTotalProfit => L10n.t('assetTotalProfit');
  static String get assetTotalDividends => L10n.t('assetTotalDividends');
  static String get assetExchangeRate => L10n.t('assetExchangeRate');
  static String get assetSelectCurrency => L10n.t('assetSelectCurrency');
  static String get assetTotalCostHelp => L10n.t('assetTotalCostHelp');
  static String get assetTotalRealizedPL => L10n.t('assetTotalRealizedPL');
  static String get assetTotalProfitHelp => L10n.t('assetTotalProfitHelp');
  static String get assetTotalAssetsHelp => L10n.t('assetTotalAssetsHelp');
  static String get assetTotalDividendsHelp =>
      L10n.t('assetTotalDividendsHelp');
  static String get assetTotalSellAmount => L10n.t('assetTotalSellAmount');
  static String get assetCostDetailLabel => L10n.t('assetCostDetailLabel');
  static String get assetFloatProfitLabel => L10n.t('assetFloatProfitLabel');
  static String get assetAfterTaxDividendsLabel =>
      L10n.t('assetAfterTaxDividendsLabel');
  static String get assetDividendRateLabel => L10n.t('assetDividendRateLabel');
  static String get assetPositionRatioLabel =>
      L10n.t('assetPositionRatioLabel');
  static String get assetPositionRatioHelp => L10n.t('assetPositionRatioHelp');

  // 首页 文案
  static String get homeTitle => L10n.t('homeTitle');
  static String get homeSubtitle => L10n.t('homeSubtitle');
  static String get homeSubtitleRefresh => L10n.t('homeSubtitleRefresh');
  static String get homeEmptyTitle => L10n.t('homeEmptyTitle');
  static String get homeEmptySubtitle => L10n.t('homeEmptySubtitle');
  static String get homeStockHeader => L10n.t('homeStockHeader');
  static String get homeHoldingHeader => L10n.t('homeHoldingHeader');
  static String get homeProfitHeader => L10n.t('homeProfitHeader');

  // 底部 Tab 文案
  static String get tabStock => L10n.t('tabStock');
  static String get tabAsset => L10n.t('tabAsset');
  static String get assetComingSoon => L10n.t('assetComingSoon');
  static String get assetComingSoonDesc => L10n.t('assetComingSoonDesc');

  // StockCard 文案
  static String get stockTotalValue => L10n.t('stockTotalValue');
  static String get stockRecord => L10n.t('stockRecord');
  static String get stockMore => L10n.t('stockMore');
  static String get stockSharesSuffix => L10n.t('stockSharesSuffix');
  static String get stockDetailTotalCost => L10n.t('stockDetailTotalCost');
  static String get stockDetailAvgPrice => L10n.t('stockDetailAvgPrice');
  static String get stockDetailMaxPrice => L10n.t('stockDetailMaxPrice');
  static String get stockDetailMinPrice => L10n.t('stockDetailMinPrice');
  static String get stockDetailBuyCount => L10n.t('stockDetailBuyCount');
  static String get stockDetailSellCount => L10n.t('stockDetailSellCount');

  // 操作类型（内部稳定标识，用于持久化与逻辑判断，保持历史数据兼容）
  static const String opBuyType = '买入';
  static const String opSellType = '卖出';

  // 操作/记录 文案（展示用，随语言变化）
  static String get opBuy => L10n.t('opBuy');
  static String get opSell => L10n.t('opSell');
  static String get opAddPosition => L10n.t('opAddPosition');
  static String get opReducePosition => L10n.t('opReducePosition');
  static String get opClosePosition => L10n.t('opClosePosition');
  static String get opOpenPosition => L10n.t('opOpenPosition');
  static String get opDeleteStock => L10n.t('opDeleteStock');
  static String get opDividend => L10n.t('opDividend');
  static String get opMoreActions => L10n.t('opMoreActions');
  static String get opConfirmDelete => L10n.t('opConfirmDelete');

  // 编辑对话框 文案
  static String get editPriceHint => L10n.t('editPriceHint');
  static String get editPricePlaceholder => L10n.t('editPricePlaceholder');
  static String get editFeeLabel => L10n.t('editFeeLabel');
  static String get editFeePlaceholder => L10n.t('editFeePlaceholder');
  static String get editAddSharesLabel => L10n.t('editAddSharesLabel');
  static String get editReduceSharesLabel => L10n.t('editReduceSharesLabel');
  static String get editAddSharesHint => L10n.t('editAddSharesHint');
  static String get editReduceSharesHint => L10n.t('editReduceSharesHint');
  static String get editInvalidInput => L10n.t('editInvalidInput');
  static String get editOverflow => L10n.t('editOverflow');
  static String get deleteConfirmContent => L10n.t('deleteConfirmContent');

  // 派息对话框 文案
  static String get dividendTitle => L10n.t('dividendTitle');
  static String get dividendDateLabel => L10n.t('dividendDateLabel');
  static String get dividendAmountLabel => L10n.t('dividendAmountLabel');
  static String get dividendAmountHint => L10n.t('dividendAmountHint');
  static String get dividendTaxRateLabel => L10n.t('dividendTaxRateLabel');
  static String get dividendConfirm => L10n.t('dividendConfirm');
  static String get dividendInvalidAmount => L10n.t('dividendInvalidAmount');
  static String get dividendSuccess => L10n.t('dividendSuccess');
  static String get dividendEditTitle => L10n.t('dividendEditTitle');
  static String get dividendEditAmountLabel =>
      L10n.t('dividendEditAmountLabel');
  static String get dividendEditSharesLabel =>
      L10n.t('dividendEditSharesLabel');
  static String get dividendEditDateLabel => L10n.t('dividendEditDateLabel');

  // 搜索对话框 文案
  static String get searchTitle => L10n.t('searchTitle');
  static String get searchHint => L10n.t('searchHint');
  static String get searchRateLimit => L10n.t('searchRateLimit');
  static String get searchRateLimitShort => L10n.t('searchRateLimitShort');
  static String get searchNotFound => L10n.t('searchNotFound');
  static String get searchNotFoundMarket => L10n.t('searchNotFoundMarket');
  static String get searchFailed => L10n.t('searchFailed');
  static String get searchInitHint => L10n.t('searchInitHint');
  static String get searchInitExample => L10n.t('searchInitExample');
  static String get searchAlreadyExists => L10n.t('searchAlreadyExists');
  static String get searchAddTitle => L10n.t('searchAddTitle');
  static String get searchStockName => L10n.t('searchStockName');
  static String get searchStockCode => L10n.t('searchStockCode');
  static String get searchMarket => L10n.t('searchMarket');
  static String get searchRealtimePrice => L10n.t('searchRealtimePrice');
  static String get searchBuyPrice => L10n.t('searchBuyPrice');
  static String get searchBuyPriceHint => L10n.t('searchBuyPriceHint');
  static String get searchShares => L10n.t('searchShares');
  static String get searchSharesHint => L10n.t('searchSharesHint');
  static String get searchInvalidPrice => L10n.t('searchInvalidPrice');
  static String get searchInvalidShares => L10n.t('searchInvalidShares');
  static String get searchQuoteUnavailable => L10n.t('searchQuoteUnavailable');

  // 记录对话框 文案
  static String get recordsOpTab => L10n.t('recordsOpTab');
  static String get recordsDivTab => L10n.t('recordsDivTab');
  static String get recordsEmptyOp => L10n.t('recordsEmptyOp');
  static String get recordsEmptyOpHint => L10n.t('recordsEmptyOpHint');
  static String get recordsEmptyDiv => L10n.t('recordsEmptyDiv');
  static String get recordsEmptyDivHint => L10n.t('recordsEmptyDivHint');
  static String get profitNoData => L10n.t('profitNoData');
  static String get filterMarketTitle => L10n.t('filterMarketTitle');
  static String get dragBetweenCategoriesHint =>
      L10n.t('dragBetweenCategoriesHint');

  static String get recordsDivAmountPerShare =>
      L10n.t('recordsDivAmountPerShare');
  static String get recordsDivShares => L10n.t('recordsDivShares');
  static String get recordsDivTotal => L10n.t('recordsDivTotal');
  static String get recordsOperationTime => L10n.t('recordsOperationTime');
  static String get recordsDateLabel => L10n.t('recordsDateLabel');
  static String get recordsOpTotalValue => L10n.t('recordsOpTotalValue');
  static String get recordsOpTotalCost => L10n.t('recordsOpTotalCost');
  static String get recordsDeleteOpConfirm => L10n.t('recordsDeleteOpConfirm');
  static String get recordsDeleteDivConfirm =>
      L10n.t('recordsDeleteDivConfirm');
  static String get recordsDeleteHint => L10n.t('recordsDeleteHint');
  static String get recordsDivDeleteHint => L10n.t('recordsDivDeleteHint');
  static String get recordsFormulaLabel => L10n.t('recordsFormulaLabel');
  static String get recordsOpLabel => L10n.t('recordsOpLabel');
  static String get recordsDivLabel => L10n.t('recordsDivLabel');
  static String get recordsEditTitle => L10n.t('recordsEditTitle');
  static String get recordsEditPrice => L10n.t('recordsEditPrice');
  static String get recordsEditShares => L10n.t('recordsEditShares');
  static const String recordsDatePattern = 'yyyy-MM-dd';
  static const String recordsDateTimePattern = 'yyyy-MM-dd HH:mm';
  static const String recordsTimesSign = ' × ';

  // 操作结果 文案
  static String get resultCloseSuccess => L10n.t('resultCloseSuccess');
  static String get resultOpenSuccess => L10n.t('resultOpenSuccess');
  static String get resultAddSuccess => L10n.t('resultAddSuccess');
  static String get resultReduceSuccess => L10n.t('resultReduceSuccess');
  static String get resultDeleteSuccess => L10n.t('resultDeleteSuccess');
  static String get resultAddStockSuccess => L10n.t('resultAddStockSuccess');

  // 收益曲线 文案
  static String get profitChartTitle => L10n.t('profitChartTitle');
  static String get profitRangeToday => L10n.t('profitRangeToday');
  static String get profitRange7d => L10n.t('profitRange7d');
  static String get profitRange30d => L10n.t('profitRange30d');
  static String get profitRange180d => L10n.t('profitRange180d');
  static String get profitRange360d => L10n.t('profitRange360d');

  // 全局股息页 文案
  static String get dividendOverviewTitle => L10n.t('dividendOverviewTitle');
  static String get dividendOverviewEmpty => L10n.t('dividendOverviewEmpty');
  static String get dividendOverviewEmptyHint =>
      L10n.t('dividendOverviewEmptyHint');
  static String get dividendTabByStock => L10n.t('dividendTabByStock');
  static String get dividendTabByRecord => L10n.t('dividendTabByRecord');
  static String get dividendCostYield => L10n.t('dividendCostYield');
  static String get dividendMarketYield => L10n.t('dividendMarketYield');
  static String get dividendTotalAfterTax => L10n.t('dividendTotalAfterTax');
  static String get dividendTrailing12m => L10n.t('dividendTrailing12m');
  static String get dividendCurrentCost => L10n.t('dividendCurrentCost');
  static String get dividendCurrentValue => L10n.t('dividendCurrentValue');
  static String get dividendRecordCount => L10n.t('dividendRecordCount');
  static String get dividendExpandAll => L10n.t('dividendExpandAll');
  static String get dividendLatestDate => L10n.t('dividendLatestDate');
  static String get dividendSortYield => L10n.t('dividendSortYield');
  static String get dividendSortCostYield => L10n.t('dividendSortCostYield');
  static String get dividendSortAmount => L10n.t('dividendSortAmount');
  static String get dividendSortDate => L10n.t('dividendSortDate');
  static String get dividendSortName => L10n.t('dividendSortName');
  static String get dividendRecords => L10n.t('dividendRecords');
  static String get dividendAllMarkets => L10n.t('dividendAllMarkets');

  /// 将记录 description 中的操作词（可能为创建时语言的任意一种）替换为当前语言
  static String localizeRecordDescription(String description) {
    const map = {
      '开仓': 'opOpenPosition',
      '加仓': 'opAddPosition',
      '减仓': 'opReducePosition',
      '平仓': 'opClosePosition',
      '開倉': 'opOpenPosition',
      '加倉': 'opAddPosition',
      '減倉': 'opReducePosition',
      '平倉': 'opClosePosition',
      'Open': 'opOpenPosition',
      'Add': 'opAddPosition',
      'Reduce': 'opReducePosition',
      'Close': 'opClosePosition',
    };
    for (final entry in map.entries) {
      if (description.startsWith(entry.key)) {
        final rest = description.substring(entry.key.length);
        return '${L10n.t(entry.value)}$rest';
      }
    }
    return description;
  }
}
