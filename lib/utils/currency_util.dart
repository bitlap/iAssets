import 'package:assets/config/app_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/utils/market_util.dart';
import '../services/exchange_rate_service.dart';

/// 货币格式化与转换工具（数据源来自 ExchangeRateService）
class CurrencyUtil {
  /// 获取货币符号
  static String getSymbol(String currency) {
    switch (currency) {
      case 'CNY':
        return '¥';
      case 'CNH':
        return '¥';
      case 'USD':
        return '\$';
      case 'HKD':
        return 'HK\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency;
    }
  }

  /// 格式化价格显示（统一4位小数）
  static String formatRate(double rate) {
    return rate.toStringAsFixed(4);
  }

  /// 紧凑格式化（简体中文超 100 万显示“万/亿”，其他语言用 K/M/B 缩写）
  static String formatCompact(
    double value, {
    String Function(double)? formatBase,
  }) {
    final fmt = formatBase ?? (v) => v.toStringAsFixed(2);
    final fmtAbbr = formatBase ?? _fmtAbbr;
    if (L10n.currentLang == L10n.langZh) {
      if (value.abs() >= 100000000) {
        return '${fmtAbbr(value / 100000000)}${AppConfig.suffixYi}';
      }
      if (value.abs() >= 1000000) {
        return '${fmtAbbr(value / 10000)}${AppConfig.suffixWan}';
      }
      return fmt(value);
    }
    if (value.abs() >= 1000000000) {
      return '${fmtAbbr(value / 1000000000)}B';
    }
    if (value.abs() >= 1000000) {
      return '${fmtAbbr(value / 1000000)}M';
    }
    if (value.abs() >= 100000) {
      return '${fmtAbbr(value / 1000)}K';
    }
    return fmt(value);
  }

  /// 美式缩写数值格式：最多 2 位小数并去除尾随零（300.00K → 300K，1.50M → 1.5M）
  static String _fmtAbbr(double v) {
    final s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) {
      return s.substring(0, s.length - 3);
    }
    if (s.endsWith('0')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 根据市场类型返回对应币种
  static String currencyForMarket(String marketType) =>
      MarketUtil.currencyForMarket(marketType);

  /// 将金额从源币种转换为目标币种（以 USD 为中间货币）
  static double convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) {
    final rates = ExchangeRateService().effectiveRates;
    final fromRate = rates[fromCurrency] ?? 1.0;
    final toRate = rates[toCurrency] ?? 1.0;
    final amountInUSD = amount / fromRate;
    return amountInUSD * toRate;
  }
}
