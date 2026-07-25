import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
import '../../models/asset_flat_item.dart';
import '../../utils/currency_helper.dart';
import '../../utils/center_toast.dart';
import '../../utils/asset_calculator.dart';
import '../../utils/asset_reorder_util.dart';
import '../../config/app_config.dart';
import '../../services/asset_data_manager.dart';
import '../common/empty_state_widget.dart';
import '../common/currency_selector.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/draggable_fab.dart';
import '../common/section_title.dart';
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
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  List<AssetBase> _assets = [];
  bool _isLoading = false;
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
            if (mounted) CenterToast.warning(context, '请在分类标题之间拖拽');
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableHeight = constraints.maxHeight;
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              color: Colors.white,
              backgroundColor: const Color(0xFF000000),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SectionTitle(
                      title: StockConfig.tabAsset,
                      subtitle: AssetConfig.assetCountLabel.replaceAll(
                        '{count}',
                        '${_assets.length}',
                      ),
                      onAdd: () async {
                        final type = await showAddAssetSheet(context);
                        if (type == null) return;
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
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AssetHeader(
                        totalAssets: _totalAssets,
                        stockTotalValue: widget.stockTotalValue,
                        currency: widget.currency,
                        onCurrencyTap: _showCurrencyMenu,
                      ),
                    ),
                  ),
                  if (_flatItems.isEmpty)
                    const SliverFillRemaining(
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
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ),
            DraggableFab(
              onTap: () async {
                final type = await showAddAssetSheet(context);
                if (type == null) return;
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
              },
              maxHeight: usableHeight,
            ),
          ],
        );
      },
    );
  }

  // Section Header

  Widget _buildSectionHeader(AssetType type, bool expanded, int index) {
    final items = _assets.where((a) => a.type == type).toList();
    final count = items.length;
    final total = _totalByType(widget.currency)[type] ?? 0;

    final (icon, iconColor, label) = switch (type) {
      AssetType.cash => (Icons.payments, Color(0xFF34C759), AssetConfig.cash),
      AssetType.timeDeposit => (
        Icons.savings,
        Color(0xFFFF9F0A),
        AssetConfig.timeDeposit,
      ),
      AssetType.wealthProduct => (
        Icons.trending_up,
        Color(0xFF5B9CF6),
        AssetConfig.wealthProduct,
      ),
      AssetType.current => (
        Icons.account_balance,
        Color(0xFF5AC8FA),
        AssetConfig.current,
      ),
      AssetType.providentFund => (
        Icons.home_work,
        Color(0xFFAF52DE),
        AssetConfig.providentFund,
      ),
    };

    final sym = CurrencyHelper.getSymbol(widget.currency);

    return ReorderableDelayedDragStartListener(
      key: ValueKey('section_${type.name}'),
      index: index,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.08),
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
                  color: iconColor.withOpacity(0.5),
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
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$sym${CurrencyHelper.formatCompact(total)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Color(0xFF636366),
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
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Color(0xFFFF3B30), size: 22),
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
    final sym = CurrencyHelper.getSymbol(cash.currency);
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(Icons.drag_indicator, size: 20, color: Color(0xFF48484A)),
        ),
      ),
      icon: Icons.payments,
      iconColor: Color(0xFF34C759),
      name: cash.name.isNotEmpty
          ? cash.name
          : AssetConfig.defaultNameCash.replaceAll('{currency}', cash.currency),
      createdAt: cash.createdAt,
      updatedAt: cash.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$sym${CurrencyHelper.formatCompact(cash.balance)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
          child: Icon(Icons.drag_indicator, size: 20, color: Color(0xFF48484A)),
        ),
      ),
      icon: Icons.savings,
      iconColor: Color(0xFFFF9F0A),
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
              '${CurrencyHelper.getSymbol(td.currency)}${CurrencyHelper.formatCompact(td.totalValue)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              daysLeft > 0
                  ? AssetConfig.daysRemaining.replaceAll('{days}', '$daysLeft')
                  : AssetConfig.expired,
              style: TextStyle(
                fontSize: 11,
                color: daysLeft > 0 ? Color(0xFF8E8E93) : Color(0xFFFF9F0A),
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
          child: Icon(Icons.drag_indicator, size: 20, color: Color(0xFF48484A)),
        ),
      ),
      icon: Icons.trending_up,
      iconColor: const Color(0xFF5B9CF6),
      name: wp.name.isNotEmpty ? wp.name : AssetConfig.defaultNameWP,
      createdAt: wp.createdAt,
      updatedAt: wp.updatedAt,
      trailing: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${CurrencyHelper.getSymbol(wp.currency)}${CurrencyHelper.formatCompact(wp.totalValue)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      onTap: () => _onEditWP(wp),
      onLongPress: () {},
    );
  }

  Widget _buildCurrentCard(CurrentAccount account, int index) {
    final sym = CurrencyHelper.getSymbol(account.currency);
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(Icons.drag_indicator, size: 20, color: Color(0xFF48484A)),
        ),
      ),
      icon: Icons.account_balance,
      iconColor: const Color(0xFF5AC8FA),
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
          '$sym${CurrencyHelper.formatCompact(account.balance)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      onTap: () => _onEditCurrent(account),
      onLongPress: () {},
    );
  }

  Widget _buildProvidentFundCard(ProvidentFundAccount account, int index) {
    final sym = CurrencyHelper.getSymbol(account.currency);
    return AssetCardFrame(
      leading: ReorderableDragStartListener(
        index: index,
        child: Container(
          width: 28,
          height: 50,
          alignment: Alignment.center,
          child: Icon(Icons.drag_indicator, size: 20, color: Color(0xFF48484A)),
        ),
      ),
      icon: Icons.home_work,
      iconColor: const Color(0xFFAF52DE),
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
          '$sym${CurrencyHelper.formatCompact(account.balance)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      onTap: () => _onEditProvidentFund(account),
      onLongPress: () {},
    );
  }
}
