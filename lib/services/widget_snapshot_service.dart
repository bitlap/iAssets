import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../utils/currency_util.dart';
import 'privacy_service.dart';

/// Publishes only the four values already shown on the asset summary card.
/// Exchange credentials, holdings, and account records never cross this bridge.
class WidgetSnapshotService {
  WidgetSnapshotService._();

  /// Wait for verified access and a completed sync. A connected portfolio
  /// needs at least one account snapshot; partial results can be shown with
  /// the incomplete marker instead of freezing the entire widget.
  static bool isPortfolioReady({
    required bool entitlementLoading,
    required bool entitlementFailed,
    required bool isPro,
    required bool cryptoInitialized,
    required bool cryptoSyncing,
    required int cryptoConnectionCount,
    required int cryptoSnapshotCount,
  }) =>
      !entitlementLoading &&
      (!entitlementFailed || isPro) &&
      cryptoInitialized &&
      (isPro
          ? !cryptoSyncing &&
                (cryptoConnectionCount == 0 || cryptoSnapshotCount > 0)
          : cryptoConnectionCount == 0);

  /// A headless task cannot distinguish a genuinely empty Keychain from an
  /// unavailable connection list. Only a foreground session may publish the
  /// zero-connection state after the user removes their last connection.
  static bool isBackgroundPortfolioReady({
    required bool entitlementLoading,
    required bool entitlementFailed,
    required bool isPro,
    required bool cryptoInitialized,
    required bool cryptoSyncing,
    required int cryptoConnectionCount,
    required int cryptoSnapshotCount,
  }) =>
      isPro &&
      cryptoConnectionCount > 0 &&
      isPortfolioReady(
        entitlementLoading: entitlementLoading,
        entitlementFailed: entitlementFailed,
        isPro: isPro,
        cryptoInitialized: cryptoInitialized,
        cryptoSyncing: cryptoSyncing,
        cryptoConnectionCount: cryptoConnectionCount,
        cryptoSnapshotCount: cryptoSnapshotCount,
      );

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
