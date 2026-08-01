/// 交易日工具：以美股市场（美东时区，含夏令时）为锚定
class TradingDayUtil {
  TradingDayUtil._();

  /// 判断 UTC 时刻是否处于美东夏令时（EDT, UTC-4）
  /// 规则：每年 3 月第二个周日 02:00 → 11 月第一个周日 02:00（美东当地时间）
  static bool isEasternDST(DateTime utc) {
    final dstStart = _nthSunday(utc.year, 3, 2)
        .add(const Duration(hours: 7)); // 02:00 EST = 07:00 UTC
    final dstEnd = _nthSunday(utc.year, 11, 1)
        .add(const Duration(hours: 6)); // 02:00 EDT = 06:00 UTC
    return !utc.isBefore(dstStart) && utc.isBefore(dstEnd);
  }

  /// 将本地时间转换为美东时间（含夏令时）
  static DateTime toEastern(DateTime local) {
    final utc = local.toUtc();
    final offset = isEasternDST(utc) ? -4 : -5;
    return utc.add(Duration(hours: offset));
  }

  /// 交易日日键：以美东时间每天 9:00 为日界线
  /// "当天" = [美东 D-1 9:00, 美东 D 9:00)，覆盖美股开盘（美东 9:30）
  static String tradingDayKey(DateTime local) {
    final et = toEastern(local);
    final shifted = et.subtract(const Duration(hours: 9));
    final y = shifted.year;
    final m = shifted.month.toString().padLeft(2, '0');
    final d = shifted.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 某年某月的第 n 个周日（UTC 当天 0 点）
  static DateTime _nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1);
    final daysUntilSunday = (DateTime.sunday - first.weekday) % 7;
    return first.add(Duration(days: daysUntilSunday + (n - 1) * 7));
  }
}
