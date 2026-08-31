import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
// import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/widgets/glass_logo.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
// import 'package:optivus/services/auth_service.dart';
import 'package:optivus/widgets/wavy_loading_indicator.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/core/utils/auth_form_readiness.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/core/widgets/auth_text_field.dart';
import 'package:optivus/widgets/auth_back_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR TOKENS
// ─────────────────────────────────────────────────────────────────────────────
const _kInk = Color(0xFF0F111A);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);
const _kRed = Color(0xFFEF4444);
const _kCream = Color(0xFFF6E6B4);
const _kBg = Color(0xFFFCF8EE);

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscurePass = true;
  bool _resetLoading = false;
  Future<void>? _authOperation;
  Future<bool>? _googleOperation;
  String? _errorMsg;
  String? _successMsg;
  String? _emailError;
  String? _passwordError;
  bool _ctaRevealed = false;
  // final AuthRepository _authRepository = AuthRepository(AuthService());

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_handleFormChanged);
    _passCtrl.addListener(_handleFormChanged);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_handleFormChanged);
    _passCtrl.removeListener(_handleFormChanged);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool get _formReady =>
      isLoginFormReady(email: _emailCtrl.text, password: _passCtrl.text);

  void _handleFormChanged() {
    final emailValid = isBasicEmailFormatValid(_emailCtrl.text);
    final passwordPresent = _passCtrl.text.isNotEmpty;
    final ready = emailValid && passwordPresent;
    setState(() {
      if (ready) _ctaRevealed = true;
      if (emailValid) _emailError = null;
      if (passwordPresent) _passwordError = null;
      _errorMsg = null;
      _successMsg = null;
    });
  }

  bool _validate() {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final emailError = email.isEmpty
        ? 'Please enter your email address.'
        : (!isBasicEmailFormatValid(email)
              ? 'Please enter a valid email address.'
              : null);
    final passwordError = pass.isEmpty ? 'Please enter your password.' : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null) {
      _emailFocus.requestFocus();
      return false;
    }
    if (passwordError != null) {
      _passFocus.requestFocus();
      return false;
    }
    return true;
  }

  // ── Firebase sign in ──────────────────────────────────────────────────────

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_validate()) return;
    if (ref.read(authProvider).isLoading ||
        _authOperation != null ||
        _googleOperation != null) {
      return;
    }

    final authOperation = ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);

    setState(() {
      _errorMsg = null;
      _successMsg = null;
      _authOperation = authOperation;
    });

    try {
      await authOperation;
      if (!mounted) return;
      // Route based on onboarding completion status
      // Handled by GoRouter redirect automatically
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMsg = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _authOperation = null);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    if (ref.read(authProvider).isLoading ||
        _authOperation != null ||
        _googleOperation != null) {
      return;
    }

    final operation = ref.read(authProvider.notifier).signInWithGoogle();
    setState(() {
      _errorMsg = null;
      _successMsg = null;
      _googleOperation = operation;
    });
    try {
      await operation;
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMsg = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _googleOperation = null);
    }
  }

  // ── Forgot password ───────────────────────────────────────────────────────

  Future<void> _forgotPassword() async {
    if (_resetLoading) return;

    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Enter your email to reset your password.');
      _emailFocus.requestFocus();
      return;
    }

    if (!isBasicEmailFormatValid(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      _emailFocus.requestFocus();
      return;
    }

    setState(() {
      _resetLoading = true;
      _errorMsg = null;
      _successMsg = null;
    });

    try {
      await ref.read(authProvider.notifier).sendPasswordResetEmail(email);

      if (!mounted) return;
      setState(() {
        _resetLoading = false;
        _successMsg = 'Password reset email sent to $email.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resetLoading = false;
        _errorMsg = friendlyAuthError(error);
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authLoading = ref.watch(authProvider).isLoading;
    final media = MediaQuery.of(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final allowAdaptiveScroll =
        media.size.height < 650 || media.textScaler.scale(16) > 19.2;

    return PopScope(
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && keyboardOpen) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: AuthLayout.authBackgroundColor,
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('login-form-scroll'),
                    physics: allowAdaptiveScroll
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuthLayout.horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: AuthLayout.backButtonTopInset),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AuthBackButton(
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/signup'),
                          ),
                        ),
                        AnimatedContainer(
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          height: keyboardOpen ? 4 : 8,
                        ),

                        // Logo
                        AnimatedContainer(
                          key: const Key('login-logo'),
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          width: keyboardOpen
                              ? AuthLayout.compactLogoSize
                              : AuthLayout.standardLogoSize,
                          height: keyboardOpen
                              ? AuthLayout.compactLogoSize
                              : AuthLayout.standardLogoSize,
                          child: const FittedBox(child: GlassLogo()),
                        ),
                        AnimatedContainer(
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          height: keyboardOpen ? 4 : 8,
                        ),

                        // Welcome back
                        AnimatedDefaultTextStyle(
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          style: TextStyle(
                            fontSize: keyboardOpen ? 22 : 26,
                            fontWeight: FontWeight.w900,
                            color: _kInk,
                            letterSpacing: -0.8,
                          ),
                          child: const Text('Welcome back.', maxLines: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to your Optivus account.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AnimatedContainer(
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          height: keyboardOpen ? 6 : 14,
                        ),

                        // Form
                        LiquidGlassPanel(
                          padding: AuthLayout.formPanelPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email
                              _FieldLabel('Email'),
                              const SizedBox(
                                height: AuthLayout.labelToFieldGap,
                              ),
                              AuthTextField(
                                controller: _emailCtrl,
                                focusNode: _emailFocus,
                                semanticLabel: 'Email',
                                hint: 'you@example.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                next: _passFocus,
                              ),
                              if (_emailError != null)
                                _InlineFieldError(message: _emailError!),
                              const SizedBox(height: AuthLayout.fieldGap),

                              // Password
                              _FieldLabel('Password'),
                              const SizedBox(
                                height: AuthLayout.labelToFieldGap,
                              ),
                              AuthTextField(
                                controller: _passCtrl,
                                focusNode: _passFocus,
                                semanticLabel: 'Password',
                                hint: 'Your password',
                                icon: Icons.lock_outline,
                                obscure: _obscurePass,
                                autofillHints: const [AutofillHints.password],
                                onSubmit: (_) => _signIn(),
                                suffix: AuthEyeButton(
                                  obscure: _obscurePass,
                                  onToggle: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                ),
                              ),
                              if (_passwordError != null)
                                _InlineFieldError(message: _passwordError!),
                              const SizedBox(height: 10),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: _resetLoading ? null : _forgotPassword,
                                  child: Text(
                                    _resetLoading
                                        ? 'Sending reset email...'
                                        : 'Forgot Password?',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _kAmber,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Error/Success messages
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _errorMsg!),
                        ],

                        if (_successMsg != null) ...[
                          const SizedBox(height: 12),
                          _SuccessBanner(message: _successMsg!),
                        ],

                        const SizedBox(height: 14),
                        _GoogleAuthProviderButton(
                          loading: _googleOperation != null,
                          onPressed: authLoading ? null : _signInWithGoogle,
                        ),
                        const SizedBox(height: 14),
                        _AuthRoutePrompt(
                          prompt: "Don't have an account?",
                          action: 'Sign Up',
                          onPressed: () => context.push('/signup'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                AnimatedContainer(
                  duration: OptivusMotion.standardDuration,
                  curve: Curves.easeInOutCubic,
                  height: _ctaRevealed || authLoading ? 74 : 0,
                  child: AnimatedSwitcher(
                    duration: OptivusMotion.fastDuration,
                    switchInCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: !_ctaRevealed && !authLoading
                        ? const SizedBox.shrink(
                            key: ValueKey('login-primary-hidden'),
                          )
                        : Padding(
                            key: const ValueKey('login-primary-visible'),
                            padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
                            child: authLoading
                                ? _LoadingButton(
                                    operation: _authOperation,
                                    label: 'Signing in…',
                                  )
                                : AppButton(
                                    key: const Key('login-submit'),
                                    text: 'Sign In',
                                    enabled: _formReady,
                                    onPressed: _formReady ? _signIn : null,
                                  ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleAuthProviderButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const _GoogleAuthProviderButton({
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue with Google',
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.48 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('login-google'),
            borderRadius: BorderRadius.circular(25),
            onTap: onPressed,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else
                    const Icon(
                      Icons.g_mobiledata_rounded,
                      color: _kInk,
                      size: 22,
                    ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Continue with Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED LOCAL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _kSub,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _InlineFieldError extends StatelessWidget {
  final String message;

  const _InlineFieldError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Padding(
        padding: const EdgeInsets.only(top: 7, left: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 15, color: _kRed),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _kRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthRoutePrompt extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onPressed;

  const _AuthRoutePrompt({
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            action,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _kRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kRed.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kRed,
                    fontWeight: FontWeight.w600,
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

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF22C55E),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
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

// ─────────────────────────────────────────────────────────────────────────────
// LOADING BUTTON — glass pill with wavy spinner, mirrors AppButton dimensions
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingButton extends StatelessWidget {
  final Future<void>? operation;
  final String label;

  const _LoadingButton({this.operation, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(33),
        color: Colors
            .transparent, // Fix: transparent background eliminates the rectangular grey-blue border visual bug
        boxShadow: [
          // Soft black shadow (10% opacity)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          // Accent glow (15% opacity)
          BoxShadow(
            color: const Color(0xFF92E0FF).withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 0,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WavyLoadingIndicator(size: 30, operation: operation),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
