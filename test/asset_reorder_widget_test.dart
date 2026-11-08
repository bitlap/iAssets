import 'dart:io';

import 'package:assets/models/asset_account.dart';
import 'package:assets/models/asset_category.dart';
import 'package:assets/services/asset_data_manager.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/widgets/asset/assets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

void main() {
  late Directory storage;
  setUpAll(() async => storage = await initializeTestStorage());
  tearDownAll(() => storage.deleteSync(recursive: true));

  testWidgets(
    'category reordering uses adjusted destination in both directions',
    (tester) async {
      await tester.runAsync(() async {
        await IcloudStorage.saveAssets([
          CashAccount(id: 'cash'),
          CurrentAccount(id: 'current'),
          TimeDeposit(id: 'deposit'),
        ]);
        await AssetDataManager.saveCategoryState(AssetCategory.builtIns, [
          'cash',
          'current',
          'timeDeposit',
          'wealthProduct',
          'providentFund',
        ]);
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AssetsPage(stockTotalValue: 0, currency: 'USD')),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);

      List<String> visibleOrder() => tester
          .widgetList<ReorderableDelayedDragStartListener>(
            find.byType(ReorderableDelayedDragStartListener),
          )
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(visibleOrder(), [
        'section_cash',
        'section_current',
        'section_timeDeposit',
      ]);
      for (final move in [(0, 2), (2, 0)]) {
        await tester.runAsync(() async {
          final reorder =
              tester
                      .widget<SliverReorderableList>(
                        find.byType(SliverReorderableList),
                      )
                      .onReorderItem!
                  as Future<void> Function(int, int);
          await reorder(move.$1, move.$2);
          final (_, _, order) = await AssetDataManager.loadCategoryState();
          expect(
            order.take(3),
            move.$1 == 0
                ? ['current', 'timeDeposit', 'cash']
                : ['cash', 'current', 'timeDeposit'],
          );
          expect((await IcloudStorage.loadAssets()).map((a) => a.id), [
            'cash',
            'current',
            'deposit',
          ]);
        });
        await tester.pumpAndSettle();
        expect(
          visibleOrder(),
          move.$1 == 0
              ? ['section_current', 'section_timeDeposit', 'section_cash']
              : ['section_cash', 'section_current', 'section_timeDeposit'],
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
