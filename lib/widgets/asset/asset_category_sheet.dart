import 'package:flutter/material.dart';

import '../../config/asset_config.dart';
import '../../l10n/l10n.dart';
import '../../models/asset_account.dart';
import '../../models/asset_category.dart';
import '../common/app_colors.dart';
import '../common/app_ui.dart';
import '../common/dialog_utils.dart';
import '../common/form_sheet.dart';
import '../../utils/center_toast.dart';
import 'asset_style.dart';

IconData assetCategoryIcon(AssetCategory category) {
  if (category.id.contains('property')) return Icons.home_outlined;
  if (category.id.contains('retirement') ||
      category.id.contains('Retirement') ||
      category.id.contains('Mpf') ||
      category.id.contains('Pension')) {
    return Icons.account_balance_wallet_outlined;
  }
  return switch (category.calculationType) {
    AssetType.cash => Icons.payments_outlined,
    AssetType.current => Icons.account_balance_outlined,
    AssetType.timeDeposit => Icons.savings_outlined,
    AssetType.wealthProduct => Icons.monetization_on_outlined,
    AssetType.providentFund => Icons.home_work_outlined,
  };
}

Color assetCategoryColor(AssetCategory category) {
  if (category.id.contains('property')) return AssetStyle.provident;
  if (category.id.contains('retirement') ||
      category.id.contains('Retirement') ||
      category.id.contains('Mpf') ||
      category.id.contains('Pension')) {
    return AssetStyle.deposit;
  }
  return switch (category.calculationType) {
    AssetType.cash => AssetStyle.cash,
    AssetType.current => AssetStyle.current,
    AssetType.timeDeposit => AssetStyle.deposit,
    AssetType.wealthProduct => AssetStyle.wealth,
    AssetType.providentFund => AssetStyle.provident,
  };
}

Future<AssetCategory?> showAssetCategorySheet(
  BuildContext context, {
  required List<AssetCategory> categories,
  Set<String> usedCategoryIds = const {},
  required Future<bool> Function(AssetCategory) onCreate,
  required Future<bool> Function(AssetCategory, String) onRename,
  required Future<bool> Function(AssetCategory) onDelete,
}) => showModalBottomSheet<AssetCategory>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (sheetContext) => _CategorySheet(
    categories: categories.where((category) {
      return AssetCategory.availableInPicker(
        category,
        AssetCategory.defaultTemplateRegion(L10n.deviceLocale.countryCode),
        hasAssets: usedCategoryIds.contains(category.id),
      );
    }).toList(),
    onCreate: onCreate,
    onRename: onRename,
    onDelete: onDelete,
  ),
);

class _CategorySheet extends StatefulWidget {
  final List<AssetCategory> categories;
  final Future<bool> Function(AssetCategory) onCreate;
  final Future<bool> Function(AssetCategory, String) onRename;
  final Future<bool> Function(AssetCategory) onDelete;

  const _CategorySheet({
    required this.categories,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late List<AssetCategory> categories;

  @override
  void initState() {
    super.initState();
    categories = List.of(widget.categories);
  }

  Future<void> _createTemplate() async {
    final category = await _showTemplateDialog(context, categories);
    if (category == null || !mounted) return;
    if (!await widget.onCreate(category)) {
      if (mounted) {
        CenterToast.error(context, AssetConfig.categoryAlreadyExists);
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(category);
  }

  Future<void> _createCustom() async {
    final category = await _showCustomDialog(context);
    if (category == null || !mounted) return;
    if (!await widget.onCreate(category)) {
      if (mounted) {
        CenterToast.error(context, AssetConfig.categoryAlreadyExists);
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(category);
  }

  Future<void> _rename(AssetCategory category) async {
    final name = await showRenameAssetCategoryDialog(context, category);
    if (name == null || !mounted) return;
    if (!await widget.onRename(category, name)) {
      if (mounted) CenterToast.error(context, AssetConfig.categoryNameInvalid);
      return;
    }
    setState(() {
      final index = categories.indexWhere((item) => item.id == category.id);
      if (index >= 0) categories[index] = category.renamed(name);
    });
  }

  Future<void> _delete(AssetCategory category) async {
    if (!await widget.onDelete(category)) {
      if (mounted) {
        CenterToast.error(context, AssetConfig.categoryDeleteBlocked);
      }
      return;
    }
    setState(() => categories.removeWhere((item) => item.id == category.id));
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .75,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(AssetConfig.categoryChoose, style: TextStyles.sectionTitle),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final color = assetCategoryColor(category);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: .12),
                      child: Icon(assetCategoryIcon(category), color: color),
                    ),
                    title: Text(
                      AssetConfig.labelForCategory(category),
                      style: TextStyles.bodyRegular,
                    ),
                    subtitle: Text(
                      _valueTypeLabel(category.calculationType),
                      style: TextStyles.body13.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: AssetConfig.categoryManage,
                      color: AppColors.surface,
                      icon: Icon(
                        Icons.more_horiz,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (action) => action == 'rename'
                          ? _rename(category)
                          : _delete(category),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(AssetConfig.categoryRename),
                        ),
                        if (!category.isBuiltIn)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(AssetConfig.categoryDelete),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).pop(category),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final template = SizedBox(
                    height: 48,
                    child: cancelButton(
                      onTap: _createTemplate,
                      text: AssetConfig.categoryTemplates,
                    ),
                  );
                  final custom = SizedBox(
                    height: 48,
                    child: confirmButton(
                      onTap: _createCustom,
                      text: AssetConfig.categoryCustom,
                      gradient: const LinearGradient(
                        colors: [AppColors.blueDark, AppColors.blueAccent],
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 360) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [template, const SizedBox(height: 12), custom],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: template),
                      const SizedBox(width: 12),
                      Expanded(child: custom),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _valueTypeLabel(AssetType type) => switch (type) {
  AssetType.timeDeposit => AssetConfig.categoryValueDeposit,
  AssetType.wealthProduct => AssetConfig.categoryValueNav,
  _ => AssetConfig.categoryValueBalance,
};

Future<AssetCategory?> _showTemplateDialog(
  BuildContext context,
  List<AssetCategory> existing,
) => showDialog<AssetCategory>(
  context: context,
  builder: (dialogContext) {
    var region = AssetCategory.defaultTemplateRegion(
      L10n.deviceLocale.countryCode,
    );
    return StatefulBuilder(
      builder: (context, setState) {
        final templates = AssetCategory.templatesForRegion(region);
        return dialogFrame(
          context: context,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  AssetConfig.categoryTemplates,
                  style: TextStyles.dialogTitle,
                ),
              ),
              const SizedBox(height: 16),
              _categoryFieldLabel(AssetConfig.categoryRegion),
              const SizedBox(height: 6),
              _categoryDropdown<String>(
                value: region,
                items: [
                  for (final value in ['global', 'US', 'HK', 'CN'])
                    DropdownMenuItem(
                      value: value,
                      child: Text(AssetConfig.regionLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => region = value);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * .42).clamp(
                  140.0,
                  340.0,
                ),
                child: ListView(
                  children: [
                    for (final template in templates)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          AssetConfig.labelForCategory(template),
                          style: TextStyles.bodyRegular,
                        ),
                        subtitle: Text(
                          _valueTypeLabel(template.calculationType),
                          style: TextStyles.body13.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        enabled: !existing.any(
                          (item) => item.id == template.id,
                        ),
                        onTap: existing.any((item) => item.id == template.id)
                            ? null
                            : () => Navigator.of(dialogContext).pop(template),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              cancelButton(
                onTap: () => Navigator.of(dialogContext).pop(),
                text: AssetConfig.categoryCancel,
              ),
            ],
          ),
        );
      },
    );
  },
);

Future<AssetCategory?> _showCustomDialog(BuildContext context) =>
    showDialog<AssetCategory>(
      context: context,
      builder: (dialogContext) => const _CustomCategoryDialog(),
    );

class _CustomCategoryDialog extends StatefulWidget {
  const _CustomCategoryDialog();

  @override
  State<_CustomCategoryDialog> createState() => _CustomCategoryDialogState();
}

class _CustomCategoryDialogState extends State<_CustomCategoryDialog> {
  final nameController = TextEditingController();
  AssetType type = AssetType.cash;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => dialogFrame(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            AssetConfig.categoryCustom,
            style: TextStyles.dialogTitle,
          ),
        ),
        const SizedBox(height: 16),
        _categoryFieldLabel(AssetConfig.categoryName),
        const SizedBox(height: 6),
        TextField(
          controller: nameController,
          maxLength: 32,
          autofocus: true,
          style: TextStyles.bodyRegular,
          decoration: appInputDecoration(hintText: AssetConfig.categoryName),
        ),
        const SizedBox(height: 12),
        _categoryFieldLabel(AssetConfig.categoryCalculation),
        const SizedBox(height: 6),
        _categoryDropdown<AssetType>(
          value: type,
          items: [
            for (final value in [
              AssetType.cash,
              AssetType.timeDeposit,
              AssetType.wealthProduct,
            ])
              DropdownMenuItem(
                value: value,
                child: Text(_valueTypeLabel(value)),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => type = value);
          },
        ),
        const SizedBox(height: 20),
        actionButtonRow(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              CenterToast.error(context, AssetConfig.categoryNameInvalid);
              return;
            }
            Navigator.of(context).pop(AssetCategory.custom(name, type));
          },
          cancelText: AssetConfig.categoryCancel,
          confirmText: AssetConfig.categoryCreate,
          confirmGradient: const LinearGradient(
            colors: [AppColors.blueDark, AppColors.blueAccent],
          ),
        ),
      ],
    ),
  );
}

Future<String?> showRenameAssetCategoryDialog(
  BuildContext context,
  AssetCategory category,
) => showDialog<String>(
  context: context,
  builder: (dialogContext) => _RenameCategoryDialog(category: category),
);

class _RenameCategoryDialog extends StatefulWidget {
  final AssetCategory category;

  const _RenameCategoryDialog({required this.category});

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: AssetConfig.labelForCategory(widget.category),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => dialogFrame(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            AssetConfig.categoryRename,
            style: TextStyles.dialogTitle,
          ),
        ),
        const SizedBox(height: 16),
        _categoryFieldLabel(AssetConfig.categoryName),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLength: 32,
          autofocus: true,
          style: TextStyles.bodyRegular,
          decoration: appInputDecoration(hintText: AssetConfig.categoryName),
        ),
        const SizedBox(height: 20),
        actionButtonRow(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () => Navigator.of(context).pop(controller.text),
          cancelText: AssetConfig.categoryCancel,
          confirmText: AssetConfig.categorySave,
          confirmGradient: const LinearGradient(
            colors: [AppColors.blueDark, AppColors.blueAccent],
          ),
        ),
      ],
    ),
  );
}

Widget _categoryFieldLabel(String label) => Text(
  label,
  style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
);

Widget _categoryDropdown<T>({
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) => DropdownButtonFormField<T>(
  initialValue: value,
  isExpanded: true,
  borderRadius: BorderRadius.circular(12),
  menuMaxHeight: 280,
  dropdownColor: AppColors.surface,
  iconEnabledColor: AppColors.textSecondary,
  style: TextStyles.bodyRegular,
  decoration: appInputDecoration(),
  items: items,
  onChanged: onChanged,
);
