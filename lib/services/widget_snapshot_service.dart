import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../utils/currency_util.dart';
import 'crypto/crypto_store.dart';
import 'privacy_service.dart';
import 'pro_service.dart';

/// 仅向小组件发布资产汇总卡片中已有的四项金额。
/// 交易所凭证、持仓明细和账户记录均不通过此桥接传输。
class WidgetSnapshotService {
  WidgetSnapshotService._();

  static const MethodChannel _channel = MethodChannel(
    'org.bitlap.assets/widget-snapshot',
  );

  /// 未完成权益校验或没有可用数字币估值时，保留组件上次的共享快照。
  static Future<void> publishPortfolio({
    required double stocks,
    required double other,
    required String currency,
    required DateTime stockUpdatedAt,
    required CryptoStore cryptoStore,
    required ProService pro,
  }) async {
    if (pro.loading ||
        pro.error != null ||
        (!pro.isPro && !pro.legacyVerified)) {
      return;
    }
    final valuation = pro.isPro ? cryptoStore.cachedValuation : null;
    if (pro.isPro && valuation == null) return;
    final crypto = CurrencyUtil.convertCurrency(
      valuation?.totalUsd.toDouble() ?? 0,
      'USD',
      currency,
    );
    if (!crypto.isFinite) return;
    final cryptoUpdatedAt = valuation?.updatedAt;
    final updatedAt =
        cryptoUpdatedAt != null && cryptoUpdatedAt.isBefore(stockUpdatedAt)
        ? cryptoUpdatedAt
        : stockUpdatedAt;
    await publish(
      total: stocks + crypto + other,
      stocks: stocks,
      crypto: crypto,
      other: other,
      currency: currency,
      updatedAt: updatedAt,
      incomplete: pro.isPro && cryptoStore.incomplete,
    );
  }

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
      // WidgetKit 仅支持 iOS，其他平台仍可运行 Flutter 应用。
    }
  }
}
