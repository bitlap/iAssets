import 'package:flutter/material.dart';

/// APP 统一语义颜色系统。
///
/// 页面继续通过语义名称取色，主题切换时由 [applyBrightness] 一次性更新，
/// 避免在业务组件中散落明暗主题判断。
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.dark;
  static bool _redUpGreenDown = true;
  static final ValueNotifier<bool> marketColorNotifier = ValueNotifier(true);

  static bool get isDark => _brightness == Brightness.dark;

  static void applyBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get redUpGreenDown => _redUpGreenDown;

  static void applyMarketColorPreference(bool value) {
    _redUpGreenDown = value;
    marketColorNotifier.value = value;
  }

  // 基础表面
  static Color get surface =>
      isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  static Color get surfaceMuted =>
      isDark ? const Color(0xFF111216) : const Color(0xFFF2F2F7);

  // 边框
  static Color get border =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFD1D1D6);

  // 文字
  static Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  static Color get textSecondary =>
      isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  static Color get textTertiary =>
      isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93);

  // 图标
  static Color get iconMuted =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);
  static Color get switchInactiveTrack =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
  static Color get switchInactiveThumb =>
      isDark ? const Color(0xFF8E8E93) : const Color(0xFFFFFFFF);

  // 功能色
  static Color get accent =>
      isDark ? const Color(0xFF5B9CF6) : const Color(0xFF007AFF);
  static const Color onAccent = Colors.white;
  static const Color warning = Color(0xFFFF9F0A);
  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFFF3B30);
  static Color get rise => redUpGreenDown ? danger : success;
  static Color get fall => redUpGreenDown ? success : danger;

  // 市场色
  static const Color marketUS = Color(0xFFFF3B30);
  static const Color marketHK = Color(0xFF34C759);
  static const Color marketA = Color(0xFFFF9500);

  // 资产分类色
  static const Color cyan = Color(0xFF5AC8FA);
  static const Color purple = Color(0xFFAF52DE);

  // 业务专用色
  static const Color blueDark = Color(0xFF1A56DB);
  static const Color blueAccent = Color(0xFF2962FF);
  static const Color greenAccent = Color(0xFF4CAF50);
  static const Color redAccent = Color(0xFFFF5252);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color amber = Color(0xFFFFC107);
  static Color get grey =>
      isDark ? const Color(0xFF9E9E9E) : const Color(0xFF636366);
  static Color get grey600 =>
      isDark ? const Color(0xFF757575) : const Color(0xFF8E8E93);
  static Color get grey500 =>
      isDark ? const Color(0xFF9E9E9E) : const Color(0xFF636366);
  static Color get grey400 =>
      isDark ? const Color(0xFFBDBDBD) : const Color(0xFF48484A);

  // 分割线/背景
  static Color get separator =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);
  static Color get tertiaryBg =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
  static Color get toastBg =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  static Color get toastBorder =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6);
  static List<BoxShadow> get toastShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// 顶部资产卡片阴影。浅色模式使用轻量阴影，避免白色卡片出现大面积灰边。
  static List<BoxShadow> get summaryCardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.08),
      blurRadius: isDark ? 20 : 12,
      offset: Offset(0, isDark ? 8 : 3),
    ),
  ];
}
