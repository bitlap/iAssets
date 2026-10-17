import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/crypto/crypto_models.dart';

/// 数字币分类配色；浅色使用较深前景，深色使用较亮前景。
class CryptoStyle {
  CryptoStyle._();
  static Color get lead =>
      AppColors.isDark ? const Color(0xFFC4A5FF) : const Color(0xFF7542BC);
  static Color get futures => AppColors.accent;
  static Color get spot =>
      AppColors.isDark ? const Color(0xFF54DCC5) : const Color(0xFF087F72);
  static Color get caution =>
      AppColors.isDark ? AppColors.warning : const Color(0xFF8A5700);
  static Color get panelBorder =>
      AppColors.isDark ? const Color(0xFF2A2D39) : AppColors.border;
  static Color get panel =>
      AppColors.isDark ? const Color(0xFF15171F) : AppColors.surface;
  static Color tint(Color color) =>
      color.withValues(alpha: AppColors.isDark ? .13 : .07);
  static Color border(Color color) =>
      color.withValues(alpha: AppColors.isDark ? .28 : .18);
  static Color category(CryptoWalletKind kind) => switch (kind) {
    CryptoWalletKind.lead => lead,
    CryptoWalletKind.futures => futures,
    CryptoWalletKind.spot => spot,
    _ => futures,
  };
  static IconData icon(CryptoWalletKind kind) => switch (kind) {
    CryptoWalletKind.lead => Icons.groups_outlined,
    CryptoWalletKind.futures => Icons.show_chart,
    CryptoWalletKind.spot => Icons.currency_bitcoin,
    _ => Icons.account_balance_wallet_outlined,
  };
  static Gradient get summaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xFF262139), Color(0xFF171F2C), Color(0xFF132622)]
        : const [Color(0xFFF4EEFF), Color(0xFFF4F8FF), Color(0xFFEFFAF7)],
  );
}
