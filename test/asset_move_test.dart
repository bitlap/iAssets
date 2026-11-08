import 'dart:convert';
import 'dart:io';

import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/models/asset_category.dart';
import 'package:assets/services/asset_data_manager.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/widgets/asset/asset_card.dart';
import 'package:assets/widgets/asset/asset_category_sheet.dart';
import 'package:assets/widgets/asset/assets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';
import 'support/pro_fixtures.dart';
import 'time_deposit_rollover_test.dart' show host, settleStorage;

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
    await setTestPro();
  });
  tearDown(() => L10n.applyLanguage('zh'));

  test(
    'all type pairs enforce the three input templates without data loss',
    () {
      final originals = <AssetBase>[
        CashAccount(id: 'cash', balance: 123.456),
        CurrentAccount(id: 'current', balance: 123.456),
        ProvidentFundAccount(id: 'providentFund', balance: 123.456),
        TimeDeposit(
          id: 'deposit',
          principal: 321,
          annualRate: 4.2,
          durationMonths: 7,
        ),
        WealthProduct(id: 'wealth', shares: 123, nav: 4.56),
      ];
      for (final original in originals) {
        original.createdAt = DateTime(2020);
        original.updatedAt = DateTime(2021);
        original.sortOrder = 7;
        original.currency = 'EUR';
        original.name = 'My asset';
        final snapshot = jsonEncode(original.toJson());
        for (final category in AssetCategory.builtIns) {
          final balanceTypes = {
            AssetType.cash,
            AssetType.current,
            AssetType.providentFund,
          };
          final allowed =
              original.type == category.calculationType ||
              (balanceTypes.contains(original.type) &&
                  balanceTypes.contains(category.calculationType));
          expect(category.accepts(original.type), allowed);
          if (!allowed) {
            expect(() => category.moveAsset(original), throwsArgumentError);
          } else {
            final moved = category.moveAsset(original);
            expect(
              moved.toJson()
                ..remove('type')
                ..remove('categoryId')
                ..remove('updatedAt'),
              original.toJson()
                ..remove('type')
                ..remove('categoryId')
                ..remove('updatedAt'),
            );
            expect(moved.categoryKey, category.id);
            expect(moved.type, category.calculationType);
            expect(moved.updatedAt!.isAfter(original.updatedAt!), isTrue);
          }
          expect(jsonEncode(original.toJson()), snapshot);
        }
      }
    },
  );

  Future<void> load(WidgetTester tester, List<AssetBase> assets) async {
    await tester.runAsync(() async {
      await IcloudStorage.saveAssets(assets);
      await AssetDataManager.saveCategoryState(AssetCategory.builtIns, [
        'cash',
        'current',
        'timeDeposit',
        'wealthProduct',
        'providentFund',
      ]);
    });
    await tester.pumpWidget(
      host(const AssetsPage(stockTotalValue: 0, currency: 'USD')),
    );
    await settleStorage(tester);
    for (final type in ['cash', 'current', 'timeDeposit', 'wealthProduct']) {
      final section = find.byKey(ValueKey('section_$type'));
      if (section.evaluate().isNotEmpty) {
        await tester.ensureVisible(section);
        await tester.tap(section);
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> reorder(WidgetTester tester, int oldIndex, int newIndex) async {
    await tester.runAsync(() async {
      final callback =
          tester
                  .widget<SliverReorderableList>(
                    find.byType(SliverReorderableList),
                  )
                  .onReorderItem!
              as Future<void> Function(int, int);
      await callback(oldIndex, newIndex);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('drag changes persisted type and target category style', (
    tester,
  ) async {
    await load(tester, [
      CashAccount(id: 'a', name: 'Savings', balance: 123.45),
      CurrentAccount(id: 'b'),
    ]);
    final card = find.byKey(const ValueKey('asset_a'));
    expect(find.byType(PopupMenuButton<Object>), findsWidgets);
    await reorder(tester, 1, 3);
    final frame = tester.widget<AssetCardFrame>(
      find.descendant(of: card, matching: find.byType(AssetCardFrame)),
    );
    final target = AssetCategory.builtIns.firstWhere((c) => c.id == 'current');
    expect(frame.icon, assetCategoryIcon(target));
    expect(frame.categoryColor, assetCategoryColor(target));
    await tester.runAsync(() async {
      final saved = (await IcloudStorage.loadAssets()).firstWhere(
        (a) => a.id == 'a',
      );
      expect(saved, isA<CurrentAccount>());
      expect((saved as CurrentAccount).balance, 123.45);
      expect(saved.id, 'a');
      expect(saved.categoryKey, 'current');
    });
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [390.0, 1194.0]) {
    testWidgets(
      'change category filters templates, cancels safely and saves at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await load(tester, [CashAccount(id: 'a', balance: 123.45)]);
        final file = File('${storage.path}/assets.json');
        final original = file.readAsStringSync();
        Future<void> openPicker() async {
          final card = find.byKey(const ValueKey('asset_a'));
          await tester.tap(
            find.descendant(
              of: card,
              matching: find.byType(PopupMenuButton<Object>),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(PopupMenuItem<Object>), findsOneWidget);
          await tester.tap(find.text(L10n.t('assetCategoryMove')));
          await tester.pumpAndSettle();
        }

        await openPicker();
        expect(
          find.byKey(const ValueKey('move_category_current')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('move_category_providentFund')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('move_category_cash')), findsNothing);
        expect(
          find.byKey(const ValueKey('move_category_timeDeposit')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('move_category_wealthProduct')),
          findsNothing,
        );
        expect(tester.getSize(find.byType(BottomSheet)).width, width);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(file.readAsStringSync(), original);
        await openPicker();
        await tester.tap(find.byKey(const ValueKey('move_category_current')));
        await settleStorage(tester);
        await tester.runAsync(() async {
          final moved = (await IcloudStorage.loadAssets()).single;
          expect(moved, isA<CurrentAccount>());
          expect(moved.categoryKey, 'current');
          expect(moved.id, 'a');
          expect((moved as CurrentAccount).balance, 123.45);
        });
        await tester.tap(find.byKey(const ValueKey('section_current')));
        await tester.pumpAndSettle();
        final frame = tester.widget<AssetCardFrame>(
          find.descendant(
            of: find.byKey(const ValueKey('asset_a')),
            matching: find.byType(AssetCardFrame),
          ),
        );
        final target = AssetCategory.builtIns.firstWhere(
          (c) => c.id == 'current',
        );
        expect(frame.icon, assetCategoryIcon(target));
        expect(frame.categoryColor, assetCategoryColor(target));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'drag moves compatible cards in both directions and inserts at destination position',
    (tester) async {
      await load(tester, [
        CashAccount(id: 'a', balance: 100),
        CurrentAccount(id: 'b', balance: 200),
      ]);
      // [cash header, a, current header, b] -> [cash header, current header, b, a]
      await reorder(tester, 1, 3);
      await tester.runAsync(() async {
        final saved = await IcloudStorage.loadAssets();
        expect(saved.map((a) => a.id), ['b', 'a']);
        expect(saved.every((a) => a is CurrentAccount), isTrue);
      });
      // Moving into a nonempty compatible category in the opposite direction.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await load(tester, [CashAccount(id: 'a'), CurrentAccount(id: 'b')]);
      await reorder(tester, 3, 1);
      await tester.runAsync(() async {
        final saved = await IcloudStorage.loadAssets();
        expect(saved.map((a) => a.id), ['b', 'a']);
        expect(saved.every((a) => a is CashAccount), isTrue);
      });
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('incompatible drag warns and keeps stored assets unchanged', (
    tester,
  ) async {
    await load(tester, [
      CashAccount(id: 'a', balance: 100),
      TimeDeposit(id: 'b', principal: 200),
    ]);
    final file = File('${storage.path}/assets.json');
    final before = file.readAsStringSync();
    await reorder(tester, 1, 3);
    expect(find.text(L10n.t('toastCrossSection')), findsOneWidget);
    expect(file.readAsStringSync(), before);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed move keeps the original card and supports retry', (
    tester,
  ) async {
    await load(tester, [
      CashAccount(id: 'a', balance: 100),
      CurrentAccount(id: 'b', balance: 200),
    ]);
    final file = File('${storage.path}/assets.json');
    final backup = '${storage.path}/assets-backup.json';
    final before = file.readAsStringSync();
    file.renameSync(backup);
    final blocker = Directory(file.path)..createSync();
    await reorder(tester, 1, 3);
    expect(find.text(L10n.t('assetSaveFailed')), findsOneWidget);
    final frame = tester.widget<AssetCardFrame>(
      find.descendant(
        of: find.byKey(const ValueKey('asset_a')),
        matching: find.byType(AssetCardFrame),
      ),
    );
    expect(frame.icon, assetCategoryIcon(AssetCategory.builtIns.first));
    blocker.deleteSync();
    File(backup).renameSync(file.path);
    expect(file.readAsStringSync(), before);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await reorder(tester, 1, 3);
    await tester.runAsync(() async {
      final moved = (await IcloudStorage.loadAssets()).firstWhere(
        (a) => a.id == 'a',
      );
      expect(moved, isA<CurrentAccount>());
      expect((moved as CurrentAccount).balance, 100);
    });
    expect(
      storage.listSync().where((file) => file.path.endsWith('.tmp')),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cards without actions hide dots; matured deposits offer rollover',
    (tester) async {
      await load(tester, [
        WealthProduct(id: 'w'),
        TimeDeposit(id: 'future', startDate: DateTime.now()),
      ]);
      expect(find.byType(PopupMenuButton<Object>), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await load(tester, [
        TimeDeposit(id: 'matured', startDate: DateTime(2020)),
      ]);
      expect(find.byType(PopupMenuButton<Object>), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
