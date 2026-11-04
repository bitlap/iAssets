import 'dart:math';

import 'asset_account.dart';

/// A display category is independent of the asset's valuation model.
class AssetCategory {
  final String id;
  final AssetType calculationType;
  final String labelKey;
  final String? customName;

  const AssetCategory({
    required this.id,
    required this.calculationType,
    required this.labelKey,
    this.customName,
  });

  bool get isBuiltIn => AssetType.values.any((type) => type.name == id);

  AssetCategory renamed(String name) => AssetCategory(
    id: id,
    calculationType: calculationType,
    labelKey: labelKey,
    customName: name.trim(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'calculationType': calculationType.name,
    'labelKey': labelKey,
    if (customName != null) 'customName': customName,
  };

  static AssetCategory? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id'];
    final typeName = value['calculationType'];
    if (id is! String || id.isEmpty || typeName is! String) return null;
    final type = AssetType.values.where((item) => item.name == typeName);
    if (type.isEmpty) return null;
    return AssetCategory(
      id: id,
      calculationType: type.first,
      labelKey: value['labelKey'] is String
          ? value['labelKey'] as String
          : typeName,
      customName: value['customName'] is String
          ? value['customName'] as String
          : null,
    );
  }

  static List<AssetCategory> get builtIns => [
    for (final type in AssetType.values)
      AssetCategory(id: type.name, calculationType: type, labelKey: type.name),
  ];

  static const List<AssetCategory> globalTemplates = [
    AssetCategory(
      id: 'template.retirement',
      calculationType: AssetType.cash,
      labelKey: 'assetCategoryRetirement',
    ),
    AssetCategory(
      id: 'template.property',
      calculationType: AssetType.cash,
      labelKey: 'assetCategoryProperty',
    ),
    AssetCategory(
      id: 'template.other',
      calculationType: AssetType.cash,
      labelKey: 'assetCategoryOther',
    ),
  ];

  static const Map<String, List<AssetCategory>> regionTemplates = {
    'US': [
      AssetCategory(
        id: 'template.usRetirement',
        calculationType: AssetType.cash,
        labelKey: 'assetCategoryUsRetirement',
      ),
    ],
    'HK': [
      AssetCategory(
        id: 'template.hkMpf',
        calculationType: AssetType.cash,
        labelKey: 'assetCategoryHkMpf',
      ),
    ],
    'CN': [
      AssetCategory(
        id: 'template.cnPension',
        calculationType: AssetType.cash,
        labelKey: 'assetCategoryCnPension',
      ),
    ],
  };

  static AssetCategory custom(String name, AssetType calculationType) {
    final random = Random.secure().nextInt(1 << 24).toRadixString(36);
    return AssetCategory(
      id: 'custom.${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}.$random',
      calculationType: calculationType,
      labelKey: calculationType.name,
      customName: name.trim(),
    );
  }
}
