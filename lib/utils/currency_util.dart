import 'package:assets/config/app_config.dart';
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

  /// 紧凑格式化（超过100万显示“万”单位）
  static String formatCompact(
    double value, {
    String Function(double)? formatBase,
  }) {
    final fmt = formatBase ?? (v) => v.toStringAsFixed(2);
    if (value.abs() >= 100000000) {
      return '${fmt(value / 100000000)}${AppConfig.suffixYi}';
    }
    if (value.abs() >= 1000000) {
      return '${fmt(value / 10000)}${AppConfig.suffixWan}';
    }
    return fmt(value);
  }

  /// 根据市场类型返回对应币种
  static String currencyForMarket(String marketType) =>
      AppConfig.currencyForMarket(marketType);

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
