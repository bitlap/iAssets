import 'dart:io';

import 'package:assets/models/asset_account.dart';
import 'package:assets/models/asset_category.dart';
import 'package:assets/models/asset_flat_item.dart';
import 'package:assets/services/asset_data_manager.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/pro_service.dart';
import 'package:assets/services/settings_service.dart';
import 'package:assets/utils/asset_calculator.dart';
import 'package:assets/utils/asset_reorder_util.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async => directory = await initializeTestStorage());
  tearDownAll(() => directory.deleteSync(recursive: true));
  setUp(() async {
    for (final file in directory.listSync()) {
      file.deleteSync(recursive: true);
    }
    await SettingsService.reload();
  });

  test('legacy assets keep their type category and valuation', () async {
    final old = AssetBase.fromJson({
      'id': 'old',
      'type': 'timeDeposit',
      'principal': 1000,
      'annualRate': 6,
      'durationMonths': 12,
    });
    expect(old.categoryKey, 'timeDeposit');
    expect(old.toJson().containsKey('categoryId'), isFalse);
    expect(AssetCalculator.getAssetValue(old, old.currency), 1060);
    await IcloudStorage.saveAssets([old]);
    final (assets, categories, order) =
        await AssetDataManager.loadCategoryState();
    expect(assets.single.categoryKey, 'timeDeposit');
    expect(categories.any((item) => item.id == 'timeDeposit'), isTrue);
    expect(order, contains('timeDeposit'));
  });

  test(
    'regional templates keep universal types and limit provident fund to CN',
    () {
      expect(AssetCategory.defaultTemplateRegion('us'), 'US');
      expect(AssetCategory.defaultTemplateRegion('hk'), 'HK');
      expect(AssetCategory.defaultTemplateRegion('cn'), 'CN');
      expect(AssetCategory.defaultTemplateRegion('GB'), 'global');
      expect(AssetCategory.defaultTemplateRegion(null), 'global');

      final globalIds = AssetCategory.templatesForRegion(
        'global',
      ).map((category) => category.id).toSet();
      expect(globalIds, contains('template.other'));
      expect(globalIds, isNot(contains('providentFund')));
      expect(
        AssetCategory.templatesForRegion('CN').map((category) => category.id),
        contains('providentFund'),
      );
      for (final type in AssetType.values.where(
        (type) => type != AssetType.providentFund,
      )) {
        final category = AssetCategory.builtIns.firstWhere(
          (item) => item.id == type.name,
        );
        expect(AssetCategory.availableInPicker(category, 'US'), isTrue);
      }
      final provident = AssetCategory.builtIns.firstWhere(
        (category) => category.id == 'providentFund',
      );
      expect(AssetCategory.availableInPicker(provident, 'US'), isFalse);
      expect(AssetCategory.availableInPicker(provident, 'CN'), isTrue);
      expect(
        AssetCategory.availableInPicker(provident, 'US', hasAssets: true),
        isTrue,
      );
    },
  );

  test('rename and backup metadata do not change calculation type', () async {
    final category = AssetCategory.custom('Retirement', AssetType.timeDeposit);
    final asset = TimeDeposit(
      id: 'retirement',
      categoryId: category.id,
      principal: 2000,
      annualRate: 3,
      durationMonths: 12,
    );
    final original = AssetCalculator.getAssetValue(asset, asset.currency);
    await AssetDataManager.saveCategoryState(
      [...AssetCategory.builtIns, category],
      [...AssetType.values.map((type) => type.name), category.id],
    );
    await IcloudStorage.saveAssets([asset]);

    final renamed = category.renamed('Pension');
    await AssetDataManager.saveCategoryState(
      [...AssetCategory.builtIns, renamed],
      [...AssetType.values.map((type) => type.name), category.id],
    );
    final (assets, categories, order) =
        await AssetDataManager.loadCategoryState();
    expect(assets.single.categoryKey, category.id);
    expect(assets.single.type, AssetType.timeDeposit);
    expect(
      AssetCalculator.getAssetValue(assets.single, asset.currency),
      original,
    );
    expect(
      categories.firstWhere((item) => item.id == category.id).customName,
      'Pension',
    );
    expect(order.last, category.id);
    expect((await SettingsService.getAll())['asset_categories'], isA<List>());
  });

  test('custom categories govern free quota and independent sorting', () {
    final a = CashAccount(id: 'a', categoryId: 'template.property');
    final b = CashAccount(id: 'b', categoryId: 'template.property');
    final c = CashAccount(id: 'c');
    final assets = <AssetBase>[a, b, c];
    const free = ProAccess();
    expect(
      free.canAddAsset(assets, AssetType.cash, categoryId: 'template.property'),
      isTrue,
    );
    expect(
      free.canAddAsset(
        [...assets, CashAccount(id: 'd', categoryId: 'template.property')],
        AssetType.cash,
        categoryId: 'template.property',
      ),
      isFalse,
    );
    final categories = [
      ...AssetCategory.builtIns,
      AssetCategory.globalTemplates[1],
    ];
    final flat = AssetDataManager.buildCategoryFlatItems(
      assets,
      categories,
      ['template.property', 'cash'],
      {'template.property'},
    );
    expect(flat.whereType<SectionHeader>().map((item) => item.categoryId), [
      'template.property',
      'cash',
    ]);
    expect(findCategorySectionRange(flat, 'template.property'), (0, 3));
    expect(
      reorderCategorySectionOrder(
        ['template.property', 'timeDeposit', 'cash'],
        flat,
        'template.property',
        0,
        3,
      ),
      ['cash', 'template.property', 'timeDeposit'],
    );
    expect(
      reorderCategoryAssets(
        assets,
        a,
        'template.property',
        1,
      ).map((item) => item.id),
      ['b', 'a', 'c'],
    );
    expect(
      free.canAddAsset([
        ...assets,
        CurrentAccount(id: 'current'),
        TimeDeposit(id: 'deposit'),
      ], AssetType.wealthProduct),
      isFalse,
    );
  });
}
