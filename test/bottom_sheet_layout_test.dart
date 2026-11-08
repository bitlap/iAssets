import 'dart:io';

import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/asset_category.dart';
import 'package:assets/services/crypto/crypto_store.dart';
import 'package:assets/widgets/asset/asset_category_sheet.dart';
import 'package:assets/widgets/asset/asset_dialogs.dart';
import 'package:assets/widgets/common/app_theme.dart';
import 'package:assets/widgets/crypto/add_exchange_sheet.dart';
import 'package:assets/widgets/stock/add_stock_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

void main() {
  late Directory storage;
  setUpAll(() async => storage = await initializeTestStorage());
  tearDownAll(() => storage.deleteSync(recursive: true));
  tearDown(() => L10n.applyLanguage(L10n.langZh));

  for (final brightness in Brightness.values) {
    testWidgets('bottom sheets fill the window and resize in $brightness', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      L10n.applyLanguage(L10n.langEn);
      final store = CryptoStore();
      addTearDown(store.dispose);
      final sheets = <String, void Function(BuildContext)>{
        'stock method': showAddStockMethodSheet,
        'custom stock': (context) => showCustomStockSheet(
          context,
          initialCurrency: 'USD',
          existingSymbols: {},
        ),
        'asset type': showAddAssetSheet,
        'asset category': (context) => showAssetCategorySheet(
          context,
          categories: AssetCategory.builtIns,
          onCreate: (_) async => true,
          onRename: (_, _) async => true,
          onDelete: (_) async => true,
        ),
        'exchange': (context) => showAddExchangeSheet(context, store),
      };
      for (final entry in sheets.entries) {
        tester.view.physicalSize = const Size(768, 1024);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(entry.key),
            theme: AppTheme.data(brightness),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => entry.value(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        // Resize an already open route: rotation and Split View must also adapt.
        for (final size in const [
          Size(768, 1024),
          Size(1024, 768),
          Size(1366, 1024),
          Size(600, 900),
          Size(390, 844),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          final sheet = find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Material),
              )
              .first;
          final rect = tester.getRect(sheet);
          expect(rect.left, closeTo(0, .01), reason: '${entry.key}: $size');
          expect(
            rect.width,
            closeTo(size.width, .01),
            reason: '${entry.key}: $size',
          );
          expect(rect.bottom, closeTo(size.height, .01));
          expect(tester.takeException(), isNull, reason: entry.key);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }
}
