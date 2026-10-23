import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
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
  Future<void>? _refreshInFlight;
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
    cryptoTotalValue: widget.cryptoTotalValue,
  );
  String get headerSubtitle => _buildSubtitle();

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

  Future<void> _load({bool showOverlay = true}) async {
    if (showOverlay) setState(() => _isLoading = true);
    final (assets, order) = await AssetDataManager.loadAssetsAndOrder();
    if (!mounted) return;
    setState(() {
      _assets = assets;
      _expandedTypes.clear();
      _sectionOrder = order;
      if (showOverlay) _isLoading = false;
      _lastRefreshTime = DateTime.now();
    });
    widget.onHeaderChanged?.call();
    _rebuildFlatItems();
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
            child: CircularProgressIndicator(color: AppColors.textSecondary),
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
      AssetType.cash => (Icons.payments, AssetStyle.cash, AssetConfig.cash),
      AssetType.timeDeposit => (
        Icons.savings,
        AssetStyle.deposit,
        AssetConfig.timeDeposit,
      ),
      AssetType.wealthProduct => (
        Icons.monetization_on,
        AssetStyle.wealth,
        AssetConfig.wealthProduct,
      ),
      AssetType.current => (
        Icons.account_balance,
        AssetStyle.current,
        AssetConfig.current,
      ),
      AssetType.providentFund => (
        Icons.home_work,
        AssetStyle.provident,
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
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
    final (icon, name, value, onTap) = switch (asset) {
      CashAccount cash => (
        Icons.payments,
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
        Icons.savings,
        td.name.isNotEmpty ? td.name : AssetConfig.defaultNameTD,
        td.totalValue,
        () => _onEditTD(td),
      ),
      WealthProduct wp => (
        Icons.monetization_on,
        wp.name.isNotEmpty ? wp.name : AssetConfig.defaultNameWP,
        wp.totalValue,
        () => _onEditWP(wp),
      ),
      CurrentAccount account => (
        Icons.account_balance,
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
        Icons.home_work,
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
      final daysLeft = asset.endDate.difference(DateTime.now()).inDays;
      detail = daysLeft > 0
          ? AssetConfig.daysRemaining.replaceAll('{days}', '$daysLeft')
          : AssetConfig.expired;
      if (daysLeft <= 0) detailColor = AssetStyle.deposit;
    } else if (asset is WealthProduct) {
      detail = '${AssetConfig.fieldNav} ${CurrencyUtil.formatRate(asset.nav)}';
    }
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
      icon: icon,
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
