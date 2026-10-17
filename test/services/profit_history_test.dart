import 'dart:io';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/icloud_storage.dart';
import 'package:assets/services/serde/file_io.dart';
import 'package:assets/utils/trading_day_util.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/core_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async => dir = await initializeTestStorage());
  tearDownAll(() => dir.deleteSync(recursive: true));
  setUp(() {
    for (final file in dir.listSync()) {
      if (!file.path.endsWith('exchange_rates.json')) {
        file.deleteSync(recursive: true);
      }
    }
  });
  test(
    'daily and intraday histories round trip and convert without rewriting source',
    () async {
      final time = DateTime.utc(2026, 1, 2, 12);
      final snapshots = [ProfitSnapshot(time: time, totalProfit: -12.5)];
      await IcloudStorage.saveDailyProfitHistory(snapshots);
      await IcloudStorage.saveIntradayProfitHistory(snapshots);
      final daily = await IcloudStorage.loadDailyProfitHistory(
        targetCurrency: 'HKD',
      );
      final intraday = await IcloudStorage.loadIntradayProfitHistory(
        targetCurrency: 'CNY',
      );
      expect(daily.single.time, time);
      expect(daily.single.totalProfit, -100);
      expect(intraday.single.totalProfit, -87.5);
      expect(
        (await IcloudStorage.loadDailyProfitHistory()).single.totalProfit,
        -12.5,
      );
      expect(
        (await IcloudStorage.loadIntradayProfitHistory()).single.totalProfit,
        -12.5,
      );
    },
  );
  test(
    'same value within ten minutes does not duplicate snapshot or reset baseline',
    () async {
      await IcloudStorage.recordProfitIfNeeded(700, 'CNY');
      await IcloudStorage.recordProfitIfNeeded(800, 'HKD');
      expect((await IcloudStorage.loadIntradayProfitHistory()).length, 1);
      expect(
        (await IcloudStorage.loadIntradayProfitHistory()).single.totalProfit,
        100,
      );
      expect(await IcloudStorage.loadTodayBaseline(), (
        TradingDayUtil.tradingDayKey(DateTime.now()),
        100.0,
      ));
      await IcloudStorage.recordProfitIfNeeded(120, 'USD');
      expect(
        (await IcloudStorage.loadIntradayProfitHistory()).map(
          (s) => s.totalProfit,
        ),
        [100.0, 120.0],
      );
      expect((await IcloudStorage.loadTodayBaseline())!.$2, 100);
    },
  );
  test('same value after ten minutes creates a new snapshot', () async {
    await IcloudStorage.saveIntradayProfitHistory([
      ProfitSnapshot(
        time: DateTime.now().subtract(const Duration(minutes: 11)),
        totalProfit: 100,
      ),
    ]);
    await IcloudStorage.recordProfitIfNeeded(100, 'USD');
    // Both instants are in the same trading day unless this runs across 9 AM ET.
    final intraday = await IcloudStorage.loadIntradayProfitHistory();
    final daily = await IcloudStorage.loadDailyProfitHistory();
    expect(intraday.length + daily.length, 2);
    expect(intraday.last.totalProfit, 100);
  });
  test(
    'new trading day archives only the last intraday value and updates baseline',
    () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 2));
      await IcloudStorage.saveDailyProfitHistory([
        ProfitSnapshot(
          time: now.subtract(const Duration(days: 400)),
          totalProfit: 1,
        ),
      ]);
      await IcloudStorage.saveIntradayProfitHistory([
        ProfitSnapshot(
          time: yesterday.subtract(const Duration(minutes: 10)),
          totalProfit: 10,
        ),
        ProfitSnapshot(time: yesterday, totalProfit: 20),
      ]);
      await IcloudStorage.saveTodayBaseline('old-day', 5);
      await IcloudStorage.recordProfitIfNeeded(30, 'USD');
      final daily = await IcloudStorage.loadDailyProfitHistory();
      expect(daily.length, 1);
      expect(daily.single.time, yesterday);
      expect(daily.single.totalProfit, 20);
      final intraday = await IcloudStorage.loadIntradayProfitHistory();
      expect(intraday.length, 1);
      expect(intraday.single.totalProfit, 30);
      expect(await IcloudStorage.loadTodayBaseline(), (
        TradingDayUtil.tradingDayKey(now),
        30.0,
      ));
    },
  );
  test('missing and corrupt baseline returns null', () async {
    expect(await IcloudStorage.loadTodayBaseline(), isNull);
    File('${dir.path}/today_baseline.json').writeAsStringSync('{bad json');
    expect(await IcloudStorage.loadTodayBaseline(), isNull);
    File('${dir.path}/today_baseline.json').writeAsStringSync('{"day":123}');
    expect(await IcloudStorage.loadTodayBaseline(), isNull);
  });
  test(
    'missing, malformed or wrong-root JSON files degrade to empty lists',
    () async {
      expect(await readJson(dir.path, 'missing.json'), isEmpty);
      final file = File('${dir.path}/bad.json');
      for (final content in ['{invalid', '{"unexpected":true}']) {
        file.writeAsStringSync(content);
        expect(await readJson(dir.path, 'bad.json'), isEmpty);
      }
      await writeJson(dir.path, 'valid.json', [
        {'value': 1.25, 'text': '中文'},
      ]);
      expect(await readJson(dir.path, 'valid.json'), [
        {'value': 1.25, 'text': '中文'},
      ]);
    },
  );
}
