import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/stock_model.dart';
import '../models/asset_account.dart';
import '../utils/currency_util.dart';
import '../utils/trading_day_util.dart';
import 'serde/serde.dart';
import 'settings_service.dart';

/// 本地持久化 + 配置 iCloud 同步服务
class IcloudStorage {
  static const _channel = MethodChannel('org.bitlap.assets/icloud');

  static String? _cloudPath;
  static String? _localPath;

  /// 初始化（获取本地 / iCloud 路径）
  static Future<void> ensureInit() async {
    if (_localPath != null) return;

    // 本地路径
    final localDir = await getApplicationDocumentsDirectory();
    _localPath = localDir.path;

    // 尝试获取 iCloud 路径（后台 isolate 无 MethodChannel，静默跳过）
    try {
      final cloudPath = await _channel.invokeMethod<String>('getContainerUrl');
      if (cloudPath != null && cloudPath.isNotEmpty) {
        final dir = Directory(cloudPath);
        if (!await dir.exists()) await dir.create(recursive: true);
        _cloudPath = cloudPath;
      }
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][iCloud] ===> 获取 iCloud 路径失败: $e，使用本地 fallback',
      );
    }
  }

  /// 保存股票和记录到本地
  static Future<void> saveStocks(
    List<StockModel> stocks,
    Map<String, List<OperationRecord>>? records,
    Map<String, List<DividendRecord>>? dividendRecords,
  ) async {
    await ensureInit();
    await writeJson(_localPath!, stocksFile, stocksToJson(stocks));
    if (records != null) {
      await writeJson(_localPath!, recordsFile, recordsToJson(records));
    }
    if (dividendRecords != null) {
      await writeJson(
        _localPath!,
        dividendRecordsFile,
        dividendRecordsToJson(dividendRecords),
      );
    }
    await _syncToCloud(stocksFile);
    if (records != null) {
      await _syncToCloud(recordsFile);
    }
    if (dividendRecords != null) {
      await _syncToCloud(dividendRecordsFile);
    }
  }

  /// 从本地加载股票和记录
  static Future<
    (
      List<StockModel> stocks,
      Map<String, List<OperationRecord>> records,
      Map<String, List<DividendRecord>> dividendRecords,
    )
  >
  loadStocks() async {
    await ensureInit();
    // 先尝试从 iCloud 拉取更新
    await _syncFromCloud(stocksFile);
    await _syncFromCloud(recordsFile);
    await _syncFromCloud(dividendRecordsFile);
    // 再读本地（此时已包含 iCloud 最新数据）
    final stocks = stocksFromJson(await readJson(_localPath!, stocksFile));
    final records = recordsFromJson(await readJson(_localPath!, recordsFile));
    final dividendRecords = dividendRecordsFromJson(
      await readJson(_localPath!, dividendRecordsFile),
    );
    return (stocks, records, dividendRecords);
  }

  /// 保存设置到本地 + 同步 iCloud
  static Future<void> pushSettingsToCloud(Map<String, dynamic> settings) async {
    await ensureInit();
    final localFile = File(localFilePath(_localPath!, settingsFile));
    await localFile.writeAsString(jsonEncode(settings));
    await _syncToCloud(settingsFile);
  }

  /// 加载设置（拉取 iCloud 更新后读本地）
  static Future<Map<String, dynamic>> pullSettingsFromCloud() async {
    await ensureInit();
    await _syncFromCloud(settingsFile);
    final local = File(localFilePath(_localPath!, settingsFile));
    if (!await local.exists()) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][本地] ===> 设置文件不存在: $settingsFile',
      );
      return {};
    }
    try {
      return jsonDecode(await local.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][本地] ===> 设置读取失败: $e',
      );
      return {};
    }
  }

  /// 从 iCloud 拉取设置到本地文件，并刷新 SettingsService 缓存
  static Future<void> loadSettings() async {
    final enabled = await SettingsService.getSyncSettings();
    if (!enabled) return;
    final cloud = await pullSettingsFromCloud();
    if (cloud.isEmpty) return;
    await SettingsService.applyAll(cloud);
  }

  /// 将当前设置同步到本地文件 + iCloud
  static Future<void> saveSettings() async {
    final enabled = await SettingsService.getSyncSettings();
    if (!enabled) return;
    final settings = await SettingsService.getAll();
    await pushSettingsToCloud(settings);
  }

  /// 将本地文件同步到 iCloud（若开启了同步且有 iCloud 路径）
  static Future<void> _syncToCloud(String name) async {
    if (_cloudPath == null) return;
    final enabled = await SettingsService.getSyncSettings();
    if (!enabled) return;
    final local = File(localFilePath(_localPath!, name));
    if (!await local.exists()) return;
    final cloud = File('$_cloudPath/$name');
    try {
      await cloud.writeAsString(await local.readAsString());
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][iCloud] ===> 同步到 iCloud 失败: $name - $e',
      );
    }
  }

  /// 从 iCloud 拉取更新到本地（若 iCloud 文件更新）
  static Future<void> _syncFromCloud(String name) async {
    if (_cloudPath == null) return;
    final enabled = await SettingsService.getSyncSettings();
    if (!enabled) return;
    final cloud = File('$_cloudPath/$name');
    if (!await cloud.exists()) return;
    try {
      final cloudTime = await cloud.lastModified();
      final local = File(localFilePath(_localPath!, name));
      final localTime = await local.exists()
          ? await local.lastModified()
          : DateTime(0);
      if (cloudTime.isAfter(localTime)) {
        await local.writeAsString(await cloud.readAsString());
        debugPrint(
          '[${DateTime.now().toString().substring(11, 19)}][iCloud] ===> 从 iCloud 同步到本地: $name',
        );
      }
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][iCloud] ===> 从 iCloud 拉取失败: $name - $e',
      );
    }
  }

  // 收益快照 - 天粒度（历史）
  static Future<List<ProfitSnapshot>> loadDailyProfitHistory({
    String targetCurrency = AppConfig.defaultCurrency,
  }) async {
    await ensureInit();
    await _syncFromCloud(dailyProfitFile);
    final data = await readJson(_localPath!, dailyProfitFile);
    final snapshots = data.map((e) => ProfitSnapshot.fromJson(e)).toList();
    if (targetCurrency != AppConfig.defaultCurrency) {
      return snapshots
          .map(
            (s) => ProfitSnapshot(
              time: s.time,
              totalProfit: CurrencyUtil.convertCurrency(
                s.totalProfit,
                AppConfig.defaultCurrency,
                targetCurrency,
              ),
            ),
          )
          .toList();
    }
    return snapshots;
  }

  static Future<void> saveDailyProfitHistory(
    List<ProfitSnapshot> snapshots,
  ) async {
    await ensureInit();
    final data = snapshots.map((e) => e.toJson()).toList();
    await writeJson(_localPath!, dailyProfitFile, data);
    await _syncToCloud(dailyProfitFile);
  }

  // 收益快照 - 10分钟粒度（仅当天）
  static Future<List<ProfitSnapshot>> loadIntradayProfitHistory({
    String targetCurrency = AppConfig.defaultCurrency,
  }) async {
    await ensureInit();
    await _syncFromCloud(intradayProfitFile);
    final data = await readJson(_localPath!, intradayProfitFile);
    final snapshots = data.map((e) => ProfitSnapshot.fromJson(e)).toList();
    if (targetCurrency != AppConfig.defaultCurrency) {
      return snapshots
          .map(
            (s) => ProfitSnapshot(
              time: s.time,
              totalProfit: CurrencyUtil.convertCurrency(
                s.totalProfit,
                AppConfig.defaultCurrency,
                targetCurrency,
              ),
            ),
          )
          .toList();
    }
    return snapshots;
  }

  static Future<void> saveIntradayProfitHistory(
    List<ProfitSnapshot> snapshots,
  ) async {
    await ensureInit();
    final data = snapshots.map((e) => e.toJson()).toList();
    await writeJson(_localPath!, intradayProfitFile, data);
    await _syncToCloud(intradayProfitFile);
  }

  // 资产持久化
  static Future<List<AssetBase>> loadAssets() async {
    await ensureInit();
    await _syncFromCloud(assetsFile);
    final data = await readJson(_localPath!, assetsFile);
    return assetsFromJson(data);
  }

  static Future<void> saveAssets(List<AssetBase> assets) async {
    await ensureInit();
    await writeJson(_localPath!, assetsFile, assetsToJson(assets));
    await _syncToCloud(assetsFile);
  }

  /// 强制同步收益快照到 iCloud
  static Future<void> syncProfitToCloud() async {
    await ensureInit();
    await _syncToCloud(dailyProfitFile);
    await _syncToCloud(intradayProfitFile);
  }

  /// 读取今日盈亏基线（总盈亏，存于 defaultCurrency）
  static Future<(String, double)?> loadTodayBaseline() async {
    await ensureInit();
    await _syncFromCloud(todayBaselineFile);
    final file = File(localFilePath(_localPath!, todayBaselineFile));
    if (!await file.exists()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (json['day'] as String, (json['baseline'] as num).toDouble());
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][基线] ===> 读取失败: $e',
      );
      return null;
    }
  }

  /// 保存今日盈亏基线
  static Future<void> saveTodayBaseline(String day, double baseline) async {
    await ensureInit();
    final file = File(localFilePath(_localPath!, todayBaselineFile));
    try {
      await file.writeAsString(jsonEncode({'day': day, 'baseline': baseline}));
      await _syncToCloud(todayBaselineFile);
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][基线] ===> 保存失败: $e',
      );
    }
  }

  static Future<void> recordProfitIfNeeded(
    double totalProfit,
    String sourceCurrency,
  ) async {
    final now = DateTime.now();
    final dayKey = TradingDayUtil.tradingDayKey(now);

    // 转换为 defaultCurrency 存储
    final profitInDefaultCurrency = CurrencyUtil.convertCurrency(
      totalProfit,
      sourceCurrency,
      AppConfig.defaultCurrency,
    );

    var daily = await loadDailyProfitHistory(
      targetCurrency: AppConfig.defaultCurrency,
    );
    var intraday = await loadIntradayProfitHistory(
      targetCurrency: AppConfig.defaultCurrency,
    );
    // 检查是否跨交易日（美东 9:00 日界）：将上一条转存为天级
    if (intraday.isNotEmpty) {
      final last = intraday.last;
      if (TradingDayUtil.tradingDayKey(last.time) != dayKey) {
        debugPrint(
          '[${now.toString().substring(11, 19)}][快照] ===> 跨交易日: 最后一条 ${last.time.toString().substring(0, 19)} → 转存为天级',
        );
        daily.add(
          ProfitSnapshot(time: last.time, totalProfit: last.totalProfit),
        );
        daily.sort((a, b) => a.time.compareTo(b.time));
        daily.removeWhere((s) => now.difference(s.time).inDays > 365);
        await saveDailyProfitHistory(daily);
        intraday.clear();
      }
    }

    // 今日盈亏基线：以美东时间9:00为日界，跨日时更新基线
    final baseline = await loadTodayBaseline();
    if (baseline == null || baseline.$1 != dayKey) {
      debugPrint(
        '[${now.toString().substring(11, 19)}][基线] ===> 跨日更新: $dayKey, 基线 = $profitInDefaultCurrency',
      );
      await saveTodayBaseline(dayKey, profitInDefaultCurrency);
    }

    // 去重：相同值且10分钟内不重复记录
    if (intraday.isNotEmpty) {
      final last = intraday.last;
      if (last.totalProfit == profitInDefaultCurrency &&
          now.difference(last.time).inMinutes < 10) {
        return;
      }
    }

    intraday.add(
      ProfitSnapshot(time: now, totalProfit: profitInDefaultCurrency),
    );
    await saveIntradayProfitHistory(intraday);
    await syncProfitToCloud();
  }
}
