import 'dart:convert';
import 'dart:io';

import 'package:assets/services/exchange_rate_service.dart';
import 'package:assets/utils/currency_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing, stale, failed, and live FX never invent a 1:1 rate', () async {
    final dir = Directory.systemTemp.createTempSync('iassets-fx-status-');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    final service = ExchangeRateService();
    await Future<void>.delayed(Duration.zero);

    expect(service.freshness, ExchangeRateFreshness.missing);
    expect(service.lastUpdatedAt, isNull);
    expect(CurrencyUtil.tryConvertCurrency(10, 'EUR', 'USD'), isNull);
    expect(CurrencyUtil.convertCurrency(10, 'EUR', 'USD').isNaN, isTrue);
    expect(CurrencyUtil.convertCurrency(10, 'EUR', 'EUR'), 10);
    expect(CurrencyUtil.convertCurrency(0, 'EUR', 'USD'), 0);

    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    final savedRecently = DateTime.now().subtract(const Duration(hours: 1));
    File('${dir.path}/exchange_rates.json').writeAsStringSync(
      jsonEncode({
        'USD': 1,
        'CNY': 7,
        '_savedAt': savedRecently.millisecondsSinceEpoch,
        '_sourceUpdatedAt': yesterday.millisecondsSinceEpoch,
      }),
    );
    expect(service.freshness, ExchangeRateFreshness.stale);
    expect(
      service.lastUpdatedAt?.millisecondsSinceEpoch,
      yesterday.millisecondsSinceEpoch,
    );
    expect(CurrencyUtil.convertCurrency(10, 'USD', 'CNY'), 70);
    expect(CurrencyUtil.tryConvertCurrency(10, 'EUR', 'USD'), isNull);

    var fetchAttempts = 0;
    await http.runWithClient(
      () => service.fetchRates(),
      () => MockClient((_) async {
        fetchAttempts++;
        return http.Response('{bad json', 200);
      }),
    );
    expect(fetchAttempts, 1);
    expect(service.freshness, ExchangeRateFreshness.stale);
    expect(CurrencyUtil.convertCurrency(10, 'USD', 'CNY'), 70);

    await http.runWithClient(
      () => service.fetchRates(),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'result': 'success',
            'time_last_update_unix':
                DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'rates': {'USD': 1, 'CNY': 7.2, 'GBP': .8},
          }),
          200,
        ),
      ),
    );
    expect(service.freshness, ExchangeRateFreshness.live);
    expect(CurrencyUtil.convertCurrency(10, 'USD', 'CNY'), closeTo(72, 1e-9));
    expect(CurrencyUtil.tryConvertCurrency(10, 'EUR', 'USD'), isNull);
    expect(CurrencyUtil.convertCurrency(100, 'GBp', 'GBP'), 1);
  });
}
