import '../../l10n/l10n.dart';
import '../../models/crypto/crypto_models.dart';

String cryptoExchangeName(CryptoExchange exchange) => switch (exchange) {
  CryptoExchange.binance => 'Binance',
  CryptoExchange.okx => 'OKX',
  CryptoExchange.bybit => 'Bybit',
};

String cryptoError(Object error) {
  if (error is! CryptoSyncException) return L10n.t('cryptoErrorStorage');
  final key = switch ((error.code, error.detail)) {
    ('network' || 'api', '-2015') => 'cryptoErrorBinanceAccess',
    ('network' || 'api', '-1021') => 'cryptoErrorBinanceTime',
    ('network' || 'api', '-1022') => 'cryptoErrorBinanceSignature',
    _ => switch (error.code) {
      'unsupportedExchange' => 'cryptoBinanceOnly',
      'copyUnavailable' => 'cryptoNoticeCopyUnavailable',
      'copyUnsupported' => 'cryptoBinanceCopyUnsupported',
      'permissionUnverified' => 'cryptoPermissionUnverified',
      'readOnly' => 'cryptoErrorReadOnly',
      'timeout' => 'cryptoErrorTimeout',
      'response' => 'cryptoErrorResponse',
      'duplicate' => 'cryptoErrorDuplicate',
      'duplicateCredentials' => 'cryptoErrorDuplicateCredentials',
      'retest' => 'cryptoErrorRetest',
      'storage' => 'cryptoErrorStorage',
      'accountChanged' => 'cryptoErrorAccountChanged',
      'futuresUnavailable' => 'cryptoErrorFuturesUnavailable',
      'networkConnection' => 'cryptoErrorNetworkConnection',
      'networkTls' => 'cryptoErrorNetworkTls',
      _ => 'cryptoErrorNetwork',
    },
  };
  final stage = error.stage == null ? '' : ' [${L10n.t(error.stage!)}]';
  final detail = error.detail == null ? '' : ' (${error.detail})';
  return '${L10n.t(key)}$stage$detail';
}

String cryptoNotice(String code) => L10n.t(switch (code) {
  'binanceSpotLeadScope' => 'cryptoScopeBinanceSpotLead',
  'tradingPermission' => 'cryptoLeadTradingPermission',
  'leadTradingPermission' => 'cryptoLeadTradingPermission',
  'binanceLeadScope' => 'cryptoScopeBinanceLead',
  'permissionUnverified' => 'cryptoPermissionUnverified',
  'binanceCopyUnsupported' => 'cryptoScopeBinance',
  'okxScope' => 'cryptoScopeOkx',
  'okxCopyScope' => 'cryptoScopeOkx',
  'unifiedEquity' => 'cryptoNoticeUnified',
  'bybitScope' => 'cryptoScopeBybit',
  'bybitCopyPositions' => 'cryptoNoticeCopyPositions',
  'copyUnavailable' => 'cryptoNoticeCopyUnavailable',
  'futuresUnavailable' => 'cryptoErrorFuturesUnavailable',
  _ => 'cryptoPartial',
});

String scopeKey(
  CryptoExchange exchange, [
  CryptoAccountRole role = CryptoAccountRole.regular,
  CryptoLeadMarket leadMarket = CryptoLeadMarket.futures,
]) => switch (exchange) {
  CryptoExchange.binance =>
    role == CryptoAccountRole.lead
        ? (leadMarket == CryptoLeadMarket.spot
              ? 'cryptoScopeBinanceSpotLead'
              : 'cryptoScopeBinanceLead')
        : 'cryptoScopeBinance',
  CryptoExchange.okx => 'cryptoScopeOkx',
  CryptoExchange.bybit => 'cryptoScopeBybit',
};

String updateText(DateTime? time) {
  if (time == null) return L10n.t('cryptoNoTime');
  final local = time.toLocal();
  final text =
      '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return L10n.t('cryptoUpdated').replaceAll('{time}', text);
}
