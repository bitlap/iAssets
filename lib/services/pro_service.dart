import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/asset_account.dart';

/// Limits apply to additions only. Existing records are never truncated.
class ProAccess {
  final bool isPro;
  const ProAccess({this.isPro = false});
  static const freeLimit = 3;

  bool canAddStock(int count) => isPro || count < freeLimit;

  bool canAddAsset(Iterable<AssetBase> assets, AssetType type) {
    if (isPro) return true;
    final types = assets.map((a) => a.type).toSet();
    return (types.contains(type) || types.length < freeLimit) &&
        assets.where((a) => a.type == type).length < freeLimit;
  }
}

class ProRequiredException implements Exception {
  const ProRequiredException();
}

class ProProduct {
  final String id;
  final String price;
  const ProProduct(this.id, this.price);
}

class ProService extends ChangeNotifier {
  static final instance = ProService();
  static const channel = MethodChannel('org.bitlap.assets/pro');
  static const monthly = 'org.bitlap.assets.pro.monthly';
  static const yearly = 'org.bitlap.assets.pro.yearly';
  static const lifetime = 'org.bitlap.assets.pro.lifetime';
  static const productIds = [monthly, yearly, lifetime];
  // Freeze this UTC timestamp at the first monetized release. Never move it.
  static const legacyCutoff = String.fromEnvironment('PRO_LEGACY_CUTOFF');
  static const privacyUrl = String.fromEnvironment(
    'PRO_PRIVACY_URL',
    defaultValue: 'https://bitlap.org/iAssets-privacy/',
  );

  ProService({
    this.legacyCutoffDate = legacyCutoff,
    this.privacyPolicyUrl = privacyUrl,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;
  final String legacyCutoffDate;
  final String privacyPolicyUrl;
  final DateTime Function() _now;
  String _kind = 'free';
  DateTime? _expiresAt;
  Timer? _expiryTimer;
  Future<void>? _refreshing;
  bool loading = true;
  bool busy = false;
  bool legacyVerified = false;
  String? error;
  List<ProProduct> products = const [];

  bool get configured => DateTime.tryParse(legacyCutoffDate)?.isUtc == true;
  bool get isPro =>
      _kind == 'legacy' ||
      _kind == 'lifetime' ||
      (_kind == 'subscription' && (_expiresAt?.isAfter(_now()) ?? false));
  String get kind => isPro ? _kind : 'free';
  bool get hasSubscription => _expiresAt?.isAfter(_now()) ?? false;
  ProAccess get access => ProAccess(isPro: isPro);
  bool get canPurchase =>
      configured &&
      legacyVerified &&
      kind != 'legacy' &&
      kind != 'lifetime' &&
      !busy &&
      Uri.tryParse(privacyPolicyUrl)?.scheme == 'https' &&
      (Uri.tryParse(privacyPolicyUrl)?.host.isNotEmpty ?? false);

  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') {
        // A purchase can complete after an in-flight snapshot was captured.
        if (_refreshing != null) await _refreshing;
        await refresh();
      }
    });
    await refresh();
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    final future = _load();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<void> _load() async {
    try {
      final value = await channel
          .invokeMapMethod<String, dynamic>('status', {
            'legacyCutoff': legacyCutoffDate,
          })
          .timeout(const Duration(seconds: 20));
      if (value == null) throw const FormatException('Missing status');
      _kind = value['kind'] as String? ?? 'free';
      _expiresAt = DateTime.tryParse(value['expiresAt'] as String? ?? '');
      legacyVerified = value['legacyVerified'] == true;
      products = [
        for (final raw in value['products'] as List? ?? const [])
          if (raw is Map &&
              productIds.contains(raw['id']) &&
              raw['price'] is String)
            ProProduct(raw['id'] as String, raw['price'] as String),
      ];
      error = null;
      _expiryTimer?.cancel();
      if (_expiresAt != null && _expiresAt!.isAfter(_now())) {
        _expiryTimer = Timer(_expiresAt!.difference(_now()), () {
          notifyListeners();
          unawaited(refresh());
        });
      }
    } catch (_) {
      // Keep a previously verified in-session entitlement only until its expiry.
      error = 'proVerificationError';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void requirePro() {
    if (!isPro) throw const ProRequiredException();
  }

  Future<String> purchase(String productId) async {
    if (!productIds.contains(productId) || !canPurchase) return 'unavailable';
    busy = true;
    error = null;
    notifyListeners();
    try {
      // Refresh first so an existing owner isn't charged again after reconnecting.
      await refresh();
      if (kind == 'legacy' ||
          kind == 'lifetime' ||
          (kind == 'subscription' && productId != lifetime)) {
        return 'owned';
      }
      if (!legacyVerified || error != null) return 'unavailable';
      return await channel.invokeMethod<String>('purchase', {
            'id': productId,
          }) ??
          'unavailable';
    } catch (_) {
      error = 'proPurchaseError';
      return 'error';
    } finally {
      await refresh();
      busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await channel.invokeMethod<void>('restore');
      await refresh();
    } catch (_) {
      error = 'proVerificationError';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}
