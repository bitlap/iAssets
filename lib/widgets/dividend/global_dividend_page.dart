import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../models/calculator_models.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_util.dart';
import '../../utils/market_util.dart';
import '../../utils/stock_calculator.dart';
import '../common/empty_state_widget.dart';
import '../common/app_ui.dart';
import 'dividend_header.dart';
import 'dividend_filter_row.dart';
import 'dividend_stock_section.dart';

/// 全局股息记录页面 - 按股票聚合展示所有股息记录
class GlobalDividendPage extends StatefulWidget {
  final List<StockModel> stocks;
  final Map<String, List<OperationRecord>> operationRecords;
  final Map<String, List<DividendRecord>> dividendRecords;
  final String selectedCurrency;
  final Future<void> Function()? onRefresh;

  const GlobalDividendPage({
    super.key,
    required this.stocks,
    required this.operationRecords,
    required this.dividendRecords,
    required this.selectedCurrency,
    this.onRefresh,
  });

  @override
  State<GlobalDividendPage> createState() => _GlobalDividendPageState();
}

class _GlobalDividendPageState extends State<GlobalDividendPage> {
  String _sortKey = 'marketYield';
  bool _sortAscending = false;
  String? _filterMarket;
  String? _expandedSymbol;
  late GlobalDividendOverview _overview;

  @override
  void initState() {
    super.initState();
    _overview = _calculateOverview();
  }

  @override
  void didUpdateWidget(GlobalDividendPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stocks != widget.stocks ||
        oldWidget.dividendRecords != widget.dividendRecords ||
        oldWidget.operationRecords != widget.operationRecords ||
        oldWidget.selectedCurrency != widget.selectedCurrency) {
      _overview = _calculateOverview();
    }
  }

  GlobalDividendOverview _calculateOverview() {
    return StockCalculator.calculateGlobalDividendOverview(
      widget.stocks,
      widget.operationRecords,
      widget.dividendRecords,
      widget.selectedCurrency,
    );
  }

  List<GlobalDividendStockItem> get _sortedItems {
    final filtered = _overview.items
        .where((i) => MarketUtil.matchesFilter(_filterMarket, i.marketType))
        .toList();
    filtered.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case 'costYield':
          cmp = a.costDividendYield.compareTo(b.costDividendYield);
          break;
        case 'totalAmount':
          cmp =
              CurrencyUtil.convertCurrency(
                a.totalAfterTaxDividends,
                a.currency,
                widget.selectedCurrency,
              ).compareTo(
                CurrencyUtil.convertCurrency(
                  b.totalAfterTaxDividends,
                  b.currency,
                  widget.selectedCurrency,
                ),
              );
          break;
        case 'latestDate':
          final da = a.latestDividendDate ?? DateTime(2000);
          final db = b.latestDividendDate ?? DateTime(2000);
          cmp = da.compareTo(db);
          break;
        case 'name':
          cmp = a.symbol.compareTo(b.symbol);
          break;
        default:
          cmp = a.marketDividendYield.compareTo(b.marketDividendYield);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return filtered;
  }

  void _toggleSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = false;
      }
    });
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
      if (mounted) setState(() => _overview = _calculateOverview());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedItems;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        toolbarHeight: AppConfig.appBarHeight,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              StockConfig.dividendOverviewTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              '${_overview.items.length} ${StockConfig.tabStock} · ${widget.selectedCurrency}',
              style: TextStyles.caption,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.textSecondary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              DividendHeader(
                overview: _overview,
                currency: widget.selectedCurrency,
              ),
              const SizedBox(height: 8),
              DividendFilterRow(
                filterMarket: _filterMarket,
                sortKey: _sortKey,
                sortAscending: _sortAscending,
                onFilterChanged: (m) => setState(() => _filterMarket = m),
                onSortChanged: _toggleSort,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const SizedBox(
                  height: 200,
                  child: EmptyStateWidget(
                    icon: Icons.attach_money,
                    title: StockConfig.dividendOverviewEmpty,
                    subtitle: StockConfig.dividendOverviewEmptyHint,
                  ),
                )
              else
                ...items.map(
                  (item) => DividendStockSection(
                    item: item,
                    isExpanded: _expandedSymbol == item.symbol,
                    onTap: () => setState(() {
                      _expandedSymbol = _expandedSymbol == item.symbol
                          ? null
                          : item.symbol;
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
