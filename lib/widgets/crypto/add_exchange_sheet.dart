import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/crypto/crypto_models.dart';
import '../../services/crypto/crypto_store.dart';
import '../common/app_ui.dart';
import '../common/dialog_utils.dart';
import '../common/form_sheet.dart';
import 'crypto_text.dart';
import 'crypto_style.dart';

Future<void> showAddExchangeSheet(BuildContext context, CryptoStore store) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExchangeSheet(store: store),
    );

class AddExchangeSheet extends StatefulWidget {
  final CryptoStore store;
  const AddExchangeSheet({super.key, required this.store});
  @override
  State<AddExchangeSheet> createState() => _AddExchangeSheetState();
}

class _AddExchangeSheetState extends State<AddExchangeSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _key = TextEditingController();
  final _secret = TextEditingController();
  final CryptoExchange _exchange = CryptoExchange.binance;
  CryptoAccountRole _role = CryptoAccountRole.regular;
  CryptoLeadMarket _leadMarket = CryptoLeadMarket.futures;
  bool get _binanceLead =>
      _exchange == CryptoExchange.binance && _role == CryptoAccountRole.lead;
  String get _scope => scopeKey(_exchange, _role, _leadMarket);
  String get _notes => _binanceLead ? 'cryptoLeadNotesBody' : 'cryptoNotesBody';
  bool _acknowledged = false;
  bool get _hasTradingRisk =>
      _tested?.snapshot.notices.any(
        (code) =>
            code == 'tradingPermission' || code == 'leadTradingPermission',
      ) ??
      false;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  TestedConnection? _tested;

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _key, _secret]) {
      controller.addListener(_invalidate);
    }
  }

  void _invalidate() {
    if (!mounted) return;
    setState(() {
      _tested = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    for (final controller in [_name, _key, _secret]) {
      controller.removeListener(_invalidate);
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _test() async {
    if (!_form.currentState!.validate() || !_acknowledged) return;
    setState(() {
      _busy = true;
      _tested = null;
      _error = null;
    });
    final candidate = ExchangeConnection(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      exchange: _exchange,
      name: _name.text.trim(),
      role: _role,
      leadMarket: _leadMarket,
      apiKey: _key.text.trim(),
      secret: _secret.text.trim(),
    );
    try {
      final result = await widget.store.test(candidate);
      if (mounted) setState(() => _tested = result);
    } catch (error) {
      if (mounted) setState(() => _error = cryptoError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final tested = _tested;
    if (tested == null || _busy) return;
    setState(() {
      _busy = true;
      _saving = true;
    });
    try {
      await widget.store.add(tested);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = cryptoError(error);
          _tested = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppFormSheet(
      title: L10n.t('cryptoAdd'),
      backgroundColor: CryptoStyle.panel,
      closeButtonOnRight: true,
      onClose: _busy ? null : () => Navigator.pop(context),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: appInputDecoration(
                  labelText: L10n.t('cryptoExchange'),
                ),
                child: Text(L10n.t('cryptoBinanceName')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CryptoAccountRole>(
                initialValue: _role,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: AppColors.surfaceElevated,
                style: TextStyles.inputText,
                iconEnabledColor: AppColors.textSecondary,
                isExpanded: true,
                decoration: appInputDecoration(
                  labelText: L10n.t('cryptoAccountRole'),
                ),
                items: CryptoAccountRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(
                          L10n.t(switch (role) {
                            CryptoAccountRole.regular => 'cryptoRegularAccount',
                            CryptoAccountRole.lead => 'cryptoLeadEquity',
                            CryptoAccountRole.copy => 'cryptoCopyEquity',
                          }),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (role) => setState(() {
                        _role = role!;
                        _acknowledged = false;
                        _tested = null;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 12),
              if (_binanceLead) ...[
                DropdownButtonFormField<CryptoLeadMarket>(
                  initialValue: _leadMarket,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: AppColors.surfaceElevated,
                  style: TextStyles.inputText,
                  iconEnabledColor: AppColors.textSecondary,
                  isExpanded: true,
                  decoration: appInputDecoration(
                    labelText: L10n.t('cryptoLeadMarket'),
                  ),
                  items: CryptoLeadMarket.values
                      .map(
                        (market) => DropdownMenuItem(
                          value: market,
                          child: Text(
                            L10n.t(
                              market == CryptoLeadMarket.spot
                                  ? 'cryptoSpotLead'
                                  : 'cryptoFuturesLead',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _leadMarket = value!;
                          _tested = null;
                          _error = null;
                          _acknowledged = false;
                        }),
                ),
                const SizedBox(height: 12),
              ],
              _field(_name, L10n.t('cryptoName')),
              const SizedBox(height: 12),
              _field(_key, L10n.t('cryptoApiKey'), secret: true),
              const SizedBox(height: 12),
              _field(_secret, L10n.t('cryptoApiSecret'), secret: true),
              const SizedBox(height: 16),
              _infoPanel(
                title: L10n.t('cryptoNotes'),
                body: L10n.t(_notes),
                icon: Icons.shield_outlined,
                color: CryptoStyle.caution,
                footer: L10n.t('cryptoRefreshHint'),
              ),
              const SizedBox(height: 12),
              _infoPanel(
                title: L10n.t('cryptoScope'),
                body: L10n.t(_scope),
                icon: Icons.info_outline,
                color: CryptoStyle.futures,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.accent,
                checkColor: AppColors.onAccent,
                value: _acknowledged,
                title: Text(
                  L10n.t(
                    _binanceLead
                        ? 'cryptoLeadAcknowledge'
                        : 'cryptoAcknowledge',
                  ),
                  style: TextStyles.body13,
                ),
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() {
                          _acknowledged = v!;
                          _tested = null;
                        });
                      },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyles.body13.copyWith(color: AppColors.danger),
                  ),
                ),
              if (_tested != null) ...[
                Text(
                  L10n.t(
                    _hasTradingRisk
                        ? 'cryptoRiskTestPassed'
                        : (_binanceLead
                              ? 'cryptoLeadTestPassed'
                              : 'cryptoTestPassed'),
                  ),
                  style: TextStyles.body13.copyWith(color: AppColors.success),
                ),
                if (!_tested!.snapshot.complete)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      L10n.t('cryptoPartial'),
                      style: TextStyles.bodySmall,
                    ),
                  ),
                for (final code in _tested!.snapshot.notices.toSet().where(
                  (code) => cryptoNotice(code) != L10n.t(_scope),
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      cryptoNotice(code),
                      style: TextStyles.bodySmall.copyWith(
                        color:
                            code == 'tradingPermission' ||
                                code == 'leadTradingPermission'
                            ? CryptoStyle.caution
                            : null,
                      ),
                    ),
                  ),
              ],
              if (_busy)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: cancelButton(
                      key: const ValueKey('crypto-test'),
                      onTap: _busy || !_acknowledged ? null : _test,
                      text: L10n.t('cryptoTest'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: confirmButton(
                      key: const ValueKey('crypto-save'),
                      onTap: _busy || _tested == null ? null : _save,
                      text: L10n.t('cryptoSave'),
                      bgColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _infoPanel({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
    String? footer,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CryptoStyle.tint(color),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: CryptoStyle.border(color), width: .5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyles.subtitle.copyWith(color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(body, style: TextStyles.bodySmall.copyWith(height: 1.5)),
        if (footer != null) ...[
          const SizedBox(height: 8),
          Text(footer, style: TextStyles.caption.copyWith(height: 1.5)),
        ],
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
  }) => TextFormField(
    controller: controller,
    style: TextStyles.inputText,
    enabled: !_busy,
    obscureText: secret,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: !secret,
    maxLength: secret ? 256 : 40,
    decoration: appInputDecoration(labelText: label).copyWith(counterText: ''),
    validator: (value) =>
        value == null || value.trim().isEmpty ? L10n.t('cryptoRequired') : null,
  );
}
