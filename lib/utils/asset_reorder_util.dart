import '../models/asset_account.dart';
import '../models/asset_flat_item.dart';

(int, int) findCategorySectionRange(
  List<AssetFlatItem> items,
  String categoryId,
) {
  var start = -1;
  var end = items.length;
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item is! SectionHeader) continue;
    if (item.categoryId == categoryId) {
      start = i;
    } else if (start >= 0) {
      end = i;
      break;
    }
  }
  return (start, end);
}

List<String> reorderCategorySectionOrder(
  List<String> order,
  List<AssetFlatItem> flatItems,
  String categoryId,
  int oldIndex,
  int newIndex,
) {
  if (!order.contains(categoryId)) return order;
  final visible = flatItems
      .whereType<SectionHeader>()
      .map((item) => item.categoryId)
      .toList();
  final oldVisibleIndex = visible.indexOf(categoryId);
  if (oldVisibleIndex < 0) return order;
  var targetSectionIndex = 0;
  for (var i = 0; i < newIndex; i++) {
    final originalIndex = i < oldIndex ? i : i + 1;
    if (originalIndex >= flatItems.length) break;
    if (flatItems[originalIndex] is SectionHeader) targetSectionIndex++;
  }
  if (oldVisibleIndex == targetSectionIndex) return order;
  visible.remove(categoryId);
  visible.insert(targetSectionIndex.clamp(0, visible.length), categoryId);
  return [
    ...visible,
    for (final id in order)
      if (!visible.contains(id)) id,
  ];
}

int computeSameCategoryCount(
  List<AssetFlatItem> flatItems,
  String categoryId,
  int oldIndex,
  int newIndex,
) {
  var count = 0;
  for (var i = 0; i < newIndex; i++) {
    final originalIndex = i < oldIndex ? i : i + 1;
    if (originalIndex >= flatItems.length) break;
    final item = flatItems[originalIndex];
    if (item is AssetCardItem && item.asset.categoryKey == categoryId) count++;
  }
  return count;
}

List<AssetBase> reorderCategoryAssets(
  List<AssetBase> assets,
  AssetBase item,
  String categoryId,
  int sameCategoryCount,
) {
  final reordered = List<AssetBase>.from(assets)..remove(item);
  var insertAt = reordered.length;
  var seen = 0;
  for (var i = 0; i < reordered.length; i++) {
    if (reordered[i].categoryKey != categoryId) continue;
    if (seen == sameCategoryCount) {
      insertAt = i;
      break;
    }
    seen++;
  }
  if (insertAt == reordered.length && seen > 0) {
    insertAt =
        reordered.lastIndexWhere((asset) => asset.categoryKey == categoryId) +
        1;
  }
  reordered.insert(insertAt, item);
  return reordered;
}

(int, int) findSectionRange(List<AssetFlatItem> items, AssetType type) {
  int start = -1;
  int end = items.length;
  for (int i = 0; i < items.length; i++) {
    if (items[i] is SectionHeader) {
      final h = items[i] as SectionHeader;
      if (h.type == type) {
        start = i;
      } else if (start >= 0 && end == items.length) {
        end = i;
        break;
      }
    }
  }
  return (start, end);
}

List<AssetType> reorderSectionOrder(
  List<AssetType> sectionOrder,
  List<AssetFlatItem> flatItems,
  AssetType type,
  int oldIndex,
  int newIndex,
) {
  final oldSectionIdx = sectionOrder.indexOf(type);
  int targetSectionIdx = 0;
  for (int i = 0; i < newIndex; i++) {
    final origIdx = i < oldIndex ? i : i + 1;
    if (origIdx >= flatItems.length) break;
    if (flatItems[origIdx] is SectionHeader) targetSectionIdx++;
  }
  if (oldSectionIdx == targetSectionIdx) return sectionOrder;

  final order = List<AssetType>.from(sectionOrder);
  order.removeAt(oldSectionIdx);
  order.insert(targetSectionIdx, type);
  for (final t in AssetType.values) {
    if (!order.contains(t)) {
      order.add(t);
    }
  }
  return order;
}

int computeSameTypeCount(
  List<AssetFlatItem> flatItems,
  AssetType type,
  int oldIndex,
  int newIndex,
) {
  int count = 0;
  for (int i = 0; i < newIndex; i++) {
    final origIdx = i < oldIndex ? i : i + 1;
    if (origIdx >= flatItems.length) break;
    final fi = flatItems[origIdx];
    if (fi is AssetCardItem && fi.asset.type == type) {
      count++;
    }
  }
  return count;
}

List<AssetBase> reorderAssets(
  List<AssetBase> assets,
  AssetBase item,
  AssetType type,
  int sameTypeCount,
) {
  final newAssets = List<AssetBase>.from(assets)
    ..removeAt(assets.indexOf(item));

  int insertAt = newAssets.length;
  int typeCount = 0;
  for (int i = 0; i < newAssets.length; i++) {
    if (newAssets[i].type == type) {
      if (typeCount == sameTypeCount) {
        insertAt = i;
        break;
      }
      typeCount++;
    }
  }
  if (insertAt == newAssets.length && typeCount > 0) {
    for (int i = newAssets.length - 1; i >= 0; i--) {
      if (newAssets[i].type == type) {
        insertAt = i + 1;
        break;
      }
    }
  }
  newAssets.insert(insertAt, item);
  return newAssets;
}
