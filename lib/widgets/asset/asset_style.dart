import 'package:flutter/material.dart';
import '../common/app_colors.dart';

/// 资产分类颜色；浅色使用较深前景以保持图标和标签清晰。
class AssetStyle {
  AssetStyle._();

  static const Color cyan = Color(0xFF5AC8FA);

  static Color get cash =>
      AppColors.isDark ? const Color(0xFF58D984) : const Color(0xFF18864A);
  static Color get deposit =>
      AppColors.isDark ? const Color(0xFFFFBE55) : const Color(0xFFAE6600);
  static Color get wealth => AppColors.accent;
  static Color get current =>
      AppColors.isDark ? const Color(0xFF69CFF4) : const Color(0xFF087FA9);
  static Color get provident =>
      AppColors.isDark ? const Color(0xFFC598F0) : const Color(0xFF8445AF);
  static Color get crypto => provident;

  /// 固定算法按资产名选色，重启、排序和切换主题不会改变色系。
  static Color nameColor(String name) {
    var hash = 2166136261;
    for (final rune in name.trim().toLowerCase().runes) {
      hash = ((hash ^ rune) * 16777619) & 0xffffffff;
    }
    const light = [
      Color(0xFF4268A2),
      Color(0xFF7C5698),
      Color(0xFF2B7B71),
      Color(0xFF9A663F),
      Color(0xFF8B596D),
      Color(0xFF617C39),
      Color(0xFF546BAA),
      Color(0xFF8E7133),
    ];
    const dark = [
      Color(0xFF8EB0EC),
      Color(0xFFC3A0E2),
      Color(0xFF84C8B9),
      Color(0xFFDBB18A),
      Color(0xFFD8A0BA),
      Color(0xFFB0C586),
      Color(0xFFA7B4E2),
      Color(0xFFDDC583),
    ];
    return (AppColors.isDark ? dark : light)[hash % light.length];
  }

  static Color tint(Color color) =>
      color.withValues(alpha: AppColors.isDark ? .15 : .08);

  static Color border(Color color) =>
      color.withValues(alpha: AppColors.isDark ? .20 : .12);

  static Gradient get summaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xFF30271D), Color(0xFF222530), Color(0xFF192A2A)]
        : const [Color(0xFFFFF5E9), Color(0xFFF9FAFD), Color(0xFFF0FAF7)],
  );

  static Color get summaryBorder =>
      AppColors.warning.withValues(alpha: AppColors.isDark ? .28 : .20);
}
