import 'dart:io';
import 'package:assets/models/asset_account.dart';
import 'package:assets/utils/asset_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));

  test(
    'deposit interest is prorated by months and crosses year boundaries',
    () {
      final deposit = TimeDeposit(
        id: 'd',
        principal: 12000,
        annualRate: 3,
        startDate: DateTime(2025, 10, 15),
        durationMonths: 6,
      );
      expect(deposit.interest, 180);
      expect(deposit.totalValue, 12180);
      expect(deposit.endDate, DateTime(2026, 4, 15));
    },
  );
  test('zero term and zero rate do not generate interest', () {
    expect(
      TimeDeposit(
        id: 'd',
        principal: 1000,
        annualRate: 3,
        durationMonths: 0,
      ).interest,
      0,
    );
    expect(
      TimeDeposit(id: 'd', principal: 1000, annualRate: 0).totalValue,
      1000,
    );
  });
  test('wealth product multiplies fractional shares and NAV', () {
    expect(
      WealthProduct(id: 'w', shares: 123.45, nav: 1.2345).totalValue,
      closeTo(152.399025, 1e-10),
    );
    expect(WealthProduct(id: 'w', shares: 0, nav: 2).totalValue, 0);
  });

  List<AssetBase> assets() => [
    CashAccount(id: 'cash', balance: 100, currency: 'USD'),
    CurrentAccount(id: 'current', balance: 700, currency: 'CNY'),
    ProvidentFundAccount(id: 'fund', balance: 800, currency: 'HKD'),
    TimeDeposit(
      id: 'deposit',
      principal: 100,
      annualRate: 12,
      durationMonths: 6,
      currency: 'USD',
    ),
    WealthProduct(id: 'wealth', shares: 50, nav: 2, currency: 'USD'),
  ];
  test('every asset class uses its appropriate value before conversion', () {
    final expected = [100.0, 100.0, 100.0, 106.0, 100.0];
    for (var i = 0; i < expected.length; i++) {
      expect(AssetCalculator.getAssetValue(assets()[i], 'USD'), expected[i]);
    }
  });
  test('combined total counts stocks and crypto once in target currency', () {
    expect(
      AssetCalculator.calculateTotalAssets(
        assets(),
        200,
        'USD',
        cryptoTotalValue: 300,
      ),
      1006,
    );
    expect(AssetCalculator.calculateTotalAssets([], 200, 'USD'), 200);
    expect(AssetCalculator.calculateTotalAssets([], 0, 'USD'), 0);
  });
  test('type totals merge matching categories after currency conversion', () {
    final items = assets()
      ..add(CashAccount(id: 'cash2', balance: 700, currency: 'CNY'));
    expect(AssetCalculator.getTotalByType(items, 'USD'), {
      AssetType.cash: 200.0,
      AssetType.current: 100.0,
      AssetType.providentFund: 100.0,
      AssetType.timeDeposit: 106.0,
      AssetType.wealthProduct: 100.0,
    });
    expect(AssetCalculator.getTotalByType([], 'USD'), isEmpty);
  });
  test('negative cash balances reduce total assets', () {
    expect(
      AssetCalculator.calculateTotalAssets(
        [CashAccount(id: 'debt', balance: -700, currency: 'CNY')],
        50,
        'USD',
      ),
      -50,
    );
  });
  test(
    'amount sorting compares converted value and leaves source unchanged',
    () {
      final items = [
        CashAccount(id: 'a', balance: 700, currency: 'CNY'),
        CashAccount(id: 'b', balance: 200, currency: 'USD'),
      ];
      expect(
        AssetCalculator.sortAssets(
          items,
          'amount',
          false,
          'USD',
        ).map((a) => a.id),
        ['b', 'a'],
      );
      expect(
        AssetCalculator.sortAssets(
          items,
          'amount',
          true,
          'USD',
        ).map((a) => a.id),
        ['a', 'b'],
      );
      expect(items.map((a) => a.id), ['a', 'b']);
    },
  );
  test('name sorting and manual order keep their documented behavior', () {
    final items = [
      CashAccount(id: 'a', name: 'Z'),
      CashAccount(id: 'b', name: 'A'),
    ];
    expect(
      AssetCalculator.sortAssets(items, 'name', true, 'USD').first.id,
      'b',
    );
    expect(
      AssetCalculator.sortAssets(items, 'name', false, 'USD').first.id,
      'a',
    );
    expect(
      AssetCalculator.sortAssets(items, null, false, 'USD').map((a) => a.id),
      ['a', 'b'],
    );
  });
}
