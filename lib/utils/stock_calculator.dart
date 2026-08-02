import '../config/app_config.dart';
import '../models/stock_model.dart';
import '../models/calculator_models.dart';
import 'currency_util.dart';

/// 持仓计算工具类 - 所有与操作记录相关的计算逻辑
class StockCalculator {
  /// 从操作记录计算完整统计信息
  static RecordStats calculateRecordStats(List<OperationRecord> records) {
    if (records.isEmpty) return const RecordStats();

    double currentShares = 0;
    double totalBuyAmount = 0.0;
    double totalSellAmount = 0.0;
    double maxBuyPrice = 0.0;
    double minBuyPrice = double.infinity;
    int buyCount = 0;
    int sellCount = 0;

    for (final record in records) {
      if (record.type == StockConfig.opBuyType) {
        currentShares += record.shares;
        totalBuyAmount += record.amount * record.shares + record.fee;
        buyCount++;
        if (record.amount > maxBuyPrice) maxBuyPrice = record.amount;
        if (record.amount < minBuyPrice) minBuyPrice = record.amount;
      } else if (record.type == StockConfig.opSellType) {
        currentShares -= record.shares;
        totalSellAmount += record.amount * record.shares - record.fee;
        sellCount++;
      }
    }

    // 防止浮点误差导致负数
    if (currentShares < 0) currentShares = 0;
    if (minBuyPrice == double.infinity) minBuyPrice = 0.0;

    // 持仓均价 = 净成本 ÷ 当前持股数（考虑卖出）
    final avgBuyPrice = currentShares > 0
        ? (totalBuyAmount - totalSellAmount) / currentShares
        : 0.0;

    return RecordStats(
      currentShares: currentShares,
      totalBuyAmount: totalBuyAmount,
      totalSellAmount: totalSellAmount,
      buyCount: buyCount,
      sellCount: sellCount,
      maxBuyPrice: maxBuyPrice,
      minBuyPrice: minBuyPrice,
      avgBuyPrice: avgBuyPrice,
    );
  }

  /// 从操作记录计算持仓均价（考虑卖出，净成本均摊到剩余股份）
  static double calculateAvgBuyPrice(List<OperationRecord> records) {
    double totalBuyAmount = 0.0;
    double totalSellAmount = 0.0;
    double currentShares = 0.0;
    for (final r in records) {
      if (r.type == StockConfig.opBuyType) {
        totalBuyAmount += r.amount * r.shares + r.fee;
        currentShares += r.shares;
      } else if (r.type == StockConfig.opSellType) {
        totalSellAmount += r.amount * r.shares - r.fee;
        currentShares -= r.shares;
      }
    }
    if (currentShares <= 0) return 0.0;
    return (totalBuyAmount - totalSellAmount) / currentShares;
  }

  /// 计算资产汇总（所有金额转换为目标币种）
  static AssetSummary calculateAssetSummary(
    List<StockModel> stocks,
    Map<String, List<OperationRecord>> operationRecords, [
    Map<String, List<DividendRecord>>? dividendRecords,
    String targetCurrency = AppConfig.defaultCurrency,
  ]) {
    double totalMarketValue = 0.0;
    double unrealizedPL = 0.0;
    double realizedPL = 0.0;
    double totalBuyAmount = 0.0;
    double totalSellAmount = 0.0;
    double totalCost = 0.0;

    for (final stock in stocks) {
      final mv = CurrencyUtil.convertCurrency(
        stock.totalValue,
        stock.currency,
        targetCurrency,
      );
      totalMarketValue += mv;

      if (stock.shares > 0) {
        final pl = CurrencyUtil.convertCurrency(
          stock.profitLossAmount,
          stock.currency,
          targetCurrency,
        );
        unrealizedPL += pl;
      } else {
        final pl = CurrencyUtil.convertCurrency(
          stock.profitLossAmount,
          stock.currency,
          targetCurrency,
        );
        realizedPL += pl;
      }

      final records = operationRecords[stock.symbol] ?? [];
      final stats = calculateRecordStats(records);
      totalBuyAmount += CurrencyUtil.convertCurrency(
        stats.totalBuyAmount,
        stock.currency,
        targetCurrency,
      );
      totalSellAmount += CurrencyUtil.convertCurrency(
        stats.totalSellAmount,
        stock.currency,
        targetCurrency,
      );
      if (stock.shares > 0) {
        totalCost += CurrencyUtil.convertCurrency(
          stats.totalBuyAmount - stats.totalSellAmount,
          stock.currency,
          targetCurrency,
        );
      }
    }

    // 总盈亏 = 持仓浮盈 + 已实现盈亏
    final totalProfit = unrealizedPL + realizedPL;

    // 总资产 = 当前持仓市值 + 累计卖出金额
    final totalAssets = totalMarketValue + totalSellAmount;

    // 总股息
    final totalAfterTaxDividends = stocks.fold(0.0, (sum, stock) {
      final divs = dividendRecords?[stock.symbol] ?? [];
      final stockDivTotal = divs.fold(0.0, (s, r) => s + r.afterTaxAmount);
      return sum +
          CurrencyUtil.convertCurrency(
            stockDivTotal,
            stock.currency,
            targetCurrency,
          );
    });

    // 总盈亏百分比 = 总盈亏 / 总买入金额
    final double totalProfitPercent;
    if (totalBuyAmount > 0) {
      totalProfitPercent = totalProfit / totalBuyAmount * 100;
    } else {
      totalProfitPercent = 0.0;
    }

    return AssetSummary(
      totalAssets: totalAssets,
      totalMarketValue: totalMarketValue,
      totalCost: totalCost,
      totalProfit: totalProfit,
      totalRealizedPL: realizedPL,
      totalProfitPercent: totalProfitPercent,
      totalSellAmount: totalSellAmount,
      totalAfterTaxDividends: totalAfterTaxDividends,
    );
  }

  /// 排序股票列表
  /// [sortColumn] 'name' = 按代码, 'holdings' = 按持仓价值, 'profit' = 按盈亏
  static List<StockModel> sortStocks(
    List<StockModel> source,
    String sortColumn,
    bool ascending,
    String targetCurrency,
  ) {
    final sorted = List<StockModel>.from(source);
    sorted.sort((a, b) {
      int cmp;
      switch (sortColumn) {
        case 'name':
          cmp = a.symbol.compareTo(b.symbol);
          break;
        case 'holdings':
          final valueA = CurrencyUtil.convertCurrency(
            a.currentPrice * a.shares,
            a.currency,
            targetCurrency,
          );
          final valueB = CurrencyUtil.convertCurrency(
            b.currentPrice * b.shares,
            b.currency,
            targetCurrency,
          );
          cmp = valueA.compareTo(valueB);
          if (cmp == 0) cmp = a.shares.compareTo(b.shares);
          break;
        case 'profit':
          final plA = CurrencyUtil.convertCurrency(
            a.profitLossAmount,
            a.currency,
            targetCurrency,
          );
          final plB = CurrencyUtil.convertCurrency(
            b.profitLossAmount,
            b.currency,
            targetCurrency,
          );
          cmp = plA.compareTo(plB);
          if (cmp == 0) {
            final valA = CurrencyUtil.convertCurrency(
              a.totalValue,
              a.currency,
              targetCurrency,
            );
            final valB = CurrencyUtil.convertCurrency(
              b.totalValue,
              b.currency,
              targetCurrency,
            );
            cmp = valA.compareTo(valB);
          }
          break;
        default:
          cmp = 0;
      }
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  /// 根据操作记录重算股票的持仓数据
  /// 返回更新后的 StockModel，如果无记录则返回原股票
  static StockModel recalculateFromRecords(
    StockModel stock,
    List<OperationRecord> records,
  ) {
    if (records.isEmpty) return stock;

    final stats = calculateRecordStats(records);

    // 当前总持仓金额 = 当前价格 × 当前数量
    final totalValue = stock.currentPrice * stats.currentShares;

    // 如果当前没有持股，已实现盈亏 = 总卖出 - 总买入
    if (stats.currentShares == 0) {
      final realizedPL = stats.totalSellAmount - stats.totalBuyAmount;
      return stock.copyWith(
        shares: 0,
        totalValue: 0,
        profitLossAmount: realizedPL,
        profitLossPercent: 0,
        isPositive: realizedPL >= 0,
      );
    }

    // 持仓均价 = 净成本 ÷ 当前持股数（考虑卖出）
    final avgCost = stats.avgBuyPrice;

    // 盈亏 = 当前总价值 - (持仓均价 × 当前持股数)
    final profitLossAmount = totalValue - avgCost * stats.currentShares;

    // 盈亏百分比 = (当前价 - 持仓均价) ÷ 持仓均价 × 100%
    final profitLossPercent = avgCost > 0
        ? ((stock.currentPrice - avgCost) / avgCost * 100.0)
        : 0.0;
    // 盈亏方向：持仓均价 <= 当前价 = 盈利
    final isPositive = avgCost <= stock.currentPrice;

    return stock.copyWith(
      shares: stats.currentShares,
      totalValue: totalValue,
      profitLossAmount: profitLossAmount,
      profitLossPercent: profitLossPercent,
      isPositive: isPositive,
    );
  }

  /// 计算单只股票的全局股息聚合项
  static GlobalDividendStockItem calculateDividendItem(
    StockModel stock,
    List<OperationRecord> operationRecords,
    List<DividendRecord> dividendRecords,
  ) {
    final stats = calculateRecordStats(operationRecords);
    final shares = stock.shares;
    final avgCost = stats.avgBuyPrice;
    final currentCost = avgCost * shares;
    final currentMarketValue = stock.currentPrice * shares;
    final now = DateTime.now();
    final trailingCutoff = DateTime(now.year - 1, now.month, now.day);
    double totalAfterTax = 0;
    double trailingAfterTax = 0;
    DateTime? latestDate;
    for (final r in dividendRecords) {
      if (latestDate == null || r.date.isAfter(latestDate)) latestDate = r.date;
      totalAfterTax += r.afterTaxAmount;
      if (!r.date.isBefore(trailingCutoff)) {
        trailingAfterTax += r.afterTaxAmount;
      }
    }
    return GlobalDividendStockItem(
      symbol: stock.symbol,
      companyName: stock.companyName,
      marketType: stock.marketType,
      currency: stock.currency,
      currentShares: shares,
      currentCost: currentCost,
      currentMarketValue: currentMarketValue,
      totalAfterTaxDividends: totalAfterTax,
      trailingAfterTaxDividends: trailingAfterTax,
      costDividendYield: currentCost > 0
          ? trailingAfterTax / currentCost * 100
          : 0,
      marketDividendYield: currentMarketValue > 0
          ? trailingAfterTax / currentMarketValue * 100
          : 0,
      latestDividendDate: latestDate,
      recordCount: dividendRecords.length,
      records: dividendRecords,
    );
  }

  /// 计算全局股息汇总
  static GlobalDividendOverview calculateGlobalDividendOverview(
    List<StockModel> stocks,
    Map<String, List<OperationRecord>> operationRecords,
    Map<String, List<DividendRecord>> dividendRecords,
    String targetCurrency,
  ) {
    final items = <GlobalDividendStockItem>[];
    double totalAfterTax = 0;
    double trailingAfterTax = 0;
    double totalCost = 0;
    double totalMarketValue = 0;
    for (final stock in stocks) {
      final divs = dividendRecords[stock.symbol] ?? [];
      if (divs.isEmpty) continue;
      final item = calculateDividendItem(
        stock,
        operationRecords[stock.symbol] ?? [],
        divs,
      );
      items.add(item);
      totalAfterTax += CurrencyUtil.convertCurrency(
        item.totalAfterTaxDividends,
        item.currency,
        targetCurrency,
      );
      trailingAfterTax += CurrencyUtil.convertCurrency(
        item.trailingAfterTaxDividends,
        item.currency,
        targetCurrency,
      );
      totalCost += CurrencyUtil.convertCurrency(
        item.currentCost,
        item.currency,
        targetCurrency,
      );
      totalMarketValue += CurrencyUtil.convertCurrency(
        item.currentMarketValue,
        item.currency,
        targetCurrency,
      );
    }
    return GlobalDividendOverview(
      items: items,
      totalAfterTaxDividends: totalAfterTax,
      trailingAfterTaxDividends: trailingAfterTax,
      totalCurrentCost: totalCost,
      totalCurrentMarketValue: totalMarketValue,
      costDividendYield: totalCost > 0 ? trailingAfterTax / totalCost * 100 : 0,
      marketDividendYield: totalMarketValue > 0
          ? trailingAfterTax / totalMarketValue * 100
          : 0,
    );
  }
}
