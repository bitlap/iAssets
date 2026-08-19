import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'icloud_storage.dart';
import 'settings_service.dart';
import '../services/serde/converters.dart';

/// 备份服务 - 将所有数据合并为单一 JSON 进行导入/导出
class BackupService {
  BackupService._();

  static const int _backupVersion = 1;

  /// 导出所有数据为统一 JSON Map
  static Future<Map<String, dynamic>> exportAll() async {
    final (stocks, operationRecords, dividendRecords) =
        await IcloudStorage.loadStocks();
    final settings = await SettingsService.getAll();
    final assets = await IcloudStorage.loadAssets();

    return {
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': AppConfig.appVersion,
      'stocks': stocksToJson(stocks),
      'operationRecords': recordsToJson(operationRecords),
      'dividendRecords': dividendRecordsToJson(dividendRecords),
      'settings': settings,
      'assets': assetsToJson(assets),
    };
  }

  /// 将数据导出为 JSON 并写入指定路径
  static Future<bool> exportToFile(String path) async {
    try {
      final data = await exportAll();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final file = File(path);
      await file.writeAsString(jsonStr);
      debugPrint('[Backup] ===> 导出成功: $path');
      return true;
    } catch (e) {
      debugPrint('[Backup] ===> 导出失败: $e');
      return false;
    }
  }

  /// 从 JSON 数据导入所有内容（先备份当前数据）
  static Future<bool> importAll(Map<String, dynamic> data) async {
    try {
      final version = data['version'] as int?;
      if (version == null || version > _backupVersion) {
        debugPrint('[Backup] ===> 不支持的备份版本: $version');
        return false;
      }

      // 备份当前数据到 .bak
      await _backupCurrent();

      // 导入股票
      if (data['stocks'] != null) {
        final stocks = (data['stocks'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final stocksJson = stocksFromJson(stocks);
        await IcloudStorage.saveStocks(
          stocksJson,
          null, // 不在此处写操作记录
          null, // 不在此处写派息记录
        );
      }

      // 导入操作记录
      if (data['operationRecords'] != null) {
        final opsList = (data['operationRecords'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final ops = recordsFromJson(opsList);
        // 需要连同股票一起保存
        final (stocks, _, _) = await IcloudStorage.loadStocks();
        await IcloudStorage.saveStocks(stocks, ops, null);
      }

      // 导入派息记录
      if (data['dividendRecords'] != null) {
        final divsList = (data['dividendRecords'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final divs = dividendRecordsFromJson(divsList);
        final (stocks, ops, _) = await IcloudStorage.loadStocks();
        await IcloudStorage.saveStocks(stocks, ops, divs);
      }

      // 导入设置
      if (data['settings'] != null) {
        final settings = data['settings'] as Map<String, dynamic>;
        await SettingsService.applyAll(settings);
      }

      // 导入资产
      if (data['assets'] != null) {
        final assetsList = (data['assets'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final assets = assetsFromJson(assetsList);
        await IcloudStorage.saveAssets(assets);
      }

      return true;
    } catch (e) {
      debugPrint('[Backup] ===> 导入失败: $e');
      return false;
    }
  }

  /// 备份当前数据到 .bak 文件（用于导入失败时回滚）
  static Future<void> _backupCurrent() async {
    try {
      final data = await exportAll();
      final jsonStr = jsonEncode(data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/backup.bak');
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('[Backup] ===> 备份当前数据失败: $e');
    }
  }

  /// 校验导入数据格式是否有效
  static bool validateImportData(Map<String, dynamic> data) {
    if (data['version'] == null) return false;
    // 至少包含一项有效数据
    return data['stocks'] != null ||
        data['operationRecords'] != null ||
        data['dividendRecords'] != null ||
        data['settings'] != null ||
        data['assets'] != null;
  }

  /// 检查是否有可用于回滚的备份
  static Future<bool> hasRollbackBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/backup.bak');
      return await file.exists();
    } catch (e) {
      debugPrint('[Backup] ===> 检查备份文件失败: $e');
      return false;
    }
  }

  /// 从 .bak 文件回滚到上次导入前的数据
  static Future<bool> rollbackFromBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/backup.bak');
      if (!await file.exists()) return false;
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!validateImportData(data)) return false;
      return await importAll(data);
    } catch (e) {
      debugPrint('[Backup] ===> 回滚失败: $e');
      return false;
    }
  }
}
