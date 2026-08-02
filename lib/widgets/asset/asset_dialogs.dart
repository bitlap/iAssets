import 'package:flutter/material.dart';
import '../../models/asset_account.dart';
import '../../utils/currency_util.dart';
import '../../services/exchange_rate_service.dart';
import '../../utils/center_toast.dart';
import '../../config/app_config.dart';
import '../../config/app_colors.dart';
import '../../config/asset_config.dart';
import '../common/app_number_field.dart';
import '../common/dialog_utils.dart';
import '../common/app_ui.dart';

// Add Asset Sheet

class _AssetOption {
  final IconData icon;
  final Color color;
  final String label;
  final AssetType type;

  const _AssetOption(this.icon, this.color, this.label, this.type);
}

List<_AssetOption> get _assetOptions => [
  _AssetOption(
    Icons.payments,
    AppColors.success,
    AssetConfig.cash,
    AssetType.cash,
  ),
  _AssetOption(
    Icons.account_balance,
    AppColors.cyan,
    AssetConfig.current,
    AssetType.current,
  ),
  _AssetOption(
    Icons.savings,
    AppColors.warning,
    AssetConfig.timeDeposit,
    AssetType.timeDeposit,
  ),
  _AssetOption(
    Icons.monetization_on,
    AppColors.accent,
    AssetConfig.wealthProduct,
    AssetType.wealthProduct,
  ),
  _AssetOption(
    Icons.home_work,
    AppColors.purple,
    AssetConfig.providentFund,
    AssetType.providentFund,
  ),
];

Future<AssetType?> showAddAssetSheet(BuildContext context) {
  return showDialog<AssetType>(
    context: context,
    builder: (ctx) => dialogFrame(
      context: ctx,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AssetConfig.titleAddAsset, style: TextStyles.dialogTitle),
          const SizedBox(height: 12),
          for (final option in _assetOptions) ...[
            if (option != _assetOptions.first)
              Divider(thickness: 0.5, height: 20, color: AppColors.border),
            _addOption(
              option.icon,
              option.color,
              option.label,
              onTap: () {
                Navigator.pop(ctx, option.type);
              },
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _addOption(
  IconData icon,
  Color color,
  String label, {
  required VoidCallback onTap,
}) {
  return SizedBox(
    height: 48,
    child: ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(label, style: TextStyles.bodyRegular),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// Balance Dialog (shared by Cash / Current / ProvidentFund)

class _BalanceDialog extends StatefulWidget {
  final AssetType assetType;
  final String titleEdit;
  final String titleAdd;
  final String hintName;
  final String defaultCurrency;
  final int assetCount;
  final AssetBase? asset;

  const _BalanceDialog({
    required this.assetType,
    required this.titleEdit,
    required this.titleAdd,
    required this.hintName,
    required this.defaultCurrency,
    required this.assetCount,
    this.asset,
  });

  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController balanceCtrl;
  late String currency;

  bool get isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    nameCtrl = TextEditingController(text: a?.name ?? '');
    balanceCtrl = TextEditingController(
      text: a != null
          ? CurrencyUtil.formatRate((a as dynamic).balance ?? 0)
          : '',
    );
    currency = a?.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    balanceCtrl.dispose();
    super.dispose();
  }

  AssetBase _buildResult(double balance) {
    final id =
        widget.asset?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    switch (widget.assetType) {
      case AssetType.cash:
        return CashAccount(
          id: id,
          sortOrder: widget.asset?.sortOrder ?? widget.assetCount,
          currency: currency,
          name: nameCtrl.text.trim(),
          balance: balance,
          createdAt: widget.asset?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
      case AssetType.current:
        return CurrentAccount(
          id: id,
          sortOrder: widget.asset?.sortOrder ?? widget.assetCount,
          currency: currency,
          name: nameCtrl.text.trim(),
          balance: balance,
          createdAt: widget.asset?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
      case AssetType.providentFund:
        return ProvidentFundAccount(
          id: id,
          sortOrder: widget.asset?.sortOrder ?? widget.assetCount,
          currency: currency,
          name: nameCtrl.text.trim(),
          balance: balance,
          createdAt: widget.asset?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
      default:
        throw ArgumentError('Unsupported asset type: ${widget.assetType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return dialogFrame(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              isEdit ? widget.titleEdit : widget.titleAdd,
              style: TextStyles.dialogTitle,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AssetConfig.fieldName,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          _dialogTextField(nameCtrl, widget.hintName),
          const SizedBox(height: 12),
          Text(
            AssetConfig.fieldBalance,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppNumberField(
                  controller: balanceCtrl,
                  hintText: '0.00',
                ),
              ),
              const SizedBox(width: 8),
              _currencySelector(
                context,
                currency,
                (c) => setState(() => currency = c),
              ),
            ],
          ),
          const SizedBox(height: 20),
          actionButtonRow(
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              final balance = double.tryParse(balanceCtrl.text);
              if (balance == null || balance < 0) {
                CenterToast.error(context, AssetConfig.toastInvalidBalance);
                return;
              }
              Navigator.pop(context, _buildResult(balance));
            },
            confirmText: isEdit ? AppConfig.btnClose : AppConfig.btnAdd,
            confirmGradient: const LinearGradient(
              colors: [AppColors.blueDark, AppColors.blueAccent],
            ),
          ),
        ],
      ),
    );
  }
}

Future<CashAccount?> showCashAssetDialog(
  BuildContext context, {
  CashAccount? cash,
  required String defaultCurrency,
  required int assetCount,
}) {
  return showDialog<CashAccount>(
    context: context,
    builder: (_) => _BalanceDialog(
      assetType: AssetType.cash,
      titleEdit: AssetConfig.titleEditCash,
      titleAdd: AssetConfig.titleAddCash,
      hintName: AssetConfig.hintCashName,
      defaultCurrency: defaultCurrency,
      assetCount: assetCount,
      asset: cash,
    ),
  );
}

Future<CurrentAccount?> showCurrentAssetDialog(
  BuildContext context, {
  CurrentAccount? account,
  required String defaultCurrency,
  required int assetCount,
}) {
  return showDialog<CurrentAccount>(
    context: context,
    builder: (_) => _BalanceDialog(
      assetType: AssetType.current,
      titleEdit: AssetConfig.titleEditCurrent,
      titleAdd: AssetConfig.titleAddCurrent,
      hintName: AssetConfig.hintCurrentName,
      defaultCurrency: defaultCurrency,
      assetCount: assetCount,
      asset: account,
    ),
  );
}

Future<ProvidentFundAccount?> showProvidentFundAssetDialog(
  BuildContext context, {
  ProvidentFundAccount? account,
  required String defaultCurrency,
  required int assetCount,
}) {
  return showDialog<ProvidentFundAccount>(
    context: context,
    builder: (_) => _BalanceDialog(
      assetType: AssetType.providentFund,
      titleEdit: AssetConfig.titleEditProvidentFund,
      titleAdd: AssetConfig.titleAddProvidentFund,
      hintName: AssetConfig.hintProvidentFundName,
      defaultCurrency: defaultCurrency,
      assetCount: assetCount,
      asset: account,
    ),
  );
}

// Time Deposit Dialog

class _TimeDepositDialog extends StatefulWidget {
  final TimeDeposit? td;
  final String defaultCurrency;
  final int assetCount;

  const _TimeDepositDialog({
    this.td,
    required this.defaultCurrency,
    required this.assetCount,
  });

  @override
  State<_TimeDepositDialog> createState() => _TimeDepositDialogState();
}

class _TimeDepositDialogState extends State<_TimeDepositDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController principalCtrl;
  late TextEditingController rateCtrl;
  late DateTime startDate;
  late int durationMonths;
  late String currency;

  @override
  void initState() {
    super.initState();
    final td = widget.td;
    nameCtrl = TextEditingController(text: td?.name ?? '');
    principalCtrl = TextEditingController(
      text: td != null ? CurrencyUtil.formatRate(td.principal) : '',
    );
    rateCtrl = TextEditingController(
      text: td != null ? td.annualRate.toString() : '',
    );
    startDate = td?.startDate ?? DateTime.now();
    durationMonths = td?.durationMonths ?? 12;
    currency = td?.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    principalCtrl.dispose();
    rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.td != null;
    return dialogFrame(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              isEdit ? AssetConfig.titleEditTD : AssetConfig.titleAddTD,
              style: TextStyles.dialogTitle,
            ),
          ),
          const SizedBox(height: 16),
          _label(AssetConfig.fieldName),
          const SizedBox(height: 6),
          _dialogTextField(nameCtrl, AssetConfig.hintTDName),
          const SizedBox(height: 12),
          Text(
            AssetConfig.fieldPrincipal,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppNumberField(
                  controller: principalCtrl,
                  hintText: '0.00',
                ),
              ),
              const SizedBox(width: 8),
              _currencySelector(
                context,
                currency,
                (c) => setState(() => currency = c),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AssetConfig.fieldAnnualRate,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          AppNumberField(controller: rateCtrl, hintText: '2.5'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _label(AssetConfig.fieldStartDate)),
              const SizedBox(width: 16),
              Expanded(child: _label(AssetConfig.fieldDuration)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _dateButton(startDate, () async {
                  final picked = await showDatePickerDialog(
                    context,
                    initialDate: startDate,
                  );
                  if (picked != null) setState(() => startDate = picked);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _durationSelector(
                  durationMonths,
                  (v) => setState(() => durationMonths = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          actionButtonRow(
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              final principal = double.tryParse(principalCtrl.text);
              final rate = double.tryParse(rateCtrl.text);
              if (principal == null || principal <= 0) {
                CenterToast.error(context, AssetConfig.toastInvalidPrincipal);
                return;
              }
              if (rate == null || rate < 0) {
                CenterToast.error(context, AssetConfig.toastInvalidRate);
                return;
              }
              final updated = TimeDeposit(
                id:
                    widget.td?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                sortOrder: widget.td?.sortOrder ?? widget.assetCount,
                currency: currency,
                name: nameCtrl.text.trim(),
                principal: principal,
                annualRate: rate,
                startDate: startDate,
                durationMonths: durationMonths,
                createdAt: widget.td?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );
              Navigator.pop(context, updated);
            },
            confirmText: isEdit ? AppConfig.btnClose : AppConfig.btnAdd,
            confirmGradient: const LinearGradient(
              colors: [AppColors.blueDark, AppColors.blueAccent],
            ),
          ),
        ],
      ),
    );
  }
}

Future<TimeDeposit?> showTimeDepositDialog(
  BuildContext context, {
  TimeDeposit? td,
  required String defaultCurrency,
  required int assetCount,
}) {
  return showDialog<TimeDeposit>(
    context: context,
    builder: (_) => _TimeDepositDialog(
      td: td,
      defaultCurrency: defaultCurrency,
      assetCount: assetCount,
    ),
  );
}

// Wealth Product Dialog

class _WealthProductDialog extends StatefulWidget {
  final WealthProduct? wp;
  final String defaultCurrency;
  final int assetCount;

  const _WealthProductDialog({
    this.wp,
    required this.defaultCurrency,
    required this.assetCount,
  });

  @override
  State<_WealthProductDialog> createState() => _WealthProductDialogState();
}

class _WealthProductDialogState extends State<_WealthProductDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController sharesCtrl;
  late TextEditingController navCtrl;
  late String currency;

  @override
  void initState() {
    super.initState();
    final wp = widget.wp;
    nameCtrl = TextEditingController(text: wp?.name ?? '');
    sharesCtrl = TextEditingController(
      text: wp != null ? CurrencyUtil.formatRate(wp.shares) : '',
    );
    navCtrl = TextEditingController(
      text: wp != null ? CurrencyUtil.formatRate(wp.nav) : '',
    );
    currency = wp?.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    sharesCtrl.dispose();
    navCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.wp != null;
    return dialogFrame(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              isEdit ? AssetConfig.titleEditWP : AssetConfig.titleAddWP,
              style: TextStyles.dialogTitle,
            ),
          ),
          const SizedBox(height: 16),
          _label(AssetConfig.fieldName),
          const SizedBox(height: 6),
          _dialogTextField(nameCtrl, AssetConfig.hintWPName),
          const SizedBox(height: 12),
          Text(
            AssetConfig.fieldShares,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          AppNumberField(controller: sharesCtrl, hintText: '0.00'),
          const SizedBox(height: 12),
          Text(
            AssetConfig.fieldNav,
            style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppNumberField(controller: navCtrl, hintText: '1.0000'),
              ),
              const SizedBox(width: 8),
              _currencySelector(
                context,
                currency,
                (c) => setState(() => currency = c),
              ),
            ],
          ),
          const SizedBox(height: 20),
          actionButtonRow(
            onCancel: () => Navigator.pop(context),
            onConfirm: () {
              final shares = double.tryParse(sharesCtrl.text);
              final nav = double.tryParse(navCtrl.text);
              if (shares == null || shares <= 0) {
                CenterToast.error(context, AssetConfig.toastInvalidShares);
                return;
              }
              if (nav == null || nav <= 0) {
                CenterToast.error(context, AssetConfig.toastInvalidNav);
                return;
              }
              final updated = WealthProduct(
                id:
                    widget.wp?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                sortOrder: widget.wp?.sortOrder ?? widget.assetCount,
                currency: currency,
                name: nameCtrl.text.trim(),
                shares: shares,
                nav: nav,
                createdAt: widget.wp?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );
              Navigator.pop(context, updated);
            },
            confirmText: isEdit ? AppConfig.btnClose : AppConfig.btnAdd,
            confirmGradient: const LinearGradient(
              colors: [AppColors.blueDark, AppColors.blueAccent],
            ),
          ),
        ],
      ),
    );
  }
}

Future<WealthProduct?> showWealthProductDialog(
  BuildContext context, {
  WealthProduct? wp,
  required String defaultCurrency,
  required int assetCount,
}) {
  return showDialog<WealthProduct>(
    context: context,
    builder: (_) => _WealthProductDialog(
      wp: wp,
      defaultCurrency: defaultCurrency,
      assetCount: assetCount,
    ),
  );
}

// Shared Form Widgets

Widget _label(String text) {
  return Text(
    text,
    style: TextStyles.body13.copyWith(color: AppColors.textSecondary),
  );
}

Widget _dialogTextField(TextEditingController ctrl, String hint) {
  return TextField(
    controller: ctrl,
    keyboardType: TextInputType.text,
    style: TextStyles.sectionTitleRegular,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyles.hintText.copyWith(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.textTertiary),
      ),
    ),
  );
}

Widget _currencySelector(
  BuildContext context,
  String selected,
  ValueChanged<String> onChanged,
) {
  final currencies = ExchangeRateService.supportedCurrencies.toList();
  return Builder(
    builder: (btnCtx) {
      return GestureDetector(
        onTap: () async {
          final RenderBox button = btnCtx.findRenderObject() as RenderBox;
          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final result = await showMenu<String>(
            context: context,
            position: RelativeRect.fromRect(
              button.localToGlobal(Offset.zero, ancestor: overlay) &
                  button.size,
              Offset.zero & overlay.size,
            ),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            items: currencies.map((c) {
              final isSel = c == selected;
              return PopupMenuItem<String>(
                value: c,
                height: 36,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: isSel
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      c,
                      style: TextStyles.subtitle.copyWith(
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
          if (result != null) onChanged(result);
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selected, style: TextStyles.subtitleRegular),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      );
    },
  );
}

Widget _dateButton(DateTime date, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: TextStyles.subtitleRegular,
          ),
          const Spacer(),
          Icon(Icons.calendar_today, size: 16, color: AppColors.textTertiary),
        ],
      ),
    ),
  );
}

Widget _durationSelector(int selected, ValueChanged<int> onChanged) {
  const options = [1, 3, 6, 12, 24, 36, 60];
  return Builder(
    builder: (btnCtx) {
      return GestureDetector(
        onTap: () async {
          final RenderBox button = btnCtx.findRenderObject() as RenderBox;
          final overlay =
              Overlay.of(btnCtx).context.findRenderObject() as RenderBox;
          final result = await showMenu<int>(
            context: btnCtx,
            position: RelativeRect.fromRect(
              button.localToGlobal(Offset.zero, ancestor: overlay) &
                  button.size,
              Offset.zero & overlay.size,
            ),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            items: options.map((m) {
              final isSel = m == selected;
              return PopupMenuItem<int>(
                value: m,
                height: 36,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: isSel
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AssetConfig.durationMonths.replaceAll('{m}', '$m'),
                      style: TextStyles.subtitle.copyWith(
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
          if (result != null) onChanged(result);
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AssetConfig.durationMonths.replaceAll('{m}', '$selected'),
                style: TextStyles.subtitleRegular,
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      );
    },
  );
}
