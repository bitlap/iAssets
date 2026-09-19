import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const String system = 'system';
  static const String light = 'light';
  static const String dark = 'dark';

  static final ValueNotifier<String> notifier = ValueNotifier(system);

  static ThemeMode get mode => switch (notifier.value) {
    light => ThemeMode.light,
    dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static void apply(String value) {
    final normalized = switch (value) {
      light => light,
      dark => dark,
      _ => system,
    };
    notifier.value = normalized;
  }

  static ThemeData data(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final surfaceElevated = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF2F2F7);
    final textPrimary = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111111);
    final textSecondary = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF636366);
    final accent = isDark ? const Color(0xFF5B9CF6) : const Color(0xFF007AFF);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surfaceElevated,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        displayLarge: TextStyle(color: textPrimary),
        headlineMedium: TextStyle(color: textPrimary),
        labelLarge: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }
}
