import 'package:assets/config/app_config.dart';

import '../../models/stock_model.dart';
import '../../models/asset_account.dart';

List<Map<String, dynamic>> stocksToJson(List<StockModel> stocks) {
  return stocks
      .map(
        (s) => {
          'symbol': s.symbol,
          'companyName': s.companyName,
          'currentPrice': s.currentPrice,
          'shares': s.shares,
          'totalValue': s.totalValue,
          'profitLossPercent': s.profitLossPercent,
          'profitLossAmount': s.profitLossAmount,
          'isPositive': s.isPositive,
          'logoUrl': s.logoUrl,
          'marketType': s.marketType,
          'changePercent': s.changePercent,
          'currency': s.currency,
          'secid': s.secid,
        },
      )
      .toList();
}

List<StockModel> stocksFromJson(List<Map<String, dynamic>> json) {
  return json
      .map(
        (j) => StockModel(
          symbol: j['symbol'] as String,
          companyName: j['companyName'] as String,
          currentPrice: (j['currentPrice'] as num).toDouble(),
          shares: (j['shares'] as num).toDouble(),
          totalValue: (j['totalValue'] as num).toDouble(),
          profitLossPercent: (j['profitLossPercent'] as num).toDouble(),
          profitLossAmount: (j['profitLossAmount'] as num).toDouble(),
          isPositive: j['isPositive'] as bool,
          logoUrl: j['logoUrl'] as String?,
          marketType: j['marketType'] as String,
          changePercent: (j['changePercent'] as num).toDouble(),
          currency: j['currency'] as String?,
          secid: j['secid'] as String,
        ),
      )
      .toList();
}

List<Map<String, dynamic>> recordsToJson(
  Map<String, List<OperationRecord>> records,
) {
  return records.entries
      .where((e) => e.value.isNotEmpty)
      .map(
        (e) => {
          'symbol': e.key,
          'records': e.value
              .map(
                (r) => {
                  'date': r.date.toIso8601String(),
                  'operationTime': r.operationTime.toIso8601String(),
                  'type': r.type,
                  'description': r.description,
                  'amount': r.amount,
                  'shares': r.shares,
                  'fee': r.fee,
                },
              )
              .toList(),
        },
      )
      .toList();
}

Map<String, List<OperationRecord>> recordsFromJson(
  List<Map<String, dynamic>> json,
) {
  final map = <String, List<OperationRecord>>{};
  for (final entry in json) {
    map[entry['symbol'] as String] = (entry['records'] as List)
        .map(
          (r) => OperationRecord(
            date: r.containsKey('date')
                ? DateTime.parse(r['date'] as String)
                : DateTime.now(),
            operationTime: r.containsKey('operationTime')
                ? DateTime.parse(r['operationTime'] as String)
                : DateTime.parse(r['date'] as String),
            type: r['type'] as String,
            description: r['description'] as String,
            amount: (r['amount'] as num).toDouble(),
            shares: (r['shares'] as num).toDouble(),
            fee: (r['fee'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }
  return map;
}

List<Map<String, dynamic>> dividendRecordsToJson(
  Map<String, List<DividendRecord>> records,
) {
  return records.entries
      .where((e) => e.value.isNotEmpty)
      .map(
        (e) => {
          'symbol': e.key,
          'records': e.value
              .map(
                (r) => {
                  'date': r.date.toIso8601String(),
                  'operationTime': r.operationTime.toIso8601String(),
                  'amount': r.amount,
                  'shares': r.shares,
                  'taxRate': r.taxRate,
                  'currency': r.currency,
                },
              )
              .toList(),
        },
      )
      .toList();
}

List<Map<String, dynamic>> assetsToJson(List<AssetBase> assets) {
  return assets.map((a) => a.toJson()).toList();
}

List<AssetBase> assetsFromJson(List<Map<String, dynamic>> json) {
  return json.map((j) => AssetBase.fromJson(j)).toList();
}

Map<String, List<DividendRecord>> dividendRecordsFromJson(
  List<Map<String, dynamic>> json,
) {
  final map = <String, List<DividendRecord>>{};
  for (final entry in json) {
    map[entry['symbol'] as String] = (entry['records'] as List)
        .map(
          (r) => DividendRecord(
            date: r.containsKey('date')
                ? DateTime.parse(r['date'] as String)
                : DateTime.now(),
            operationTime: r.containsKey('operationTime')
                ? DateTime.parse(r['operationTime'] as String)
                : DateTime.parse(r['date'] as String),
            amount: (r['amount'] as num).toDouble(),
            shares: (r['shares'] as num).toDouble(),
            taxRate: r.containsKey('taxRate')
                ? (r['taxRate'] as num).toDouble()
                : 0.0,
            currency: r['currency'] as String? ?? AppConfig.defaultCurrency,
          ),
        )
        .toList();
  }
  return map;
}
