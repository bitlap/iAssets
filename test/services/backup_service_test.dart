import '../support/pro_fixtures.dart';
import 'dart:convert';
import 'dart:io';
import 'package:assets/models/asset_account.dart';
import 'package:assets/services/backup_service.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/serde/converters.dart';
import 'package:assets/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(() async {
    await setTestPro();
    for (final file in dir.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SettingsService.reload();
  });
  Map<String, dynamic> bundle(String symbol, double balance) => {
    'version': 1,
    'stocks': stocksToJson([stock(symbol: symbol)]),
    'operationRecords': recordsToJson({
      symbol: [trade(fee: 1.25)],
    }),
    'dividendRecords': dividendRecordsToJson({
      symbol: [dividend()],
    }),
    'settings': {
      'default_currency': 'HKD',
      'sync_settings': false,
      'theme_mode': 'dark',
    },
    'assets': assetsToJson([
      CashAccount(
        id: 'cash',
        balance: balance,
        currency: 'USD',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]),
  };
  Future<void> expectRestored(Map<String, dynamic> expected) async {
    final exported = await BackupService.exportAll();
    for (final key in [
      'stocks',
      'operationRecords',
      'dividendRecords',
      'assets',
      'settings',
    ]) {
      expect(exported[key], expected[key], reason: 'restored $key');
    }
    expect(exported['version'], 1);
    expect(DateTime.tryParse(exported['exportedAt'] as String), isNotNull);
  }

  test(
    'full backup import and export retain all core data categories',
    () async {
      final data = bundle('ORIGINAL', 123.45);
      expect(await BackupService.importAll(data), isTrue);
      await expectRestored(data);
      final file = '${dir.path}/export.json';
      expect(await BackupService.exportToFile(file), isTrue);
      final exported =
          jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      expect(exported['stocks'], data['stocks']);
      expect(exported['assets'], data['assets']);
    },
  );
  test('rollback restores the state before an overwrite', () async {
    final original = bundle('ORIGINAL', 100);
    expect(await BackupService.importAll(original), isTrue);
    expect(await BackupService.importAll(bundle('REPLACEMENT', 999)), isTrue);
    expect((await IcloudStorage.loadStocks()).$1.single.symbol, 'REPLACEMENT');
    expect(await BackupService.hasRollbackBackup(), isTrue);
    expect(await BackupService.rollbackFromBackup(), isTrue);
    await expectRestored(original);
  });
  test(
    'unsupported and missing versions leave current state untouched',
    () async {
      final original = bundle('ORIGINAL', 100);
      await BackupService.importAll(original);
      expect(
        await BackupService.importAll({'version': 999, 'stocks': []}),
        isFalse,
      );
      expect(await BackupService.importAll({'stocks': []}), isFalse);
      await expectRestored(original);
    },
  );
  test('partial import only replaces supplied categories', () async {
    final original = bundle('ORIGINAL', 100);
    await BackupService.importAll(original);
    final newAssets = assetsToJson([
      CashAccount(
        id: 'new',
        balance: 20,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    expect(
      await BackupService.importAll({'version': 1, 'assets': newAssets}),
      isTrue,
    );
    await expectRestored({...original, 'assets': newAssets});
  });
  test('missing, corrupt and invalid rollback files fail safely', () async {
    expect(await BackupService.hasRollbackBackup(), isFalse);
    expect(await BackupService.rollbackFromBackup(), isFalse);
    final file = File('${dir.path}/backup.bak');
    file.writeAsStringSync('{broken');
    expect(await BackupService.rollbackFromBackup(), isFalse);
    file.writeAsStringSync('{"version":1}');
    expect(await BackupService.rollbackFromBackup(), isFalse);
  });
  test('export reports failure for an unwritable destination', () async {
    expect(
      await BackupService.exportToFile('${dir.path}/missing/export.json'),
      isFalse,
    );
  });
  test('empty data can be exported and validated for later import', () async {
    final data = await BackupService.exportAll();
    expect(BackupService.validateImportData(data), isTrue);
    expect(data['stocks'], isEmpty);
    expect(data['operationRecords'], isEmpty);
    expect(data['dividendRecords'], isEmpty);
    expect(data['assets'], isEmpty);
    expect(BackupService.validateImportData({}), isFalse);
    expect(BackupService.validateImportData({'version': 1}), isFalse);
  });
}
