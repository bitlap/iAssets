import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
import '../../models/asset_category.dart';
import '../../models/asset_flat_item.dart';
import '../../utils/currency_util.dart';
import '../../utils/center_toast.dart';
import '../../utils/asset_calculator.dart';
import '../../utils/asset_reorder_util.dart';
import '../../config/app_config.dart';
import '../common/app_colors.dart';
import '../../services/asset_data_manager.dart';
import '../common/empty_state_widget.dart';
import '../common/currency_selector.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/app_ui.dart';
import 'asset_card.dart';
import 'asset_header.dart';
import 'asset_dialogs.dart';
import 'asset_style.dart';
import '../common/sensitive_text.dart';
import 'asset_category_sheet.dart';
import '../../services/pro_service.dart';
import '../pro/pro_page.dart';

enum _AssetCardAction { rollover, changeCategory }

class AssetsPage extends StatefulWidget {
  final double stockTotalValue;
  final double cryptoTotalValue;
  final bool cryptoIncomplete;
  final DateTime? cryptoUpdatedAt;
  final Future<void> Function()? onRefreshCrypto;
  final String currency;
  final ValueChanged<String>? onCurrencyChanged;
  final VoidCallback? onHeaderChanged;

  const AssetsPage({
    super.key,
    required this.stockTotalValue,
    this.cryptoTotalValue = 0,
    this.cryptoIncomplete = false,
    this.cryptoUpdatedAt,
    this.onRefreshCrypto,
    required this.currency,
    this.onCurrencyChanged,
    this.onHeaderChanged,
  });

  @override
  State<AssetsPage> createState() => AssetsPageState();
}

class AssetsPageState extends State<AssetsPage> {
  List<AssetBase> _assets = [];
  bool _isLoading = false;
  bool _rolloverOpen = false;
  Future<void>? _refreshInFlight;
  DateTime? _lastRefreshTime;
  final Set<String> _expandedCategories = {};
  List<AssetCategory> _categories = AssetCategory.builtIns;
  List<String> _sectionOrder = AssetType.values
      .map((type) => type.name)
      .toList();
  List<AssetFlatItem> _flatItems = [];

  double get _totalAssets => AssetCalculator.calculateTotalAssets(
    _assets,
    widget.stockTotalValue,
    widget.currency,
    cryptoTotalValue: widget.cryptoTotalValue,
  );
  String get headerSubtitle => _buildSubtitle();

  Map<AssetType, double> _totalByType(String currency) =>
      AssetCalculator.getTotalByType(_assets, currency);

  Map<String, double> _totalByCategory(String currency) {
    final totals = <String, double>{};
    for (final asset in _assets) {
      totals.update(
        asset.categoryKey,
        (value) => value + AssetCalculator.getAssetValue(asset, currency),
        ifAbsent: () => AssetCalculator.getAssetValue(asset, currency),
      );
    }
    return totals;
  }

  void _rebuildFlatItems() {
    _flatItems = AssetDataManager.buildCategoryFlatItems(
      _assets,
      _categories,
      _sectionOrder,
      _expandedCategories,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showOverlay = true}) async {
    if (showOverlay) setState(() => _isLoading = true);
    final (assets, categories, order) =
        await AssetDataManager.loadCategoryState();
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _categories = categories;
      _expandedCategories.clear();
      _sectionOrder = order;
      if (showOverlay) _isLoading = false;
      _lastRefreshTime = DateTime.now();
      _rebuildFlatItems();
    });
    widget.onHeaderChanged?.call();
  }

  Future<void> _refreshAssets() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final future = Future.wait([
      _load(showOverlay: false),
      if (widget.onRefreshCrypto != null) widget.onRefreshCrypto!(),
    ]);
    _refreshInFlight = future;
    return future.whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _save() async {
    await AssetDataManager.saveAssets(_assets);
    widget.onHeaderChanged?.call();
  }

  bool _canAddAsset(AssetType type, String categoryId) {
    if (_isLoading) return false;
    if (ProService.instance.access.canAddAsset(
      _assets,
      type,
      categoryId: categoryId,
    )) {
      return true;
    }
    showProPage(
      context,
      reason: _assets.any((a) => a.categoryKey == categoryId)
          ? ProReason.assetRecordLimit
          : ProReason.assetTypeLimit,
    );
    return false;
  }

  Future<bool> _addAsset(AssetBase asset) async {
    if (!mounted || !_canAddAsset(asset.type, asset.categoryKey)) return false;
    setState(() {
      _assets.add(asset);
      if (!_sectionOrder.contains(asset.categoryKey)) {
        _sectionOrder.add(asset.categoryKey);
      }
    });
    _rebuildFlatItems();
    try {
      await _save();
    } catch (_) {}
    return true;
  }

  Future<void> _updateAsset(String id, AssetBase asset) async {
    if (!mounted) return;
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    setState(() {
      asset.categoryId = _assets[idx].categoryId;
      _assets[idx] = asset;
      if (!_sectionOrder.contains(asset.categoryKey)) {
        _sectionOrder.add(asset.categoryKey);
      }
    });
    _rebuildFlatItems();
    try {
      await _save();
    } catch (_) {}
  }

  Future<void> _deleteAsset(String id) async {
    if (!mounted) return;
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final name = _assets[idx].name;
    setState(() => _assets.removeAt(idx));
    _rebuildFlatItems();
    try {
      await _save();
    } catch (_) {}
    if (mounted) {
      CenterToast.success(
        context,
        AssetConfig.toastDeleted.replaceAll('{name}', name),
      );
    }
  }

  List<AssetCategory> _moveDestinations(AssetBase asset) => _categories
      .where(
        (category) =>
            category.id != asset.categoryKey && category.accepts(asset.type),
      )
      .toList();

  Future<void> _onChangeCategory(AssetBase asset) async {
    if (_isLoading) return;
    final destinations = _moveDestinations(asset);
    if (destinations.isEmpty) {
      CenterToast.warning(context, AssetConfig.toastCrossSection);
      return;
    }
    final target = await showModalBottomSheet<AssetCategory>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AssetConfig.categoryMove,
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final category in destinations)
                        ListTile(
                          key: ValueKey('move_category_${category.id}'),
                          leading: Icon(
                            assetCategoryIcon(category),
                            color: assetCategoryColor(category),
                          ),
                          title: Text(AssetConfig.labelForCategory(category)),
                          onTap: () => Navigator.pop(sheetContext, category),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || target == null) return;
    await _moveAssetToCategory(asset, target);
  }

  Future<void> _moveAssetToCategory(
    AssetBase asset,
    AssetCategory category, {
    int? position,
  }) async {
    if (!mounted || _isLoading) return;
    if (!_categories.any((item) => item.id == category.id) ||
        !category.accepts(asset.type)) {
      CenterToast.warning(context, AssetConfig.toastCrossSection);
      return;
    }
    if (asset.categoryKey == category.id) return;
    final remaining = _assets.where((item) => item.id != asset.id).toList();
    if (!ProService.instance.access.canAddAsset(
      remaining,
      asset.type,
      categoryId: category.id,
    )) {
      if (mounted) {
        showProPage(
          context,
          reason: remaining.any((item) => item.categoryKey == category.id)
              ? ProReason.assetRecordLimit
              : ProReason.assetTypeLimit,
        );
      }
      return;
    }
    final moved = category.moveAsset(asset);
    final updated = List<AssetBase>.of(remaining);
    final targetAssets = updated
        .where((a) => a.categoryKey == category.id)
        .toList();
    final targetPosition = (position ?? targetAssets.length).clamp(
      0,
      targetAssets.length,
    );
    final insertAt = targetPosition < targetAssets.length
        ? updated.indexOf(targetAssets[targetPosition])
        : targetAssets.isEmpty
        ? updated.length
        : updated.indexOf(targetAssets.last) + 1;
    updated.insert(insertAt, moved);
    setState(() => _isLoading = true);
    try {
      await AssetDataManager.saveAssets(updated, requireSuccess: true);
      if (!mounted) return;
      setState(() {
        _assets = updated;
        _rebuildFlatItems();
      });
      widget.onHeaderChanged?.call();
      CenterToast.success(context, AssetConfig.toastSaved);
    } catch (_) {
      if (mounted) CenterToast.error(context, AssetConfig.assetSaveFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onFlatReorder(int oldIndex, int newIndex) async {
    if (_isLoading) return;
    try {
      final item = _flatItems[oldIndex];

      if (item is SectionHeader) {
        if (newIndex < _flatItems.length - 1) {
          final targetIdx = newIndex < oldIndex ? newIndex : newIndex + 1;
          if (_flatItems[targetIdx] is AssetCardItem) {
            if (mounted) {
              CenterToast.warning(
                context,
                StockConfig.dragBetweenCategoriesHint,
              );
            }
            return;
          }
        }
        final order = reorderCategorySectionOrder(
          _sectionOrder,
          _flatItems,
          item.categoryId,
          oldIndex,
          newIndex,
        );
        if (identical(order, _sectionOrder)) return;
        setState(() => _sectionOrder = order);
      } else if (item is AssetCardItem) {
        final categoryId = item.asset.categoryKey;
        final categoryAssetsLen = _assets
            .where((asset) => asset.categoryKey == categoryId)
            .length;

        final (sectionStart, sectionEnd) = findCategorySectionRange(
          _flatItems,
          categoryId,
        );
        if (sectionStart < 0) return;

        int adjEnd = sectionEnd;
        if (oldIndex < sectionStart) {
          adjEnd--;
        } else if (oldIndex < sectionEnd) {
          adjEnd--;
        }
        if (newIndex <= sectionStart || newIndex > adjEnd) {
          // Destination indices refer to the list after removing the dragged card.
          final remainingItems = List<AssetFlatItem>.of(_flatItems)
            ..removeAt(oldIndex);
          String? targetId;
          for (var i = 0; i < newIndex && i < remainingItems.length; i++) {
            final entry = remainingItems[i];
            if (entry is SectionHeader) targetId = entry.categoryId;
          }
          final targets = _categories.where(
            (category) => category.id == targetId,
          );
          if (targets.isEmpty) {
            CenterToast.warning(context, AssetConfig.toastCrossSection);
          } else {
            final target = targets.first;
            await _moveAssetToCategory(
              item.asset,
              target,
              position: computeSameCategoryCount(
                _flatItems,
                target.id,
                oldIndex,
                newIndex,
              ),
            );
          }
          return;
        }
        if (categoryAssetsLen <= 1) return;

        final sameCategoryCount = computeSameCategoryCount(
          _flatItems,
          categoryId,
          oldIndex,
          newIndex,
        );
        final newAssets = reorderCategoryAssets(
          _assets,
          item.asset,
          categoryId,
          sameCategoryCount,
        );
        setState(() => _assets = newAssets);
      } else {
        return;
      }

      _rebuildFlatItems();
      await _saveSectionOrder();
      await _save();
    } catch (_) {
      _rebuildFlatItems();
    }
  }

  Future<void> _saveSectionOrder() async {
    await AssetDataManager.saveCategoryState(_categories, _sectionOrder);
  }

  void _toggleSection(String categoryId) {
    setState(() {
      if (_expandedCategories.contains(categoryId)) {
        _expandedCategories.remove(categoryId);
      } else {
        _expandedCategories.add(categoryId);
      }
    });
    _rebuildFlatItems();
  }

  void _showCurrencyMenu() {
    CurrencySelector.show(
      context: context,
      selectedCurrency: widget.currency,
      onCurrencyChanged: (c) => widget.onCurrencyChanged?.call(c),
    );
  }

  // 弹窗

  void _onAddCash(String categoryId) => _openDialog<CashAccount>(
    showCashAssetDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
    categoryId: categoryId,
  );

  void _onEditCash(CashAccount cash) => _openDialog<CashAccount>(
    showCashAssetDialog(
      context,
      cash: cash,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onUpdate: (r) => _updateAsset(cash.id, r),
  );

  void _onAddTD(String categoryId) => _openDialog<TimeDeposit>(
    showTimeDepositDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
    categoryId: categoryId,
  );

  void _onEditTD(TimeDeposit td) => _openDialog<TimeDeposit>(
    showTimeDepositDialog(
      context,
      td: td,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onUpdate: (r) => _updateAsset(td.id, r),
  );

  Future<void> _onRolloverTD(TimeDeposit deposit) async {
    if (_rolloverOpen || _isLoading) return;
    _rolloverOpen = true;
    try {
      final result = await showTimeDepositDialog(
        context,
        td: deposit,
        rollover: true,
        defaultCurrency: deposit.currency,
        assetCount: _assets.length,
      );
      if (!mounted || result == null) return;
      final index = _assets.indexWhere((asset) => asset.id == deposit.id);
      if (index < 0) return;
      result.categoryId = _assets[index].categoryId;
      final updated = List<AssetBase>.of(_assets)..[index] = result;
      setState(() => _isLoading = true);
      try {
        await AssetDataManager.saveAssets(updated, requireSuccess: true);
      } catch (_) {
        if (mounted) CenterToast.error(context, AssetConfig.assetSaveFailed);
        return;
      }
      if (!mounted) return;
      setState(() {
        _assets = updated;
        _rebuildFlatItems();
      });
      widget.onHeaderChanged?.call();
      CenterToast.success(context, AssetConfig.toastSaved);
    } finally {
      _rolloverOpen = false;
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _onAddWP(String categoryId) => _openDialog<WealthProduct>(
    showWealthProductDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
    categoryId: categoryId,
  );

  void _onEditWP(WealthProduct wp) => _openDialog<WealthProduct>(
    showWealthProductDialog(
      context,
      wp: wp,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onUpdate: (r) => _updateAsset(wp.id, r),
  );

  void _onAddCurrent(String categoryId) => _openDialog<CurrentAccount>(
    showCurrentAssetDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
    categoryId: categoryId,
  );

  void _onEditCurrent(CurrentAccount account) => _openDialog<CurrentAccount>(
    showCurrentAssetDialog(
      context,
      account: account,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onUpdate: (r) => _updateAsset(account.id, r),
  );

  void _onAddProvidentFund(String categoryId) =>
      _openDialog<ProvidentFundAccount>(
        showProvidentFundAssetDialog(
          context,
          defaultCurrency: widget.currency,
          assetCount: _assets.length,
        ),
        onAdd: (r) => _addAsset(r),
        categoryId: categoryId,
      );

  void _onEditProvidentFund(ProvidentFundAccount account) =>
      _openDialog<ProvidentFundAccount>(
        showProvidentFundAssetDialog(
          context,
          account: account,
          defaultCurrency: widget.currency,
          assetCount: _assets.length,
        ),
        onUpdate: (r) => _updateAsset(account.id, r),
      );

  void _openDialog<T extends AssetBase>(
    Future<T?> dialog, {
    Future<bool> Function(T)? onAdd,
    Future<void> Function(T)? onUpdate,
    String? categoryId,
  }) async {
    final result = await dialog;
    if (result != null && mounted) {
      if (categoryId != null) result.categoryId = categoryId;
      if (onAdd != null && !await onAdd(result)) return;
      if (onUpdate != null) await onUpdate(result);
      if (mounted) CenterToast.success(context, AssetConfig.toastSaved);
    }
  }

  Future<void> showAddAssetPicker() async {
    if (_isLoading) return;
    final category = await showAssetCategorySheet(
      context,
      categories: _categories,
      usedCategoryIds: _assets.map((asset) => asset.categoryKey).toSet(),
      onCreate: _createCategory,
      onRename: _renameCategory,
      onDelete: _deleteCategory,
    );
    if (category != null && mounted) {
      onAddAsset(category.calculationType, categoryId: category.id);
    }
  }

  Future<bool> _createCategory(AssetCategory category) async {
    if (_categories.any((item) => item.id == category.id)) {
      // 仅适用于中国大陆的内置分类仍保留在存储中，以兼容已有账户。
      // 在其他地区的设备上选择中国大陆模板时，仍可打开添加资产表单，
      // 无需重复创建该分类。
      return category.id == AssetType.providentFund.name &&
          !_assets.any((asset) => asset.categoryKey == category.id);
    }
    if (_categories.any(
      (item) =>
          AssetConfig.labelForCategory(item).toLowerCase() ==
          AssetConfig.labelForCategory(category).toLowerCase(),
    )) {
      return false;
    }
    setState(() {
      _categories.add(category);
      _sectionOrder.add(category.id);
    });
    await _saveSectionOrder();
    return true;
  }

  Future<bool> _renameCategory(AssetCategory category, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        _categories.any(
          (item) =>
              item.id != category.id &&
              AssetConfig.labelForCategory(item).toLowerCase() ==
                  trimmed.toLowerCase(),
        )) {
      return false;
    }
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index < 0) return false;
    setState(() => _categories[index] = category.renamed(trimmed));
    await _saveSectionOrder();
    return true;
  }

  Future<bool> _deleteCategory(AssetCategory category) async {
    if (category.isBuiltIn ||
        _assets.any((asset) => asset.categoryKey == category.id)) {
      return false;
    }
    setState(() {
      _categories.removeWhere((item) => item.id == category.id);
      _sectionOrder.remove(category.id);
      _expandedCategories.remove(category.id);
    });
    await _saveSectionOrder();
    return true;
  }

  // 页面构建

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshAssets,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: AssetHeader(
                  totalAssets: _totalAssets,
                  stockTotalValue: widget.stockTotalValue,
                  cryptoTotalValue: widget.cryptoTotalValue,
                  cryptoIncomplete: widget.cryptoIncomplete,
                  cryptoUpdatedAt: widget.cryptoUpdatedAt,
                  currency: widget.currency,
                  totalsByType: _totalByType(widget.currency),
                  categories: _categories,
                  totalsByCategory: _totalByCategory(widget.currency),
                  onCurrencyTap: _showCurrencyMenu,
                ),
              ),
              if (_flatItems.isNotEmpty)
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
              if (_flatItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: Icons.account_balance_wallet_outlined,
                    title: AssetConfig.emptyTitle,
                    subtitle: AssetConfig.emptySubtitle,
                    iconSize: 64,
                    padding: EdgeInsets.symmetric(vertical: 40),
                  ),
                )
              else
                SliverReorderableList(
                  itemCount: _flatItems.length,
                  onReorderItem: _onFlatReorder,
                  itemBuilder: (context, index) {
                    final item = _flatItems[index];
                    return switch (item) {
                      SectionHeader(:final categoryId, :final expanded) =>
                        _buildSectionHeader(categoryId, expanded, index),
                      AssetCardItem(:final asset) => _buildAssetCardItem(
                        asset,
                        index,
                      ),
                    };
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black26,
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: AppColors.textSecondary),
          ),
      ],
    );
  }

  // 分类标题

  Widget _buildSectionHeader(String categoryId, bool expanded, int index) {
    final category = _categories.firstWhere((item) => item.id == categoryId);
    final items = _assets
        .where((asset) => asset.categoryKey == categoryId)
        .toList();
    final count = items.length;
    final total = _totalByCategory(widget.currency)[categoryId] ?? 0;
    final icon = assetCategoryIcon(category);
    final iconColor = assetCategoryColor(category);
    final label = AssetConfig.labelForCategory(category);

    final sym = CurrencyUtil.getSymbol(widget.currency);

    return ReorderableDelayedDragStartListener(
      key: ValueKey('section_$categoryId'),
      index: index,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AssetStyle.tint(iconColor),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AssetStyle.border(iconColor)),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: iconColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => _toggleSection(categoryId),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: label, style: TextStyles.subtitle),
                            TextSpan(
                              text: ' ($count)',
                              style: TextStyles.body13.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SensitiveText(
                      '$sym${CurrencyUtil.formatCompact(total)}',
                      style: TextStyles.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 资产条目

  Widget _buildAssetCardItem(AssetBase asset, int index) {
    return ReorderableDelayedDragStartListener(
      key: ValueKey('asset_${asset.id}'),
      index: index,
      child: Dismissible(
        key: ValueKey('del_${asset.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: 20),
          child: Icon(Icons.delete, color: AppColors.danger, size: 22),
        ),
        confirmDismiss: (_) => _confirmDelete(asset),
        onDismissed: (_) => _deleteAsset(asset.id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildAssetCard(asset, index),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(AssetBase asset) async {
    final name = asset.name.isNotEmpty
        ? asset.name
        : AssetConfig.defaultNameFallback;
    return ConfirmDeleteDialog.show(
      context,
      title: AppConfig.btnConfirm,
      content: AssetConfig.deleteConfirm.replaceAll('{name}', name),
    );
  }

  Widget _buildAssetCard(AssetBase asset, int index) {
    final (name, value, onTap) = switch (asset) {
      CashAccount cash => (
        cash.name.isNotEmpty
            ? cash.name
            : AssetConfig.defaultNameCash.replaceAll(
                '{currency}',
                cash.currency,
              ),
        cash.balance,
        () => _onEditCash(cash),
      ),
      TimeDeposit td => (
        td.name.isNotEmpty ? td.name : AssetConfig.defaultNameTD,
        td.totalValue,
        () => _onEditTD(td),
      ),
      WealthProduct wp => (
        wp.name.isNotEmpty ? wp.name : AssetConfig.defaultNameWP,
        wp.totalValue,
        () => _onEditWP(wp),
      ),
      CurrentAccount account => (
        account.name.isNotEmpty
            ? account.name
            : AssetConfig.defaultNameCurrent.replaceAll(
                '{currency}',
                account.currency,
              ),
        account.balance,
        () => _onEditCurrent(account),
      ),
      ProvidentFundAccount account => (
        account.name.isNotEmpty
            ? account.name
            : AssetConfig.defaultNameProvidentFund.replaceAll(
                '{currency}',
                account.currency,
              ),
        account.balance,
        () => _onEditProvidentFund(account),
      ),
    };
    String? detail;
    Color? detailColor;
    if (asset is TimeDeposit) {
      final daysLeft = DateUtils.dateOnly(
        asset.endDate,
      ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
      final term = daysLeft > 0
          ? AssetConfig.daysRemaining.replaceAll('{days}', '$daysLeft')
          : AssetConfig.expired;
      detail =
          '${AssetConfig.fieldAnnualRate.replaceAll(' (%)', '')} ${CurrencyUtil.formatCompact(asset.annualRate)}%\n$term';
      if (daysLeft <= 0) detailColor = AssetStyle.deposit;
    } else if (asset is WealthProduct) {
      detail =
          '${AssetConfig.fieldShares} ${CurrencyUtil.formatCompact(asset.shares)}\n${AssetConfig.fieldNav} ${CurrencyUtil.formatRate(asset.nav)}';
    }
    final category = _categories.firstWhere(
      (category) => category.id == asset.categoryKey,
      orElse: () => AssetCategory(
        id: asset.categoryKey,
        calculationType: asset.type,
        labelKey: asset.type.name,
      ),
    );
    final canChangeCategory = _moveDestinations(asset).isNotEmpty;
    final canRollover =
        asset is TimeDeposit &&
        !DateUtils.dateOnly(
          asset.endDate,
        ).isAfter(DateUtils.dateOnly(DateTime.now()));
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: SizedBox(
          width: 28,
          height: 50,
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: AppColors.iconMuted,
          ),
        ),
      ),
      icon: assetCategoryIcon(category),
      categoryColor: assetCategoryColor(category),
      name: name,
      colorSeed: asset.name.trim().isNotEmpty
          ? asset.name
          : '${asset.type.name}:${asset.currency}',
      currency: asset.currency,
      amount:
          '${CurrencyUtil.getSymbol(asset.currency)}${CurrencyUtil.formatCompact(value)}',
      detail: detail,
      detailColor: detailColor,
      createdAt: asset.createdAt,
      updatedAt: asset.updatedAt,
      onTap: onTap,
      trailing: !canRollover && !canChangeCategory
          ? null
          : PopupMenuButton<Object>(
              tooltip: AssetConfig.assetActions,
              color: AppColors.surface,
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: AppColors.textSecondary,
              ),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onSelected: (action) {
                if (action == _AssetCardAction.rollover &&
                    asset is TimeDeposit) {
                  _onRolloverTD(asset);
                } else if (action == _AssetCardAction.changeCategory) {
                  _onChangeCategory(asset);
                }
              },
              itemBuilder: (_) => [
                if (canRollover)
                  PopupMenuItem<Object>(
                    value: _AssetCardAction.rollover,
                    child: Text(AssetConfig.depositRollover),
                  ),
                if (canChangeCategory)
                  PopupMenuItem<Object>(
                    value: _AssetCardAction.changeCategory,
                    child: Text(AssetConfig.categoryMove),
                  ),
              ],
            ),
    );
  }

  /// 由底部 + 号按钮调用
  void onAddAsset(AssetType type, {String? categoryId}) {
    final id = categoryId ?? type.name;
    if (!_canAddAsset(type, id)) return;
    switch (type) {
      case AssetType.cash:
        _onAddCash(id);
      case AssetType.timeDeposit:
        _onAddTD(id);
      case AssetType.wealthProduct:
        _onAddWP(id);
      case AssetType.current:
        _onAddCurrent(id);
      case AssetType.providentFund:
        _onAddProvidentFund(id);
    }
  }

  String _buildSubtitle() {
    if (_lastRefreshTime == null) {
      return AssetConfig.assetSubtitleRefresh.replaceAll('{time}', '-');
    }
    return AssetConfig.assetSubtitleRefresh.replaceAll(
      '{time}',
      formatRefreshTime(_lastRefreshTime!),
    );
  }
}
