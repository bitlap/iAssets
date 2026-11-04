import 'asset_account.dart';

sealed class AssetFlatItem {
  const AssetFlatItem();
}

class SectionHeader extends AssetFlatItem {
  final AssetType type;
  final String categoryId;
  final bool expanded;
  SectionHeader(this.type, this.expanded, {String? categoryId})
    : categoryId = categoryId ?? type.name;
}

class AssetCardItem extends AssetFlatItem {
  final AssetBase asset;
  const AssetCardItem(this.asset);
}
