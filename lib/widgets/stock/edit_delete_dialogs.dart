import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../models/stock_search_models.dart';
import '../../utils/currency_util.dart';
import '../../utils/stock_calculator.dart';
import '../../services/settings_service.dart';
import '../../services/stock_quote_service.dart';
import '../../utils/center_toast.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../common/app_number_field.dart';
import '../common/info_row_widget.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/app_ui.dart';
import '../common/dialog_utils.dart';
import '../common/percent_selector.dart';

/// 加仓/减仓对话框
class EditStockDialog extends StatefulWidget {
  final StockModel stock;
  final void Function(
    StockModel updatedStock,
    OperationRecord? record,
    bool isClosed,
  )
  onSave;
  final List<OperationRecord> operationRecords;
  final bool isAdd; // true=加仓, false=减仓

  const EditStockDialog({
    super.key,
    required this.stock,
    required this.onSave,
    required this.isAdd,
    this.operationRecords = const [],
  });

  @override
  State<EditStockDialog> createState() => _EditStockDialogState();
}

class _EditStockDialogState extends State<EditStockDialog> {
  late TextEditingController _sharesController;
  late TextEditingController _priceController;
  late TextEditingController _feeController;
  final StockQuoteService _quoteService = StockQuoteService();
  bool _isLoadingPrice = false;
  String _feeType = SettingsService.feeTypePercentage;
  double _feeSettingValue = 0.0;

  /// 从操作记录计算买入均价
  double get _avgBuyPrice =>
      StockCalculator.calculateAvgBuyPrice(widget.operationRecords);

  double? get _feeValue => double.tryParse(_feeController.text);

  @override
  void initState() {
    super.initState();
    _sharesController = TextEditingController();
    _priceController = TextEditingController(
      text: widget.stock.currentPrice > 0
          ? CurrencyUtil.formatRate(widget.stock.currentPrice)
          : '',
    );
    _feeController = TextEditingController();
    _loadFeeSettings();
    _priceController.addListener(_updateFeeFromInput);
    _sharesController.addListener(_updateFeeFromInput);
    _fetchRealtimePrice();
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

  Future<void> _fetchRealtimePrice() async {
    final secid = widget.stock.secid;
    if (secid == null || secid.isEmpty) return;
    if (_quoteService.cooldownRemainingSeconds > 0) return;
    setState(() => _isLoadingPrice = true);
    try {
      final stock = StockSearchResult(
        code: widget.stock.symbol,
        name: widget.stock.companyName,
        market: widget.stock.marketType,
        secid: secid,
      );
      final quotes = await _quoteService.getStockQuotesBatch([stock]);
      if (!mounted) return;
      final quote = quotes[secid];
      if (quote != null && quote.currentPrice > 0) {
        _priceController.text = CurrencyUtil.formatRate(quote.currentPrice);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPrice = false);
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_updateFeeFromInput);
    _sharesController.removeListener(_updateFeeFromInput);
    _sharesController.dispose();
    _priceController.dispose();
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
                widget.isAdd
                    ? StockConfig.opAddPosition
                    : StockConfig.opReducePosition,
                style: TextStyles.dialogTitle,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  StockConfig.editPriceHint,
                  style: TextStyles.body13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (_isLoadingPrice)
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
            const SizedBox(height: 8),
            AppNumberField(
              controller: _priceController,
              hintText: StockConfig.editPricePlaceholder,
            ),
            const SizedBox(height: 12),
            AppNumberField(
              controller: _sharesController,
              label: widget.isAdd
                  ? StockConfig.editAddSharesLabel
                  : StockConfig.editReduceSharesLabel,
              hintText: widget.isAdd
                  ? StockConfig.editAddSharesHint
                  : StockConfig.editReduceSharesHint,
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
              confirmText: widget.isAdd
                  ? AppConfig.btnConfirmBuy
                  : AppConfig.btnConfirmSell,
              confirmBgColor: widget.isAdd
                  ? AppColors.danger
                  : AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  void _onConfirm() {
    final diffShares = double.tryParse(_sharesController.text);
    final newPrice = double.tryParse(_priceController.text);
    if (diffShares == null ||
        diffShares <= 0 ||
        newPrice == null ||
        newPrice <= 0) {
      CenterToast.error(context, StockConfig.editInvalidInput);
      return;
    }

    final oldShares = widget.stock.shares;

    if (!widget.isAdd && diffShares > oldShares) {
      CenterToast.error(context, StockConfig.editOverflow);
      return;
    }

    final newShares = widget.isAdd
        ? oldShares + diffShares
        : oldShares - diffShares;
    final bool isClosePosition =
        !widget.isAdd && (diffShares - oldShares).abs() < 1e-9;
    final double avgBuyPrice = _avgBuyPrice;
    final double profitLoss = avgBuyPrice > 0
        ? (newPrice - avgBuyPrice) * newShares
        : 0.0;

    final updatedStock = widget.stock.copyWith(
      shares: newShares,
      totalValue: widget.stock.currentPrice * newShares,
      profitLossAmount: profitLoss,
    );

    String recordType, description;
    if (isClosePosition) {
      recordType = StockConfig.opSellType;
      description = '${StockConfig.opClosePosition} ${widget.stock.symbol}';
    } else if (widget.operationRecords.isEmpty) {
      recordType = StockConfig.opBuyType;
      description = '${StockConfig.opOpenPosition} ${widget.stock.symbol}';
    } else {
      recordType = widget.isAdd
          ? StockConfig.opBuyType
          : StockConfig.opSellType;
      description =
          '${widget.isAdd ? StockConfig.opAddPosition : StockConfig.opReducePosition} ${widget.stock.symbol}';
    }

    final record = OperationRecord(
      date: DateTime.now(),
      type: recordType,
      description: description,
      amount: newPrice,
      shares: diffShares,
      fee: _feeValue ?? 0.0,
    );

    widget.onSave(updatedStock, record, isClosePosition);
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRowWidget(
            label: StockConfig.searchStockCode,
            value: widget.stock.symbol,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            label: StockConfig.searchStockName,
            value: widget.stock.companyName,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            label: StockConfig.searchRealtimePrice,
            value:
                '${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(widget.stock.currentPrice)}',
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            label: StockConfig.searchShares,
            value:
                '${CurrencyUtil.formatRate(widget.stock.shares)}${StockConfig.stockSharesSuffix}',
          ),
          if (_avgBuyPrice > 0) ...[
            const SizedBox(height: 8),
            InfoRowWidget(
              label: StockConfig.stockDetailAvgPrice,
              value:
                  '${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(_avgBuyPrice)}',
            ),
          ],
        ],
      ),
    );
  }
}

/// 删除确认对话框（使用通用组件）
class DeleteStockDialog extends StatelessWidget {
  final StockModel stock;
  final VoidCallback onDelete;

  const DeleteStockDialog({
    super.key,
    required this.stock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ConfirmDeleteDialog(
      title: AppConfig.btnConfirm,
      content: StockConfig.deleteConfirmContent
          .replaceAll('{symbol}', stock.symbol)
          .replaceAll('{name}', stock.companyName),
      onConfirm: onDelete,
    );
  }
}

/// 更多操作对话框
class MoreOptionsDialog extends StatelessWidget {
  final StockModel stock;
  final VoidCallback onAdd;
  final VoidCallback onReduce;
  final VoidCallback onDelete;
  final VoidCallback onDividend;

  const MoreOptionsDialog({
    super.key,
    required this.stock,
    required this.onAdd,
    required this.onReduce,
    required this.onDelete,
    required this.onDividend,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * AppConfig.dialogWidthRatio,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    StockConfig.opMoreActions,
                    style: TextStyles.sectionTitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(thickness: 0.5, color: AppColors.border),
                ListTile(
                  leading: const Icon(
                    Icons.add_circle,
                    color: AppColors.danger,
                  ),
                  title: Text(
                    StockConfig.opAddPosition,
                    style: TextStyles.listTileTitle,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onAdd();
                  },
                ),
                Divider(thickness: 0.5, color: AppColors.border),
                ListTile(
                  leading: const Icon(
                    Icons.remove_circle,
                    color: AppColors.success,
                  ),
                  title: Text(
                    StockConfig.opReducePosition,
                    style: TextStyles.listTileTitle,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onReduce();
                  },
                ),
                Divider(thickness: 0.5, color: AppColors.border),
                ListTile(
                  leading: const Icon(
                    Icons.monetization_on,
                    color: AppColors.warning,
                  ),
                  title: Text(
                    StockConfig.opDividend,
                    style: TextStyles.bodyRegular,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDividend();
                  },
                ),
                Divider(thickness: 0.5, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.danger),
                  title: Text(
                    StockConfig.opDeleteStock,
                    style: TextStyles.listTileTitle.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 派息对话框
class DividendDialog extends StatefulWidget {
  final StockModel stock;
  final void Function(DateTime date, double amountPerShare, double taxRate)
  onConfirm;

  const DividendDialog({
    super.key,
    required this.stock,
    required this.onConfirm,
  });

  @override
  State<DividendDialog> createState() => _DividendDialogState();
}

class _DividendDialogState extends State<DividendDialog> {
  late TextEditingController _amountController;
  DateTime _selectedDate = DateTime.now();
  double _taxRate = 10;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePickerDialog(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return dialogFrame(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              StockConfig.dividendTitle,
              style: TextStyles.dialogTitle,
            ),
          ),
          const SizedBox(height: 16),
          _buildStockInfoSection(),
          const SizedBox(height: 16),
          Text(
            StockConfig.dividendDateLabel,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildDatePicker(),
          const SizedBox(height: 12),
          Text(
            StockConfig.dividendAmountLabel,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppNumberField(
                  controller: _amountController,
                  hintText: StockConfig.dividendAmountHint,
                ),
              ),
              const SizedBox(width: 8),
              buildPercentSelector(
                context,
                _taxRate,
                (v) => setState(() => _taxRate = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          actionButtonRow(
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              final amount = double.tryParse(_amountController.text);
              if (amount == null || amount <= 0) {
                CenterToast.error(context, StockConfig.dividendInvalidAmount);
                return;
              }
              widget.onConfirm(_selectedDate, amount, _taxRate / 100);
            },
            confirmText: StockConfig.dividendConfirm,
            confirmBgColor: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfoSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRowWidget(
            label: StockConfig.searchStockCode,
            value: widget.stock.symbol,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            label: StockConfig.searchStockName,
            value: widget.stock.companyName,
          ),
          const SizedBox(height: 8),
          InfoRowWidget(
            label: StockConfig.searchShares,
            value:
                '${CurrencyUtil.formatRate(widget.stock.shares)}${StockConfig.stockSharesSuffix}',
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(
              _formatDate(_selectedDate),
              style: TextStyles.sectionTitleRegular,
            ),
            const Spacer(),
            Icon(Icons.calendar_today, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
