import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../services/privacy_service.dart';
import 'app_colors.dart';
import 'app_ui.dart';

/// 本地身份验证完成前，遮盖所有页面和弹窗。
class PrivacyGate extends StatefulWidget {
  const PrivacyGate({super.key, required this.child, this.authenticate});
  final Widget child;
  final Future<bool> Function(String reason)? authenticate;

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> with WidgetsBindingObserver {
  bool _active = true;
  late bool _locked;
  bool _authenticating = false;
  bool _resumeNeedsPrompt = false;
  bool _promptAfterCurrent = false;
  int? _authenticatedWhileInactive;
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
    // 启用时已完成生物识别验证；下次冷启动或从后台返回时，
    // 再锁定当前会话。
    if (!PrivacyService.instance.biometricLock.value) {
      setState(() => _locked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (!PrivacyService.instance.biometricLock.value) return;
      // 系统身份验证弹窗本身就可能让 iOS 进入非活跃状态。
      // 仅在应用确实进入后台时，才使本次验证失效。
      if (state != AppLifecycleState.inactive || !_authenticating) {
        _generation++;
        _resumeNeedsPrompt = true;
        _authenticatedWhileInactive = null;
      }
      if (mounted) {
        setState(() {
          _active = false;
          if (PrivacyService.instance.biometricLock.value) _locked = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      final authenticated = _authenticatedWhileInactive == _generation;
      _authenticatedWhileInactive = null;
      setState(() {
        _active = true;
        if (authenticated) _locked = false;
      });
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
    _promptAfterCurrent = false;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final reason = L10n.t('privacyAuthReason');
      final success =
          await (widget.authenticate?.call(reason) ??
              PrivacyService.instance.authenticate(reason));
      if (mounted && success && generation == _generation) {
        if (_active) {
          setState(() => _locked = false);
        } else {
          // LocalAuthentication 可能在 iOS 通知 resumed 状态前返回。
          // 继续保留遮罩，待应用恢复前台后再应用验证成功的结果。
          _authenticatedWhileInactive = generation;
        }
      }
    } on PlatformException {
      if (mounted) setState(() => _error = L10n.t('privacyAuthFailed'));
    } catch (_) {
      if (mounted) setState(() => _error = L10n.t('privacyAuthFailed'));
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
        final shouldRetry = _promptAfterCurrent && _active && _locked;
        _promptAfterCurrent = false;
        if (shouldRetry) {
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
