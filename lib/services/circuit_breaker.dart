import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class CircuitBreaker {
  CircuitBreaker({this.source = '网络'});
  final String source;

  static final stockSearch = CircuitBreaker(source: '股票搜索');
  static final tencent = CircuitBreaker(source: '腾讯行情');
  static final eastMoney = CircuitBreaker(source: '东方财富行情');
  static final yahoo = CircuitBreaker(source: 'Yahoo行情');

  int _consecutiveFailures = 0;
  DateTime? _cooldownUntil;
  static const int _failureThreshold = AppConfig.failureThreshold;
  static const Duration _cooldownDuration = Duration(
    minutes: AppConfig.cooldownDurationMin,
  );

  bool get isInCooldown {
    if (_cooldownUntil == null) return false;
    if (DateTime.now().isAfter(_cooldownUntil!)) {
      _cooldownUntil = null;
      _consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  int get cooldownRemainingSeconds {
    if (_cooldownUntil == null) return 0;
    final remaining = _cooldownUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void onSuccess() {
    _consecutiveFailures = 0;
    _cooldownUntil = null;
  }

  void onFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _failureThreshold) {
      _cooldownUntil = DateTime.now().add(_cooldownDuration);
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][$source] ===> 连续失败$_consecutiveFailures次，进入冷却期${_cooldownDuration.inMinutes}分钟',
      );
    } else {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][$source] ===> 请求失败 ($_consecutiveFailures/$_failureThreshold)',
      );
    }
  }
}
