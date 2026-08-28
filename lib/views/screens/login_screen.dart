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
import 'package:optivus/core/utils/focus_utils.dart';

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
  String? _errorMsg;
  String? _successMsg;
  String? _emailError;
  String? _passwordError;
  bool _ctaRevealed = false;
  final _emailFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
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
      _focusAndReveal(_emailFocus, _emailFieldKey);
      return false;
    }
    if (passwordError != null) {
      _focusAndReveal(_passFocus, _passwordFieldKey);
      return false;
    }
    return true;
  }

  void _focusAndReveal(FocusNode focusNode, GlobalKey key) {
    focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = key.currentContext;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    });
  }

  // ── Firebase sign in ──────────────────────────────────────────────────────

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_validate()) return;
    if (ref.read(authProvider).isLoading || _authOperation != null) return;

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

  // ── Forgot password ───────────────────────────────────────────────────────

  Future<void> _forgotPassword() async {
    if (_resetLoading) return;

    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = 'Enter your email to reset your password.');
      _focusAndReveal(_emailFocus, _emailFieldKey);
      return;
    }

    if (!isBasicEmailFormatValid(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      _focusAndReveal(_emailFocus, _emailFieldKey);
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && keyboardOpen) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: Scaffold(
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 50),

                        // Logo
                        const GlassLogo(),
                        const SizedBox(height: 32),

                        // Welcome back
                        const Text(
                          'Welcome back.',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _kInk,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to your Optivus account.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blueGrey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Form
                        LiquidGlassPanel(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email
                              _FieldLabel('Email'),
                              const SizedBox(height: 6),
                              _GlassInput(
                                key: _emailFieldKey,
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
                              const SizedBox(height: 18),

                              // Password
                              _FieldLabel('Password'),
                              const SizedBox(height: 6),
                              _GlassInput(
                                key: _passwordFieldKey,
                                controller: _passCtrl,
                                focusNode: _passFocus,
                                semanticLabel: 'Password',
                                hint: 'Your password',
                                icon: Icons.lock_outline,
                                obscure: _obscurePass,
                                autofillHints: const [AutofillHints.password],
                                onSubmit: (_) => _signIn(),
                                suffix: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: IconButton(
                                    icon: Icon(
                                      _obscurePass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    tooltip: _obscurePass
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () => _obscurePass = !_obscurePass,
                                    ),
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
                          const SizedBox(height: 16),
                          _ErrorBanner(message: _errorMsg!),
                        ],

                        if (_successMsg != null) ...[
                          const SizedBox(height: 16),
                          _SuccessBanner(message: _successMsg!),
                        ],

                        const SizedBox(height: 20),
                        const _DisabledAuthProviders(),
                        const SizedBox(height: 24),
                        _AuthRoutePrompt(
                          prompt: "Don't have an account?",
                          action: 'Sign Up',
                          onPressed: () => context.push('/signup'),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: _ctaRevealed || authLoading ? 88 : 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
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
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
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

class _DisabledAuthProviders extends StatelessWidget {
  const _DisabledAuthProviders();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _DisabledProviderButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Continue with Google',
        ),
        SizedBox(height: 10),
        _DisabledProviderButton(
          icon: Icons.apple_rounded,
          label: 'Continue with Apple',
        ),
      ],
    );
  }
}

class _DisabledProviderButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DisabledProviderButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label is not configured yet.',
      child: Opacity(
        opacity: 0.48,
        child: Container(
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
              Icon(icon, color: _kInk, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: TextStyle(color: Colors.grey.shade600)),
        TextButton(onPressed: onPressed, child: Text(action)),
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

class _GlassInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final FocusNode? next;
  final Widget? suffix;
  final void Function(String)? onSubmit;
  final String? semanticLabel;
  final Iterable<String>? autofillHints;

  const _GlassInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.next,
    this.suffix,
    this.onSubmit,
    this.semanticLabel,
    this.autofillHints,
  });

  @override
  State<_GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<_GlassInput> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _focused ? 0.28 : 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _focused
              ? _kAmber.withValues(alpha: 0.70)
              : Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? _kAmber.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: _focused ? 18 : 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.50),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.5),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.5),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.15, 0.4, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.40),
                        Colors.white.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                ),
              ),
              TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                autofillHints: widget.autofillHints,
                onTapOutside: dismissPrimaryFocusOnTapOutside,
                textInputAction: widget.next != null
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted:
                    widget.onSubmit ??
                    (_) {
                      if (widget.next != null) {
                        FocusScope.of(context).requestFocus(widget.next);
                      } else {
                        FocusManager.instance.primaryFocus?.unfocus();
                      }
                    },
                style: const TextStyle(
                  color: Color(0xFF1E202A),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
                cursorColor: _kAmber,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.25),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            offset: const Offset(2, 2),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            offset: const Offset(-2, -2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: _focused ? _kAmber : const Color(0xFF1E202A),
                        size: 22,
                      ),
                    ),
                  ),
                  suffixIcon: widget.suffix,
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF1E202A).withValues(alpha: 0.40),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
