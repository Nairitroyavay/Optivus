import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/widgets/wavy_loading_indicator.dart';

const _kInk = Color(0xFF0F111A);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kCream = Color(0xFFF6E6B4);
const _kBg = Color(0xFFFCF8EE);

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldownSeconds = 60;

  bool _checking = false;
  bool _resending = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;
  String? _success;
  Future<void>? _verifyOperation;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    if (_checking) return;

    final operation = ref.read(authProvider.notifier).checkEmailVerification();
    setState(() {
      _checking = true;
      _verifyOperation = operation;
      _error = null;
      _success = null;
    });

    try {
      await operation;
      if (!mounted) return;
      setState(() => _success = 'Email verified.');
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('Email not verified yet.')
          ? 'We could not confirm it yet. Tap the link in your email, then try again.'
          : friendlyAuthError(error);
      setState(() => _error = message);
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _verifyOperation = null;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;

    setState(() {
      _resending = true;
      _error = null;
      _success = null;
    });

    try {
      await ref.read(authProvider.notifier).resendEmailVerification();
      if (!mounted) return;
      setState(() {
        _success = 'Verification email sent. Check your inbox.';
        _cooldown = _resendCooldownSeconds;
      });
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  Future<void> _signOut() async {
    if (ref.read(authProvider).isLoading) return;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final email = auth.user?.email ?? 'your email address';
    final busy = _checking || auth.isLoading;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kCream, _kBg],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 52),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: _kInk,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Verify your email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _kInk,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We sent a verification link to:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LiquidGlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alternate_email_rounded,
                                color: _kAmber,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  email,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _kInk,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Check your inbox and tap the verification link. Then return here and press I verified.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _kSub,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          _MessageBanner(
                            message: _error!,
                            color: _kRed,
                            icon: Icons.error_outline_rounded,
                          ),
                        ],
                        if (_success != null) ...[
                          const SizedBox(height: 18),
                          _MessageBanner(
                            message: _success!,
                            color: _kGreen,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _VerificationHelpCard(
                          cooldown: _cooldown,
                          resending: _resending,
                          onResend: _resend,
                          onTryAnotherEmail: _signOut,
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
                busy
                    ? _LoadingButton(operation: _verifyOperation)
                    : AppButton(text: 'I verified', onPressed: _checkVerified),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Try another email',
                        icon: Icons.edit_outlined,
                        onTap: _signOut,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Log out',
                        icon: Icons.logout_rounded,
                        danger: true,
                        onTap: _signOut,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationHelpCard extends StatelessWidget {
  final int cooldown;
  final bool resending;
  final VoidCallback onResend;
  final VoidCallback onTryAnotherEmail;

  const _VerificationHelpCard({
    required this.cooldown,
    required this.resending,
    required this.onResend,
    required this.onTryAnotherEmail,
  });

  @override
  Widget build(BuildContext context) {
    final resendEnabled = !resending && cooldown == 0;
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Didn’t receive it?',
            style: TextStyle(
              color: _kInk,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _HelpActionRow(
            icon: Icons.refresh_rounded,
            label: cooldown > 0
                ? 'Resend email in ${cooldown}s'
                : resending
                ? 'Sending...'
                : 'Resend email',
            enabled: resendEnabled,
            onTap: onResend,
          ),
          const SizedBox(height: 10),
          const _HelpTextRow(
            icon: Icons.alternate_email_rounded,
            label: 'Make sure the email address is correct',
          ),
          const SizedBox(height: 10),
          _HelpActionRow(
            icon: Icons.edit_outlined,
            label: 'Try another email',
            onTap: onTryAnotherEmail,
          ),
          const SizedBox(height: 12),
          const Text(
            'Still not finding it? Some email apps may move new app emails to Updates, Promotions, or Spam during testing.',
            style: TextStyle(
              color: _kSub,
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _HelpActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Row(
          children: [
            Icon(icon, color: _kAmber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kSub, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HelpTextRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HelpTextRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kSub, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _kSub,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? _kRed : _kInk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _MessageBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  final Future<void>? operation;

  const _LoadingButton({this.operation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(33),
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF92E0FF).withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withValues(alpha: 0.40),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
          ),
          child: Center(
            child: WavyLoadingIndicator(size: 36, operation: operation),
          ),
        ),
      ),
    );
  }
}
