import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import '../../models/stock_search_models.dart';
import '../../services/settings_service.dart';
import '../../services/stock_search_service.dart';
import '../../services/stock_quote_service.dart';
import '../../utils/center_toast.dart';
import '../../utils/currency_util.dart';
import '../../utils/logo_cacher.dart';
import '../../utils/market_util.dart';
import '../../config/app_config.dart';
import '../common/app_number_field.dart';
import '../common/info_row_widget.dart';
import '../common/dialog_utils.dart';

/// 股票搜索弹窗 - 支持按名称/代码搜索港股、美股
class SearchStockDialog extends StatefulWidget {
  /// 选中股票后的回调，返回新构建的 StockModel 和建仓操作记录
  final void Function(StockModel stock, OperationRecord buyRecord) onStockAdded;

  /// 当前已持有的股票代码列表，用于去重
  final Set<String> existingSymbols;

  const SearchStockDialog({
    super.key,
    required this.onStockAdded,
    this.existingSymbols = const {},
  });

  @override
  State<SearchStockDialog> createState() => _SearchStockDialogState();
}

class _SearchStockDialogState extends State<SearchStockDialog> {
  final _controller = TextEditingController();
  final _searchService = StockSearchService();
  final _quoteService = StockQuoteService();
  final _focusNode = FocusNode();

  List<StockSearchResult> _results = [];
  List<StockSearchResult> _allResults = []; // 全部搜索结果（过滤前）
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  Timer? _debounceTimer;
  String? _selectedMarket; // 市场筛选：null=全部, '美股', '港股'

  // 正在获取行情的股票（loading 状态）
  final Set<String> _loadingQuotes = {};
  // 缓存行情数据
  final Map<String, StockQuote?> _quoteCache = {};
  // 行情获取失败的股票
  final Set<String> _failedQuotes = {};

  @override
  void initState() {
    super.initState();
    // 弹窗打开后自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    // 不再 dispose service，因为是单例，其他 dialog 还要用
    _focusNode.dispose();
    super.dispose();
  }

  /// 触发搜索（带防抖）
  void _onSearchChanged(String keyword) {
    _debounceTimer?.cancel();
    if (keyword.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = '';
      });
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: AppConfig.searchDebounceMs),
      () {
        _doSearch(keyword);
      },
    );
  }

  /// 执行搜索
  Future<void> _doSearch(String keyword) async {
    // 检查是否在冷却期
    final cooldownSecs = _searchService.cooldownRemainingSeconds;
    if (cooldownSecs > 0) {
      setState(() {
        _errorMessage = StockConfig.searchRateLimit.replaceAll(
          '{secs}',
          '${cooldownSecs}',
        );
        _hasSearched = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _failedQuotes.clear();
      // 不清空缓存，保留已缓存的行情数据
    });

    try {
      final results = await _searchService.searchStocks(keyword);
      if (!mounted) return;

      // 搜索后再次检查冷却状态
      if (_searchService.cooldownRemainingSeconds > 0 && results.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasSearched = true;
          _errorMessage = StockConfig.searchRateLimitShort;
        });
        return;
      }

      setState(() {
        _allResults = results;
        _results = _applyMarketFilter(results);
        _isLoading = false;
        _hasSearched = true;
        if (_results.isEmpty) {
          _errorMessage = _selectedMarket != null
              ? StockConfig.searchNotFoundMarket.replaceAll(
                  '{market}',
                  _selectedMarket ?? '',
                )
              : StockConfig.searchNotFound;
        }
      });
      // 从 service 缓存中恢复已有行情
      _restoreCachedQuotes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMessage = StockConfig.searchFailed;
      });
    }
  }

  /// 添加股票到持仓列表
  Future<void> _addStock(StockSearchResult stock) async {
    if (widget.existingSymbols.contains(stock.code)) {
      CenterToast.warning(
        context,
        StockConfig.searchAlreadyExists.replaceAll('{code}', '${stock.code}'),
      );
      return;
    }

    // 先尝试从缓存获取行情，没有则实时获取
    StockQuote? quote = _quoteCache[stock.secid];
    if (quote == null) {
      // 检查冷却状态
      final cooldownSecs = _searchService.cooldownRemainingSeconds;
      if (cooldownSecs > 0) {
        CenterToast.warning(
          context,
          StockConfig.searchRateLimit.replaceAll('{secs}', '${cooldownSecs}'),
        );
        return;
      }
      setState(() => _loadingQuotes.add(stock.secid));
      final quotes = await _quoteService.getStockQuotesBatch([stock]);
      if (!mounted) return;
      setState(() => _loadingQuotes.remove(stock.secid));
      quote = quotes[stock.secid];
    }

    final defaultPrice = quote?.currentPrice ?? 0.0;

    // 弹出输入价格和股数的弹窗
    if (!mounted) return;
    final result = await showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AddStockConfirmDialog(
        stockCode: stock.code,
        stockName: quote?.name ?? stock.name,
        market: stock.market,
        defaultPrice: defaultPrice,
      ),
    );

    if (result == null) return; // 用户取消

    final price = result['price']!;
    final shares = result['shares']!;
    final fee = result['fee'] ?? 0.0;
    final totalValue = price * shares;

    final stockModel = StockModel(
      symbol: stock.code,
      companyName: quote?.name ?? stock.name,
      currentPrice: defaultPrice > 0 ? defaultPrice : price, // 优先使用真实价格，回退到用户输入
      shares: shares,
      totalValue: defaultPrice > 0
          ? defaultPrice * shares
          : totalValue, // 使用真实价格计算总金额
      profitLossPercent: 0.0, // 刚建仓，盈亏为0
      profitLossAmount: 0.0,
      isPositive: true,
      logoUrl: StockQuoteService.getLogoUrl(stock.code, stock.market),
      marketType: stock.market,
      changePercent: quote?.changePercent ?? 0.0,
      currency: CurrencyUtil.currencyForMarket(stock.market),
      secid: stock.secid,
    );

    // 创建建仓操作记录
    final buyRecord = OperationRecord(
      date: DateTime.now(),
      type: StockConfig.opBuy,
      description: StockConfig.opOpenPosition + ' ${stock.code}',
      amount: price,
      shares: shares,
      fee: fee,
    );

    widget.onStockAdded(stockModel, buyRecord);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Color(0xFF1C1C1E)!),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * AppConfig.dialogWidthRatio,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(),
            const Divider(thickness: 0.5, color: Color(0xFF1C1C1E)),
            FlexibleChild(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  /// 搜索栏
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                StockConfig.searchTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close,
                  color: Color(0xFF8E8E93),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1C1C1E)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: Color(0xFF8E8E93), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: StockConfig.searchHint,
                      hintStyle: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _hasSearched = false;
                        _errorMessage = '';
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.clear,
                        color: Color(0xFF8E8E93),
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildTag(MarketUtil.searchAll, _selectedMarket == null),
              _buildTag(
                MarketUtil.searchMarketUS,
                _selectedMarket == MarketUtil.searchMarketUS,
              ),
              _buildTag(
                MarketUtil.searchMarketHK,
                _selectedMarket == MarketUtil.searchMarketHK,
              ),
              _buildTag(
                MarketUtil.searchMarketCN,
                _selectedMarket == MarketUtil.searchMarketCN,
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMarket = label == MarketUtil.searchAll ? null : label;
          _results = _applyMarketFilter(_allResults);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF2C2C2E).withValues(alpha: 0.5)
              : Color(0xFF2C2C2E).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Color(0xFF2C2C2E).withValues(alpha: 0.7)
                : Color(0xFF2C2C2E).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Color(0xFF8E8E93),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 根据选中的市场筛选结果
  List<StockSearchResult> _applyMarketFilter(List<StockSearchResult> results) {
    if (_selectedMarket == null) return results;
    return results
        .where((s) => MarketUtil.matchesFilter(_selectedMarket, s.market))
        .toList();
  }

  /// 从 service 缓存中恢复已有行情，并对未缓存的股票批量获取行情
  void _restoreCachedQuotes() {
    final needFetch = <StockSearchResult>[];
    for (final stock in _allResults) {
      if (!_quoteCache.containsKey(stock.secid)) {
        final cached = _quoteService.getCachedQuote(stock.secid);
        if (cached != null) {
          _quoteCache[stock.secid] = cached;
        } else {
          needFetch.add(stock);
        }
      }
    }
    if (needFetch.isEmpty) {
      // 全部命中缓存，直接结束 loading 显示结果
      setState(() => _isLoading = false);
    } else {
      _fetchQuotesBatch(needFetch);
    }
  }

  /// 批量获取股票行情并更新 UI
  Future<void> _fetchQuotesBatch(List<StockSearchResult> stocks) async {
    setState(() {
      for (final stock in stocks) {
        _loadingQuotes.add(stock.secid);
      }
    });
    final quotes = await _quoteService.getStockQuotesBatch(stocks);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      for (final stock in stocks) {
        _loadingQuotes.remove(stock.secid);
        final quote = quotes[stock.secid];
        if (quote != null) {
          _quoteCache[stock.secid] = quote;
        } else {
          _failedQuotes.add(stock.secid);
        }
      }
    });
  }

  /// 搜索结果列表
  Widget _buildResultsList() {
    if (_isLoading && _results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF8E8E93)),
        ),
      );
    }

    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, color: Color(0xFF8E8E93), size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: Color(0xFF8E8E93),
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                StockConfig.searchInitHint,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
              SizedBox(height: 6),
              Text(
                StockConfig.searchInitExample,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final stock = _results[index];
        final quote = _quoteCache[stock.secid];
        final isLoadingQuote = _loadingQuotes.contains(stock.secid);
        final isFailedQuote = _failedQuotes.contains(stock.secid);
        final isExisting = widget.existingSymbols.contains(stock.code);

        return _buildStockItem(
          stock,
          quote,
          isLoadingQuote,
          isFailedQuote,
          isExisting,
        );
      },
    );
  }

  /// 单只股票行
  Widget _buildStockItem(
    StockSearchResult stock,
    StockQuote? quote,
    bool isLoadingQuote,
    bool isFailedQuote,
    bool isExisting,
  ) {
    final changePercent = quote?.changePercent ?? 0.0;
    final isPositive = changePercent >= 0;
    final priceColor = isPositive
        ? const Color(0xFFFF5252)
        : const Color(0xFF4CAF50);

    return InkWell(
      onTap: isExisting ? null : () => _addStock(stock),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF1C1C1E)!, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: () {
                  final logoUrl = StockQuoteService.getLogoUrl(
                    stock.code,
                    stock.market,
                  );
                  if (logoUrl != null) {
                    return FutureBuilder<ImageProvider>(
                      future: LogoCacher.getLogo(stock.code, logoUrl),
                      builder: (_, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasData) {
                            return Image(
                              image: snapshot.data!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildLogoFallback(stock),
                            );
                          }
                          return _buildLogoFallback(stock);
                        }
                        return Container(
                          width: 36,
                          height: 36,
                          color: const Color(0xFF2C2C2E),
                        );
                      },
                    );
                  }
                  return _buildLogoFallback(stock);
                }(),
              ),
            ),
            const SizedBox(width: 12),
            // 股票信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        stock.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stock.market,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: MarketUtil.marketColor(stock.market),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stock.name,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 行情数据 + 添加按钮（右侧固定区域，限制最大宽度防溢出）
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.35,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 行情数据
                  if (isLoadingQuote)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8E8E93),
                      ),
                    )
                  else if (isFailedQuote)
                    Flexible(
                      child: Text(
                        StockConfig.searchQuoteUnavailable,
                        style: TextStyle(
                          color: Color(0xFF636366),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (quote != null)
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyUtil.formatCompact(
                              quote.currentPrice,
                              formatBase: CurrencyUtil.formatRate,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isPositive ? '+' : '-'}${changePercent.abs().toStringAsFixed(2)}%',
                            style: TextStyle(color: priceColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  // 添加按钮
                  const SizedBox(width: 12),
                  if (isExisting)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF1C1C1E)!,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        AppConfig.btnAdded,
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF2C2C2E).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Color(0xFF2C2C2E).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        AppConfig.btnAdd,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoFallback(StockSearchResult stock) {
    final firstChar = stock.name.isNotEmpty ? stock.name[0] : stock.code[0];
    return Container(
      color: const Color(0xFF2C2C2E),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// 可伸缩子组件，让列表占满剩余空间
class FlexibleChild extends StatelessWidget {
  final Widget child;
  const FlexibleChild({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Flexible(child: child);
  }
}

/// 添加股票确认弹窗 - 输入价格和股数
class _AddStockConfirmDialog extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final String market;
  final double defaultPrice;

  const _AddStockConfirmDialog({
    required this.stockCode,
    required this.stockName,
    required this.market,
    required this.defaultPrice,
  });

  @override
  State<_AddStockConfirmDialog> createState() => _AddStockConfirmDialogState();
}

class _AddStockConfirmDialogState extends State<_AddStockConfirmDialog> {
  late final TextEditingController _priceController;
  late final TextEditingController _sharesController;
  late final TextEditingController _feeController;
  String _feeType = SettingsService.feeTypePercentage;
  double _feeSettingValue = 0.0;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.defaultPrice > 0
          ? CurrencyUtil.formatRate(widget.defaultPrice)
          : '',
    );
    _sharesController = TextEditingController();
    _feeController = TextEditingController();
    _loadFeeSettings();
    _priceController.addListener(_updateFeeFromInput);
    _sharesController.addListener(_updateFeeFromInput);
  }

  void _updateFeeFromInput() {
    if (_feeType != SettingsService.feeTypePercentage ||
        _feeSettingValue <= 0) {
      return;
    }
    final price = double.tryParse(_priceController.text);
    final shares = double.tryParse(_sharesController.text);
    if (price == null || shares == null || price <= 0 || shares <= 0) return;
    final fee = price * shares * _feeSettingValue / 100;
    _feeController.text = CurrencyUtil.formatRate(fee);
    setState(() {});
  }

  Future<void> _loadFeeSettings() async {
    final feeType = await SettingsService.getDefaultFeeType();
    final feeValue = await SettingsService.getDefaultFeeValue();
    if (!mounted) return;
    _feeType = feeType;
    _feeSettingValue = feeValue;
    if (feeValue <= 0) return;
    if (feeType == SettingsService.feeTypeFixed) {
      _feeController.text = CurrencyUtil.formatRate(feeValue);
      return;
    }
    _updateFeeFromInput();
  }

  @override
  void dispose() {
    _priceController.removeListener(_updateFeeFromInput);
    _sharesController.removeListener(_updateFeeFromInput);
    _priceController.dispose();
    _sharesController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return dialogFrame(
      context: context,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                StockConfig.searchAddTitle.replaceAll(
                  '{code}',
                  widget.stockCode,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),
            AppNumberField(
              controller: _priceController,
              label: StockConfig.searchBuyPrice,
              hintText: StockConfig.searchBuyPriceHint,
            ),
            const SizedBox(height: 12),
            AppNumberField(
              controller: _sharesController,
              label: StockConfig.searchShares,
              hintText: StockConfig.searchSharesHint,
            ),
            const SizedBox(height: 12),
            AppNumberField(
              controller: _feeController,
              label: StockConfig.editFeeLabel,
              hintText: StockConfig.editFeePlaceholder,
            ),
            const SizedBox(height: 20),
            actionButtonRow(
              onCancel: () => Navigator.pop(context),
              onConfirm: _onConfirm,
              confirmText: AppConfig.btnConfirmAdd,
              confirmGradient: const LinearGradient(
                colors: [Color(0xFF1A56DB), Color(0xFF2962FF)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C1C1E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRowWidget(
            label: StockConfig.searchStockName,
            value: widget.stockName,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(label: StockConfig.searchMarket, value: widget.market),
          if (widget.defaultPrice > 0) ...[
            const SizedBox(height: 8),
            InfoRowWidget(
              label: StockConfig.searchRealtimePrice,
              value: CurrencyUtil.formatRate(widget.defaultPrice),
            ),
          ],
        ],
      ),
    );
  }

  void _onConfirm() {
    final price = double.tryParse(_priceController.text);
    final shares = double.tryParse(_sharesController.text);
    final fee = double.tryParse(_feeController.text) ?? 0.0;

    if (price == null || price <= 0) {
      CenterToast.error(context, StockConfig.searchInvalidPrice);
      return;
    }
    if (shares == null || shares <= 0) {
      CenterToast.error(context, StockConfig.searchInvalidShares);
      return;
    }

    Navigator.pop(context, {'price': price, 'shares': shares, 'fee': fee});
  }
}
