import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../services/privacy_service.dart';
import 'app_colors.dart';
import 'app_ui.dart';

/// Covers every route and dialog until local authentication completes.
class PrivacyGate extends StatefulWidget {
  const PrivacyGate({super.key, required this.child});
  final Widget child;

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> with WidgetsBindingObserver {
  bool _active = true;
  late bool _locked;
  bool _authenticating = false;
  bool _resumeNeedsPrompt = false;
  bool _promptAfterCurrent = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = PrivacyService.instance.biometricLock.value;
    PrivacyService.instance.biometricLock.addListener(_onSettingChanged);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  void _onSettingChanged() {
    if (!mounted) return;
    // Enabling already required a successful biometric challenge. The next
    // cold launch or return from background will lock this session.
    if (!PrivacyService.instance.biometricLock.value) {
      setState(() => _locked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // The system authentication prompt itself can make iOS inactive.
      // Only invalidate that prompt when the app actually backgrounds.
      if (state != AppLifecycleState.inactive || !_authenticating) {
        _generation++;
        _resumeNeedsPrompt = true;
      }
      if (mounted) {
        setState(() {
          _active = false;
          if (PrivacyService.instance.biometricLock.value) _locked = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _active = true);
      if (_locked && _resumeNeedsPrompt) {
        if (_authenticating) {
          _promptAfterCurrent = true;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
        }
      }
      _resumeNeedsPrompt = false;
    }
  }

  Future<void> _unlock() async {
    if (!mounted || !_active || !_locked || _authenticating) return;
    final generation = _generation;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final success = await PrivacyService.instance.authenticate(
        L10n.t('privacyAuthReason'),
      );
      if (mounted && success && _active && generation == _generation) {
        setState(() => _locked = false);
      }
    } on PlatformException {
      if (mounted) setState(() => _error = L10n.t('privacyAuthFailed'));
    } catch (_) {
      if (mounted) setState(() => _error = L10n.t('privacyAuthFailed'));
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
        if (_promptAfterCurrent && _active && _locked) {
          _promptAfterCurrent = false;
          WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PrivacyService.instance.biometricLock.removeListener(_onSettingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: !_active || _locked,
          child: IgnorePointer(
            ignoring: !_active || _locked,
            child: widget.child,
          ),
        ),
        if (!_active || _locked)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.surface,
              child: SafeArea(
                child: Center(
                  child: _active
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 48,
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              L10n.t('privacyLocked'),
                              style: TextStyles.sectionTitle,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: TextStyles.bodySmall),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _authenticating ? null : _unlock,
                              child: Text(L10n.t('privacyUnlock')),
                            ),
                          ],
                        )
                      : const Icon(Icons.shield_outlined, size: 48),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
