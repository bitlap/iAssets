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
