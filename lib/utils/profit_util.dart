import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'currency_util.dart';

/// 涨跌显示工具：红涨绿跌，零值灰显
class ProfitUtil {
  static const double _zeroThreshold = 0.0001;

  /// 是否约等于零
  static bool isZero(double value) => value.abs() < _zeroThreshold;

  /// 涨跌颜色：正红 / 负绿 / 零灰
  static Color colorOf(double value) {
    if (isZero(value)) return AppColors.textTertiary;
    return value > 0 ? AppColors.danger : AppColors.success;
  }

  /// 涨跌符号：正 "+" / 负 "-" / 零 ""
  static String signOf(double value) {
    if (isZero(value)) return '';
    return value > 0 ? '+' : '-';
  }

  /// 带符号的金额（+123.45）
  static String amount(double value) =>
      '${signOf(value)}${CurrencyUtil.formatCompact(value.abs())}';

  /// 带符号的百分比（+1.23%）
  static String percent(double value, {int digits = 2}) =>
      '${signOf(value)}${value.abs().toStringAsFixed(digits)}%';
}
