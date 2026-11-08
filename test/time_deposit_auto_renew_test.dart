import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/widgets/asset/asset_card.dart';
import 'package:assets/widgets/asset/asset_dialogs.dart';
import 'package:assets/widgets/asset/assets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'support/core_fixtures.dart';
import 'support/pro_fixtures.dart';
import 'time_deposit_rollover_test.dart' show host, settleStorage;

TimeDeposit sample({bool autoRenew = true}) => TimeDeposit(
  id: 'deposit',
  name: 'Savings',
  currency: 'USD',
  principal: 1000,
  annualRate: 6,
  durationMonths: 3,
  startDate: DateTime(2100, 1, 15),
  autoRenew: autoRenew,
  categoryId: 'timeDeposit',
  sortOrder: 7,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2021),
);

void main() {
  late Directory storage;
  setUpAll(() async => storage = await initializeTestStorage());
  tearDownAll(() => storage.deleteSync(recursive: true));
  setUp(() async {
    L10n.applyLanguage('en');
    for (final file in storage.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SettingsService.reload();
    await setTestPro(enabled: false);
  });
  tearDown(() => L10n.applyLanguage('zh'));

  test(
    'legacy records default off; enabled flag survives serialization and moves',
    () {
      final legacy = sample().toJson()..remove('autoRenew');
      expect(TimeDeposit.fromJson(legacy).autoRenew, isFalse);
      expect(AssetBase.fromJson(sample().toJson()).toJson(), sample().toJson());
    },
  );

  test(
    'renewal respects maturity date, compounds missed terms once and preserves identity',
    () {
      final original = sample();
      final snapshot = jsonEncode(original.toJson());
      expect(
        identical(
          original.renewedThrough(DateTime(2100, 4, 14, 23, 59)),
          original,
        ),
        isTrue,
      );
      final first = original.renewedThrough(DateTime(2100, 4, 15));
      expect(first.principal, 1015);
      expect(first.startDate, DateTime(2100, 4, 15));
      expect(first.endDate, DateTime(2100, 7, 15));
      final caughtUp = original.renewedThrough(DateTime(2101, 1, 15, 17));
      expect(caughtUp.principal, closeTo(1000 * pow(1.015, 4), 1e-9));
      expect(caughtUp.startDate, DateTime(2101, 1, 15));
      expect(caughtUp.endDate, DateTime(2101, 4, 15));
      expect(caughtUp.id, original.id);
      expect(caughtUp.categoryId, original.categoryId);
      expect(caughtUp.currency, original.currency);
      expect(caughtUp.sortOrder, 7);
      expect(caughtUp.createdAt, original.createdAt);
      expect(caughtUp.annualRate, 6);
      expect(caughtUp.durationMonths, 3);
      expect(
        identical(caughtUp.renewedThrough(DateTime(2101, 1, 15, 23)), caughtUp),
        isTrue,
      );
      expect(jsonEncode(original.toJson()), snapshot);
      expect(
        identical(
          sample(autoRenew: false).renewedThrough(DateTime(2200)),
          original,
        ),
        isFalse,
      );
      final off = sample(autoRenew: false);
      expect(identical(off.renewedThrough(DateTime(2200)), off), isTrue);
    },
  );

  test(
    'month-end and leap-year maturities clamp without skipping February',
    () {
      final leap = TimeDeposit(
        id: 'leap',
        principal: 1000,
        annualRate: 0,
        durationMonths: 1,
        startDate: DateTime(2028, 1, 31),
        autoRenew: true,
      );
      expect(leap.endDate, DateTime(2028, 2, 29));
      final next = leap.renewedThrough(DateTime(2028, 2, 29));
      expect(next.startDate, DateTime(2028, 2, 29));
      expect(next.endDate, DateTime(2028, 3, 29));
      expect(next.principal, 1000);
      expect(
        TimeDeposit(
          id: 'month',
          startDate: DateTime(2027, 1, 31),
          durationMonths: 1,
        ).endDate,
        DateTime(2027, 2, 28),
      );
    },
  );

  test(
    'invalid terms or overflowing amounts fail without altering the original',
    () {
      for (final invalid in [
        sample()..durationMonths = 0,
        sample()..annualRate = -1,
        sample()..principal = double.infinity,
        sample()..annualRate = double.nan,
        sample()
          ..principal = 1e308
          ..annualRate = 1e308,
      ]) {
        final principal = invalid.principal;
        expect(() => invalid.renewedThrough(DateTime(2101)), throwsStateError);
        expect(invalid.principal, principal);
        expect(invalid.startDate, DateTime(2100, 1, 15));
      }
    },
  );

  test('concurrent reads persist catch-up once and leave one record', () async {
    await IcloudStorage.saveAssets([sample()]);
    final results = await Future.wait(
      List.generate(
        6,
        (_) => IcloudStorage.loadAssets(asOf: DateTime(2101, 1, 15)),
      ),
    );
    for (final list in results) {
      expect(list, hasLength(1));
      expect(
        (list.single as TimeDeposit).principal,
        closeTo(1000 * pow(1.015, 4), 1e-9),
      );
    }
    final saved = await IcloudStorage.loadAssets(renewDeposits: false);
    expect(saved.single.toJson(), results.last.single.toJson());
    expect(storage.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
  });

  test(
    'failed renewal preserves disk data and disabling allows recovery',
    () async {
      final original = sample()
        ..principal = 1e308
        ..annualRate = 1e308;
      final file = File('${storage.path}/assets.json')
        ..writeAsStringSync(jsonEncode([original.toJson()]));
      final snapshot = file.readAsStringSync();
      await expectLater(
        IcloudStorage.loadAssets(asOf: DateTime(2101)),
        throwsStateError,
      );
      expect(file.readAsStringSync(), snapshot);
      final disabled = await IcloudStorage.setDepositAutoRenew(
        'deposit',
        false,
      );
      expect((disabled.single as TimeDeposit).autoRenew, isFalse);
      expect(
        (await IcloudStorage.loadAssets()).single.toJson(),
        disabled.single.toJson(),
      );
    },
  );

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'deposit form preserves auto-renew and fits all languages at 320px / $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final language in L10n.languages.keys) {
          L10n.applyLanguage(language);
          TimeDeposit? result;
          await tester.pumpWidget(
            host(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showTimeDepositDialog(
                      context,
                      td: sample(),
                      defaultCurrency: 'USD',
                      assetCount: 1,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
              key: ValueKey(language),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
            isTrue,
          );
          if (language == 'zh' && scale == 1) {
            final rate = tester.getRect(find.byType(TextField).at(2));
            final duration = tester.getRect(
              find.text(L10n.t('durationMonths').replaceAll('{m}', '3')),
            );
            expect((rate.center.dy - duration.center.dy).abs(), lessThan(8));
            final start = tester.getRect(find.text('2100-01-15'));
            expect(start.top, greaterThan(rate.bottom));
          }
          await tester.ensureVisible(find.text(AppConfig.btnClose).last);
          await tester.tap(find.text(AppConfig.btnClose).last);
          await tester.pumpAndSettle();
          expect(result!.autoRenew, isTrue, reason: language);
          expect(result!.principal, 1000, reason: language);
          expect(tester.takeException(), isNull, reason: language);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'unmatured deposit hides empty menu and edits auto-renew through the form',
    (tester) async {
      await tester.runAsync(
        () => IcloudStorage.saveAssets([sample(autoRenew: false)]),
      );
      await tester.pumpWidget(
        host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
      );
      await settleStorage(tester);
      await tester.tap(find.byKey(const ValueKey('section_timeDeposit')));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<Object>), findsNothing);
      for (final enabled in [true, false]) {
        await tester.tap(find.byType(AssetCardFrame));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          !enabled,
        );
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.ensureVisible(find.text(AppConfig.btnClose).last);
        await tester.tap(find.text(AppConfig.btnClose).last);
        await settleStorage(tester);
        final card = tester.widget<AssetCardFrame>(find.byType(AssetCardFrame));
        expect(card.detail!.contains(L10n.t('depositAutoRenew')), enabled);
        expect(
          card.detail,
          contains(
            DateFormat.yMd(L10n.intlLocale).format(DateTime(2100, 4, 15)),
          ),
        );
        if (enabled) {
          expect(
            card.detail,
            contains(
              '${DateFormat.yMd(L10n.intlLocale).format(DateTime(2100, 4, 15))} · ${L10n.t('depositAutoRenew')}',
            ),
          );
        }
        await tester.runAsync(() async {
          final saved =
              (await IcloudStorage.loadAssets()).single as TimeDeposit;
          expect(saved.autoRenew, enabled);
          expect(saved.principal, 1000);
          expect(saved.id, 'deposit');
        });
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'automatic renewal card details remain complete in all languages at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() => IcloudStorage.saveAssets([sample()]));
      for (final language in L10n.languages.keys) {
        L10n.applyLanguage(language);
        await tester.pumpWidget(
          host(
            const AssetsPage(stockTotalValue: 0, currency: 'USD'),
            key: ValueKey(language),
          ),
        );
        await settleStorage(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('section_timeDeposit')),
        );
        await tester.tap(find.byKey(const ValueKey('section_timeDeposit')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('asset_deposit')));
        final card = tester.widget<AssetCardFrame>(find.byType(AssetCardFrame));
        expect(
          card.detail,
          contains(L10n.t('depositAutoRenew')),
          reason: language,
        );
        expect(card.detailMaxLines, 3);
        expect(card.fitDetailLines, isTrue);
        expect(card.detail!.split('\n'), hasLength(3));
        final detailText = find.text(card.detail!);
        expect(tester.widget<Text>(detailText).softWrap, isFalse);
        final detailRect = tester.getRect(detailText);
        final amountRect = tester.getRect(
          find.descendant(
            of: find.byType(AssetCardFrame),
            matching: find.text(card.amount),
          ),
        );
        if (Directionality.of(tester.element(detailText)) ==
            TextDirection.rtl) {
          expect(
            detailRect.right,
            lessThanOrEqualTo(amountRect.left),
            reason: language,
          );
        } else {
          expect(
            detailRect.left,
            greaterThanOrEqualTo(amountRect.right),
            reason: language,
          );
        }
        expect(
          detailRect.right,
          lessThanOrEqualTo(tester.getRect(find.byType(AssetCardFrame)).right),
          reason: language,
        );
        expect(tester.takeException(), isNull, reason: language);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'deposit delete commits before removing the card and can recover from failure',
    (tester) async {
      await tester.runAsync(() => IcloudStorage.saveAssets([sample()]));
      await tester.pumpWidget(
        host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
      );
      await settleStorage(tester);
      await tester.tap(find.byKey(const ValueKey('section_timeDeposit')));
      await tester.pumpAndSettle();
      final file = File('${storage.path}/assets.json');
      final backup = '${storage.path}/backup.json';
      final before = file.readAsStringSync();
      file.renameSync(backup);
      final blocker = Directory(file.path)..createSync();
      Future<void> delete() async {
        await tester.drag(
          find.byKey(const ValueKey('del_deposit')),
          const Offset(-700, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppConfig.btnDelete));
        await settleStorage(tester);
      }

      await delete();
      expect(find.text(L10n.t('assetSaveFailed')), findsOneWidget);
      expect(find.byKey(const ValueKey('asset_deposit')), findsOneWidget);
      expect(tester.takeException(), isNull);
      blocker.deleteSync();
      File(backup).renameSync(file.path);
      expect(file.readAsStringSync(), before);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await delete();
      expect(find.byKey(const ValueKey('asset_deposit')), findsNothing);
      expect(jsonDecode(file.readAsStringSync()), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'form save failure keeps auto-renew unchanged and permits retry',
    (tester) async {
      await tester.runAsync(
        () => IcloudStorage.saveAssets([sample(autoRenew: false)]),
      );
      await tester.pumpWidget(
        host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
      );
      await settleStorage(tester);
      await tester.tap(find.byKey(const ValueKey('section_timeDeposit')));
      await tester.pumpAndSettle();
      final file = File('${storage.path}/assets.json');
      final backup = '${storage.path}/backup.json';
      file.renameSync(backup);
      final blocker = Directory(file.path)..createSync();
      await tester.tap(find.byType(AssetCardFrame));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.ensureVisible(find.text(AppConfig.btnClose).last);
      await tester.tap(find.text(AppConfig.btnClose).last);
      await settleStorage(tester);
      expect(find.text(L10n.t('assetSaveFailed')), findsOneWidget);
      expect(
        tester.widget<AssetCardFrame>(find.byType(AssetCardFrame)).detail,
        isNot(contains(L10n.t('depositAutoRenew'))),
      );
      blocker.deleteSync();
      File(backup).renameSync(file.path);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AssetCardFrame));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.ensureVisible(find.text(AppConfig.btnClose).last);
      await tester.tap(find.text(AppConfig.btnClose).last);
      await settleStorage(tester);
      expect(
        tester.widget<AssetCardFrame>(find.byType(AssetCardFrame)).detail,
        contains(L10n.t('depositAutoRenew')),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
