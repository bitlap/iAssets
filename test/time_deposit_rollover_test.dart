import 'dart:convert';
import 'dart:io';

import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/models/asset_category.dart';
import 'package:assets/services/asset_data_manager.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/serde/file_io.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/widgets/asset/asset_dialogs.dart';
import 'package:assets/widgets/asset/assets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';
import 'support/pro_fixtures.dart';

Widget host(Widget child, {Key? key}) => MaterialApp(
  key: key,
  locale: L10n.currentLocale,
  supportedLocales: L10n.supportedLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

TimeDeposit deposit({String id = 'deposit', DateTime? start}) => TimeDeposit(
  id: id,
  name: 'Savings',
  principal: 1000,
  annualRate: 6,
  durationMonths: 6,
  startDate: start ?? DateTime(2020, 1, 8),
  currency: 'USD',
  sortOrder: 7,
  categoryId: 'custom.savings',
  createdAt: DateTime(2020, 1, 1),
  updatedAt: DateTime(2020, 1, 2),
);

Future<void> settleStorage(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

Future<void> openCardMenu(WidgetTester tester, String assetId) async {
  final section = find.byKey(const ValueKey('section_custom.savings'));
  await tester.tap(section);
  await tester.pumpAndSettle();
  final card = find.byKey(ValueKey('asset_$assetId'));
  await tester.ensureVisible(card);
  await tester.tap(
    find.descendant(of: card, matching: find.byType(PopupMenuButton<Object>)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  testWidgets(
    'rollover defaults preserve identity and capitalize once in all languages',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = deposit();
      final snapshot = jsonEncode(original.toJson());
      for (final language in L10n.languages.keys) {
        L10n.applyLanguage(language);
        TimeDeposit? saved;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => saved = await showTimeDepositDialog(
                  context,
                  td: original,
                  rollover: true,
                  defaultCurrency: 'EUR',
                  assetCount: 99,
                ),
                child: const Text('Open'),
              ),
            ),
            key: ValueKey(language),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(1))
              .controller!
              .text,
          '1030.0000',
          reason: language,
        );
        await tester.ensureVisible(find.text(L10n.t('depositRollover')).last);
        await tester.tap(find.text(L10n.t('depositRollover')).last);
        await tester.pumpAndSettle();
        expect(saved, isNotNull, reason: language);
        expect(saved!.principal, 1030, reason: language);
        expect(saved!.startDate, original.endDate);
        expect(saved!.totalValue, closeTo(1060.9, 1e-9));
        expect(saved!.id, original.id);
        expect(saved!.categoryId, original.categoryId);
        expect(saved!.currency, 'USD');
        expect(saved!.sortOrder, 7);
        expect(saved!.createdAt, original.createdAt);
        expect(saved!.updatedAt!.isAfter(original.updatedAt!), isTrue);
        expect(jsonEncode(original.toJson()), snapshot);
        expect(tester.takeException(), isNull, reason: language);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'rollover can use actual bank proceeds and a new local-format rate',
    (tester) async {
      L10n.applyLanguage('fr');
      TimeDeposit? saved;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await showTimeDepositDialog(
                context,
                td: deposit(),
                rollover: true,
                defaultCurrency: 'USD',
                assetCount: 1,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '1299,32');
      await tester.enterText(find.byType(TextField).at(2), '3,65');
      await tester.ensureVisible(find.text(L10n.t('depositRollover')).last);
      await tester.tap(find.text(L10n.t('depositRollover')).last);
      await tester.pumpAndSettle();
      expect(saved!.principal, 1299.32);
      expect(saved!.annualRate, 3.65);
      expect(saved!.startDate, DateTime(2020, 7, 8));
    },
  );

  for (final cancel in [true, false]) {
    testWidgets(
      'card rollover ${cancel ? 'cancels without changes' : 'replaces and persists without duplicate totals or Pro limit'}',
      (tester) async {
        final originals = [
          deposit(),
          for (var i = 1; i < 4; i++) deposit(id: 'other$i'),
        ];
        await tester.runAsync(() async {
          await IcloudStorage.saveAssets(originals);
          await AssetDataManager.saveCategoryState(
            [
              ...AssetCategory.builtIns,
              const AssetCategory(
                id: 'custom.savings',
                calculationType: AssetType.timeDeposit,
                labelKey: 'timeDeposit',
                customName: 'Savings category',
              ),
            ],
            ['custom.savings'],
          );
        });
        await tester.pumpWidget(
          host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
        );
        await settleStorage(tester);
        await openCardMenu(tester, 'deposit');
        final actions = tester
            .widgetList<PopupMenuItem<Object>>(
              find.byType(PopupMenuItem<Object>),
            )
            .toList();
        expect(actions, hasLength(2));
        expect(actions.every((action) => action.enabled), isTrue);
        expect(find.text(L10n.t('assetCategoryMove')), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text(L10n.t('depositRollover')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find
              .text(cancel ? AppConfig.btnCancel : L10n.t('depositRollover'))
              .last,
        );
        await tester.tap(
          find
              .text(cancel ? AppConfig.btnCancel : L10n.t('depositRollover'))
              .last,
        );
        await settleStorage(tester);
        await tester.runAsync(() async {
          final assets = await IcloudStorage.loadAssets();
          expect(assets.length, 4);
          expect(assets.where((a) => a.id == 'deposit').length, 1);
          final updated = assets.first as TimeDeposit;
          expect(updated.principal, cancel ? 1000 : 1030);
          expect(
            updated.startDate,
            cancel ? DateTime(2020, 1, 8) : DateTime(2020, 7, 8),
          );
          expect(updated.categoryId, 'custom.savings');
          expect(updated.createdAt, originals.first.createdAt);
          expect(
            assets.skip(1).map((a) => jsonEncode(a.toJson())).toList(),
            originals.skip(1).map((a) => jsonEncode(a.toJson())).toList(),
          );
          expect(
            assets.cast<TimeDeposit>().fold<double>(
              0,
              (sum, a) => sum + a.totalValue,
            ),
            closeTo(cancel ? 4120 : 4150.9, 1e-9),
          );
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 4));
      },
    );
  }

  testWidgets('non-deposit cards do not offer rollover', (tester) async {
    await tester.runAsync(
      () => IcloudStorage.saveAssets([
        CashAccount(id: 'cash', categoryId: 'custom.savings', balance: 50),
      ]),
    );
    await tester.pumpWidget(
      host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
    );
    await settleStorage(tester);
    await openCardMenu(tester, 'cash');
    expect(find.text(L10n.t('depositRollover')), findsNothing);
    expect(find.byType(PopupMenuItem<Object>), findsOneWidget);
    expect(find.text(L10n.t('assetCategoryMove')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('future deposits do not offer rollover', (tester) async {
    await tester.runAsync(() async {
      await IcloudStorage.saveAssets([deposit(start: DateTime.now())]);
    });
    await tester.pumpWidget(
      host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
    );
    await settleStorage(tester);
    await openCardMenu(tester, 'deposit');
    expect(find.text(L10n.t('assetCategoryMove')), findsOneWidget);
    expect(find.text(L10n.t('depositRollover')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed rollover save keeps the original card and allows retry', (
    tester,
  ) async {
    final original = deposit();
    await tester.runAsync(() => IcloudStorage.saveAssets([original]));
    await tester.pumpWidget(
      host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
    );
    await settleStorage(tester);
    await openCardMenu(tester, 'deposit');
    await tester.tap(find.text(L10n.t('depositRollover')));
    await tester.pumpAndSettle();
    final file = File('${storage.path}/assets.json');
    final backup = '${storage.path}/assets-original.json';
    file.renameSync(backup);
    final blocker = Directory(file.path)..createSync();
    await tester.ensureVisible(find.text(L10n.t('depositRollover')).last);
    await tester.tap(find.text(L10n.t('depositRollover')).last);
    await settleStorage(tester);
    expect(find.text(L10n.t('assetSaveFailed')), findsOneWidget);
    expect(find.text(r'$1030.00'), findsWidgets);
    blocker.deleteSync();
    File(backup).renameSync(file.path);
    await tester.runAsync(() async {
      final saved = (await IcloudStorage.loadAssets()).single as TimeDeposit;
      expect(saved.principal, 1000);
    });
    final menu = find.descendant(
      of: find.byKey(const ValueKey('asset_deposit')),
      matching: find.byType(PopupMenuButton<Object>),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(L10n.t('depositRollover')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(L10n.t('depositRollover')).last);
    await tester.tap(find.text(L10n.t('depositRollover')).last);
    await settleStorage(tester);
    await tester.runAsync(
      () async => expect(
        ((await IcloudStorage.loadAssets()).single as TimeDeposit).principal,
        1030,
      ),
    );
    expect(storage.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });

  test(
    'strict atomic JSON replacement reports encoding failure without damaging original data',
    () async {
      final original = '[{"principal":1000}]';
      final file = File('${storage.path}/atomic.json')
        ..writeAsStringSync(original);
      await expectLater(
        writeJson(storage.path, 'atomic.json', [
          {'invalid': Object()},
        ], requireSuccess: true),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(file.readAsStringSync(), original);
      await writeJson(storage.path, 'atomic.json', [
        {'principal': 1030},
      ], requireSuccess: true);
      expect(jsonDecode(file.readAsStringSync()), [
        {'principal': 1030},
      ]);
      expect(storage.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
    },
  );
}
