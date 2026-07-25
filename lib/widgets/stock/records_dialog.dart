import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock_model.dart';
import '../../utils/currency_util.dart';
import '../../config/app_config.dart';
import '../common/empty_state_widget.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/app_number_field.dart';
import '../common/dialog_utils.dart';
import '../common/percent_selector.dart';

/// 记录弹窗（底部弹出，支持下拉关闭）
class RecordsDialog extends StatefulWidget {
  final StockModel stock;
  final List<OperationRecord> operationRecords;
  final List<DividendRecord> dividendRecords;
  final ScrollController scrollController;
  final void Function(String symbol, int index)? onDeleteOperationRecord;
  final void Function(String symbol, int index, OperationRecord updated)?
  onEditOperationRecord;
  final void Function(String symbol, int index)? onDeleteDividendRecord;
  final void Function(String symbol, int index, DividendRecord updated)?
  onEditDividendRecord;

  const RecordsDialog({
    super.key,
    required this.stock,
    required this.scrollController,
    this.operationRecords = const [],
    this.dividendRecords = const [],
    this.onDeleteOperationRecord,
    this.onEditOperationRecord,
    this.onDeleteDividendRecord,
    this.onEditDividendRecord,
  });

  @override
  State<RecordsDialog> createState() => _RecordsDialogState();
}

class _RecordsDialogState extends State<RecordsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF1C1C1E), width: 0.5),
          left: BorderSide(color: Color(0xFF1C1C1E), width: 0.5),
          right: BorderSide(color: Color(0xFF1C1C1E), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // 拖拽手柄
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stock.symbol,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    StockConfig.stockRecord,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B9CF6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1C1C1E),
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: _selectedTab == 0
                      ? const Color(0xFF2962FF)
                      : const Color(0xFF2962FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(10),
                tabs: [
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(StockConfig.recordsOpTab),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: _showOpDeleteHint,
                          child: Icon(
                            Icons.help_outline,
                            size: 14,
                            color: _selectedTab == 0
                                ? Colors.white
                                : const Color(0xFF2962FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(StockConfig.recordsDivTab),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: _showDivDeleteHint,
                          child: Icon(
                            Icons.help_outline,
                            size: 14,
                            color: _selectedTab == 1
                                ? Colors.white
                                : const Color(0xFF2962FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OperationRecordsTab(
                  stock: widget.stock,
                  operationRecords: widget.operationRecords,
                  onDeleteRecord: widget.onDeleteOperationRecord,
                  onEditRecord: widget.onEditOperationRecord,
                ),
                _DividendRecordsTab(
                  stock: widget.stock,
                  dividendRecords: widget.dividendRecords,
                  onDeleteRecord: widget.onDeleteDividendRecord,
                  onEditRecord: widget.onEditDividendRecord,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOpDeleteHint() {
    showHelpDialog(
      context,
      title: StockConfig.recordsOpTab,
      icon: Icons.info_outline,
      iconColor: const Color(0xFF5B9CF6),
      content: Text(
        StockConfig.recordsDeleteHint,
        style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
      ),
    );
  }

  void _showDivDeleteHint() {
    showHelpDialog(
      context,
      title: StockConfig.recordsDivTab,
      icon: Icons.info_outline,
      iconColor: Colors.amber,
      content: Text(
        StockConfig.recordsDivDeleteHint,
        style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
      ),
    );
  }
}

/// 操作记录Tab
class _OperationRecordsTab extends StatefulWidget {
  final StockModel stock;
  final List<OperationRecord> operationRecords;
  final void Function(String symbol, int index)? onDeleteRecord;
  final void Function(String symbol, int index, OperationRecord updated)?
  onEditRecord;

  const _OperationRecordsTab({
    required this.stock,
    required this.operationRecords,
    this.onDeleteRecord,
    this.onEditRecord,
  });

  @override
  State<_OperationRecordsTab> createState() => _OperationRecordsTabState();
}

class _OperationRecordsTabState extends State<_OperationRecordsTab> {
  late List<OperationRecord> allRecords;

  @override
  void initState() {
    super.initState();
    allRecords = List.from(widget.operationRecords);
  }

  @override
  Widget build(BuildContext context) {
    if (allRecords.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.list_alt,
        title: StockConfig.recordsEmptyOp,
        subtitle: StockConfig.recordsEmptyOpHint,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: allRecords.length,
      itemBuilder: (context, index) {
        final record = allRecords[index];
        final isBuy = record.type == StockConfig.opBuy;
        final iconColor = isBuy ? Colors.redAccent : Colors.greenAccent;
        final iconBgColor = isBuy
            ? Colors.red.withOpacity(0.15)
            : Colors.green.withOpacity(0.15);
        final icon = isBuy ? Icons.arrow_upward : Icons.arrow_downward;
        return Dismissible(
          key: ValueKey(
            'op_${index}_${record.operationTime.millisecondsSinceEpoch}',
          ),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
          ),
          confirmDismiss: (_) => ConfirmDeleteDialog.show(
            context,
            title: AppConfig.btnConfirm,
            content: StockConfig.recordsDeleteOpConfirm,
          ),
          onDismissed: (_) {
            setState(() => allRecords.removeAt(index));
            widget.onDeleteRecord?.call(widget.stock.symbol, index);
          },
          child: InkWell(
            onTap: () => _showEditRecordDialog(context, index, record),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1C1C1E), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${isBuy ? "+" : "-"}${CurrencyUtil.formatRate(record.shares)}${StockConfig.stockSharesSuffix}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (record.amount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${StockConfig.recordsFormulaLabel}: ${CurrencyUtil.formatRate(record.amount)} × ${CurrencyUtil.formatRate(record.shares)}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              Text(
                                '${StockConfig.recordsOpLabel}: ${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(record.amount * record.shares)}',
                                style: TextStyle(
                                  color: isBuy
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '${StockConfig.recordsOperationTime}: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(record.operationTime)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${StockConfig.recordsDateLabel}: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(record.date)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditRecordDialog(
    BuildContext context,
    int index,
    OperationRecord record,
  ) {
    final priceCtrl = TextEditingController(
      text: CurrencyUtil.formatRate(record.amount),
    );
    final sharesCtrl = TextEditingController(
      text: CurrencyUtil.formatRate(record.shares),
    );

    showDialog(
      context: context,
      builder: (ctx) => dialogFrame(
        context: ctx,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                StockConfig.recordsEditTitle.replaceAll(
                  '{desc}',
                  record.description,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              StockConfig.recordsEditPrice,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 16, color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF000000),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1C1C1E),
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1C1C1E),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              StockConfig.recordsEditShares,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: sharesCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 16, color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF000000),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1C1C1E),
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1C1C1E),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            actionButtonRow(
              onCancel: () => Navigator.pop(ctx),
              onConfirm: () {
                final newPrice = double.tryParse(priceCtrl.text);
                final newShares = double.tryParse(sharesCtrl.text);
                if (newPrice == null ||
                    newPrice <= 0 ||
                    newShares == null ||
                    newShares <= 0)
                  return;
                final updated = record.copyWith(
                  amount: newPrice,
                  shares: newShares,
                );
                setState(() => allRecords[index] = updated);
                widget.onEditRecord?.call(widget.stock.symbol, index, updated);
                Navigator.pop(ctx);
              },
              confirmText: AppConfig.btnClose,
              confirmGradient: const LinearGradient(
                colors: [Color(0xFF1A56DB), Color(0xFF2962FF)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 派息记录Tab
class _DividendRecordsTab extends StatefulWidget {
  final StockModel stock;
  final List<DividendRecord> dividendRecords;
  final void Function(String symbol, int index)? onDeleteRecord;
  final void Function(String symbol, int index, DividendRecord updated)?
  onEditRecord;

  const _DividendRecordsTab({
    required this.stock,
    this.dividendRecords = const [],
    this.onDeleteRecord,
    this.onEditRecord,
  });

  @override
  State<_DividendRecordsTab> createState() => _DividendRecordsTabState();
}

class _DividendRecordsTabState extends State<_DividendRecordsTab> {
  late List<DividendRecord> allRecords;

  @override
  void initState() {
    super.initState();
    // 按操作时间降序排序（最新在前）
    allRecords = List.from(widget.dividendRecords)
      ..sort((a, b) => b.operationTime.compareTo(a.operationTime));
  }

  @override
  void didUpdateWidget(covariant _DividendRecordsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dividendRecords != oldWidget.dividendRecords) {
      allRecords = List.from(widget.dividendRecords)
        ..sort((a, b) => b.operationTime.compareTo(a.operationTime));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (allRecords.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.attach_money,
        title: StockConfig.recordsEmptyDiv,
        subtitle: StockConfig.recordsEmptyDivHint,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: allRecords.length,
      itemBuilder: (context, index) {
        final record = allRecords[index];
        return Dismissible(
          key: ValueKey(
            'div_${index}_${record.operationTime.millisecondsSinceEpoch}',
          ),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
          ),
          confirmDismiss: (_) => ConfirmDeleteDialog.show(
            context,
            title: AppConfig.btnConfirm,
            content: StockConfig.recordsDeleteDivConfirm,
          ),
          onDismissed: (_) {
            setState(() => allRecords.removeAt(index));
            widget.onDeleteRecord?.call(widget.stock.symbol, index);
          },
          child: InkWell(
            onTap: () => _showEditDividendDialog(context, index, record),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1C1C1E), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                StockConfig.recordsDivTab +
                                    ' ${widget.stock.symbol}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(record.totalAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${StockConfig.recordsFormulaLabel}: ${CurrencyUtil.formatRate(record.shares)} × ${CurrencyUtil.formatRate(record.amount)} × ${1 - record.taxRate}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            Text(
                              '${StockConfig.recordsDivLabel}: ${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(record.afterTaxAmount)}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${StockConfig.dividendDateLabel}: ${DateFormat('yyyy-MM-dd').format(record.date)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${StockConfig.recordsOperationTime}: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(record.operationTime)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditDividendDialog(
    BuildContext context,
    int index,
    DividendRecord record,
  ) {
    final amountCtrl = TextEditingController(
      text: CurrencyUtil.formatRate(record.amount),
    );
    final sharesCtrl = TextEditingController(
      text: CurrencyUtil.formatRate(record.shares),
    );
    DateTime selectedDate = record.date;
    double editTaxRate = record.taxRate * 100; // 显示为百分比（0~50）

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => dialogFrame(
          context: ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  StockConfig.dividendEditTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                StockConfig.dividendEditDateLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePickerDialog(
                    ctx,
                    initialDate: selectedDate,
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1C1C1E),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                StockConfig.dividendEditAmountLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppNumberField(
                      controller: amountCtrl,
                      hintText: StockConfig.dividendAmountHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  buildPercentSelector(
                    ctx,
                    editTaxRate,
                    (v) => setDialogState(() => editTaxRate = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppNumberField(
                controller: sharesCtrl,
                label: StockConfig.dividendEditSharesLabel,
                hintText: StockConfig.editAddSharesHint,
              ),
              const SizedBox(height: 16),
              actionButtonRow(
                onCancel: () => Navigator.pop(ctx),
                onConfirm: () {
                  final newAmount = double.tryParse(amountCtrl.text);
                  final newShares = double.tryParse(sharesCtrl.text);
                  if (newAmount == null ||
                      newAmount <= 0 ||
                      newShares == null ||
                      newShares <= 0)
                    return;
                  final updated = record.copyWith(
                    date: selectedDate,
                    amount: newAmount,
                    shares: newShares,
                    taxRate: editTaxRate / 100,
                  );
                  setState(() => allRecords[index] = updated);
                  widget.onEditRecord?.call(
                    widget.stock.symbol,
                    index,
                    updated,
                  );
                  Navigator.pop(ctx);
                },
                confirmText: AppConfig.btnClose,
                confirmGradient: const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF2962FF)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
