import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import '../../models/calculator_models.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../utils/center_toast.dart';
import '../../utils/market_util.dart';
import '../../services/stock_quote_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/settings_service.dart';
import '../../services/stock_data_manager.dart';
import '../common/empty_state_widget.dart';
import '../common/app_ui.dart';
import '../common/section_title.dart';
import 'stock_card.dart';
import 'stock_list_header.dart';
import '../records/records_dialog.dart';
import 'edit_delete_dialogs.dart';
import 'search_stock_dialog.dart';
import 'stock_header_card.dart';
import '../dividend/global_dividend_page.dart';
import '../settings_page.dart';

/// 股票持仓主页 - 仅负责状态管理和页面组装
class StockPortfolioPage extends StatefulWidget {
  const StockPortfolioPage({super.key});

  @override
  StockPortfolioPageState createState() => StockPortfolioPageState();
}

class StockPortfolioPageState extends State<StockPortfolioPage>
    with WidgetsBindingObserver {
  // 状态
  List<StockModel> stocks = [];
  String selectedCurrency = AppConfig.defaultCurrency;
  String? _expandedStockSymbol;
  // 每只股票的操作记录
  final Map<String, List<OperationRecord>> _operationRecords = {};
  // 每只股票的派息记录
  final Map<String, List<DividendRecord>> _dividendRecords = {};

  // 行情服务实例和定时刷新
  final StockQuoteService _quoteService = StockQuoteService();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();
  Timer? _priceRefreshTimer;
  bool _isForeground = true;

  /// 平仓后是否保留持仓股票（若选择删除，则清空数据，效果等同直接删除股票）
  bool _keepStockAfterClose = false;

  // 排序状态
  String _sortColumn = 'profit'; // 'name', 'holdings', 'profit'
  bool _sortAscending = false;
  // 市场筛选
  String? _filterMarket;

  /// 数据是否有变更（脏标记），用于延迟写入 iCloud
  bool _dataDirty = false;

  /// 防抖定时器：修改后延迟自动异步同步到 iCloud
  Timer? _syncTimer;

  final ScrollController _scrollController = ScrollController();
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    StockDataManager.loadSettings().then((_) {
      _loadSavedCurrency();
      _loadKeepStockSetting();
      _loadSortSettings();
    });
    _syncStockData();
    _startRefresh();
  }

  /// 从本地存储加载默认货币
  Future<void> _loadSavedCurrency() async {
    final saved = await SettingsService.getDefaultCurrency();
    if (saved != null && mounted) {
      setState(() => selectedCurrency = saved);
    }
  }

  /// 加载平仓后是否保留持仓股票的设置
  Future<void> _loadKeepStockSetting() async {
    final keep = await SettingsService.getKeepStockAfterClose();
    if (mounted) setState(() => _keepStockAfterClose = keep);
  }

  /// 加载排序设置
  Future<void> _loadSortSettings() async {
    final column = await SettingsService.getSortColumn();
    final ascending = await SettingsService.getSortAscending();
    if (mounted) {
      setState(() {
        _sortColumn = column;
        _sortAscending = ascending;
      });
    }
  }

  /// 从本地加载股票和记录，并尝试从 iCloud 拉取最新
  Future<void> _syncStockData() async {
    final data = await StockDataManager.loadStocks();
    if (!mounted) return;
    setState(() {
      stocks = data.$1;
      _operationRecords
        ..clear()
        ..addAll(data.$2);
      _dividendRecords
        ..clear()
        ..addAll(data.$3);
      stocks = stocks
          .map(
            (s) => StockDataManager.recalculateStock(
              s,
              _operationRecords[s.symbol],
            ),
          )
          .toList();
    });
  }

  /// 标记数据已变更，并启动防抖定时器异步同步到 iCloud
  void _markDirty() {
    _dataDirty = true;
    // 取消上一次的定时器，重新计时（防抖）
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () {
      if (_dataDirty && mounted) {
        _saveAll();
      }
    });
  }

  /// 真正写入本地（同步到 iCloud 由内部按配置处理）
  Future<void> _saveAll() async {
    _syncTimer?.cancel();
    if (!_dataDirty) return;
    await StockDataManager.saveAll(stocks, _operationRecords, _dividendRecords);
    _dataDirty = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _priceRefreshTimer?.cancel();
    super.dispose();
  }

  /// 应用生命周期监听：进入后台时写入 iCloud，回到前台时拉取
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isForeground = false;
      if (_dataDirty) _saveAll();
      unawaited(_recordProfitOnPaused());
    } else if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      unawaited(_refreshAll());
    }
  }

  void _startRefresh() {
    Future.delayed(Duration(seconds: AppConfig.refreshInitialDelaySec), () {
      if (mounted) _refreshAll();
    });
    _priceRefreshTimer = Timer.periodic(
      Duration(seconds: AppConfig.refreshIntervalSec),
      (_) {
        if (mounted) _refreshAll();
      },
    );
  }

  /// 统一刷新：同步云端→推送本地脏数据→拉取汇率→加载股票→拉取行情
  Future<void> _refreshAll() async {
    if (!_isForeground || !mounted) return;
    _collapseExpandedStock();

    await StockDataManager.loadSettings();
    if (_dataDirty) await _saveAll();
    await StockDataManager.fetchExchangeRates(_exchangeRateService);

    final data = await StockDataManager.loadStocks();
    if (!mounted) return;
    setState(() {
      stocks = data.$1;
      _operationRecords
        ..clear()
        ..addAll(data.$2);
      _dividendRecords
        ..clear()
        ..addAll(data.$3);
    });

    final updated = await StockDataManager.fetchQuotesAndSave(
      _quoteService,
      stocks,
      _operationRecords,
      _dividendRecords,
    );
    if (mounted) setState(() => stocks = updated);
    await StockDataManager.recordProfitIfNeeded(totalProfit, selectedCurrency);
    if (mounted) {
      setState(() => _lastRefreshTime = DateTime.now());
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _recordProfitOnPaused() async {
    await StockDataManager.fetchExchangeRates(_exchangeRateService);
    stocks = await StockDataManager.fetchQuotesAndSave(
      _quoteService,
      stocks,
      _operationRecords,
      _dividendRecords,
    );
    await StockDataManager.recordProfitIfNeeded(totalProfit, selectedCurrency);
  }

  // 计算属性
  AssetSummary get _assetSummary => StockDataManager.calculateAssetSummary(
    stocks,
    _operationRecords,
    _dividendRecords,
    selectedCurrency,
  );
  double get totalAssets => _assetSummary.totalAssets;
  double get totalMarketValue => _assetSummary.totalMarketValue;
  double get totalCost => _assetSummary.totalCost;
  double get totalProfit => _assetSummary.totalProfit;
  double get totalAfterTaxDividends => _assetSummary.totalAfterTaxDividends;
  double get totalSellAmount => _assetSummary.totalSellAmount;
  double get totalRealizedPL => _assetSummary.totalRealizedPL;
  double get totalProfitPercent => _assetSummary.totalProfitPercent;
  double get exchangeRate =>
      _exchangeRateService.effectiveRates[selectedCurrency] ?? 1.0;
  List<StockModel> get _filteredStocks => _filterMarket == null
      ? stocks
      : stocks
            .where((s) => MarketUtil.matchesFilter(_filterMarket, s.marketType))
            .toList();

  List<StockModel> get _sortedStocks => StockDataManager.sortStocks(
    _filteredStocks,
    _sortColumn,
    _sortAscending,
    selectedCurrency,
  );

  void _onColumnTap(String column) {
    _collapseExpandedStock();
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
    });
  }

  void _showMarketFilter() {
    final markets = <String?>[
      null,
      MarketUtil.searchMarketUS,
      MarketUtil.searchMarketHK,
      MarketUtil.searchMarketCN,
    ];
    final labels = [
      '全部',
      MarketUtil.searchMarketUS,
      MarketUtil.searchMarketHK,
      MarketUtil.searchMarketCN,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        title: const Text('筛选市场', style: TextStyles.sectionTitleRegular),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(markets.length, (i) {
            final selected = _filterMarket == markets[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: GestureDetector(
                onTap: () {
                  setState(() => _filterMarket = markets[i]);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        markets[i] != null
                            ? MarketUtil.marketIcon(markets[i])
                            : Icons.all_inclusive,
                        size: 20,
                        color: selected
                            ? (markets[i] != null
                                  ? MarketUtil.marketColor(markets[i])
                                  : Colors.white)
                            : (markets[i] != null
                                  ? MarketUtil.marketColor(markets[i])
                                  : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (selected) const Spacer(),
                      if (selected)
                        const Icon(Icons.check, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // 事件处理
  void _onStockTap(StockModel stock) {
    setState(() {
      _expandedStockSymbol = _expandedStockSymbol == stock.symbol
          ? null
          : stock.symbol;
    });
  }

  /// 收缩已展开的股票卡片（仅收缩，不切换）
  void _collapseExpandedStock() {
    if (_expandedStockSymbol != null) {
      setState(() => _expandedStockSymbol = null);
    }
  }

  void _onEditStock(
    StockModel updatedStock,
    OperationRecord? record,
    bool isClosed,
  ) {
    setState(() {
      if (isClosed) {
        // 平仓后保留股票记录，只清持仓数量，保留已实现盈亏
        final index = stocks.indexWhere((s) => s.symbol == updatedStock.symbol);
        if (index == -1) {
          stocks.add(updatedStock.copyWith(shares: 0, totalValue: 0));
        }
      } else {
        // 加仓或减仓：更新股票
        final index = stocks.indexWhere((s) => s.symbol == updatedStock.symbol);
        if (index != -1) stocks[index] = updatedStock;
      }
      // 添加操作记录
      if (record != null) {
        _operationRecords.putIfAbsent(updatedStock.symbol, () => []);
        _operationRecords[updatedStock.symbol]!.insert(0, record);
        final i = stocks.indexWhere((s) => s.symbol == updatedStock.symbol);
        if (i != -1) {
          stocks[i] = StockDataManager.recalculateStock(
            stocks[i],
            _operationRecords[updatedStock.symbol],
          );
        }
      }
    });
    _markDirty();
    Navigator.pop(context);
    if (record != null) {
      String action;
      if (isClosed) {
        action = StockConfig.opClosePosition;
      } else if (_operationRecords[updatedStock.symbol]?.length == 1) {
        action = StockConfig.opOpenPosition;
      } else {
        action = record.type == StockConfig.opBuy
            ? StockConfig.opAddPosition
            : StockConfig.opReducePosition;
      }
      CenterToast.success(
        context,
        '${action}${StockConfig.resultAddSuccess.replaceAll(StockConfig.opAddPosition, '')}',
      );
    }
  }

  void _onDeleteStock(StockModel stock) {
    setState(() {
      stocks.remove(stock);
      _operationRecords.remove(stock.symbol);
      _dividendRecords.remove(stock.symbol);
    });
    _markDirty();
    CenterToast.success(context, StockConfig.resultDeleteSuccess);
  }

  void _showRecordsDialog(StockModel stock) {
    final records = _operationRecords[stock.symbol] ?? [];
    final divRecords = _dividendRecords[stock.symbol] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => RecordsDialog(
          stock: stock,
          operationRecords: records,
          dividendRecords: divRecords,
          scrollController: scrollController,
          onDeleteOperationRecord: (symbol, index) {
            setState(() {
              final list = _operationRecords[symbol];
              if (list != null && index < list.length) {
                list.removeAt(index);
              }
              if (list == null || list.isEmpty) {
                if (_keepStockAfterClose) {
                  final i = stocks.indexWhere((s) => s.symbol == symbol);
                  if (i != -1)
                    stocks[i] = StockDataManager.recalculateStock(
                      stocks[i],
                      null,
                    );
                } else {
                  stocks.removeWhere((s) => s.symbol == symbol);
                  _operationRecords.remove(symbol);
                  _dividendRecords.remove(symbol);
                }
              } else {
                final i = stocks.indexWhere((s) => s.symbol == symbol);
                if (i != -1)
                  stocks[i] = StockDataManager.recalculateStock(
                    stocks[i],
                    _operationRecords[symbol],
                  );
              }
            });
            _markDirty();
          },
          onEditOperationRecord: (symbol, index, updated) {
            setState(() {
              final list = _operationRecords[symbol];
              if (list != null && index < list.length) {
                list[index] = updated;
              }
              final i = stocks.indexWhere((s) => s.symbol == symbol);
              if (i != -1)
                stocks[i] = StockDataManager.recalculateStock(
                  stocks[i],
                  _operationRecords[symbol],
                );
            });
            _markDirty();
          },
          onDeleteDividendRecord: (symbol, index) {
            setState(() {
              final list = _dividendRecords[symbol];
              if (list != null && index < list.length) {
                list.removeAt(index);
              }
            });
            _markDirty();
          },
          onEditDividendRecord: (symbol, index, updated) {
            setState(() {
              final list = _dividendRecords[symbol];
              if (list != null && index < list.length) {
                list[index] = updated;
              }
            });
            _markDirty();
          },
        ),
      ),
    );
  }

  void _showMoreOptions(StockModel stock) {
    showDialog(
      context: context,
      builder: (_) => MoreOptionsDialog(
        stock: stock,
        onAdd: () => _showEditDialog(stock, isAdd: true),
        onReduce: () => _showEditDialog(stock, isAdd: false),
        onDelete: () => _showDeleteDialog(stock),
        onDividend: () => _showDividendDialog(stock),
      ),
    );
  }

  void _showDividendDialog(StockModel stock) {
    showDialog(
      context: context,
      builder: (_) => DividendDialog(
        stock: stock,
        onConfirm: (date, amountPerShare, taxRate) {
          setState(() {
            final record = DividendRecord(
              date: date,
              amount: amountPerShare,
              shares: stock.shares,
              taxRate: taxRate,
              currency: stock.currency,
            );
            _dividendRecords.putIfAbsent(stock.symbol, () => []);
            _dividendRecords[stock.symbol]!.add(record);
          });
          _markDirty();
          Navigator.pop(context);
          CenterToast.success(context, StockConfig.dividendSuccess);
        },
      ),
    );
  }

  void _showEditDialog(StockModel stock, {required bool isAdd}) {
    final records = _operationRecords[stock.symbol] ?? [];
    showDialog(
      context: context,
      builder: (_) => EditStockDialog(
        stock: stock,
        onSave: _onEditStock,
        isAdd: isAdd,
        operationRecords: records,
      ),
    );
  }

  void _showDeleteDialog(StockModel stock) {
    showDialog(
      context: context,
      builder: (_) => DeleteStockDialog(
        stock: stock,
        onDelete: () => _onDeleteStock(stock),
      ),
    );
  }

  void showSearchStockDialog() {
    _collapseExpandedStock();
    final existingSymbols = stocks.map((s) => s.symbol).toSet();
    showDialog(
      context: context,
      builder: (_) => SearchStockDialog(
        existingSymbols: existingSymbols,
        onStockAdded: (newStock, buyRecord) {
          setState(() {
            stocks.add(newStock);
            _operationRecords[newStock.symbol] = [buyRecord];
            final i = stocks.length - 1;
            stocks[i] = StockDataManager.recalculateStock(
              stocks[i],
              _operationRecords[newStock.symbol],
            );
          });
          _markDirty();
          CenterToast.success(context, StockConfig.resultAddStockSuccess);
        },
      ),
    );
  }

  // 设置页面本地货币变更回调
  void _onCurrencyChanged(String newCurrency) {
    _collapseExpandedStock();
    setState(() => selectedCurrency = newCurrency);
    SettingsService.setDefaultCurrency(newCurrency);
    _markDirty();
  }

  /// 设置页面排序变更回调
  void _onSortChanged(String column) {
    setState(() {
      _sortColumn = column;
    });
    SettingsService.setSortColumn(column);
    SettingsService.setSortAscending(false);
    _markDirty();
  }

  /// 设置页面排序方向变更回调
  void _onSortDirectionChanged(bool ascending) {
    setState(() => _sortAscending = ascending);
    SettingsService.setSortAscending(ascending);
    _markDirty();
  }

  /// 设置页面平仓保留变更回调
  void _onKeepStockChanged(bool value) {
    SettingsService.setKeepStockAfterClose(value);
    _markDirty();
  }

  /// 同步开关被切换
  Future<void> _onSyncToggled() async {
    if (stocks.isNotEmpty) {
      if (_dataDirty) await _saveAll();
    } else {
      await _syncStockData();
    }
  }

  /// 打开全局股息页面
  void _showDividendOverview() {
    _collapseExpandedStock();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalDividendPage(
          stocks: stocks,
          operationRecords: _operationRecords,
          dividendRecords: _dividendRecords,
          selectedCurrency: selectedCurrency,
          onRefresh: _refreshAll,
        ),
      ),
    );
  }

  /// 打开全屏设置页面
  void _showSettingsPage() {
    _collapseExpandedStock();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          currentCurrency: selectedCurrency,
          onCurrencyChanged: _onCurrencyChanged,
          onSortChanged: _onSortChanged,
          onSortDirectionChanged: _onSortDirectionChanged,
          onSyncToggled: _onSyncToggled,
          onKeepStockChanged: _onKeepStockChanged,
          onSettingsChanged: () => StockDataManager.saveSettings(),
        ),
      ),
    ).then((_) {
      // 从设置页返回后重新加载设置
      if (mounted) {
        _loadKeepStockSetting();
        _loadSortSettings();
      }
    });
  }

  // 页面组装（仅股票内容，不含外壳/底部 Tab）

  String _buildSubtitle() {
    if (_lastRefreshTime == null) {
      return AssetConfig.assetSubtitleRefresh.replaceAll('{time}', '-');
    }
    return StockConfig.homeSubtitleRefresh.replaceAll(
      '{time}',
      formatRefreshTime(_lastRefreshTime!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildStockTab();
      },
    );
  }

  /// 股票 Tab 内容
  Widget _buildStockTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppColors.textSecondary,
      backgroundColor: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              // 点击空白区域自动收缩已展开的股票卡片
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: _collapseExpandedStock,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      title: StockConfig.homeTitle,
                      subtitle: _buildSubtitle(),
                      onDividendOverview: () => _showDividendOverview(),
                      onSettings: _showSettingsPage,
                    ),
                    const SizedBox(height: 8),
                    StockHeaderCard(
                      selectedCurrency: selectedCurrency,
                      totalAssets: totalAssets,
                      totalMarketValue: totalMarketValue,
                      totalCost: totalCost,
                      totalProfit: totalProfit,
                      totalRealizedPL: totalRealizedPL,
                      totalProfitPercent: totalProfitPercent,
                      totalAfterTaxDividends: totalAfterTaxDividends,
                      totalSellAmount: totalSellAmount,
                      onCurrencyChanged: _onCurrencyChanged,
                      onCollapse: _collapseExpandedStock,
                    ),
                    const SizedBox(height: 8),
                    StockListHeader(
                      sortColumn: _sortColumn,
                      sortAscending: _sortAscending,
                      onColumnTap: _onColumnTap,
                      filterMarket: _filterMarket,
                      onFilterTap: _showMarketFilter,
                      stockCount: _sortedStocks.length,
                    ),
                    const SizedBox(height: 2),
                    if (_sortedStocks.isEmpty) ...[
                      const EmptyStateWidget(
                        icon: Icons.show_chart,
                        title: StockConfig.homeEmptyTitle,
                        subtitle: StockConfig.homeEmptySubtitle,
                        iconSize: 64,
                        padding: EdgeInsets.symmetric(vertical: 60),
                      ),
                    ] else ...[
                      Column(
                        children: _sortedStocks.map((stock) {
                          return StockCard(
                            stock: stock,
                            isExpanded: _expandedStockSymbol == stock.symbol,
                            onExpandTap: () => _onStockTap(stock),
                            onRecordTap: () => _showRecordsDialog(stock),
                            onMoreTap: () => _showMoreOptions(stock),
                            operationRecords:
                                _operationRecords[stock.symbol] ?? [],
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
