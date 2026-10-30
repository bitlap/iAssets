import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/l10n.dart';
import '../../services/pro_service.dart';
import '../common/app_colors.dart';

enum ProReason {
  general,
  stockLimit,
  assetTypeLimit,
  assetRecordLimit,
  crypto,
  backup,
  customStock,
}

String _reasonKey(ProReason reason) => switch (reason) {
  ProReason.stockLimit => 'proReasonStocks',
  ProReason.assetTypeLimit => 'proReasonAssetTypes',
  ProReason.assetRecordLimit => 'proReasonAssetRecords',
  ProReason.crypto => 'proReasonCrypto',
  ProReason.backup => 'proReasonBackup',
  ProReason.customStock => 'proReasonCustom',
  ProReason.general => 'proFeatures',
};

Future<void> showProPage(
  BuildContext context, {
  ProReason reason = ProReason.general,
}) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => ProPage(reason: reason)));

Future<bool> ensurePro(
  BuildContext context, {
  ProReason reason = ProReason.general,
}) async {
  if (ProService.instance.isPro) return true;
  await showProPage(context, reason: reason);
  return ProService.instance.isPro;
}

const _gold = Color(0xFFE5C286);
const _navy = Color(0xFF142B43);

class ProGate extends StatelessWidget {
  const ProGate({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: Color(0xFFB18A49),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            L10n.t('proCryptoTitle'),
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            L10n.t('proCryptoDescription'),
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            ),
            onPressed: () => showProPage(context, reason: ProReason.crypto),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(L10n.t('proView')),
          ),
          const SizedBox(height: 14),
          Text(
            L10n.t('proLegacyHint'),
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class ProPage extends StatefulWidget {
  const ProPage({super.key, this.reason = ProReason.general, this.service});
  final ProReason reason;
  final ProService? service;
  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  late final ProService service = widget.service ?? ProService.instance;
  String _selected = ProService.yearly;
  bool _upgradeLifetime = false;
  bool get _permanent => service.kind == 'legacy' || service.kind == 'lifetime';
  bool get _showPlans => !_permanent && (!service.isPro || _upgradeLifetime);
  String get _selectedId => _upgradeLifetime ? ProService.lifetime : _selected;
  ProProduct? get _product =>
      service.products.where((p) => p.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    service.refresh();
  }

  Future<void> _restore() async {
    await service.restore();
    if (!mounted) return;
    _message(
      service.error ??
          (service.isPro ? 'proPurchaseSuccess' : 'proNoPurchases'),
    );
  }

  void _message(String key) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(L10n.t(key))));

  Future<void> _purchase() async {
    final id = _selectedId;
    if (id == ProService.lifetime && service.hasSubscription) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L10n.t('proLifetimeName')),
          content: Text(L10n.t('proLifetimeWarning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(L10n.t('btnCancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(L10n.t('btnConfirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final result = await service.purchase(id);
    if (!mounted || result == 'cancelled') return;
    if (result == 'success' || result == 'owned') {
      setState(() => _upgradeLifetime = false);
    }
    _message(switch (result) {
      'success' || 'owned' => 'proPurchaseSuccess',
      'pending' => 'proPending',
      _ => 'proPurchaseError',
    });
  }

  Future<void> _open(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) _message('proLinkError');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'iAssets Pro',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: service.busy ? null : _restore,
            child: Text(L10n.t('proRestoreShort')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (!service.isPro && widget.reason != ProReason.general) ...[
            _notice(L10n.t(_reasonKey(widget.reason)), Icons.lock_outline),
            const SizedBox(height: 16),
          ],
          _hero(),
          const SizedBox(height: 24),
          if (service.isPro) ...[
            _notice(
              L10n.t(switch (service.kind) {
                'legacy' => 'proLegacy',
                'lifetime' => 'proLifetimeActive',
                _ => 'proSubscriptionActive',
              }),
              service.kind == 'legacy'
                  ? Icons.card_giftcard
                  : Icons.verified_outlined,
            ),
            const SizedBox(height: 24),
          ],
          Text(
            L10n.t('proBenefitsHeading'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _benefits(),
          const SizedBox(height: 16),
          Text(
            L10n.t('proFreeLimits'),
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          if (_showPlans) ...[
            const SizedBox(height: 28),
            Text(
              L10n.t('proChoosePlan'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              L10n.t('proSameBenefits'),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final id in ProService.productIds)
              if (!_upgradeLifetime || id == ProService.lifetime) _plan(id),
            if (!service.configured || service.privacyPolicyUrl.isEmpty)
              _statusText('proNotConfigured'),
            if (service.configured &&
                !service.legacyVerified &&
                !service.loading)
              _statusText('proLegacyUnverified'),
            if (service.error != null) _statusText(service.error!),
            if (service.hasSubscription) _statusText('proLifetimeWarning'),
            const SizedBox(height: 12),
            Text(
              L10n.t('proRenewalTerms'),
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (service.kind == 'subscription') ...[
            TextButton(
              onPressed: () =>
                  _open('https://apps.apple.com/account/subscriptions'),
              child: Text(L10n.t('proManage')),
            ),
            if (!_upgradeLifetime)
              TextButton(
                onPressed: () => setState(() => _upgradeLifetime = true),
                child: Text(L10n.t('proUpgradeLifetime')),
              ),
          ],
          const SizedBox(height: 12),
          if (!_permanent)
            Text(
              L10n.t('proLegacyHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: service.busy ? null : _restore,
                child: Text(L10n.t('proRestoreShort')),
              ),
              TextButton(
                onPressed: () => _open(
                  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                ),
                child: Text(L10n.t('proTerms')),
              ),
              if (service.privacyPolicyUrl.isNotEmpty)
                TextButton(
                  onPressed: () => _open(service.privacyPolicyUrl),
                  child: Text(L10n.t('proPrivacy')),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _hero() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF142B43), Color(0xFF244C65)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -40,
          top: -60,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _gold.withValues(alpha: .13),
                width: 30,
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: -60,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .04),
                width: 22,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 22, color: _gold),
                  const SizedBox(width: 10),
                  const Text(
                    'iAssets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                L10n.t('proHeroTitle'),
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.35,
                  letterSpacing: -.6,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                L10n.t('proHeroSubtitle'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: Colors.white.withValues(alpha: .72),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _notice(String text, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _gold.withValues(alpha: AppColors.isDark ? .12 : .16),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 2),
        Icon(
          icon,
          size: 19,
          color: AppColors.isDark ? _gold : const Color(0xFF8A682C),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _benefits() {
    Widget item(IconData icon, Color color, String title, String detail) =>
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 12),
              Text(
                L10n.t(title),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                L10n.t(detail),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item(
                  Icons.all_inclusive,
                  const Color(0xFF537EAB),
                  'proBenefitUnlimited',
                  'proBenefitUnlimitedDetail',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: item(
                  Icons.currency_bitcoin,
                  const Color(0xFFB38A43),
                  'proBenefitCrypto',
                  'proBenefitCryptoDetail',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item(
                  Icons.import_export_rounded,
                  const Color(0xFF4C8D79),
                  'proBenefitBackup',
                  'proBenefitBackupDetail',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: item(
                  Icons.edit_note_rounded,
                  const Color(0xFF8A6AA6),
                  'proBenefitCustom',
                  'proBenefitCustomDetail',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plan(String id) {
    final selected = _selectedId == id;
    final price = service.products.where((p) => p.id == id).firstOrNull?.price;
    final (name, detail) = switch (id) {
      ProService.monthly => ('proMonthlyName', 'proMonthlyDetail'),
      ProService.yearly => ('proYearlyName', 'proYearlyDetail'),
      _ => ('proLifetimeName', 'proLifetimeDetail'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? _gold.withValues(alpha: AppColors.isDark ? .10 : .13)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? const Color(0xFFC39A57) : AppColors.border,
              width: selected ? 1.5 : .7,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('pro-plan-$id'),
            onTap: service.busy ? null : () => setState(() => _selected = id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 21,
                    color: selected
                        ? const Color(0xFFB18A49)
                        : AppColors.iconMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              L10n.t(name),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (id == ProService.yearly)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _gold.withValues(alpha: .25),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  L10n.t('proRecommended'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.isDark
                                        ? _gold
                                        : const Color(0xFF82632D),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          L10n.t(detail),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (price != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ] else
                          Text(
                            L10n.t('proUnavailable'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusText(String key) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      L10n.t(key),
      style: TextStyle(
        fontSize: 12,
        height: 1.6,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _bottomBar() {
    final continuePro = service.isPro && !_upgradeLifetime;
    final canBuy = service.canPurchase && _product != null;
    final billingKey = switch (_selectedId) {
      ProService.monthly => 'proMonthlyBilling',
      ProService.yearly => 'proYearlyBilling',
      _ => 'proLifetimeBilling',
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: .5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('pro-purchase'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.isDark ? _gold : _navy,
                    foregroundColor: AppColors.isDark ? _navy : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: service.busy || service.loading
                      ? null
                      : continuePro
                      ? () => Navigator.pop(context)
                      : canBuy
                      ? _purchase
                      : null,
                  child: service.busy || service.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          L10n.t(
                            continuePro
                                ? 'proContinue'
                                : _selectedId == ProService.lifetime
                                ? 'proUnlockLifetime'
                                : 'proSubscribe',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                continuePro
                    ? L10n.t('proAllUnlocked')
                    : _product == null
                    ? L10n.t('proUnavailable')
                    : L10n.t(billingKey).replaceAll('{price}', _product!.price),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
