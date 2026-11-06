import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

enum ExchangeRateFreshness { live, cached, stale, missing }

/// 汇率服务 - 只使用接口或此前成功获取的缓存，不使用固定估算汇率。
class ExchangeRateService extends ChangeNotifier {
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
  };

  /// 汇率缓存
  Map<String, double>? _cachedRates;
  DateTime? _lastFetchTime;
  DateTime? _sourceUpdatedAt;
  bool _fromNetwork = false;
  Future<Map<String, double>?>? _pendingFetch;
  static const Duration _cacheTTL = Duration(
    minutes: AppConfig.exchangeRateCacheTTLMin,
  );
  // 数据源在每日更新时间刚过时，仍可能返回昨日快照。
  // 对已过期的源数据进行重试，避免每分钟都请求。
  static const Duration _staleSourceRetryInterval = Duration(minutes: 5);

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
      return _parseStoredRates(data);
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
      _cachedRates = _parseStoredRates(data);
      if (_cachedRates == null) return;
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 从文件恢复: ${_cachedRates!.length}种币种',
      );
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 文件恢复失败: $e',
      );
    }
  }

  Map<String, double>? _parseStoredRates(Map<String, dynamic> data) {
    final savedAt = data['_savedAt'];
    final sourceAt = data['_sourceUpdatedAt'];
    _lastFetchTime = savedAt is num
        ? DateTime.fromMillisecondsSinceEpoch(savedAt.toInt())
        : null;
    _sourceUpdatedAt = sourceAt is num
        ? DateTime.fromMillisecondsSinceEpoch(sourceAt.toInt())
        : _lastFetchTime;
    _fromNetwork = false;
    final rates = _validatedRates(data);
    return rates.length > 1 ? rates : null;
  }

  static Map<String, double> _validatedRates(Map<String, dynamic> data) {
    final rates = <String, double>{'USD': 1};
    for (final currency in supportedCurrencies) {
      if (currency == 'USD') continue;
      final raw = data[currency];
      if (raw is! num) continue;
      final rate = raw.toDouble();
      if (rate.isFinite && rate > 0) rates[currency] = rate;
    }
    return rates;
  }

  /// 将成功获取的汇率保存到文件
  Future<void> _saveToFile() async {
    if (_cachedRates == null) return;
    try {
      final path = await _getPath();
      final data = Map<String, dynamic>.from(_cachedRates!);
      data['_savedAt'] = _lastFetchTime?.millisecondsSinceEpoch;
      data['_sourceUpdatedAt'] = _sourceUpdatedAt?.millisecondsSinceEpoch;
      final file = File('$path/$_fileName');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 文件保存失败: $e',
      );
    }
  }

  /// 可用汇率：实时汇率或文件缓存；USD 自身及便士单位换算是精确关系。
  Map<String, double> get effectiveRates {
    if (_cachedRates == null) {
      final fileRates = _loadFromFileSync();
      if (fileRates != null) {
        _cachedRates = fileRates;
      } else {
        return {'USD': 1};
      }
    }
    final merged = Map<String, double>.from(_cachedRates!);
    // 仅兼容此前以便士保存的记录，不将这些单位列入货币选择。
    if (merged['GBP'] case final gbp?) {
      merged['GBp'] = gbp * 100;
      merged['GBX'] = gbp * 100;
    }
    return merged;
  }

  ExchangeRateFreshness get freshness {
    if (effectiveRates.length <= 1) return ExchangeRateFreshness.missing;
    if (_lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) >= _cacheTTL ||
        (_sourceUpdatedAt != null &&
            DateTime.now().difference(_sourceUpdatedAt!) >= _cacheTTL)) {
      return ExchangeRateFreshness.stale;
    }
    return _fromNetwork
        ? ExchangeRateFreshness.live
        : ExchangeRateFreshness.cached;
  }

  DateTime? get lastUpdatedAt {
    effectiveRates;
    return _sourceUpdatedAt;
  }

  /// 是否已有有效缓存
  bool get hasValidCache {
    if (_cachedRates == null || _lastFetchTime == null) return false;
    final now = DateTime.now();
    final fetchAge = now.difference(_lastFetchTime!);
    if (fetchAge >= _cacheTTL) return false;
    if (_sourceUpdatedAt != null &&
        now.difference(_sourceUpdatedAt!) >= _cacheTTL) {
      return fetchAge < _staleSourceRetryInterval;
    }
    return true;
  }

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
    return _conversionRate(effectiveRates, from, to);
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
        final data = json.decode(response.body) as Map<String, dynamic>;
        if ((data['result'] != null && data['result'] != 'success') ||
            data['rates'] is! Map) {
          throw const FormatException('Invalid exchange rate response');
        }
        final rates = _validatedRates(
          Map<String, dynamic>.from(data['rates'] as Map),
        );
        if (rates.length <= 1) {
          throw const FormatException('No valid exchange rates');
        }
        _onRequestSuccess();
        _cachedRates = rates;
        _lastFetchTime = DateTime.now();
        final sourceAt = data['time_last_update_unix'];
        _sourceUpdatedAt = sourceAt is num
            ? DateTime.fromMillisecondsSinceEpoch(sourceAt.toInt() * 1000)
            : _lastFetchTime;
        _fromNetwork = true;
        await _saveToFile();
        notifyListeners();
        debugPrint(
          '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 更新成功: USD=${rates['USD']}, CNY=${rates['CNY']}, HKD=${rates['HKD']}',
        );
        return rates;
      }
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> HTTP ${response.statusCode}',
      );
      _onRequestFailure();
      notifyListeners();
      return _cachedRates;
    } catch (e) {
      client?.close();
      debugPrint(
        '[${DateTime.now().toString().substring(11, 19)}][汇率] ===> 请求失败: $e',
      );
      _onRequestFailure();
      notifyListeners();
      return _cachedRates;
    }
  }
}
