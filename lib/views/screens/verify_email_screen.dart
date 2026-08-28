import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/services/native/email_launcher_service.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/auth_back_button.dart';

const _kInk = OptivusColors.ink;
const _kSub = OptivusColors.textSecondary;
const _kAmber = Color(0xFFFFB830);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kCream = OptivusColors.onboardingTop;
const _kBg = Color(0xFFFCF8EE);

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  static const _resendCooldownSeconds = 60;

  bool _checking = false;
  bool _resending = false;
  bool _openingEmail = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;
  String? _success;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cooldown = _calculateRemainingCooldown();
    if (_cooldown > 0) {
      _startCooldown();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final rem = _calculateRemainingCooldown();
      if (mounted) {
        setState(() => _cooldown = rem);
      }
      if (rem > 0) {
        _startCooldown();
      } else {
        _timer?.cancel();
      }
      _checkVerified(isAutomatic: true);
    }
  }

  int _calculateRemainingCooldown() {
    final lastSent = ref.read(authProvider).lastVerificationEmailSent;
    if (lastSent == null) return 0;
    final elapsed = DateTime.now().difference(lastSent).inSeconds;
    final remaining = _resendCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  void _startCooldown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _calculateRemainingCooldown();
      if (remaining <= 0) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      if (mounted) setState(() => _cooldown = remaining);
    });
  }

  Future<void> _checkVerified({bool isAutomatic = false}) async {
    if (!mounted || _checking || _resending) return;
    final currentUid = ref.read(authProvider).user?.uid;
    if (currentUid == null) return;

    setState(() {
      _checking = true;
      if (!isAutomatic) {
        _error = null;
        _success = null;
        _infoMessage = null;
      }
    });

    try {
      await ref.read(authProvider.notifier).checkEmailVerification();
      if (!mounted) return;
      final updatedAuth = ref.read(authProvider);
      if (updatedAuth.user?.uid != currentUid) return;

      if (updatedAuth.user?.emailVerified == true) {
        setState(() {
          _success = 'Email verified ✓';
        });
      }
    } catch (error) {
      if (!mounted) return;
      final updatedAuth = ref.read(authProvider);
      if (updatedAuth.user?.uid != currentUid) return;

      if (!isAutomatic) {
        final message = error.toString().contains('Email not verified yet.')
            ? 'We couldn’t confirm it yet. Tap the link in your email, then try again.'
            : friendlyAuthError(error);
        setState(() => _error = message);
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _openEmailApp() async {
    if (_openingEmail) return;
    setState(() {
      _openingEmail = true;
      _infoMessage = null;
      _error = null;
    });

    final launched = await ref
        .read(emailLauncherServiceProvider)
        .openEmailApp();
    if (!mounted) return;
    setState(() => _openingEmail = false);

    if (!launched) {
      setState(() {
        _infoMessage =
            'We couldn’t open an email app. Open your inbox manually, then return here.';
      });
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    if (!mounted) return;

    setState(() {
      _resending = true;
      _error = null;
      _success = null;
      _infoMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).resendEmailVerification();
      if (!mounted) return;
      _cooldown = _calculateRemainingCooldown();
      if (_cooldown == 0) {
        _cooldown = _resendCooldownSeconds;
      }
      setState(() {
        _success = 'Verification email sent. Check your inbox.';
      });
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _useAnotherEmail() async {
    if (ref.read(authProvider).isLoading) return;
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _signOut() async {
    if (ref.read(authProvider).isLoading) return;
    await ref.read(authProvider.notifier).logout();
  }

  void _showLeaveConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Dialog(
            backgroundColor: Colors.white.withValues(alpha: 0.90),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kAmber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: _kAmber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Leave verification?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is created and awaiting verification. Leaving will keep your account saved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: _kSub,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Stay here',
                            style: TextStyle(
                              color: _kInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _useAnotherEmail();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kInk,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Sign out',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final email = auth.user?.email ?? 'your email address';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showLeaveConfirmation();
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
              padding: const EdgeInsets.symmetric(
                horizontal: AuthLayout.horizontalPadding,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: AuthLayout.backButtonTopInset),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AuthBackButton(onTap: _showLeaveConfirmation),
                    ),
                    const SizedBox(height: 20),
                    // Verification Badge
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _kInk,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kInk.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    const Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Destination Subtitle
                    const Text(
                      'We sent a verification link to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kSub,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Compact Email Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.alternate_email_rounded,
                            color: _kAmber,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _kInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Concise Instruction
                    const Text(
                      'Check your inbox and tap the link.\nWe’ll continue automatically when you return.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kSub,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _MessageBanner(
                        message: _error!,
                        color: _kRed,
                        icon: Icons.error_outline_rounded,
                      ),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: 14),
                      _MessageBanner(
                        message: _success!,
                        color: _kGreen,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ],
                    if (_infoMessage != null) ...[
                      const SizedBox(height: 14),
                      _MessageBanner(
                        message: _infoMessage!,
                        color: const Color(0xFF3B82F6),
                        icon: Icons.info_outline_rounded,
                      ),
                    ],
                    const SizedBox(height: 28),
                    // PRIMARY ACTION: Open email
                    AppButton(
                      key: const Key('verify-email-open-email'),
                      text: 'Open email',
                      onPressed: _openEmailApp,
                    ),
                    const SizedBox(height: 10),
                    // SECONDARY ACTION: Resend email / Countdown
                    _ResendAction(
                      key: const Key('verify-email-resend'),
                      cooldown: _cooldown,
                      resending: _resending,
                      onResend: _resend,
                    ),
                    const SizedBox(height: 4),
                    // SMALL FALLBACK: I've verified
                    _ManualCheckFallback(
                      key: const Key('verify-email-manual-check'),
                      checking: _checking,
                      onTap: () => _checkVerified(isAutomatic: false),
                    ),
                    const SizedBox(height: 16),
                    // SUPPORTING HELP TEXT
                    const Text(
                      'Didn’t receive it? Check Spam or Promotions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // TERTIARY ACTION: Use another email
                    _TertiaryAction(
                      key: const Key('verify-email-use-another'),
                      label: 'Use another email',
                      onTap: _useAnotherEmail,
                    ),
                    const SizedBox(height: 4),
                    // LOWEST EMPHASIS: Sign out
                    _SignOutAction(
                      key: const Key('verify-email-sign-out'),
                      onTap: _signOut,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResendAction extends StatelessWidget {
  final int cooldown;
  final bool resending;
  final VoidCallback onResend;

  const _ResendAction({
    super.key,
    required this.cooldown,
    required this.resending,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !resending && cooldown == 0;
    final label = resending
        ? 'Sending...'
        : cooldown > 0
        ? 'Resend in ${cooldown}s'
        : 'Resend email';

    return TextButton.icon(
      onPressed: enabled ? onResend : null,
      icon: resending
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kInk),
            )
          : Icon(
              Icons.refresh_rounded,
              size: 16,
              color: enabled ? _kInk : _kSub.withValues(alpha: 0.65),
            ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: enabled ? _kInk : _kSub.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _ManualCheckFallback extends StatelessWidget {
  final bool checking;
  final VoidCallback onTap;

  const _ManualCheckFallback({
    super.key,
    required this.checking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: checking ? null : onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: checking
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _kSub,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'Checking...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kSub,
                  ),
                ),
              ],
            )
          : const Text(
              'I’ve verified',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kSub,
              ),
            ),
    );
  }
}

class _TertiaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TertiaryAction({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _kInk,
        ),
      ),
    );
  }
}

class _SignOutAction extends StatelessWidget {
  final VoidCallback onTap;

  const _SignOutAction({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      child: Text(
        'Sign out',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kSub.withValues(alpha: 0.8),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
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
