import '../models/asset_account.dart';
import 'currency_util.dart';

/// 资产计算工具类
class AssetCalculator {
  /// 获取单个资产在目标货币下的价值
  static double getAssetValue(AssetBase asset, String targetCurrency) {
    switch (asset) {
      case CashAccount c:
        return CurrencyUtil.convertCurrency(
          c.balance,
          c.currency,
          targetCurrency,
        );
      case CurrentAccount c:
        return CurrencyUtil.convertCurrency(
          c.balance,
          c.currency,
          targetCurrency,
        );
      case ProvidentFundAccount c:
        return CurrencyUtil.convertCurrency(
          c.balance,
          c.currency,
          targetCurrency,
        );
      case TimeDeposit t:
        return CurrencyUtil.convertCurrency(
          t.totalValue,
          t.currency,
          targetCurrency,
        );
      case WealthProduct w:
        return CurrencyUtil.convertCurrency(
          w.totalValue,
          w.currency,
          targetCurrency,
        );
    }
  }

  /// 计算总资产（含股票市值）
  static double calculateTotalAssets(
    List<AssetBase> assets,
    double stockTotalValue,
    String targetCurrency,
  ) {
    double sum = stockTotalValue;
    for (final a in assets) {
      sum += getAssetValue(a, targetCurrency);
    }
    return sum;
  }

  /// 按类型汇总资产价值
  static Map<AssetType, double> getTotalByType(
    List<AssetBase> assets,
    String targetCurrency,
  ) {
    final totals = <AssetType, double>{};
    for (final a in assets) {
      totals.update(
        a.type,
        (v) => v + getAssetValue(a, targetCurrency),
        ifAbsent: () => getAssetValue(a, targetCurrency),
      );
    }
    return totals;
  }

  /// 排序资产列表
  static List<AssetBase> sortAssets(
    List<AssetBase> source,
    String? sortColumn,
    bool ascending,
    String targetCurrency,
  ) {
    if (sortColumn == null) return source;
    final sorted = List<AssetBase>.from(source);
    sorted.sort((a, b) {
      int cmp;
      switch (sortColumn) {
        case 'name':
          cmp = a.name.compareTo(b.name);
          break;
        case 'amount':
          cmp = getAssetValue(
            a,
            targetCurrency,
          ).compareTo(getAssetValue(b, targetCurrency));
          break;
        default:
          cmp = 0;
      }
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }
}
