import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/stock_config.dart';
import '../../l10n/l10n.dart';
import '../../models/crypto/crypto_models.dart';
import '../../services/crypto/crypto_store.dart';
import '../../utils/currency_util.dart';
import '../common/app_ui.dart';
import '../common/currency_selector.dart';
import '../common/confirm_delete_dialog.dart';
import '../common/empty_state_widget.dart';
import '../common/form_sheet.dart';
import 'add_exchange_sheet.dart';
import 'crypto_text.dart';
import 'crypto_style.dart';

class CryptoPage extends StatefulWidget {
  final CryptoStore store;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  const CryptoPage({
    super.key,
    required this.store,
    required this.currency,
    required this.onCurrencyChanged,
  });
  @override
  State<CryptoPage> createState() => CryptoPageState();
}

class CryptoPageState extends State<CryptoPage>
    with AutomaticKeepAliveClientMixin {
  int _tab = 0;
  String? _connection;
  String _search = '';
  bool _hideSmall = false;
  @override
  bool get wantKeepAlive => true;
  Future<void> addConnection() => showAddExchangeSheet(context, widget.store);
  String _money(Decimal? usd, {bool showSymbol = true}) => usd == null
      ? L10n.t('cryptoUnknown')
      : '${showSymbol ? CurrencyUtil.getSymbol(widget.currency) : ''}${CurrencyUtil.formatCompact(CurrencyUtil.convertCurrency(usd.toDouble(), 'USD', widget.currency))}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.store,
        AppColors.marketColorNotifier,
      ]),
      builder: (context, _) {
        final connections = widget.store.connections;
        final selected = connections
            .where((c) => _connection == null || c.id == _connection)
            .toList();
        final snapshots = selected
            .map((c) => widget.store.snapshot(c.id))
            .whereType<CryptoSnapshot>()
            .toList();
        final total = snapshots.fold<Decimal>(
          Decimal.zero,
          (v, s) => v + s.totalUsd,
        );
        return RefreshIndicator(
          onRefresh: () => widget.store.refresh(),
          color: AppColors.accent,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SummaryCardFrame(
                gradient: CryptoStyle.summaryGradient,
                borderColor: CryptoStyle.border(CryptoStyle.lead),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            StockConfig.assetTotalAssets,
                            style: TextStyles.body13,
                          ),
                        ),
                        CurrencySelectorButton(
                          currency: widget.currency,
                          onTap: () => CurrencySelector.show(
                            context: context,
                            selectedCurrency: widget.currency,
                            onCurrencyChanged: widget.onCurrencyChanged,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _money(
                        snapshots.isEmpty && selected.isNotEmpty ? null : total,
                      ),
                      style: TextStyles.amountLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in [
                          (CryptoWalletKind.futures, 'cryptoBreakdownFutures'),
                          (CryptoWalletKind.spot, 'cryptoBreakdownSpot'),
                          (CryptoWalletKind.lead, 'cryptoBreakdownLead'),
                        ])
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: entry.$1 == CryptoWalletKind.lead
                                    ? 0
                                    : 6,
                              ),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CryptoStyle.tint(
                                  CryptoStyle.category(entry.$1),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CryptoStyle.border(
                                    CryptoStyle.category(entry.$1),
                                  ),
                                  width: .5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        CryptoStyle.icon(entry.$1),
                                        size: 13,
                                        color: CryptoStyle.category(entry.$1),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          L10n.t(entry.$2),
                                          style: TextStyles.caption.copyWith(
                                            color: CryptoStyle.category(
                                              entry.$1,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _money(
                                        snapshots.fold<Decimal>(
                                          Decimal.zero,
                                          (value, snapshot) =>
                                              value +
                                              snapshot.subtotal(entry.$1),
                                        ),
                                        showSymbol: false,
                                      ),
                                      style: TextStyles.subtitle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.store.syncing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(color: AppColors.accent),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      L10n.t('cryptoConnections'),
                      style: TextStyles.sectionTitle,
                    ),
                  ),
                ],
              ),
              if (widget.store.storageError != null)
                Text(
                  cryptoError(widget.store.storageError!),
                  style: TextStyles.bodySmall.copyWith(color: AppColors.danger),
                ),
              if (connections.isEmpty)
                EmptyStateWidget(
                  icon: Icons.currency_bitcoin,
                  title: L10n.t('cryptoEmpty'),
                  subtitle: L10n.t('cryptoEmptyHint'),
                ),
              if (connections.isNotEmpty) ...[
                const SizedBox(height: 8),
                if (connections.length > 1)
                  DropdownButtonFormField<String>(
                    key: ValueKey('filter-$_connection-${connections.length}'),
                    initialValue: connections.any((c) => c.id == _connection)
                        ? _connection
                        : null,
                    decoration: appInputDecoration(),
                    dropdownColor: AppColors.surfaceElevated,
                    style: TextStyles.body13,
                    isExpanded: true,
                    iconEnabledColor: AppColors.textSecondary,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(L10n.t('cryptoAll')),
                      ),
                      ...connections.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _connection = v),
                  ),
                if (connections.length > 1) const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in [
                        (0, 'cryptoOverview'),
                        (1, 'cryptoSpot'),
                        (2, 'cryptoContracts'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterPill(
                            label: L10n.t(entry.$2),
                            selected: _tab == entry.$1,
                            selectionColor: entry.$1 == 0
                                ? CryptoStyle.lead
                                : entry.$1 == 1
                                ? CryptoStyle.spot
                                : CryptoStyle.futures,
                            onTap: () => setState(() => _tab = entry.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_tab != 0) const SizedBox(height: 8),
                if (_tab != 0)
                  TextField(
                    style: TextStyles.inputText,
                    decoration: appInputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: L10n.t('cryptoSearch'),
                    ),
                    onChanged: (v) =>
                        setState(() => _search = v.trim().toUpperCase()),
                  ),
                if (_tab == 1)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.accent,
                    checkColor: AppColors.onAccent,
                    value: _hideSmall,
                    onChanged: (v) => setState(() => _hideSmall = v!),
                    title: Text(
                      L10n.t('cryptoHideSmall'),
                      style: TextStyles.bodySmall,
                    ),
                  ),
                for (final c in selected) ...[
                  const SizedBox(height: 8),
                  _connectionStatus(c),
                  if (_tab == 0) _overview(c),
                  if (_tab == 1) ..._balances(c),
                  if (_tab == 2) ..._positions(c),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _connectionStatus(ExchangeConnection c) {
    final error = widget.store.errors[c.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CryptoStyle.tint(
                  c.role == CryptoAccountRole.lead
                      ? CryptoStyle.lead
                      : CryptoStyle.futures,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                c.role == CryptoAccountRole.lead
                    ? Icons.groups_outlined
                    : Icons.account_balance_wallet_outlined,
                size: 18,
                color: c.role == CryptoAccountRole.lead
                    ? CryptoStyle.lead
                    : CryptoStyle.futures,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(c.name, style: TextStyles.subtitle)),
            IconButton(
              tooltip: L10n.t('cryptoRemove'),
              onPressed: () => _remove(c),
              icon: Icon(
                Icons.link_off,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              cryptoError(error),
              style: TextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _overview(ExchangeConnection c) {
    final snapshot = widget.store.snapshot(c.id);
    if (snapshot == null) return const SizedBox.shrink();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in snapshot.wallets) ...[
            _row(
              _walletLabel(w),
              _money(w.equityUsd),
              valueColor: CryptoStyle.category(w.kind),
            ),
            if (w.walletBalance != null)
              _row(
                L10n.t('cryptoWalletBalance'),
                '${w.walletBalance} ${w.settlement ?? ''}',
              ),
            if (w.unrealizedPnl != null)
              _row(
                L10n.t('cryptoPnl'),
                '${w.unrealizedPnl} ${w.settlement ?? ''}',
                valueColor: _pnlColor(w.unrealizedPnl),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _balances(ExchangeConnection c) {
    final snapshot = widget.store.snapshot(c.id);
    if (snapshot == null) return [];
    final balances =
        snapshot.balances
            .where(
              (b) =>
                  b.asset.toUpperCase().contains(_search) &&
                  (!_hideSmall ||
                      b.valueUsd == null ||
                      b.valueUsd!.abs() >= Decimal.one),
            )
            .toList()
          ..sort(
            (a, b) => (b.valueUsd ?? Decimal.zero).compareTo(
              a.valueUsd ?? Decimal.zero,
            ),
          );
    if (balances.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(L10n.t('cryptoNoBalances'), style: TextStyles.bodySmall),
        ),
      ];
    }
    return balances
        .map(
          (b) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(b.asset, _money(b.valueUsd)),
                  _row(L10n.t('cryptoQuantity'), '${b.quantity} ${b.asset}'),
                  _row(L10n.t('cryptoPrice'), _money(b.priceUsd)),
                  if (b.available != null)
                    _row(L10n.t('cryptoAvailable'), '${b.available}'),
                  if (b.frozen != null)
                    _row(L10n.t('cryptoFrozen'), '${b.frozen}'),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _positions(ExchangeConnection c) {
    if (c.exchange == CryptoExchange.binance &&
        c.role == CryptoAccountRole.lead &&
        c.leadMarket == CryptoLeadMarket.spot) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            L10n.t('cryptoSpotLeadNoContracts'),
            style: TextStyles.bodySmall,
          ),
        ),
      ];
    }
    final snapshot = widget.store.snapshot(c.id);
    if (snapshot == null) return [];
    final positions = snapshot.positions
        .where((p) => p.symbol.toUpperCase().contains(_search))
        .toList();
    return [
      for (final wallet in snapshot.wallets.where(
        (w) => w.kind != CryptoWalletKind.spot,
      ))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _card(_row(_walletLabel(wallet), _money(wallet.equityUsd))),
        ),
      if (positions.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(L10n.t('cryptoNoPositions'), style: TextStyles.bodySmall),
        ),
      for (final p in positions)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  p.symbol,
                  L10n.t(p.isLong ? 'cryptoLong' : 'cryptoShort'),
                  valueColor: p.isLong ? AppColors.rise : AppColors.fall,
                ),
                const SizedBox(height: 6),
                _row(
                  L10n.t('cryptoQuantity'),
                  '${p.quantity} ${p.unit == 'contracts' ? L10n.t('cryptoUnitContracts') : p.unit}',
                ),
                _row(
                  L10n.t('cryptoMarkPrice'),
                  '${p.markPrice ?? '—'} ${_priceUnit(p)}',
                ),
                _row(
                  L10n.t('cryptoPnl'),
                  '${p.unrealizedPnl ?? '—'} ${p.settlement}',
                  valueColor: _pnlColor(p.unrealizedPnl),
                ),
                if (p.leverage != null)
                  _row(L10n.t('cryptoLeverage'), '${p.leverage}×'),
                if (p.liquidationPrice != null &&
                    p.liquidationPrice! > Decimal.zero)
                  _row(
                    L10n.t('cryptoLiquidation'),
                    '${p.liquidationPrice} ${_priceUnit(p)}',
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  String _walletLabel(CryptoWallet wallet) => L10n.t(switch (wallet.kind) {
    CryptoWalletKind.spot => 'cryptoBreakdownSpot',
    CryptoWalletKind.futures => switch (wallet.name) {
      'USDⓈ-M' || 'USD-M' => 'cryptoUsdMarginedWallet',
      'COIN-M' => 'cryptoCoinMarginedWallet',
      _ => 'cryptoFuturesEquity',
    },
    CryptoWalletKind.lead => 'cryptoAccountEquity',
    CryptoWalletKind.unified => 'cryptoUnifiedEquity',
    CryptoWalletKind.copy => 'cryptoCopyEquity',
  });

  String _priceUnit(CryptoPosition p) => p.symbol.contains('USDT')
      ? 'USDT'
      : p.symbol.contains('USDC')
      ? 'USDC'
      : 'USD';
  Color _pnlColor(Decimal? value) => value == null || value == Decimal.zero
      ? AppColors.textPrimary
      : value > Decimal.zero
      ? AppColors.rise
      : AppColors.fall;

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: TextStyles.bodySmall)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyles.subtitle.copyWith(color: valueColor),
          ),
        ),
      ],
    ),
  );
  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CryptoStyle.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: CryptoStyle.panelBorder, width: .5),
    ),
    child: child,
  );
  Future<void> _remove(ExchangeConnection c) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: L10n.t('cryptoRemove'),
      content: L10n.t('cryptoRemoveConfirm'),
      icon: Icons.link_off,
      confirmText: L10n.t('cryptoRemove'),
    );
    if (confirmed != true) return;
    try {
      await widget.store.remove(c.id);
      if (mounted && _connection == c.id) setState(() => _connection = null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cryptoError(error))));
      }
    }
  }
}
