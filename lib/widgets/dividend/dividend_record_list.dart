import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock_model.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../utils/currency_util.dart';
import '../common/app_ui.dart';

/// 展开的股息记录列表
class DividendRecordList extends StatelessWidget {
  final List<DividendRecord> records;
  final String currency;

  const DividendRecordList({
    super.key,
    required this.records,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text(StockConfig.profitNoData, style: TextStyles.bodySmall),
      );
    }
    final sorted = List<DividendRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        const Divider(color: AppColors.border, thickness: 0.5, height: 0.5),
        const SizedBox(height: 4),
        ...sorted.map(
          (r) => _DividendRecordItem(record: r, currency: currency),
        ),
      ],
    );
  }
}

/// 单条股息记录
class _DividendRecordItem extends StatelessWidget {
  final DividendRecord record;
  final String currency;

  const _DividendRecordItem({required this.record, required this.currency});

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.warning,
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
                      DateFormat(StockConfig.recordsDatePattern).format(record.date),
                      style: TextStyles.valueSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${StockConfig.recordsDivLabel}: $sym${CurrencyUtil.formatCompact(record.afterTaxAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyUtil.formatRate(record.shares)}${StockConfig.recordsTimesSign}${CurrencyUtil.formatRate(record.amount)}${StockConfig.recordsTimesSign}${1 - record.taxRate}',
                  style: TextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
