import 'package:assets/models/asset_account.dart';
import 'package:assets/models/asset_flat_item.dart';
import 'package:assets/services/asset_data_manager.dart';
import 'package:assets/utils/asset_reorder_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CashAccount a;
  late CashAccount b;
  late CurrentAccount c;
  late List<AssetBase> assets;
  late List<AssetFlatItem> flat;
  setUp(() {
    a = CashAccount(id: 'a');
    b = CashAccount(id: 'b');
    c = CurrentAccount(id: 'c');
    assets = [a, b, c];
    flat = AssetDataManager.buildFlatItems(
      assets,
      [AssetType.cash, AssetType.current, AssetType.wealthProduct],
      {AssetType.cash, AssetType.current},
    );
  });
  test('flat sections follow configured order and preserve asset order', () {
    expect(flat.length, 5);
    expect(flat.whereType<SectionHeader>().map((h) => h.type), [
      AssetType.cash,
      AssetType.current,
    ]);
    expect(flat.whereType<AssetCardItem>().map((i) => i.asset.id), [
      'a',
      'b',
      'c',
    ]);
  });
  test('collapsed categories keep headers and hide their cards', () {
    final result = AssetDataManager.buildFlatItems(
      assets,
      [AssetType.current, AssetType.cash],
      {AssetType.current},
    );
    expect(result.length, 3);
    expect(result.whereType<SectionHeader>().map((h) => h.expanded), [
      true,
      false,
    ]);
    expect(result.whereType<AssetCardItem>().single.asset.id, 'c');
    expect(assets.map((a) => a.id), ['a', 'b', 'c']);
  });
  test('section range stops at the next header or list end', () {
    expect(findSectionRange(flat, AssetType.cash), (0, 3));
    expect(findSectionRange(flat, AssetType.current), (3, 5));
    expect(findSectionRange(flat, AssetType.wealthProduct), (-1, 5));
    expect(findSectionRange([], AssetType.cash), (-1, 0));
  });
  test('moving a category to the end retains every category once', () {
    final order = [
      AssetType.cash,
      AssetType.current,
      AssetType.timeDeposit,
      AssetType.wealthProduct,
      AssetType.providentFund,
    ];
    final original = List<AssetType>.from(order);
    final result = reorderSectionOrder(order, flat, AssetType.cash, 0, 4);
    expect(result.take(2), [AssetType.current, AssetType.cash]);
    expect(result.toSet(), AssetType.values.toSet());
    expect(result.length, AssetType.values.length);
    expect(order, original);
  });
  test('same-category drag counts exclude the dragged card', () {
    expect(computeSameTypeCount(flat, AssetType.cash, 1, 2), 1);
    expect(computeSameTypeCount(flat, AssetType.cash, 2, 1), 0);
    expect(computeSameTypeCount(flat, AssetType.cash, 1, 4), 1);
  });
  test(
    'asset reordering stays within the category without mutating source',
    () {
      expect(reorderAssets(assets, a, AssetType.cash, 1).map((a) => a.id), [
        'b',
        'a',
        'c',
      ]);
      expect(reorderAssets(assets, b, AssetType.cash, 0).map((a) => a.id), [
        'b',
        'a',
        'c',
      ]);
      expect(assets.map((a) => a.id), ['a', 'b', 'c']);
    },
  );
  test('moving a sole asset and empty groups preserves all ids', () {
    final result = reorderAssets([c, a], c, AssetType.current, 0);
    expect(result.map((a) => a.id).toSet(), {'a', 'c'});
    expect(result.length, 2);
    expect(AssetDataManager.buildFlatItems([], AssetType.values, {}), isEmpty);
  });
}
