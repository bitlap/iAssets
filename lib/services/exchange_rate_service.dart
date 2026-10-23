import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

/// 汇率服务 - 使用免费 API 获取实时汇率
/// 单例模式，带缓存和熔断机制
class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  factory ExchangeRateService() => _instance;
  ExchangeRateService._internal() {
    getApplicationDocumentsDirectory().then((dir) => _docPath = dir.path);
  }

  static const String _apiUrl = 'https://open.er-api.com/v6/latest/USD';
  static const String _fileName = 'exchange_rates.json';

  /// 支持的币种列表
  static const Set<String> supportedCurrencies = {
    'CNY',
    'CNH',
    'USD',
    'HKD',
    'EUR',
    'JPY',
    'GBP',
    'AUD',
    'CAD',
    'CHF',
    'KRW',
    'SGD',
    'SEK',
    'NOK',
    'DKK',
    'PLN',
    'CZK',
    'HUF',
    'NZD',
    'ZAR',
    'ILS',
    'MXN',
    'TRY',
    'GBp',
    'GBX',
  };

  /// 默认汇率（实时汇率取不到时的回退值）
  static const Map<String, double> defaultRates = {
    'CNY': 6.77,
    'CNH': 6.77,
    'USD': 1.0,
    'HKD': 7.78,
    'EUR': 0.92,
    'JPY': 149.0,
    'GBP': 0.79,
    'AUD': 1.52,
    'CAD': 1.36,
    'CHF': 0.88,
    'KRW': 1320.0,
    'SGD': 1.34,
    'SEK': 9.910213,
    'NOK': 9.343987,
    'DKK': 6.66782,
    'PLN': 3.899348,
    'CZK': 21.634943,
    'HUF': 326.19222,
    'NZD': 1.759591,
    'ZAR': 16.495348,
    'ILS': 3.110654,
    'MXN': 18.733975,
    'TRY': 49.680228,
    'GBp': 79.0,
    'GBX': 79.0,
  };

  /// 汇率缓存
  Map<String, double>? _cachedRates;
  DateTime? _lastFetchTime;
  Future<Map<String, double>?>? _pendingFetch;
  static const Duration _cacheTTL = Duration(
    minutes: AppConfig.exchangeRateCacheTTLMin,
  );

  /// 熔断机制（与股票服务独立，互不影响）
  int _consecutiveFailures = 0;
  DateTime? _cooldownUntil;
  static const int _failureThreshold = AppConfig.failureThreshold;
  static const Duration _cooldownDuration = Duration(
    minutes: AppConfig.cooldownDurationMin,
  );

  bool get _isInCooldown {
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

  void _onRequestSuccess() {
    _consecutiveFailures = 0;
    _cooldownUntil = null;
  }

  void _onRequestFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _failureThreshold) {
      _cooldownUntil = DateTime.now().add(_cooldownDuration);
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 连续失败$_consecutiveFailures次，进入冷却期${_cooldownDuration.inMinutes}分钟',
      );
    } else {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 请求失败 ($_consecutiveFailures/$_failureThreshold)',
      );
    }
  }

  static String? _docPath;

  static String? get _syncDocPath => _docPath;

  Future<String> _getPath() async {
    if (_docPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _docPath = dir.path;
    }
    return _docPath!;
  }

  /// 从文件同步加载（供 effectiveRates 冷启动兜底）
  Map<String, double>? _loadFromFileSync() {
    final path = _syncDocPath;
    if (path == null) return null;
    try {
      final file = File('$path/$_fileName');
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 文件同步读取失败: $e',
      );
      return null;
    }
  }

  /// 从文件异步加载（用于 fetchRates 正常流程）
  Future<void> _loadFromFile() async {
    try {
      final path = await _getPath();
      final file = File('$path/$_fileName');
      if (!await file.exists()) return;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _cachedRates = data.map((k, v) => MapEntry(k, (v as num).toDouble()));
      _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(
        _cachedRates!.remove('_savedAt')?.toInt() ?? 0,
      );
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 从文件恢复: ${_cachedRates!.length}种币种',
      );
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 文件恢复失败: $e',
      );
    }
  }

  /// 将成功获取的汇率保存到文件
  Future<void> _saveToFile() async {
    if (_cachedRates == null) return;
    try {
      final path = await _getPath();
      final data = Map<String, dynamic>.from(_cachedRates!);
      data['_savedAt'] = DateTime.now().millisecondsSinceEpoch;
      final file = File('$path/$_fileName');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 文件保存失败: $e',
      );
    }
  }

  /// 有效汇率：实时汇率 → 文件缓存 → 默认值
  Map<String, double> get effectiveRates {
    if (_cachedRates == null) {
      final fileRates = _loadFromFileSync();
      if (fileRates != null) {
        _cachedRates = fileRates;
      } else {
        return Map.from(defaultRates);
      }
    }
    final merged = Map<String, double>.from(defaultRates);
    for (final c in supportedCurrencies) {
      if (_cachedRates!.containsKey(c)) merged[c] = _cachedRates![c]!;
    }
    // 报价便士保持原单位；只在资产汇总或用户切换货币时按 100:1 换算。
    merged['GBp'] = merged['GBP']! * 100;
    merged['GBX'] = merged['GBP']! * 100;
    return merged;
  }

  /// 是否已有有效缓存
  bool get hasValidCache =>
      _cachedRates != null &&
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheTTL;

  /// 获取实时汇率，返回各币种对 USD 的汇率
  /// 1 USD = X 目标货币
  Future<Map<String, double>?> fetchRates() {
    return _pendingFetch ??= _fetchRates().whenComplete(
      () => _pendingFetch = null,
    );
  }

  /// 只使用接口或其缓存中的汇率，不能把缺失币种当作 1:1 换算。
  Future<double?> conversionRate(String from, String to) async {
    if (from == to) return 1;
    final rates = await fetchRates();
    return _conversionRate(rates, from, to);
  }

  /// 用于同步更新旧持仓；没有真实汇率就保留原价格，避免重解释历史成本。
  double? cachedConversionRate(String from, String to) {
    if (from == to) return 1;
    _cachedRates ??= _loadFromFileSync();
    return _conversionRate(_cachedRates, from, to);
  }

  static double? _conversionRate(
    Map<String, double>? rates,
    String from,
    String to,
  ) {
    // GBP 与 GBp/GBX 之间是单位关系，不依赖网络汇率。
    String base(String code) => code == 'GBp' || code == 'GBX' ? 'GBP' : code;
    double units(String code) => code == 'GBp' || code == 'GBX' ? 100 : 1;
    if (base(from) == base(to)) return units(to) / units(from);
    double? unitRate(String code) {
      final value = rates?[base(code)];
      return value == null ? null : value * units(code);
    }

    final source = unitRate(from);
    final target = unitRate(to);
    if (source == null ||
        target == null ||
        !source.isFinite ||
        !target.isFinite ||
        source <= 0 ||
        target <= 0) {
      return null;
    }
    final rate = target / source;
    return rate.isFinite && rate > 0 ? rate : null;
  }

  Future<Map<String, double>?> _fetchRates() async {
    // 内存缓存有效，直接返回
    if (hasValidCache) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 内存缓存有效，跳过请求',
      );
      return _cachedRates;
    }

    // 冷启动：从文件恢复上次成功获取的汇率
    if (_cachedRates == null) await _loadFromFile();

    // 熔断中，返回已有缓存（内存或文件恢复）
    if (_isInCooldown) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 冷却期中，跳过请求 (剩余$cooldownRemainingSeconds秒)',
      );
      return _cachedRates;
    }

    debugPrint(
      '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 开始请求汇率...',
    );
    Client? client;
    try {
      client = Client();
      final response = await client
          .get(Uri.parse(_apiUrl))
          .timeout(Duration(seconds: AppConfig.httpTimeoutSec));
      client.close();
      client = null;

      if (response.statusCode == 200) {
        _onRequestSuccess();
        final data = json.decode(response.body);
        final rates = <String, double>{};
        final rawRates = data['rates'] as Map<String, dynamic>;

        for (final entry in rawRates.entries) {
          rates[entry.key] = (entry.value as num).toDouble();
        }

        _cachedRates = rates;
        _lastFetchTime = DateTime.now();
        await _saveToFile();
        debugPrint(
          '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 更新成功: USD=${rates['USD']}, CNY=${rates['CNY']}, HKD=${rates['HKD']}',
        );
        return rates;
      }
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> HTTP ${response.statusCode}',
      );
      return _cachedRates;
    } catch (e) {
      client?.close();
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 请求失败: $e',
      );
      _onRequestFailure();
      return _cachedRates;
    }
  }
}
