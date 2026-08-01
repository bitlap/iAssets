import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const String stocksFile = 'stocks.json';
const String recordsFile = 'records.json';
const String dividendRecordsFile = 'dividend_records.json';
const String profitHistoryFile = 'profit_history.json';
const String dailyProfitFile = 'profit_history_daily.json';
const String intradayProfitFile = 'profit_history_intraday.json';
const String settingsFile = 'settings.json';
const String assetsFile = 'assets.json';
const String exchangeRatesFile = 'exchange_rates.json';
const String todayBaselineFile = 'today_baseline.json';

String localFilePath(String localPath, String name) => '$localPath/$name';

Future<List<Map<String, dynamic>>> readJson(
  String localPath,
  String name,
) async {
  final file = File(localFilePath(localPath, name));
  if (!await file.exists()) {
    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][本地] ===> 文件不存在: $name',
    );
    return [];
  }
  try {
    final list = jsonDecode(await file.readAsString()) as List;
    return list.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][本地] ===> 读取文件失败: $name - $e',
    );
    return [];
  }
}

Future<void> writeJson(String localPath, String name, List<Map> data) async {
  final file = File(localFilePath(localPath, name));
  try {
    await file.writeAsString(jsonEncode(data));
  } catch (e) {
    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][本地] ===> 写入文件失败: $name - $e',
    );
  }
}
