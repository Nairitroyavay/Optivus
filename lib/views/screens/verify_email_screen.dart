import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/verification_lifecycle_state.dart';

const _ink = OptivusColors.ink;
const _sub = OptivusColors.textSecondary;
const _amber = Color(0xFFFFB830);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  late final VerificationLifecycleController _lifecycleController;
  bool _loggedScreenEntry = false;

  @override
  void initState() {
    super.initState();
    _lifecycleController = ref.read(verificationLifecycleProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lifecycleController.activate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleController.detach();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lifecycleController.resume();
    } else {
      _lifecycleController.pause();
    }
  }

  Future<void> _logout() async {
    if (ref.read(authProvider).isLoading) return;
    final controller = ref.read(verificationLifecycleProvider.notifier)
      ..clearError()
      ..clearSuccessMessage();
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      if (mounted) {
        final authError = ref.read(authProvider).error;
        if (authError != null) {
          controller.showAccountError(authError);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final lifecycle = ref.watch(verificationLifecycleProvider);
    if (!_loggedScreenEntry) {
      _loggedScreenEntry = true;
      if (kDebugMode) {
        final state = switch (auth.verificationEmailSendStatus) {
          VerificationEmailSendStatus.sent => 'sent',
          VerificationEmailSendStatus.failed => 'failed',
          VerificationEmailSendStatus.pending => 'pending',
        };
        debugPrint(
          '[EmailVerification] stage=verify_screen_entered initialSendState=$state',
        );
      }
    }
    final email = auth.user?.email?.trim();
    final displayEmail = email == null || email.isEmpty
        ? 'Email address unavailable'
        : email;
    final actionsEnabled = !auth.isLoading && !lifecycle.resendInFlight;
    final deliveryFailed =
        auth.verificationEmailSendStatus == VerificationEmailSendStatus.failed;
    final activeError = lifecycle.error ?? (deliveryFailed ? auth.error : null);
    final messageError = activeError?.publicMessage;
    final successMessage = activeError == null
        ? lifecycle.successMessage
        : null;
    final titleCopy = switch (auth.verificationEmailSendStatus) {
      VerificationEmailSendStatus.sent => 'We sent you a verification link',
      VerificationEmailSendStatus.failed =>
        'We couldn\'t send the verification link',
      VerificationEmailSendStatus.pending =>
        'Sending your verification link...',
    };

    return PopScope(
      // The auth router owns this destination. System Back stays here; the
      // explicit account actions below use transactional logout.
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: OptivusTheme.authOverlayStyle,
        child: Scaffold(
          backgroundColor: AuthLayout.authBackgroundColor,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [OptivusColors.onboardingTop, Color(0xFFFCF8EE)],
                stops: [0, 0.58],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    key: const Key('verify-email-scroll-view'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuthLayout.horizontalPadding,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),
                              const _HeroIcon(),
                              const SizedBox(height: 14),
                              const Text(
                                'Verify your email',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                titleCopy,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _sub,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _VerificationCard(email: displayEmail),
                              const SizedBox(height: 10),
                              _StableMessageRegion(
                                error: messageError,
                                success: successMessage,
                              ),
                              const SizedBox(height: 14),
                              _ResendAction(
                                key: const Key('verify-email-resend'),
                                cooldown: lifecycle.resendSecondsRemaining,
                                resending: lifecycle.resendInFlight,
                                enabled: actionsEnabled,
                                onResend: () => ref
                                    .read(
                                      verificationLifecycleProvider.notifier,
                                    )
                                    .resend(),
                              ),
                              const SizedBox(height: 18),
                              _TextAction(
                                key: const Key('verify-email-use-another'),
                                label: 'Use another email',
                                enabled: actionsEnabled,
                                onTap: _logout,
                              ),
                              const SizedBox(height: 6),
                              _TextAction(
                                key: const Key('verify-email-sign-out'),
                                label: 'Sign out',
                                enabled: actionsEnabled,
                                muted: true,
                                onTap: _logout,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.85),
            _amber.withValues(alpha: 0.20),
          ],
        ),
        border: Border.all(
          color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _amber.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: _ink, shape: BoxShape.circle),
          child: Padding(
            padding: EdgeInsets.all(9),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final String email;

  const _VerificationCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('verify-email-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _amber.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Identity Section ──────────────────────────────────
          Semantics(
            label: 'Sent to email: $email',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SENT TO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _sub,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.alternate_email_rounded,
                      color: _amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0x12000000)),
          const SizedBox(height: 14),

          // ── Step 1 ───────────────────────────────────────────
          const _StepRow(
            number: '1',
            title: 'Open your email',
            description: 'Tap the verification link we sent.',
          ),

          const SizedBox(height: 12),

          // ── Step 2 ───────────────────────────────────────────
          const _StepRow(
            number: '2',
            title: 'Return to Optivus',
            description: 'We\'ll check it automatically.',
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0x12000000)),
          const SizedBox(height: 12),

          // ── Passive Waiting Status ────────────────────────────
          const _PassiveWaitingStatus(),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _ink.withValues(alpha: 0.07),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: _sub,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassiveWaitingStatus extends StatefulWidget {
  const _PassiveWaitingStatus();

  @override
  State<_PassiveWaitingStatus> createState() => _PassiveWaitingStatusState();
}

class _PassiveWaitingStatusState extends State<_PassiveWaitingStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Purely visual presentation animation — does NOT trigger any network requests or polling.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Waiting for verification',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.45 + (_pulseController.value * 0.55),
                child: child,
              );
            },
            child: const DecoratedBox(
              decoration: BoxDecoration(color: _amber, shape: BoxShape.circle),
              child: SizedBox(width: 8, height: 8),
            ),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Waiting for verification',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '•••',
            style: TextStyle(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StableMessageRegion extends StatelessWidget {
  final String? error;
  final String? success;

  const _StableMessageRegion({required this.error, required this.success});

  @override
  Widget build(BuildContext context) {
    final message = error ?? success;
    final isError = error != null;
    return SizedBox(
      key: const Key('verify-email-message-region'),
      height: 48,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: message == null
            ? const SizedBox(
                key: Key('verify-email-message-empty'),
                height: 40,
                width: double.infinity,
              )
            : Container(
                key: ValueKey(message),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                alignment: Alignment.center,
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isError ? _red : _green,
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
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
  final bool enabled;
  final VoidCallback onResend;

  const _ResendAction({
    super.key,
    required this.cooldown,
    required this.resending,
    required this.enabled,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final canResend = enabled && !resending && cooldown == 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.center,
      child: resending
          ? const Text(
              'Sending verification email...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _sub,
              ),
            )
          : cooldown > 0
          ? Text(
              'Resend available in ${cooldown}s',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _sub,
              ),
            )
          : Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Didn\'t get it?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _sub,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: canResend ? onResend : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Text(
                      'Resend email',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: canResend ? _ink : _sub,
                        decoration: TextDecoration.underline,
                        decorationColor: canResend
                            ? _ink.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool muted;
  final VoidCallback onTap;

  const _TextAction({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: muted ? 12.5 : 13.5,
            fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
            color: muted ? _sub : _ink,
          ),
        ),
      ),
    );
  }
}
