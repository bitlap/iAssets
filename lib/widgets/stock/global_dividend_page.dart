import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock_model.dart';
import '../../models/calculator_models.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_util.dart';
import '../../utils/market_util.dart';
import '../../utils/stock_calculator.dart';
import '../common/empty_state_widget.dart';
import '../common/app_ui.dart';

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
    final filtered = _overview.items.where(
      (i) => MarketUtil.matchesFilter(_filterMarket, i.marketType),
    ).toList();
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
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
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
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF8E8E93),
        backgroundColor: const Color(0xFF000000),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildMetricCards(),
              const SizedBox(height: 8),
              _buildFilterRow(),
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
                ...items.map(_buildStockSection),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 汇总指标卡片 ───
  Widget _buildMetricCards() {
    final sym = CurrencyUtil.getSymbol(widget.selectedCurrency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendTotalAfterTax,
                  value:
                      '$sym${CurrencyUtil.formatCompact(_overview.totalAfterTaxDividends)}',
                  valueColor: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendTrailing12m,
                  value:
                      '$sym${CurrencyUtil.formatCompact(_overview.trailingAfterTaxDividends)}',
                  valueColor: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendCostYield,
                  value: '${_overview.costDividendYield.toStringAsFixed(2)}%',
                  valueColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatMetricCard(
                  label: StockConfig.dividendMarketYield,
                  value: '${_overview.marketDividendYield.toStringAsFixed(2)}%',
                  valueColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 筛选行 ───
  Widget _buildFilterRow() {
    final markets = <String?>[
      null,
      MarketUtil.searchMarketUS,
      MarketUtil.searchMarketHK,
      MarketUtil.searchMarketCN,
    ];
    final labels = [
      StockConfig.dividendAllMarkets,
      MarketUtil.searchMarketUS,
      MarketUtil.searchMarketHK,
      MarketUtil.searchMarketCN,
    ];
    final sortOptions = [
      StockConfig.dividendSortYield,
      StockConfig.dividendSortCostYield,
      StockConfig.dividendSortAmount,
      StockConfig.dividendSortDate,
      StockConfig.dividendSortName,
    ];
    final sortKeys = [
      'marketYield',
      'costYield',
      'totalAmount',
      'latestDate',
      'name',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(markets.length, (i) {
                final selected = _filterMarket == markets[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < markets.length - 1 ? 8 : 0,
                  ),
                  child: FilterPill(
                    label: labels[i],
                    selected: selected,
                    onTap: () => setState(() => _filterMarket = markets[i]),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(sortOptions.length, (i) {
                final selected = _sortKey == sortKeys[i];
                final icon = selected
                    ? (_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                    : null;
                return Padding(
                  padding: EdgeInsets.only(
                    right: i < sortOptions.length - 1 ? 8 : 0,
                  ),
                  child: FilterPill(
                    label: sortOptions[i],
                    selected: selected,
                    onTap: () => _toggleSort(sortKeys[i]),
                    trailingIcon: icon,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 每只股票聚合区块 ───
  Widget _buildStockSection(GlobalDividendStockItem item) {
    final isExpanded = _expandedSymbol == item.symbol;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedSymbol = isExpanded ? null : item.symbol;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C1C1E), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：公司信息 + 市场标签
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.companyName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.symbol} · ${item.recordCount} ${StockConfig.dividendRecordCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MarketAndCurrencyBadges(
                      market: item.marketType,
                      currency: item.currency,
                      fontSize: 11,
                    ),
                  ],
                ),
              ),
              // 收益率双卡
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: YieldTile(
                        label: StockConfig.dividendCostYield,
                        value: '${item.costDividendYield.toStringAsFixed(2)}%',
                        valueColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: YieldTile(
                        label: StockConfig.dividendMarketYield,
                        value:
                            '${item.marketDividendYield.toStringAsFixed(2)}%',
                        valueColor: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              // 详情行
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _buildDetailRow(item),
              ),
              const SizedBox(height: 8),
              const DashedDivider(),
              const SizedBox(height: 8),
              // 底部信息行
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${StockConfig.dividendLatestDate} ${item.latestDividendDate != null ? DateFormat('yyyy-MM-dd').format(item.latestDividendDate!) : '-'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                    Text(
                      StockConfig.dividendExpandAll,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5B9CF6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // 展开的派息记录
              if (isExpanded) _buildDividendRecordsList(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(GlobalDividendStockItem item) {
    final sym = CurrencyUtil.getSymbol(item.currency);
    return Row(
      children: [
        Expanded(
          child: _buildDetailCell(
            StockConfig.dividendTotalAfterTax,
            '$sym${CurrencyUtil.formatCompact(item.totalAfterTaxDividends)}',
          ),
        ),
        Expanded(
          child: _buildDetailCell(
            StockConfig.dividendCurrentCost,
            '$sym${CurrencyUtil.formatCompact(item.currentCost)}',
          ),
        ),
        Expanded(
          child: _buildDetailCell(
            StockConfig.dividendCurrentValue,
            '$sym${CurrencyUtil.formatCompact(item.currentMarketValue)}',
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8E8E93),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.2,
            fontFamily: 'SFMono',
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDividendRecordsList(GlobalDividendStockItem item) {
    if (item.records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text(
          StockConfig.profitNoData,
          style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
        ),
      );
    }
    // 时间倒序
    final sorted = List<DividendRecord>.from(item.records)
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        const Divider(color: Color(0xFF1C1C1E), thickness: 0.5, height: 0.5),
        const SizedBox(height: 4),
        ...sorted.map((r) => _buildRecordItem(r, item.currency)),
      ],
    );
  }

  Widget _buildRecordItem(DividendRecord record, String currency) {
    final sym = CurrencyUtil.getSymbol(currency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9F0A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(record.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${StockConfig.recordsDivLabel}: $sym${CurrencyUtil.formatCompact(record.afterTaxAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF9F0A),
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyUtil.formatRate(record.shares)}${StockConfig.stockSharesSuffix} × ${CurrencyUtil.formatRate(record.amount)}/${StockConfig.recordsDivAmountPerShare} × ${(1 - record.taxRate) * 100}%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
