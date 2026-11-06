import 'package:flutter/material.dart';

/// 确保列表表头与卡片内容的列边界一致。
class StockColumns extends StatelessWidget {
  static const double logoWidth = 40;
  static const double logoGap = 8;

  final Widget name;
  final Widget holdings;
  final Widget profit;

  const StockColumns({
    super.key,
    required this.name,
    required this.holdings,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final remaining = constraints.maxWidth - logoWidth - logoGap;
        return Row(
          children: [
            SizedBox(
              width: logoWidth + logoGap + remaining * 2 / 5,
              child: name,
            ),
            SizedBox(width: remaining * 2 / 5, child: holdings),
            Expanded(child: profit),
          ],
        );
      },
    );
  }
}
