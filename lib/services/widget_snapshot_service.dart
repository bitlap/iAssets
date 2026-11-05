import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../utils/currency_util.dart';
import 'privacy_service.dart';

/// Publishes only the four values already shown on the asset summary card.
/// Exchange credentials, holdings, and account records never cross this bridge.
class WidgetSnapshotService {
  WidgetSnapshotService._();

  static const MethodChannel _channel = MethodChannel(
    'org.bitlap.assets/widget-snapshot',
  );

  static Future<void> publish({
    required double total,
    required double stocks,
    required double crypto,
    required double other,
    required String currency,
    required DateTime updatedAt,
    required bool incomplete,
  }) async {
    final privacy = PrivacyService.instance;
    final hidden = privacy.hideAmounts.value || privacy.biometricLock.value;
    String? display(double value) => value.isFinite
        ? '${CurrencyUtil.getSymbol(currency)}${CurrencyUtil.formatCompact(value)}'
        : null;

    final payload = <String, Object?>{
      'schema': 1,
      'currency': currency,
      'language': L10n.currentLang,
      'updatedAtMillis': updatedAt.millisecondsSinceEpoch,
      'incomplete': incomplete || !total.isFinite,
      'hidden': hidden,
      'total': hidden ? null : display(total),
      'stocks': hidden ? null : display(stocks),
      'crypto': hidden ? null : display(crypto),
      'other': hidden ? null : display(other),
    };
    try {
      await _channel.invokeMethod<void>('publish', payload);
    } on MissingPluginException {
      // WidgetKit is iOS-only; other platforms can still run the Flutter app.
    }
  }
}
