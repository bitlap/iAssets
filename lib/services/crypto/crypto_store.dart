import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/crypto/crypto_models.dart';
import 'exchange_client.dart';

abstract interface class CryptoPersistence {
  Future<String?> readConnections();
  Future<void> writeConnections(String value);
  Future<void> clearLegacyCache();
}

class DeviceCryptoPersistence implements CryptoPersistence {
  static const _channel = MethodChannel('org.bitlap.assets/crypto-storage');
  @override
  Future<String?> readConnections() =>
      _channel.invokeMethod<String>('readConnections');
  @override
  Future<void> writeConnections(String value) =>
      _channel.invokeMethod<void>('writeConnections', value);
  @override
  Future<void> clearLegacyCache() =>
      _channel.invokeMethod<void>('clearLegacyCache');
}

class TestedConnection {
  final ExchangeConnection connection;
  final CryptoSnapshot snapshot;
  final DateTime testedAt;
  final String _fingerprint;
  TestedConnection._(this.connection, this.snapshot, this.testedAt)
    : _fingerprint = _identity(connection);
}

String _identity(ExchangeConnection c) =>
    sha256.convert(utf8.encode(jsonEncode(c.toSecureJson()))).toString();

class CryptoStore extends ChangeNotifier {
  static final instance = CryptoStore();
  final ExchangeReader reader;
  final CryptoPersistence persistence;
  final DateTime Function() now;
  CryptoStore({
    ExchangeReader? reader,
    CryptoPersistence? persistence,
    DateTime Function()? clock,
  }) : reader = reader ?? ExchangeClient(),
       persistence = persistence ?? DeviceCryptoPersistence(),
       now = clock ?? DateTime.now;

  List<ExchangeConnection> _connections = [];
  final Map<String, CryptoSnapshot> _snapshots = {};
  final Map<String, CryptoSyncException> _errors = {};
  List<ExchangeConnection> get connections => List.unmodifiable(_connections);
  Map<String, CryptoSyncException> get errors => Map.unmodifiable(_errors);
  CryptoSyncException? storageError;
  bool initialized = false;
  bool syncing = false;
  Future<void>? _initializing;
  Future<void>? _refreshing;
  Future<void> _writes = Future.value();

  CryptoSnapshot? snapshot(String id) {
    if (_connections.any(
      (c) => c.id == id && c.exchange != CryptoExchange.binance,
    )) {
      return null;
    }
    final s = _snapshots[id];
    return s == null || now().isBefore(s.updatedAt) ? null : s;
  }

  DateTime? updatedAt(String id) => _snapshots[id]?.updatedAt;
  Decimal get totalUsd => _connections.fold(
    Decimal.zero,
    (value, c) => value + (snapshot(c.id)?.totalUsd ?? Decimal.zero),
  );
  Decimal subtotal(CryptoWalletKind kind) => _connections.fold(
    Decimal.zero,
    (value, c) => value + (snapshot(c.id)?.subtotal(kind) ?? Decimal.zero),
  );
  bool get incomplete =>
      storageError != null ||
      _connections.any(
        (c) =>
            snapshot(c.id) == null ||
            !snapshot(c.id)!.complete ||
            _errors.containsKey(c.id),
      );
  DateTime? get oldestUpdate {
    final times = _connections
        .map((c) => snapshot(c.id)?.updatedAt)
        .whereType<DateTime>()
        .toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.first;
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      final raw = await persistence.readConnections();
      if (raw != null) {
        _connections = (jsonDecode(raw) as List)
            .map(
              (j) => ExchangeConnection.fromSecureJson(
                Map<String, dynamic>.from(j),
              ),
            )
            .toList();
      }
    } catch (_) {
      storageError = const CryptoSyncException('storage');
      _initializing = null;
      notifyListeners();
      return; // Never overwrite inaccessible Keychain entries with an empty list.
    }
    try {
      await persistence.clearLegacyCache();
    } catch (_) {
      // Retry legacy-file cleanup on the next launch; no snapshot is ever read or written.
    }
    initialized = true;
    storageError = null;
    notifyListeners();
  }

  Future<TestedConnection> test(ExchangeConnection c) async {
    await initialize();
    if (!initialized) throw const CryptoSyncException('storage');
    _requireSupported(c);
    _checkDuplicateCredentials(c);
    final s = await reader.read(c);
    if (s.accountId.isEmpty) throw const CryptoSyncException('response');
    final identified = c.identified(s.accountId, s.accountReferences);
    _checkDuplicate(identified);
    return TestedConnection._(identified, s, now());
  }

  void _requireSupported(ExchangeConnection connection) {
    if (connection.exchange != CryptoExchange.binance) {
      throw const CryptoSyncException('unsupportedExchange');
    }
  }

  void _checkDuplicate(ExchangeConnection c) {
    _checkDuplicateCredentials(c);
    if (_connections.any(
      (existing) =>
          existing.exchange == c.exchange &&
          existing.region == c.region &&
          (existing.accountId == c.accountId ||
              existing.accountReferences.any(c.accountReferences.contains)),
    )) {
      throw const CryptoSyncException('duplicate');
    }
  }

  void _checkDuplicateCredentials(ExchangeConnection c) {
    if (_connections.any(
      (existing) =>
          existing.exchange == c.exchange &&
          existing.region == c.region &&
          existing.apiKey == c.apiKey &&
          existing.secret == c.secret,
    )) {
      throw const CryptoSyncException('duplicateCredentials');
    }
  }

  Future<void> add(TestedConnection tested) async {
    if (!initialized ||
        now().difference(tested.testedAt) >= const Duration(minutes: 5) ||
        now().isBefore(tested.testedAt) ||
        _identity(tested.connection) != tested._fingerprint) {
      throw const CryptoSyncException('retest');
    }
    await _serialize(() async {
      _checkDuplicate(tested.connection);
      final next = [..._connections, tested.connection];
      await persistence.writeConnections(
        jsonEncode(next.map((c) => c.toSecureJson()).toList()),
      );
      _connections = next;
      _snapshots[tested.connection.id] = tested.snapshot;
      notifyListeners();
    });
  }

  Future<void> remove(String id) => _serialize(() async {
    final next = _connections.where((c) => c.id != id).toList();
    await persistence.writeConnections(
      jsonEncode(next.map((c) => c.toSecureJson()).toList()),
    );
    _connections = next;
    _snapshots.remove(id);
    _errors.remove(id);
    notifyListeners();
  });

  Future<void> _serialize(Future<void> Function() operation) {
    final task = _writes.then((_) => operation());
    _writes = task.catchError((Object _) {});
    return task;
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    final future = _refresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    await initialize();
    if (!initialized) return;
    final targets = List<ExchangeConnection>.of(_connections);
    if (targets.isEmpty) {
      notifyListeners();
      return;
    }
    syncing = true;
    notifyListeners();
    try {
      // Sequential per-account calls avoid bursting exchange rate limits.
      for (final c in targets) {
        try {
          _requireSupported(c);
          final s = await reader.read(c);
          if (s.accountId != c.accountId) {
            throw const CryptoSyncException('accountChanged');
          }
          if (!_connections.any((v) => v.id == c.id)) continue;
          _snapshots[c.id] = s;
          _errors.remove(c.id);
        } catch (error) {
          if (!_connections.any((v) => v.id == c.id)) continue;
          _errors[c.id] = error is CryptoSyncException
              ? error
              : const CryptoSyncException('network');
        }
        notifyListeners();
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
