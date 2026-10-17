import 'package:flutter/material.dart';
import 'dart:math';
import '../../config/app_colors.dart';
import '../../utils/market_util.dart';

// ═══════════════════════════════════════
//  通用文本样式
// ═══════════════════════════════════════

class TextStyles {
  TextStyles._();

  static TextStyle get caption =>
      TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.2);

  static TextStyle get captionMono => TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    height: 1.2,
    fontFamily: 'SFMono',
  );

  static TextStyle get label =>
      TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.2);

  static TextStyle get bodySmall =>
      TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.2);

  static TextStyle get valueSmall => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get valueSmallMono => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
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

  static TextStyle get headline => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get accentLink => TextStyle(
    fontSize: 11,
    color: AppColors.accent,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  // ── 标题类 ──
  static TextStyle get dialogTitle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get sectionTitle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get sectionTitleRegular =>
      TextStyle(fontSize: 16, color: AppColors.textPrimary);

  // ── 正文类 ──
  static TextStyle get subtitle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get subtitleRegular =>
      TextStyle(fontSize: 14, color: AppColors.textPrimary);

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyRegular =>
      TextStyle(fontSize: 15, color: AppColors.textPrimary);

  static TextStyle get body13 =>
      TextStyle(fontSize: 13, color: AppColors.textPrimary);

  /// 13px 灰色正文
  static TextStyle get body13Grey =>
      TextStyle(fontSize: 13, color: AppColors.grey, height: 1.2);

  /// 15px 白色列表标题
  static TextStyle get listTileTitle =>
      TextStyle(fontSize: 15, color: AppColors.textPrimary);

  /// 16px 白色输入框文字
  static TextStyle get inputText =>
      TextStyle(fontSize: 16, color: AppColors.textPrimary);

  /// 12px 白色加粗
  static TextStyle get whiteBold12 => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// 13px 白色加粗正文
  static TextStyle get body13Bold => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// 11px 白色加粗
  static TextStyle get whiteBold11 => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 34px 白色加粗（总资产金额）
  static TextStyle get amountLarge => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  /// 17px 白色加粗（AppBar 标题）
  static TextStyle get appBarTitle => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 14px 灰色提示文字（hintStyle 备用）
  static TextStyle get hintText =>
      TextStyle(fontSize: 14, color: AppColors.textSecondary);

  // ── 小型强调 ──
  static TextStyle get smallBold => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
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
        MarketUtil.marketLabel(market),
        style: TextStyles.smallBold.copyWith(fontSize: fontSize, color: color),
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
        style: TextStyles.smallBold.copyWith(
          fontSize: fontSize,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
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
  final Color? selectionColor;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
    this.color,
    this.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? selectionColor?.withValues(alpha: .12) ??
                    AppColors.surfaceElevated
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected && selectionColor != null
                ? selectionColor!.withValues(alpha: .35)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyles.bodySmall.copyWith(
                color:
                    color ??
                    (selected && selectionColor != null
                        ? selectionColor
                        : selected
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
          Text(label, style: TextStyles.caption),
          const SizedBox(height: 6),
          Text(value, style: TextStyles.valueLarge.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

/// 股票、资产与数字币顶部共用的汇总卡片。
class SummaryCardFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? borderColor;
  const SummaryCardFrame({
    super.key,
    required this.child,
    this.margin,
    this.gradient,
    this.borderColor,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppColors.summaryCardShadow,
      border: Border.all(color: borderColor ?? AppColors.border, width: .5),
    ),
    child: child,
  );
}

/// 顶部汇总卡片共用的刷新反馈，与数字币同步进度保持一致。
class SummaryRefreshIndicator extends StatelessWidget {
  final Color color;

  const SummaryRefreshIndicator({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: LinearProgressIndicator(color: color),
  );
}

/// 股票和资产汇总卡片的主题色，浅色保留清晰边界，深色避免纯黑卡片单调。
class SummaryCardPalette {
  SummaryCardPalette._();

  static Gradient get stockGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xFF1B2940), Color(0xFF151E2D), Color(0xFF142B31)]
        : const [Color(0xFFEEF5FF), Color(0xFFF8FAFF), Color(0xFFF0FAFC)],
  );

  static Gradient get assetGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xFF30271D), Color(0xFF222530), Color(0xFF192A2A)]
        : const [Color(0xFFFFF5E9), Color(0xFFF9FAFD), Color(0xFFF0FAF7)],
  );

  static Color get stockBorder =>
      AppColors.accent.withValues(alpha: AppColors.isDark ? .28 : .20);

  static Color get assetBorder =>
      AppColors.warning.withValues(alpha: AppColors.isDark ? .28 : .20);
}
