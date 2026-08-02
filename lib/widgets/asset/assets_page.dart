import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
import '../../models/asset_flat_item.dart';
import '../../utils/currency_util.dart';
import '../../utils/center_toast.dart';
import '../../utils/asset_calculator.dart';
import '../../utils/asset_reorder_util.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../services/asset_data_manager.dart';
import '../common/empty_state_widget.dart';
import '../common/currency_selector.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/section_title.dart';
import '../common/app_ui.dart';
import 'asset_card.dart';
import 'asset_header.dart';
import 'asset_dialogs.dart';

class AssetsPage extends StatefulWidget {
  final double stockTotalValue;
  final String currency;
  final ValueChanged<String>? onCurrencyChanged;

  const AssetsPage({
    super.key,
    required this.stockTotalValue,
    required this.currency,
    this.onCurrencyChanged,
  });

  @override
  State<AssetsPage> createState() => AssetsPageState();
}

class AssetsPageState extends State<AssetsPage> {
  List<AssetBase> _assets = [];
  bool _isLoading = false;
  DateTime? _lastRefreshTime;
  final Set<AssetType> _expandedTypes = {};
  List<AssetType> _sectionOrder = [
    AssetType.cash,
    AssetType.timeDeposit,
    AssetType.wealthProduct,
    AssetType.current,
    AssetType.providentFund,
  ];
  List<AssetFlatItem> _flatItems = [];

  double get _totalAssets => AssetCalculator.calculateTotalAssets(
    _assets,
    widget.stockTotalValue,
    widget.currency,
  );

  Map<AssetType, double> _totalByType(String currency) =>
      AssetCalculator.getTotalByType(_assets, currency);

  void _rebuildFlatItems() {
    _flatItems = AssetDataManager.buildFlatItems(
      _assets,
      _sectionOrder,
      _expandedTypes,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final (assets, order) = await AssetDataManager.loadAssetsAndOrder();
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _expandedTypes.clear();
      _sectionOrder = order;
      _isLoading = false;
      _lastRefreshTime = DateTime.now();
    });
    _rebuildFlatItems();
  }

  Future<void> _save() async {
    await AssetDataManager.saveAssets(_assets);
  }

  Future<void> _addAsset(AssetBase asset) async {
    if (!mounted) return;
    setState(() {
      _assets.add(asset);
      if (!_sectionOrder.contains(asset.type)) {
        _sectionOrder.add(asset.type);
      }
    });
    _rebuildFlatItems();
    try {
      await _save();
    } catch (_) {}
  }

  Future<void> _updateAsset(String id, AssetBase asset) async {
    if (!mounted) return;
    final idx = _assets.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    setState(() {
      _assets[idx] = asset;
      if (!_sectionOrder.contains(asset.type)) {
        _sectionOrder.add(asset.type);
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

  void _onFlatReorder(int oldIndex, int newIndex) {
    try {
      if (newIndex > oldIndex) newIndex--;
      final item = _flatItems[oldIndex];

      if (item is SectionHeader) {
        if (newIndex < _flatItems.length - 1) {
          final targetIdx = newIndex < oldIndex ? newIndex : newIndex + 1;
          if (_flatItems[targetIdx] is AssetCardItem) {
            if (mounted)
              CenterToast.warning(
                context,
                StockConfig.dragBetweenCategoriesHint,
              );
            return;
          }
        }
        final order = reorderSectionOrder(
          _sectionOrder,
          _flatItems,
          item.type,
          oldIndex,
          newIndex,
        );
        if (identical(order, _sectionOrder)) return;
        setState(() => _sectionOrder = order);
      } else if (item is AssetCardItem) {
        final type = item.asset.type;
        final typeAssetsLen = _assets.where((a) => a.type == type).length;

        final (sectionStart, sectionEnd) = findSectionRange(_flatItems, type);
        if (sectionStart < 0) return;

        int adjEnd = sectionEnd;
        if (oldIndex < sectionStart) {
          adjEnd--;
        } else if (oldIndex < sectionEnd) {
          adjEnd--;
        }
        if (newIndex <= sectionStart || newIndex > adjEnd) {
          if (mounted)
            CenterToast.warning(context, AssetConfig.toastCrossSection);
          return;
        }
        if (typeAssetsLen <= 1) return;

        final sameTypeCount = computeSameTypeCount(
          _flatItems,
          type,
          oldIndex,
          newIndex,
        );
        final newAssets = reorderAssets(
          _assets,
          item.asset,
          type,
          sameTypeCount,
        );
        setState(() => _assets = newAssets);
      } else {
        return;
      }

      _rebuildFlatItems();
      _saveSectionOrder();
      _save();
    } catch (_) {
      _rebuildFlatItems();
    }
  }

  Future<void> _saveSectionOrder() async {
    await AssetDataManager.saveSectionOrder(_sectionOrder);
  }

  void _toggleSection(AssetType type) {
    setState(() {
      if (_expandedTypes.contains(type)) {
        _expandedTypes.remove(type);
      } else {
        _expandedTypes.add(type);
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

  // Dialogs

  void _onAddCash() => _openDialog<CashAccount>(
    showCashAssetDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
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

  void _onAddTD() => _openDialog<TimeDeposit>(
    showTimeDepositDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
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

  void _onAddWP() => _openDialog<WealthProduct>(
    showWealthProductDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
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

  void _onAddCurrent() => _openDialog<CurrentAccount>(
    showCurrentAssetDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
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

  void _onAddProvidentFund() => _openDialog<ProvidentFundAccount>(
    showProvidentFundAssetDialog(
      context,
      defaultCurrency: widget.currency,
      assetCount: _assets.length,
    ),
    onAdd: (r) => _addAsset(r),
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
    Future<void> Function(T)? onAdd,
    Future<void> Function(T)? onUpdate,
  }) async {
    final result = await dialog;
    if (result != null && mounted) {
      if (onAdd != null) await onAdd(result);
      if (onUpdate != null) await onUpdate(result);
      CenterToast.success(context, AssetConfig.toastSaved);
    }
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          color: Colors.white,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SectionTitle(
                  title: StockConfig.tabAsset,
                  subtitle: _buildSubtitle(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AssetHeader(
                    totalAssets: _totalAssets,
                    stockTotalValue: widget.stockTotalValue,
                    currency: widget.currency,
                    totalsByType: _totalByType(widget.currency),
                    onCurrencyTap: _showCurrencyMenu,
                  ),
                ),
              ),
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
                  onReorder: _onFlatReorder,
                  itemBuilder: (context, index) {
                    final item = _flatItems[index];
                    return switch (item) {
                      SectionHeader(:final type, :final expanded) =>
                        _buildSectionHeader(type, expanded, index),
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
            child: const CircularProgressIndicator(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  // Section Header

  Widget _buildSectionHeader(AssetType type, bool expanded, int index) {
    final items = _assets.where((a) => a.type == type).toList();
    final count = items.length;
    final total = _totalByType(widget.currency)[type] ?? 0;

    final (icon, iconColor, label) = switch (type) {
      AssetType.cash => (Icons.payments, AppColors.success, AssetConfig.cash),
      AssetType.timeDeposit => (
        Icons.savings,
        AppColors.warning,
        AssetConfig.timeDeposit,
      ),
      AssetType.wealthProduct => (
        Icons.monetization_on,
        AppColors.accent,
        AssetConfig.wealthProduct,
      ),
      AssetType.current => (
        Icons.account_balance,
        AppColors.cyan,
        AssetConfig.current,
      ),
      AssetType.providentFund => (
        Icons.home_work,
        AppColors.purple,
        AssetConfig.providentFund,
      ),
    };

    final sym = CurrencyUtil.getSymbol(widget.currency);

    return ReorderableDelayedDragStartListener(
      key: ValueKey('section_${type.name}'),
      index: index,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
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
                onTap: () => _toggleSection(type),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(label, style: TextStyles.subtitle),
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyles.body13.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
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

  // Asset Item

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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: AppColors.danger, size: 22),
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
    return switch (asset) {
      CashAccount c => _buildCashCard(c, index),
      TimeDeposit t => _buildTimeDepositCard(t, index),
      WealthProduct w => _buildWealthProductCard(w, index),
      CurrentAccount c => _buildCurrentCard(c, index),
      ProvidentFundAccount p => _buildProvidentFundCard(p, index),
    };
  }

  Widget _buildCashCard(CashAccount cash, int index) {
    final sym = CurrencyUtil.getSymbol(cash.currency);
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: AppColors.iconMuted,
          ),
        ),
      ),
      icon: Icons.payments,
      iconColor: AppColors.success,
      name: cash.name.isNotEmpty
          ? cash.name
          : AssetConfig.defaultNameCash.replaceAll('{currency}', cash.currency),
      createdAt: cash.createdAt,
      updatedAt: cash.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$sym${CurrencyUtil.formatCompact(cash.balance)}',
          style: TextStyles.sectionTitle,
        ),
      ),
      onTap: () => _onEditCash(cash),
      onLongPress: () {},
    );
  }

  Widget _buildTimeDepositCard(TimeDeposit td, int index) {
    final remaining = td.endDate.difference(DateTime.now());
    final daysLeft = remaining.inDays > 0 ? remaining.inDays : 0;
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: AppColors.iconMuted,
          ),
        ),
      ),
      icon: Icons.savings,
      iconColor: AppColors.warning,
      name: td.name.isNotEmpty ? td.name : AssetConfig.defaultNameTD,
      createdAt: td.createdAt,
      updatedAt: td.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${CurrencyUtil.getSymbol(td.currency)}${CurrencyUtil.formatCompact(td.totalValue)}',
              style: TextStyles.sectionTitle,
            ),
            const SizedBox(height: 2),
            Text(
              daysLeft > 0
                  ? AssetConfig.daysRemaining.replaceAll('{days}', '$daysLeft')
                  : AssetConfig.expired,
              style: TextStyles.caption.copyWith(
                color: daysLeft > 0
                    ? AppColors.textSecondary
                    : AppColors.warning,
              ),
            ),
          ],
        ),
      ),
      onTap: () => _onEditTD(td),
      onLongPress: () {},
    );
  }

  Widget _buildWealthProductCard(WealthProduct wp, int index) {
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: AppColors.iconMuted,
          ),
        ),
      ),
      icon: Icons.monetization_on,
      iconColor: AppColors.accent,
      name: wp.name.isNotEmpty ? wp.name : AssetConfig.defaultNameWP,
      createdAt: wp.createdAt,
      updatedAt: wp.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${CurrencyUtil.getSymbol(wp.currency)}${CurrencyUtil.formatCompact(wp.totalValue)}',
          style: TextStyles.sectionTitle,
        ),
      ),
      onTap: () => _onEditWP(wp),
      onLongPress: () {},
    );
  }

  Widget _buildCurrentCard(CurrentAccount account, int index) {
    final sym = CurrencyUtil.getSymbol(account.currency);
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: AppColors.iconMuted,
          ),
        ),
      ),
      icon: Icons.account_balance,
      iconColor: AppColors.cyan,
      name: account.name.isNotEmpty
          ? account.name
          : AssetConfig.defaultNameCurrent.replaceAll(
              '{currency}',
              account.currency,
            ),
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$sym${CurrencyUtil.formatCompact(account.balance)}',
          style: TextStyles.sectionTitle,
        ),
      ),
      onTap: () => _onEditCurrent(account),
      onLongPress: () {},
    );
  }

  Widget _buildProvidentFundCard(ProvidentFundAccount account, int index) {
    final sym = CurrencyUtil.getSymbol(account.currency);
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(
            Icons.drag_indicator,
            size: 20,
            color: AppColors.iconMuted,
          ),
        ),
      ),
      icon: Icons.home_work,
      iconColor: AppColors.purple,
      name: account.name.isNotEmpty
          ? account.name
          : AssetConfig.defaultNameProvidentFund.replaceAll(
              '{currency}',
              account.currency,
            ),
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$sym${CurrencyUtil.formatCompact(account.balance)}',
          style: TextStyles.sectionTitle,
        ),
      ),
      onTap: () => _onEditProvidentFund(account),
      onLongPress: () {},
    );
  }

  /// 由底部 + 号按钮调用
  void onAddAsset(AssetType type) {
    switch (type) {
      case AssetType.cash:
        _onAddCash();
      case AssetType.timeDeposit:
        _onAddTD();
      case AssetType.wealthProduct:
        _onAddWP();
      case AssetType.current:
        _onAddCurrent();
      case AssetType.providentFund:
        _onAddProvidentFund();
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
