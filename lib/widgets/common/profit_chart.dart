import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_config.dart';
import '../../services/stock_data_manager.dart';
import '../../models/stock_model.dart';
import '../../utils/currency_util.dart';
import '../../utils/trading_day_util.dart';
import 'app_ui.dart';

class ProfitChartWidget extends StatefulWidget {
  final double totalProfit;
  final String targetCurrency;

  const ProfitChartWidget({
    super.key,
    required this.totalProfit,
    required this.targetCurrency,
  });

  @override
  State<ProfitChartWidget> createState() => _ProfitChartWidgetState();
}

class _ProfitChartWidgetState extends State<ProfitChartWidget> {
  bool _isExpanded = false;
  int _selectedRange = 0;
  int? _selectedIndex;
  List<ProfitSnapshot> _snapshots = [];
  List<ProfitSnapshot> _dailySnapshots = [];
  List<ProfitSnapshot> _intradaySnapshots = [];

  static const List<_RangeOption> _rangeOptions = [
    _RangeOption(StockConfig.profitRangeToday, 0),
    _RangeOption(StockConfig.profitRange7d, 1),
    _RangeOption(StockConfig.profitRange30d, 2),
    _RangeOption(StockConfig.profitRange180d, 3),
    _RangeOption(StockConfig.profitRange360d, 4),
  ];

  @override
  void initState() {
    super.initState();
    _loadIntradayOnly();
  }

  @override
  void didUpdateWidget(covariant ProfitChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.totalProfit != oldWidget.totalProfit ||
        widget.targetCurrency != oldWidget.targetCurrency) {
      _loadIntradayOnly();
    }
    if (_isExpanded) _loadSnapshots();
  }

  Future<void> _loadIntradayOnly() async {
    final intraday = await _loadTodaySnapshots();
    if (!mounted) return;
    setState(() => _intradaySnapshots = intraday);
  }

  /// 今日盈亏曲线：日内快照 − 今日基线（昨收），返回相对基线的盈亏
  /// 以美东 9:00 日界筛选（覆盖美股开盘）
  Future<List<ProfitSnapshot>> _loadTodaySnapshots() async {
    final baseline = await StockDataManager.loadTodayBaseline();
    final intraday = await StockDataManager.loadIntradayProfitHistory(
      targetCurrency: widget.targetCurrency,
    );
    final dayKey = TradingDayUtil.tradingDayKey(DateTime.now());
    final today = intraday
        .where((s) => TradingDayUtil.tradingDayKey(s.time) == dayKey)
        .toList();
    if (baseline == null) return today;
    final baselineInTarget = CurrencyUtil.convertCurrency(
      baseline.$2,
      AppConfig.defaultCurrency,
      widget.targetCurrency,
    );
    return today
        .map(
          (s) => ProfitSnapshot(
            time: s.time,
            totalProfit: s.totalProfit - baselineInTarget,
          ),
        )
        .toList();
  }

  Future<void> _loadSnapshots() async {
    final daily = await StockDataManager.loadDailyProfitHistory(
      targetCurrency: widget.targetCurrency,
    );
    final intraday = await _loadTodaySnapshots();
    if (!mounted) return;
    setState(() {
      _dailySnapshots = daily;
      _intradaySnapshots = intraday;
      _applyRange();
    });
    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][图表] ===> 加载: 天级=${daily.length}, 10分钟=${intraday.length}, 展示=${_snapshots.length}, 货币=${widget.targetCurrency}',
    );
  }

  void _applyRange() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    if (_selectedRange == 0) {
      // 今日：日内快照已在 _loadTodaySnapshots 中按美东 9:00 日界过滤
      _snapshots = _intradaySnapshots;
    } else {
      final cutoff = todayDate.subtract(
        Duration(days: [0, 7, 30, 180, 360][_selectedRange]),
      );
      _snapshots = _dailySnapshots
          .where((s) => s.time.isAfter(cutoff))
          .toList();
    }
    _snapshots.sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _isExpanded = !_isExpanded;
            _selectedIndex = null;
            if (_isExpanded) _loadSnapshots();
          }),
          child: Row(
            children: [
              const Icon(Icons.timeline, size: 12, color: AppColors.warning),
              const Spacer(),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        if (!_isExpanded) ...[const SizedBox(height: 6), _buildMiniChart()],
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          _buildRangeSelector(),
          const SizedBox(height: 8),
          _buildChart(),
        ],
      ],
    );
  }

  Widget _buildMiniChart() {
    final data = _intradaySnapshots;
    if (data.isEmpty) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: const Text(StockConfig.profitNoData, style: TextStyles.caption),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: CustomPaint(
          size: const Size(double.infinity, 38),
          painter: _MiniChartPainter(
            data: data.map((s) => s.totalProfit).toList(),
            isPositive: widget.totalProfit >= 0,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Row(
      children: _rangeOptions.map((option) {
        final isSelected = option.index == _selectedRange;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedRange = option.index;
              _selectedIndex = null;
              _applyRange();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.warning.withValues(alpha: 0.3)
                    : AppColors.textPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AppColors.warning, width: 1.5)
                    : null,
              ),
              child: Text(
                option.label,
                style: TextStyles.label.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChart() {
    final data = _snapshots;
    if (data.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(StockConfig.profitNoData, style: TextStyles.bodySmall),
      );
    }

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 44,
              right: 8,
              top: 16,
              bottom: 20,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) =>
                      _onTapDownAt(details.localPosition.dx, constraints, data),
                  onHorizontalDragUpdate: (details) =>
                      _onTapDownAt(details.localPosition.dx, constraints, data),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _ProfitChartPainter(
                      snapshots: data,
                      isPositive: widget.totalProfit >= 0,
                      selectedIndex: _selectedIndex,
                      selectedRange: _selectedRange,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onTapDownAt(
    double localX,
    BoxConstraints constraints,
    List<ProfitSnapshot> data,
  ) {
    if (data.isEmpty) return;
    final count = data.length;
    final index = (localX / constraints.maxWidth * (count - 1)).round().clamp(
      0,
      count - 1,
    );
    setState(() => _selectedIndex = index);
  }
}

class _RangeOption {
  final String label;
  final int index;
  const _RangeOption(this.label, this.index);
}

class _ProfitChartPainter extends CustomPainter {
  final List<ProfitSnapshot> snapshots;
  final bool isPositive;
  final int? selectedIndex;
  final int selectedRange;

  _ProfitChartPainter({
    required this.snapshots,
    required this.isPositive,
    this.selectedIndex,
    this.selectedRange = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;

    final data = snapshots.map((s) => s.totalProfit).toList();
    final paintWidth = size.width;
    final paintHeight = size.height;
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final color = AppColors.warning;

    double scaleY(double val) {
      if (minVal == maxVal) return paintHeight / 2;
      return paintHeight -
          ((val - minVal) / (maxVal - minVal)) * (paintHeight - 8);
    }

    double scaleX(int index) {
      if (data.length == 1) return paintWidth / 2;
      return (index / (data.length - 1)) * paintWidth;
    }

    // Y-axis labels
    for (int i = 0; i <= 4; i++) {
      final val = minVal + (maxVal - minVal) * i / 4;
      final y = paintHeight - (i / 4) * (paintHeight - 8);
      final tp = TextPainter(
        text: TextSpan(
          text: CurrencyUtil.formatCompact(val),
          style: TextStyles.label.copyWith(
            fontSize: 9,
            color: AppColors.textPrimary.withValues(alpha: 0.4),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 60);
      tp.paint(canvas, Offset(-tp.width, y - tp.height / 2));
    }

    // grid lines
    final gridPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = paintHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(paintWidth, y), gridPaint);
    }

    // zero line
    if (minVal < 0 && maxVal > 0) {
      final zeroY = scaleY(0);
      final zeroPaint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.15)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, zeroY), Offset(paintWidth, zeroY), zeroPaint);
    }

    // fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, paintWidth, paintHeight));

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = scaleX(i);
      final y = scaleY(data[i]);
      if (i == 0) {
        path.moveTo(x, paintHeight);
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(scaleX(data.length - 1), paintHeight);
    path.close();
    canvas.drawPath(path, fillPaint);

    // line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = scaleX(i);
      final y = scaleY(data[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // data points
    for (int i = 0; i < data.length; i++) {
      final x = scaleX(i);
      final y = scaleY(data[i]);
      final isSel = i == selectedIndex;
      canvas.drawCircle(
        Offset(x, y),
        isSel ? 4 : 1.5,
        Paint()
          ..color = isSel
              ? color.withValues(alpha: 1)
              : color.withValues(alpha: 0.4),
      );
    }

    // selected indicator: dashed vertical line + value + date
    if (selectedIndex != null && selectedIndex! < data.length) {
      final selX = scaleX(selectedIndex!);
      final selY = scaleY(data[selectedIndex!]);
      final selSnapshot = snapshots[selectedIndex!];

      // dashed vertical line from top to bottom of chart container
      final dashPaint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const dashLen = 5.0;
      const gapLen = 3.0;
      const topInset = 16.0;
      const bottomInset = 20.0;
      double dashY = -topInset;
      while (dashY < paintHeight + bottomInset) {
        final endY = (dashY + dashLen).clamp(
          -topInset,
          paintHeight + bottomInset,
        );
        canvas.drawLine(Offset(selX, dashY), Offset(selX, endY), dashPaint);
        dashY += dashLen + gapLen;
      }

      // value label at top
      final valueText = CurrencyUtil.formatCompact(data[selectedIndex!]);
      final valueTp = TextPainter(
        text: TextSpan(
          text: valueText,
          style: TextStyles.whiteBold11.copyWith(
            color: color.withValues(alpha: 0.95),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final labelW = valueTp.width + 10;
      final labelH = valueTp.height + 6;
      final labelX = (selX - labelW / 2).clamp(0.0, paintWidth - labelW);
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX, 0, labelW, labelH),
        const Radius.circular(4),
      );
      canvas.drawRRect(labelRect, Paint()..color = AppColors.border);
      canvas.drawRRect(
        labelRect,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      valueTp.paint(canvas, Offset(labelX + 5, 3));

      // date label at bottom
      final dateText = selectedRange == 0
          ? DateFormat('HH:mm').format(selSnapshot.time)
          : DateFormat('MM-dd').format(selSnapshot.time);
      final dateTp = TextPainter(
        text: TextSpan(
          text: dateText,
          style: TextStyles.label.copyWith(
            color: AppColors.textPrimary.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final dateLabelW = dateTp.width + 10;
      final dateLabelH = dateTp.height + 6;
      final dateLabelX = (selX - dateLabelW / 2).clamp(
        0.0,
        paintWidth - dateLabelW,
      );
      final dateLabelY = paintHeight - dateLabelH;
      final dateRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dateLabelX, dateLabelY, dateLabelW, dateLabelH),
        const Radius.circular(4),
      );
      canvas.drawRRect(dateRect, Paint()..color = AppColors.border);
      canvas.drawRRect(
        dateRect,
        Paint()
          ..color = AppColors.textPrimary.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
      dateTp.paint(canvas, Offset(dateLabelX + 5, dateLabelY + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _ProfitChartPainter oldDelegate) {
    return oldDelegate.snapshots != snapshots ||
        oldDelegate.isPositive != isPositive ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

/// 缩小版今日盈亏曲线绘制器（用于折叠预览行）
class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final bool isPositive;

  _MiniChartPainter({required this.data, required this.isPositive});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paintWidth = size.width;
    final paintHeight = size.height;
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final color = isPositive ? AppColors.danger : AppColors.success;

    double scaleY(double val) {
      if (minVal == maxVal) return paintHeight / 2;
      return paintHeight -
          ((val - minVal) / (maxVal - minVal)) * (paintHeight - 4);
    }

    double scaleX(int index) {
      if (data.length == 1) return paintWidth / 2;
      return (index / (data.length - 1)) * paintWidth;
    }

    // dashed zero line
    if (minVal < 0 && maxVal > 0) {
      final zeroY = scaleY(0);
      final dashPaint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      const dashLen = 4.0;
      const gapLen = 2.0;
      double dx = 0;
      while (dx < paintWidth) {
        canvas.drawLine(
          Offset(dx, zeroY),
          Offset((dx + dashLen).clamp(0, paintWidth), zeroY),
          dashPaint,
        );
        dx += dashLen + gapLen;
      }
    }

    // fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, paintWidth, paintHeight));

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = scaleX(i);
      final y = scaleY(data[i]);
      if (i == 0) {
        path.moveTo(x, paintHeight);
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(scaleX(data.length - 1), paintHeight);
    path.close();
    canvas.drawPath(path, fillPaint);

    // line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = scaleX(i);
      final y = scaleY(data[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.isPositive != isPositive;
  }
}
