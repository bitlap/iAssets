import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock_model.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_util.dart';
import '../common/app_ui.dart';
import '../common/empty_state_widget.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/app_number_field.dart';
import '../common/dialog_utils.dart';
import '../common/percent_selector.dart';

/// 派息记录Tab
class DividendRecordsTab extends StatefulWidget {
  final StockModel stock;
  final List<DividendRecord> dividendRecords;
  final void Function(String symbol, int index)? onDeleteRecord;
  final void Function(String symbol, int index, DividendRecord updated)?
  onEditRecord;

  const DividendRecordsTab({
    super.key,
    required this.stock,
    this.dividendRecords = const [],
    this.onDeleteRecord,
    this.onEditRecord,
  });

  @override
  State<DividendRecordsTab> createState() => _DividendRecordsTabState();
}

class _DividendRecordsTabState extends State<DividendRecordsTab> {
  late List<DividendRecord> allRecords;

  @override
  void initState() {
    super.initState();
    allRecords = List.from(widget.dividendRecords)
      ..sort((a, b) => b.operationTime.compareTo(a.operationTime));
  }

  @override
  void didUpdateWidget(covariant DividendRecordsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dividendRecords != oldWidget.dividendRecords) {
      allRecords = List.from(widget.dividendRecords)
        ..sort((a, b) => b.operationTime.compareTo(a.operationTime));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (allRecords.isEmpty) {
      return EmptyStateWidget(
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
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(
              Icons.delete,
              color: AppColors.redAccent,
              size: 20,
            ),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _icon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerRow(record),
                        const SizedBox(height: 4),
                        _detailRow(record),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            StockConfig.recordsDateTimePattern,
                          ).format(record.operationTime),
                          style: TextStyles.caption,
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

  Widget _icon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.monetization_on,
        color: AppColors.amber,
        size: 16,
      ),
    );
  }

  Widget _headerRow(DividendRecord record) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${StockConfig.recordsDivTab} ${widget.stock.symbol}',
            style: TextStyles.body13.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(record.totalAmount)}',
          style: TextStyles.body13.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.amber,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(DividendRecord record) {
    return Row(
      children: [
        Text(
          '${CurrencyUtil.formatRate(record.shares)}${StockConfig.recordsTimesSign}${CurrencyUtil.formatRate(record.amount)}${StockConfig.recordsTimesSign}${1 - record.taxRate}',
          style: TextStyles.caption,
        ),
        const Spacer(),
        Text(
          DateFormat(StockConfig.recordsDatePattern).format(record.date),
          style: TextStyles.caption,
        ),
      ],
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
    double editTaxRate = record.taxRate * 100;

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
                  style: TextStyles.dialogTitle,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                StockConfig.dividendEditDateLabel,
                style: TextStyles.body13Grey,
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        DateFormat(
                          StockConfig.recordsDatePattern,
                        ).format(selectedDate),
                        style: TextStyles.inputText,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: AppColors.grey600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                StockConfig.dividendEditAmountLabel,
                style: TextStyles.body13Grey,
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
                  colors: [AppColors.blueDark, AppColors.blueAccent],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
