import 'package:assets/utils/currency_util.dart';

import '../config/app_config.dart';
import '../utils/market_util.dart';

/// 股票数据模型
class StockModel {
  final String symbol;
  final String companyName;
  final double currentPrice; // 股票自身币种价格
  final double shares;
  final double totalValue; // 股票自身币种总值
  final double profitLossPercent;
  final double profitLossAmount; // 股票自身币种盈亏
  final bool isPositive;
  final String? logoUrl; // Logo URL
  final String marketType; // 市场类型：美股、港股
  final double changePercent; // 日涨跌幅（%）
  final String? _currency; // 股票币种
  String get currency =>
      _currency ?? CurrencyUtil.currencyForMarket(marketType);
  final String? secid; // 东方财富 secid（用于获取行情）

  StockModel({
    required this.symbol,
    required this.companyName,
    required this.currentPrice,
    required this.shares,
    required this.totalValue,
    required this.profitLossPercent,
    required this.profitLossAmount,
    required this.isPositive,
    this.logoUrl,
    this.marketType = MarketUtil.searchMarketUS,
    this.changePercent = 0.0,
    String? currency,
    this.secid,
  }) : _currency = currency;

  /// 复制并修改
  StockModel copyWith({
    String? symbol,
    String? companyName,
    double? currentPrice,
    double? shares,
    double? totalValue,
    double? profitLossPercent,
    double? profitLossAmount,
    bool? isPositive,
    String? logoUrl,
    String? marketType,
    double? changePercent,
    String? currency,
    String? secid,
  }) {
    return StockModel(
      symbol: symbol ?? this.symbol,
      companyName: companyName ?? this.companyName,
      currentPrice: currentPrice ?? this.currentPrice,
      shares: shares ?? this.shares,
      totalValue: totalValue ?? this.totalValue,
      profitLossPercent: profitLossPercent ?? this.profitLossPercent,
      profitLossAmount: profitLossAmount ?? this.profitLossAmount,
      isPositive: isPositive ?? this.isPositive,
      logoUrl: logoUrl ?? this.logoUrl,
      marketType: marketType ?? this.marketType,
      changePercent: changePercent ?? this.changePercent,
      currency: currency ?? this.currency,
      secid: secid ?? this.secid,
    );
  }
}

/// 操作记录模型
class OperationRecord {
  final DateTime date; // 创建时间
  final DateTime operationTime; // 操作时间（含时分秒，编辑时更新）
  final String type;
  final String description;
  final double amount;
  final double shares;
  final double fee; // 交易手续费（可选，默认0）

  OperationRecord({
    required this.date,
    DateTime? operationTime,
    required this.type,
    required this.description,
    required this.amount,
    required this.shares,
    this.fee = 0.0,
  }) : operationTime = operationTime ?? DateTime.now();

  /// 复制并修改
  OperationRecord copyWith({
    DateTime? date,
    DateTime? operationTime,
    String? type,
    String? description,
    double? amount,
    double? shares,
    double? fee,
  }) {
    return OperationRecord(
      date: date ?? this.date,
      operationTime: operationTime ?? DateTime.now(),
      type: type ?? this.type,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      shares: shares ?? this.shares,
      fee: fee ?? this.fee,
    );
  }
}

/// 股息记录模型
class DividendRecord {
  final DateTime date; // 派息日期（仅日期）
  final DateTime operationTime; // 操作时间（含时分秒，编辑时更新）
  final double amount; // 每股派息金额
  final double shares; // 持仓股数
  final double taxRate; // 税率（0~1，如 0.1 表示 10%）
  final String currency;

  DividendRecord({
    required this.date,
    DateTime? operationTime,
    required this.amount,
    required this.shares,
    this.taxRate = 0.1,
    required this.currency,
  }) : operationTime = operationTime ?? DateTime.now();

  /// 总派息金额（税前）
  double get totalAmount => amount * shares;

  /// 税后股息
  double get afterTaxAmount => totalAmount * (1 - taxRate);

  /// 复制并修改
  DividendRecord copyWith({
    DateTime? date,
    DateTime? operationTime,
    double? amount,
    double? shares,
    double? taxRate,
    String? currency,
  }) {
    return DividendRecord(
      date: date ?? this.date,
      operationTime: operationTime ?? DateTime.now(),
      amount: amount ?? this.amount,
      shares: shares ?? this.shares,
      taxRate: taxRate ?? this.taxRate,
      currency: currency ?? this.currency,
    );
  }
}

/// 收益快照（用于收益曲线）
class ProfitSnapshot {
  final DateTime time;
  final double totalProfit;

  ProfitSnapshot({required this.time, required this.totalProfit});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'totalProfit': totalProfit,
  };

  factory ProfitSnapshot.fromJson(Map<String, dynamic> json) => ProfitSnapshot(
    time: DateTime.parse(json['time'] as String),
    totalProfit: (json['totalProfit'] as num).toDouble(),
  );
}
