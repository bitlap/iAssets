import '../../models/asset_account.dart';
import '../../models/asset_flat_item.dart';
import '../../services/icloud_storage.dart';
import '../../services/settings_service.dart';

class AssetDataManager {
  static Future<(List<AssetBase>, List<AssetType>)> loadAssetsAndOrder() async {
    final results = await Future.wait([
      IcloudStorage.loadAssets(),
      SettingsService.getAssetSectionOrder(),
    ]);
    final assets = results[0] as List<AssetBase>;
    final savedOrder = (results[1] as List<String>)
        .map(
          (s) => AssetType.values.firstWhere(
            (t) => t.name == s,
            orElse: () => AssetType.cash,
          ),
        )
        .toList();
    for (final type in AssetType.values) {
      if (assets.any((a) => a.type == type) && !savedOrder.contains(type)) {
        savedOrder.add(type);
      }
    }
    return (assets, savedOrder);
  }

  static Future<void> saveAssets(List<AssetBase> assets) =>
      IcloudStorage.saveAssets(assets);

  static Future<void> saveSectionOrder(List<AssetType> order) =>
      SettingsService.setAssetSectionOrder(order.map((t) => t.name).toList());

  static List<AssetFlatItem> buildFlatItems(
    List<AssetBase> assets,
    List<AssetType> sectionOrder,
    Set<AssetType> expandedTypes,
  ) {
    final items = <AssetFlatItem>[];
    for (final type in sectionOrder) {
      final typeAssets = assets.where((a) => a.type == type).toList();
      if (typeAssets.isEmpty) continue;
      items.add(SectionHeader(type, expandedTypes.contains(type)));
      if (expandedTypes.contains(type)) {
        items.addAll(typeAssets.map((a) => AssetCardItem(a)));
      }
    }
    return items;
  }
}
