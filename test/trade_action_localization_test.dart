import 'package:assets/config/stock_config.dart';
import 'package:assets/l10n/l10n.dart';
import 'package:assets/models/stock_model.dart';
import 'package:assets/services/serde/converters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => L10n.applyLanguage('zh'));

  test(
    'Spanish legacy open and close remain distinct and translate completely',
    () {
      L10n.applyLanguage('es');
      expect(
        StockConfig.recordTitle('Posición abierta OLD', 'AAPL'),
        'Abrir posición AAPL',
      );
      expect(
        StockConfig.recordTitle('Posición cercana OLD', 'AAPL'),
        'Cerrar posición AAPL',
      );
      L10n.applyLanguage('zh');
      expect(
        StockConfig.recordTitle('Posición abierta OLD', 'AAPL'),
        '开仓 AAPL',
      );
      expect(
        StockConfig.recordTitle('Posición cercana OLD', 'AAPL'),
        '平仓 AAPL',
      );
      expect(
        StockConfig.localizeRecordDescription('Posición cercana AAPL'),
        '平仓 AAPL',
      );
    },
  );

  test('old translations remain readable after correcting financial terms', () {
    L10n.applyLanguage('en');
    for (final entry in {
      'Haltekraft erhöhen AAPL': 'Add AAPL',
      'Poste ouvert AAPL': 'Open AAPL',
      'Увеличение холдинга AAPL': 'Add AAPL',
      'クローズポジション AAPL': 'Close AAPL',
      '開倉 AAPL': 'Open AAPL',
      '减仓 AAPL': 'Reduce AAPL',
    }.entries) {
      expect(StockConfig.recordTitle(entry.key, 'AAPL'), entry.value);
    }
    expect(
      StockConfig.localizeRecordDescription('Address AAPL'),
      'Address AAPL',
    );
    expect(
      StockConfig.recordTitle(
        'unrecognized old text',
        'AAPL',
        type: StockConfig.opSellType,
      ),
      'Sell AAPL',
    );
  });

  test('stable actions survive storage, edits and every language switch', () {
    for (final action in TradeAction.values) {
      final record = OperationRecord(
        date: DateTime.utc(2026),
        type: 'buy',
        description: 'legacy custom text',
        action: action,
        amount: 12.34,
        shares: 2,
        fee: 1.23,
      );
      final wire = recordsToJson({
        'AAPL': [record],
      });
      expect(
        ((wire.single['records'] as List).single as Map)['action'],
        action.name,
      );
      final restored = recordsFromJson(
        wire,
      )['AAPL']!.single.copyWith(amount: 15);
      expect(restored.action, action);
      expect(restored.fee, 1.23);
      for (final language in L10n.languages.keys) {
        L10n.applyLanguage(language);
        final title = StockConfig.recordTitle(
          restored.description,
          'AAPL',
          action: restored.action,
        );
        expect(title, '${L10n.t(StockConfig.actionKey(action))} AAPL');
      }
    }
  });

  test('legacy or unknown action fields do not break import', () {
    final original = OperationRecord(
      date: DateTime.utc(2026),
      type: 'sell',
      description: 'Posición cercana AAPL',
      amount: 12,
      shares: 1,
    );
    final wire = recordsToJson({
      'AAPL': [original],
    });
    expect(
      ((wire.single['records'] as List).single as Map).containsKey('action'),
      isFalse,
    );
    for (final value in [null, 'future_action']) {
      final record = Map<String, dynamic>.from(
        (wire.single['records'] as List).single as Map,
      );
      record['action'] = value;
      final restored = recordsFromJson([
        {
          'symbol': 'AAPL',
          'records': [record],
        },
      ])['AAPL']!.single;
      expect(restored.action, isNull);
      L10n.applyLanguage('en');
      expect(
        StockConfig.recordTitle(
          restored.description,
          'AAPL',
          action: restored.action,
        ),
        'Close AAPL',
      );
    }
  });
}
