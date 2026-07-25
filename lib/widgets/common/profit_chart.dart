import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../services/icloud_storage.dart';
import '../../models/stock_model.dart';
import '../../utils/currency_helper.dart';

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
    _loadSnapshots();
  }

  @override
  void didUpdateWidget(covariant ProfitChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isExpanded) _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final daily = await IcloudStorage.loadDailyProfitHistory(
      targetCurrency: widget.targetCurrency,
    );
    final intraday = await IcloudStorage.loadIntradayProfitHistory(
      targetCurrency: widget.targetCurrency,
    );
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
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (_selectedRange == 0) {
      _snapshots = _intradaySnapshots
          .where((s) => !s.time.isBefore(todayDate))
          .toList();
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
              const Icon(Icons.timeline, size: 12, color: Color(0xFFFF9F0A)),
              const SizedBox(width: 4),
              const Text(
                StockConfig.profitChartTitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Color(0xFF8E8E93),
              ),
            ],
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          _buildRangeSelector(),
          const SizedBox(height: 8),
          _buildChart(),
        ],
      ],
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
                    ? Color(0xFFFF9F0A).withOpacity(0.3)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Color(0xFFFF9F0A), width: 1.5)
                    : null,
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.white,
                  height: 1.2,
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
        child: Text(
          StockConfig.profitNoData,
          style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
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
    final color = Color(0xFFFF9F0A);

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
          text: CurrencyHelper.formatCompact(val),
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 60);
      tp.paint(canvas, Offset(-tp.width, y - tp.height / 2));
    }

    // grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = paintHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(paintWidth, y), gridPaint);
    }

    // zero line
    if (minVal < 0 && maxVal > 0) {
      final zeroY = scaleY(0);
      final zeroPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, zeroY), Offset(paintWidth, zeroY), zeroPaint);
    }

    // fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.02)],
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
      ..color = color.withOpacity(0.8)
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
        Paint()..color = isSel ? color.withOpacity(1) : color.withOpacity(0.4),
      );
    }

    // selected indicator: dashed vertical line + value + date
    if (selectedIndex != null && selectedIndex! < data.length) {
      final selX = scaleX(selectedIndex!);
      final selY = scaleY(data[selectedIndex!]);
      final selSnapshot = snapshots[selectedIndex!];

      // dashed vertical line from top to bottom of chart container
      final dashPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
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
      final valueText = CurrencyHelper.formatCompact(data[selectedIndex!]);
      final valueTp = TextPainter(
        text: TextSpan(
          text: valueText,
          style: TextStyle(
            color: color.withOpacity(0.95),
            fontSize: 11,
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
      canvas.drawRRect(labelRect, Paint()..color = const Color(0xFF1C1C1E));
      canvas.drawRRect(
        labelRect,
        Paint()
          ..color = color.withOpacity(0.9)
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
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
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
      canvas.drawRRect(dateRect, Paint()..color = const Color(0xFF1C1C1E));
      canvas.drawRRect(
        dateRect,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
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
