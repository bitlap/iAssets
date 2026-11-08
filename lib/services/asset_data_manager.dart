import '../../models/asset_account.dart';
import '../../models/asset_category.dart';
import '../../models/asset_flat_item.dart';
import '../../services/icloud_storage.dart';
import '../../services/settings_service.dart';

class AssetDataManager {
  static Future<(List<AssetBase>, List<AssetCategory>, List<String>)>
  loadCategoryState() async {
    await IcloudStorage.loadSettings();
    final results = await Future.wait([
      IcloudStorage.loadAssets(),
      SettingsService.getAssetCategories(),
      SettingsService.getAssetSectionOrder(),
    ]);
    final assets = results[0] as List<AssetBase>;
    final saved = results[1] as List<Map<String, dynamic>>;
    final byId = <String, AssetCategory>{
      for (final category in AssetCategory.builtIns) category.id: category,
    };
    for (final raw in saved) {
      final category = AssetCategory.fromJson(raw);
      if (category == null) continue;
      final builtIn = byId[category.id];
      byId[category.id] = builtIn != null && builtIn.isBuiltIn
          ? builtIn.renamed(category.customName ?? '')
          : category;
    }
    for (final asset in assets) {
      byId.putIfAbsent(
        asset.categoryKey,
        () => AssetCategory(
          id: asset.categoryKey,
          calculationType: asset.type,
          labelKey: asset.type.name,
        ),
      );
    }
    final order = <String>[];
    for (final id in results[2] as List<String>) {
      if (byId.containsKey(id) && !order.contains(id)) order.add(id);
    }
    for (final id in byId.keys) {
      if (!order.contains(id)) order.add(id);
    }
    return (assets, byId.values.toList(), order);
  }

  static Future<void> saveCategoryState(
    List<AssetCategory> categories,
    List<String> order,
  ) async {
    await SettingsService.setAssetCategories(
      categories.map((category) => category.toJson()).toList(),
    );
    await SettingsService.setAssetSectionOrder(order);
    await IcloudStorage.saveSettings();
  }

  static List<AssetFlatItem> buildCategoryFlatItems(
    List<AssetBase> assets,
    List<AssetCategory> categories,
    List<String> sectionOrder,
    Set<String> expandedIds,
  ) {
    final byId = {for (final category in categories) category.id: category};
    final items = <AssetFlatItem>[];
    for (final id in sectionOrder) {
      final category = byId[id];
      if (category == null) continue;
      final members = assets.where((asset) => asset.categoryKey == id).toList();
      if (members.isEmpty) continue;
      items.add(
        SectionHeader(
          category.calculationType,
          expandedIds.contains(id),
          categoryId: id,
        ),
      );
      if (expandedIds.contains(id)) {
        items.addAll(members.map((asset) => AssetCardItem(asset)));
      }
    }
    return items;
  }

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

  static Future<void> saveAssets(
    List<AssetBase> assets, {
    bool requireSuccess = false,
  }) => IcloudStorage.saveAssets(assets, requireSuccess: requireSuccess);

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
