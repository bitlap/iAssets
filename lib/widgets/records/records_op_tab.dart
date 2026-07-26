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

/// 操作记录Tab
class OperationRecordsTab extends StatefulWidget {
  final StockModel stock;
  final List<OperationRecord> operationRecords;
  final void Function(String symbol, int index)? onDeleteRecord;
  final void Function(String symbol, int index, OperationRecord updated)?
  onEditRecord;

  const OperationRecordsTab({
    super.key,
    required this.stock,
    required this.operationRecords,
    this.onDeleteRecord,
    this.onEditRecord,
  });

  @override
  State<OperationRecordsTab> createState() => _OperationRecordsTabState();
}

class _OperationRecordsTabState extends State<OperationRecordsTab> {
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
        return Dismissible(
          key: ValueKey(
            'op_${index}_${record.operationTime.millisecondsSinceEpoch}',
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _icon(isBuy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerRow(record, isBuy),
                        const SizedBox(height: 4),
                        _detailRow(record, isBuy),
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

  Widget _icon(bool isBuy) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isBuy
            ? Colors.red.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isBuy ? Icons.arrow_upward : Icons.arrow_downward,
        color: isBuy ? AppColors.redAccent : AppColors.greenAccent,
        size: 16,
      ),
    );
  }

  Widget _headerRow(OperationRecord record, bool isBuy) {
    return Row(
      children: [
        Expanded(
          child: Text(
            record.description,
            style: TextStyles.body13.copyWith(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${isBuy ? "+" : "-"}${CurrencyUtil.formatRate(record.shares)}${StockConfig.stockSharesSuffix}',
          style: TextStyles.body13.copyWith(
            fontWeight: FontWeight.bold,
            color: isBuy ? AppColors.redAccent : AppColors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(OperationRecord record, bool isBuy) {
    return Row(
      children: [
        if (record.amount > 0)
          Text(
            '${CurrencyUtil.formatRate(record.amount)}${StockConfig.recordsTimesSign}${CurrencyUtil.formatRate(record.shares)}',
            style: TextStyles.caption,
          )
        else
          const Text('-', style: TextStyles.caption),
        const Spacer(),
        Text(
          '${CurrencyUtil.getSymbol(widget.stock.currency)}${CurrencyUtil.formatRate(record.amount * record.shares)}',
          style: TextStyles.smallBold.copyWith(
            color: isBuy ? AppColors.redAccent : AppColors.greenAccent,
          ),
        ),
      ],
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
                style: TextStyles.dialogTitle,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              StockConfig.recordsEditPrice,
              style: TextStyles.body13Grey,
            ),
            const SizedBox(height: 6),
            _buildTextField(priceCtrl),
            const SizedBox(height: 12),
            const Text(
              StockConfig.recordsEditShares,
              style: TextStyles.body13Grey,
            ),
            const SizedBox(height: 6),
            _buildTextField(sharesCtrl),
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
                colors: [AppColors.blueDark, AppColors.blueAccent],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyles.inputText,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }
}
