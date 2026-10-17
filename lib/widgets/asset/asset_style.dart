import 'package:flutter/material.dart';
import '../../config/app_colors.dart';

/// 资产分类颜色；浅色使用较深前景以保持图标和标签清晰。
class AssetStyle {
  AssetStyle._();

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
}
