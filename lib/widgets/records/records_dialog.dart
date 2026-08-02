import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../common/app_ui.dart';
import '../common/dialog_utils.dart';
import 'records_op_tab.dart';
import 'records_div_tab.dart';

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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
          left: BorderSide(color: AppColors.border, width: 0.5),
          right: BorderSide(color: AppColors.border, width: 0.5),
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
                color: AppColors.grey600,
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
                Text(widget.stock.symbol, style: TextStyles.dialogTitle),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    StockConfig.stockRecord,
                    style: TextStyles.body13.copyWith(
                      fontSize: 12,
                      color: AppColors.accent,
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
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.grey,
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.blueAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.grey,
                labelStyle: TextStyles.body13.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyles.body13.copyWith(
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
                        Text(StockConfig.recordsOpTab),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: _showOpDeleteHint,
                          child: Icon(
                            Icons.help_outline,
                            size: 14,
                            color: _selectedTab == 0
                                ? Colors.white
                                : AppColors.blueAccent,
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
                        Text(StockConfig.recordsDivTab),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: _showDivDeleteHint,
                          child: Icon(
                            Icons.help_outline,
                            size: 14,
                            color: _selectedTab == 1
                                ? Colors.white
                                : AppColors.blueAccent,
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
                OperationRecordsTab(
                  stock: widget.stock,
                  operationRecords: widget.operationRecords,
                  onDeleteRecord: widget.onDeleteOperationRecord,
                  onEditRecord: widget.onEditOperationRecord,
                ),
                DividendRecordsTab(
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
      iconColor: AppColors.accent,
      content: Text(
        StockConfig.recordsDeleteHint,
        style: TextStyles.body13.copyWith(
          color: AppColors.grey400,
          height: 1.4,
        ),
      ),
    );
  }

  void _showDivDeleteHint() {
    showHelpDialog(
      context,
      title: StockConfig.recordsDivTab,
      icon: Icons.info_outline,
      iconColor: AppColors.amber,
      content: Text(
        StockConfig.recordsDivDeleteHint,
        style: TextStyles.body13.copyWith(
          color: AppColors.grey400,
          height: 1.4,
        ),
      ),
    );
  }
}
