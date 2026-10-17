import 'dart:convert';
import 'package:assets/config/app_config.dart';
import 'package:assets/models/asset_account.dart';
import 'package:assets/services/serde/converters.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/core_fixtures.dart';

List<Map<String, dynamic>> wire(List<Map<String, dynamic>> value) =>
    (jsonDecode(jsonEncode(value)) as List).cast<Map<String, dynamic>>();

void main() {
  test(
    'stock round trip retains custom currency and fractional negative data',
    () {
      final original = stocksToJson([
        stock(
          symbol: 'CUSTOM',
          currency: 'EUR',
          price: 1.23456789,
          shares: .12345678,
          profit: -12.345,
          custom: true,
        ),
      ]);
      final restored = stocksFromJson(wire(original));
      expect(stocksToJson(restored), original);
      expect(restored.single.isCustom, isTrue);
      expect(restored.single.currency, 'EUR');
      expect(restored.single.profitLossAmount, -12.345);
    },
  );
  test(
    'legacy stock infers currency from market and defaults custom to false',
    () {
      final json = stocksToJson([stock()]).single
        ..remove('currency')
        ..remove('isCustom');
      json['marketType'] = '港股';
      final result = stocksFromJson([json]).single;
      expect(result.currency, 'HKD');
      expect(result.isCustom, isFalse);
    },
  );
  test(
    'trade round trip retains fees, timestamps, descriptions and fractions',
    () {
      final original = recordsToJson({
        'TEST': [trade(price: 1.23456789, shares: .12345678, fee: .005)],
        'EMPTY': [],
      });
      final result = recordsFromJson(wire(original));
      expect(recordsToJson(result), original);
      expect(result.keys, ['TEST']);
      expect(
        result['TEST']!.single.operationTime,
        DateTime.utc(2026, 1, 2, 14, 30),
      );
      expect(result['TEST']!.single.fee, .005);
    },
  );
  test('legacy trade uses date as operation timestamp and zero fee', () {
    final json = recordsToJson({
      'TEST': [trade()],
    }).single;
    final record = (json['records'] as List).single as Map;
    record.remove('operationTime');
    record.remove('fee');
    final restored = recordsFromJson([json])['TEST']!.single;
    expect(restored.operationTime, restored.date);
    expect(restored.fee, 0);
  });
  test('dividend round trip retains tax, currency and operation time', () {
    final original = dividendRecordsToJson({
      'TEST': [
        dividend(amount: .12345678, shares: 123, tax: .15, currency: 'HKD'),
      ],
      'EMPTY': [],
    });
    final restored = dividendRecordsFromJson(wire(original));
    expect(dividendRecordsToJson(restored), original);
    expect(restored.keys, ['TEST']);
    expect(
      restored['TEST']!.single.afterTaxAmount,
      closeTo(12.907406349, 1e-9),
    );
  });
  test('legacy dividend defaults tax and currency without changing date', () {
    final json = dividendRecordsToJson({
      'TEST': [dividend()],
    }).single;
    final record = (json['records'] as List).single as Map;
    record.remove('operationTime');
    record.remove('taxRate');
    record.remove('currency');
    final restored = dividendRecordsFromJson([json])['TEST']!.single;
    expect(restored.operationTime, restored.date);
    expect(restored.taxRate, 0);
    expect(restored.currency, AppConfig.defaultCurrency);
  });
  test(
    'all five asset classes retain type, order, dates and computed values',
    () {
      final date = DateTime.utc(2026, 1, 2);
      final assets = <AssetBase>[
        CashAccount(id: 'a', balance: -123.45),
        CurrentAccount(id: 'b', balance: .0001),
        ProvidentFundAccount(id: 'c', balance: 1000),
        TimeDeposit(
          id: 'd',
          principal: 1000,
          annualRate: 3.5,
          durationMonths: 18,
          startDate: date,
        ),
        WealthProduct(id: 'e', shares: 123.45, nav: 1.2345),
      ];
      for (var i = 0; i < assets.length; i++) {
        assets[i]
          ..createdAt = date
          ..updatedAt = date
          ..sortOrder = i
          ..name = '账户 $i'
          ..currency = 'HKD';
      }
      final original = assetsToJson(assets);
      final restored = assetsFromJson(wire(original));
      expect(assetsToJson(restored), original);
      expect(restored.map((a) => a.type), [
        AssetType.cash,
        AssetType.current,
        AssetType.providentFund,
        AssetType.timeDeposit,
        AssetType.wealthProduct,
      ]);
      expect((restored[3] as TimeDeposit).totalValue, 1052.5);
      expect(
        (restored[4] as WealthProduct).totalValue,
        closeTo(152.399025, 1e-9),
      );
    },
  );
  test('legacy assets with minimal metadata load with safe defaults', () {
    final result = AssetBase.fromJson({'id': 'old', 'balance': 10});
    expect(result, isA<CashAccount>());
    expect((result as CashAccount).balance, 10);
    expect(result.sortOrder, 0);
    expect(result.currency, AppConfig.defaultCurrency);
  });
}
