import 'package:flutter/material.dart';
import 'dart:math';
import '../../config/app_colors.dart';
import '../../utils/market_util.dart';

// ═══════════════════════════════════════
//  通用文本样式
// ═══════════════════════════════════════

class TextStyles {
  TextStyles._();

  static const caption = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static const captionMono = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    height: 1.2,
    fontFamily: 'SFMono',
  );

  static const label = TextStyle(
    fontSize: 10,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static const valueSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
  );

  static const valueSmallMono = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
    fontFamily: 'SFMono',
  );

  static const valueMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFamily: 'SFMono',
  );

  static const valueLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFamily: 'SFMono',
  );

  static const headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
  );

  static const accentLink = TextStyle(
    fontSize: 11,
    color: AppColors.accent,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // ── 标题类 ──
  static const dialogTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const sectionTitleRegular = TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  // ── 正文类 ──
  static const subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const subtitleRegular = TextStyle(fontSize: 14, color: Colors.white);

  static const bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const bodyRegular = TextStyle(fontSize: 15, color: Colors.white);

  static const body13 = TextStyle(fontSize: 13, color: Colors.white);

  // ── 小型强调 ──
  static const smallBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
  );
}

// ═══════════════════════════════════════
//  通用工具函数
// ═══════════════════════════════════════

/// 格式化时间用于「最近更新」subtitle
String formatRefreshTime(DateTime t) {
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════
//  标签组件
// ═══════════════════════════════════════

/// 市场标签 - 带颜色背景
class MarketBadge extends StatelessWidget {
  final String market;
  final double fontSize;

  const MarketBadge(this.market, {super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final color = MarketUtil.marketColor(market);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        market,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

/// 收益率展示瓦片（深灰底，标签在上，大号值在下）
class YieldTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const YieldTile({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyles.valueMedium.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// 货币标签 - 深灰背景
class CurrencyBadge extends StatelessWidget {
  final String currency;
  final double fontSize;

  const CurrencyBadge(this.currency, {super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        currency,
        style: TextStyle(
          fontSize: fontSize,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}

/// 市场 + 货币组合标签
class MarketAndCurrencyBadges extends StatelessWidget {
  final String market;
  final String currency;
  final double fontSize;

  const MarketAndCurrencyBadges({
    super.key,
    required this.market,
    required this.currency,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CurrencyBadge(currency, fontSize: fontSize),
        const SizedBox(width: 4),
        MarketBadge(market, fontSize: fontSize),
      ],
    );
  }
}

// ═══════════════════════════════════════
//  虚线分割线
// ═══════════════════════════════════════

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(double.infinity, 0.5),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashGap = 3.0;
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;
    double x = 0;
    while (x < size.width) {
      final end = min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}

// ═══════════════════════════════════════
//  筛选/排序药丸按钮
// ═══════════════════════════════════════

/// 可选中的药丸按钮
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final Color? color;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    color ??
                    (selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(trailingIcon, size: 12, color: AppColors.textPrimary),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  统计指标卡片
// ═══════════════════════════════════════

/// 通用统计指标卡片（圆角黑底，用于汇总展示）
class StatMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const StatMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.1,
              fontFamily: 'SFMono',
            ),
          ),
        ],
      ),
    );
  }
}
