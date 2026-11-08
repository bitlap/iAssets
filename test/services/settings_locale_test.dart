import 'dart:io';

import 'package:assets/services/settings_service.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(() async {
    File('${dir.path}/settings.json').writeAsStringSync('{}');
    await SettingsService.reload();
  });

  test('all language preferences survive storage reload', () async {
    for (final language in [L10n.langSystem, ...L10n.languages.keys]) {
      await SettingsService.setPreferredLanguage(language);
      await SettingsService.reload();
      expect(await SettingsService.getPreferredLanguage(), language);
    }
  });

  test(
    'first launch stores a region-specific market color preference',
    () async {
      expect(
        await SettingsService.getRedUpGreenDown(
          deviceLocale: const Locale('en', 'US'),
        ),
        isFalse,
      );
      expect(
        await SettingsService.getRedUpGreenDown(
          deviceLocale: const Locale('zh', 'CN'),
        ),
        isFalse,
      );
    },
  );

  test('existing market color preference survives locale changes', () async {
    await SettingsService.setRedUpGreenDown(true);
    expect(
      await SettingsService.getRedUpGreenDown(
        deviceLocale: const Locale('en', 'US'),
      ),
      isTrue,
    );
    await SettingsService.reload();
    expect(
      await SettingsService.getRedUpGreenDown(
        deviceLocale: const Locale('fr', 'FR'),
      ),
      isTrue,
    );
  });

  test('red-up regions and English markets use expected defaults', () {
    expect(
      SettingsService.defaultRedUpGreenDown(const Locale('zh', 'HK')),
      isTrue,
    );
    expect(
      SettingsService.defaultRedUpGreenDown(const Locale('ja', 'JP')),
      isTrue,
    );
    expect(
      SettingsService.defaultRedUpGreenDown(const Locale('ko', 'KR')),
      isTrue,
    );
    expect(
      SettingsService.defaultRedUpGreenDown(const Locale('en', 'GB')),
      isFalse,
    );
    expect(
      SettingsService.defaultRedUpGreenDown(const Locale('de', 'DE')),
      isFalse,
    );
  });
}
