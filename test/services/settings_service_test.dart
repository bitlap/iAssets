import 'dart:convert';
import 'dart:io';

import 'package:assets/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));

  test(
    'retired closed-position setting is removed locally and on import',
    () async {
      final file = File('${directory.path}/settings.json');
      await file.writeAsString(
        jsonEncode({'keep_stock_after_close': true, 'sort_column': 'name'}),
      );

      await SettingsService.reload();
      expect(await SettingsService.getSortColumn(), 'name');
      expect(
        (await SettingsService.getAll()).containsKey('keep_stock_after_close'),
        isFalse,
      );
      expect(
        (jsonDecode(await file.readAsString()) as Map).containsKey(
          'keep_stock_after_close',
        ),
        isFalse,
      );

      await SettingsService.applyAll({'keep_stock_after_close': false});
      expect(
        (await SettingsService.getAll()).containsKey('keep_stock_after_close'),
        isFalse,
      );
      expect(
        (jsonDecode(await file.readAsString()) as Map).containsKey(
          'keep_stock_after_close',
        ),
        isFalse,
      );
    },
  );
}
