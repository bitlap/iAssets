import 'dart:convert';
import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/exchange_rate_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Isolates all persistence and fixes USD/CNY/HKD rates without network access.
Future<Directory> initializeTestStorage() async {
  final dir = Directory.systemTemp.createTempSync('iassets-core-tests-');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => dir.path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('org.bitlap.assets/icloud'),
    (_) async => null,
  );
  File('${dir.path}/exchange_rates.json').writeAsStringSync(
    jsonEncode({'USD': 1, 'CNY': 7, 'CNH': 7, 'HKD': 8, 'EUR': .5}),
  );
  final rates = ExchangeRateService();
  // Allow its platform path lookup to finish before any synchronous conversion.
  await Future<void>.delayed(Duration.zero);
  expect(rates.effectiveRates['CNY'], 7);
  return dir;
}

StockModel stock({
  String symbol = 'TEST',
  String currency = 'USD',
  double price = 12,
  double shares = 10,
  double? value,
  double profit = 20,
  bool custom = false,
}) => StockModel(
  symbol: symbol,
  companyName: '$symbol company',
  currentPrice: price,
  shares: shares,
  totalValue: value ?? price * shares,
  profitLossPercent: 20,
  profitLossAmount: profit,
  isPositive: profit >= 0,
  currency: currency,
  secid: '105.$symbol',
  isCustom: custom,
);

OperationRecord trade({
  String type = StockConfig.opBuyType,
  double price = 10,
  double shares = 10,
  double fee = 0,
}) => OperationRecord(
  date: DateTime.utc(2026, 1, 2),
  operationTime: DateTime.utc(2026, 1, 2, 14, 30),
  type: type,
  description: 'test trade',
  amount: price,
  shares: shares,
  fee: fee,
);

DividendRecord dividend({
  DateTime? date,
  double amount = 1,
  double shares = 10,
  double tax = .1,
  String currency = 'USD',
}) => DividendRecord(
  date: date ?? DateTime(2026, 1, 2),
  operationTime: DateTime.utc(2026, 1, 3, 12),
  amount: amount,
  shares: shares,
  taxRate: tax,
  currency: currency,
);
