import 'package:flutter/material.dart';

/// APP 统一颜色系统 - 暗色主题
class AppColors {
  AppColors._();

  // 基础表面
  static const Color surface = Color(0xFF000000);
  static const Color surfaceElevated = Color(0xFF2C2C2E);
  static const Color surfaceMuted = Color(0xFF111216);

  // 边框
  static const Color border = Color(0xFF1C1C1E);

  // 文字
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  // 图标
  static const Color iconMuted = Color(0xFF48484A);

  // 功能色
  static const Color accent = Color(0xFF5B9CF6);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color success = Color(0xFF34C759); // 跌
  static const Color danger = Color(0xFFFF3B30); // 涨

  // 市场色
  static const Color marketUS = Color(0xFFFF3B30);
  static const Color marketHK = Color(0xFF34C759);
  static const Color marketA = Color(0xFFFF9500);
}
