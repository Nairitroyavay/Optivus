import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
// import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
// import 'package:optivus/services/auth_service.dart';
import 'package:optivus/widgets/wavy_loading_indicator.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/core/utils/password_policy.dart';
import 'package:optivus/core/utils/auth_form_readiness.dart';
import 'package:optivus/core/theme/auth_layout.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_motion.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/core/widgets/auth_text_field.dart';
import 'package:optivus/widgets/auth_back_button.dart';
import 'package:optivus/widgets/glass_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR TOKENS
// ─────────────────────────────────────────────────────────────────────────────
const _kInk = Color(0xFF0F111A);
const _kSub = Color(0xFF6B7280);
const _kAmber = Color(0xFFFFB830);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kCream = Color(0xFFF6E6B4);
const _kBg = Color(0xFFFCF8EE);
const _compactPasswordRuleLabels = [
  '8+ characters',
  'Capital letter',
  'Number',
  'Special character',
];

// ─────────────────────────────────────────────────────────────────────────────
// SIGNUP SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Focus nodes
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _scrollController = ScrollController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  Future<void>? _authOperation;
  String? _errorMsg;
  String? _successMsg;
  String? _accountExistsEmail;
  bool _resetLoading = false;
  bool _ctaRevealed = false;
  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmationTouched = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmationError;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(_handleFormChanged);
    _nameCtrl.addListener(_handleFormChanged);
    _emailCtrl.addListener(_handleFormChanged);
    _confirmCtrl.addListener(_handleFormChanged);
    _nameFocus.addListener(_handleNameFocus);
    _emailFocus.addListener(_handleEmailFocus);
    _passFocus.addListener(_handlePasswordFocus);
    _confirmFocus.addListener(_handleConfirmationFocus);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_handleFormChanged);
    _emailCtrl.removeListener(_handleFormChanged);
    _confirmCtrl.removeListener(_handleFormChanged);
    _passCtrl.removeListener(_handleFormChanged);
    _nameFocus.removeListener(_handleNameFocus);
    _emailFocus.removeListener(_handleEmailFocus);
    _passFocus.removeListener(_handlePasswordFocus);
    _confirmFocus.removeListener(_handleConfirmationFocus);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────

  bool get _formReady => isSignupFormReady(
    name: _nameCtrl.text,
    email: _emailCtrl.text,
    password: _passCtrl.text,
    confirmation: _confirmCtrl.text,
  );

  void _handleNameFocus() {
    if (_nameFocus.hasFocus) {
      _nameTouched = true;
    } else if (_nameTouched) {
      final name = _nameCtrl.text.trim();
      setState(() {
        _nameError = name.length < 2
            ? (name.isEmpty
                  ? 'Please enter your full name.'
                  : 'Name must be at least 2 characters.')
            : null;
      });
    }
  }

  void _handleEmailFocus() {
    if (_emailFocus.hasFocus) {
      _emailTouched = true;
    } else if (_emailTouched) {
      final email = _emailCtrl.text.trim();
      setState(() {
        _emailError = email.isEmpty
            ? 'Please enter your email address.'
            : (!isBasicEmailFormatValid(email)
                  ? 'Please enter a valid email address.'
                  : null);
      });
    }
  }

  void _handlePasswordFocus() {
    if (_passFocus.hasFocus) {
      _passwordTouched = true;
      setState(() {});
    } else if (_passwordTouched) {
      final password = _passCtrl.text;
      setState(() {
        _passwordError = password.isEmpty
            ? 'Please enter a password.'
            : (!isOptivusPasswordValid(password)
                  ? 'Password does not meet all requirements.'
                  : null);
      });
    }
  }

  void _handleConfirmationFocus() {
    if (_confirmFocus.hasFocus) {
      _confirmationTouched = true;
      setState(() {});
    } else if (_confirmationTouched) {
      setState(() {
        _confirmationError = _confirmCtrl.text != _passCtrl.text
            ? 'Passwords do not match.'
            : null;
      });
    }
  }

  void _handleFormChanged() {
    if (!mounted) return;
    final ready = _formReady;
    setState(() {
      if (ready) _ctaRevealed = true;
      if (_nameCtrl.text.trim().length >= 2) _nameError = null;
      if (isBasicEmailFormatValid(_emailCtrl.text)) _emailError = null;
      if (isOptivusPasswordValid(_passCtrl.text)) _passwordError = null;
      if (_confirmationTouched && _confirmCtrl.text.isNotEmpty) {
        _confirmationError = _confirmCtrl.text == _passCtrl.text
            ? null
            : 'Passwords do not match.';
      } else if (_confirmCtrl.text == _passCtrl.text) {
        _confirmationError = null;
      }
      _errorMsg = null;
      _successMsg = null;
    });
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    setState(() {
      _nameError = name.length < 2
          ? (name.isEmpty
                ? 'Please enter your full name.'
                : 'Name must be at least 2 characters.')
          : null;
      _emailError = email.isEmpty
          ? 'Please enter your email address.'
          : (!isBasicEmailFormatValid(email)
                ? 'Please enter a valid email address.'
                : null);
      _passwordError = pass.isEmpty
          ? 'Please enter a password.'
          : (!isOptivusPasswordValid(pass)
                ? 'Password does not meet all requirements below.'
                : null);
      _confirmationError = confirm != pass ? 'Passwords do not match.' : null;
    });
    final focus = _nameError != null
        ? _nameFocus
        : _emailError != null
        ? _emailFocus
        : _passwordError != null
        ? _passFocus
        : _confirmationError != null
        ? _confirmFocus
        : null;
    focus?.requestFocus();
    return focus == null;
  }

  // ── Firebase create account ─────────────────────────────────────────────

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (!_validate()) return;

    if (ref.read(authProvider).isLoading || _authOperation != null) return;

    final authOperation = ref
        .read(authProvider.notifier)
        .signup(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);

    setState(() {
      _errorMsg = null;
      _successMsg = null;
      _accountExistsEmail = null;
      _authOperation = authOperation;
    });

    try {
      await authOperation;
      if (!mounted) return;
      // Signup always goes to onboarding first
      // Handled by GoRouter redirect automatically
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _accountExistsEmail = isEmailAlreadyInUseError(error)
            ? _emailCtrl.text.trim()
            : null;
        _errorMsg = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _authOperation = null);
      }
    }
  }

  Future<void> _sendResetForExistingAccount() async {
    if (_resetLoading) return;

    final currentEmail = _emailCtrl.text.trim();
    final isValidEmail = RegExp(
      r'^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$',
      caseSensitive: false,
    ).hasMatch(currentEmail);

    if ((currentEmail.isEmpty || !isValidEmail) &&
        _accountExistsEmail != null &&
        _accountExistsEmail!.isNotEmpty) {
      _emailCtrl.text = _accountExistsEmail!;
    }

    final email =
        (_emailCtrl.text.isNotEmpty
                ? _emailCtrl.text
                : _accountExistsEmail ?? '')
            .trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Enter your email to reset your password.');
      return;
    }

    setState(() {
      _resetLoading = true;
      _successMsg = null;
    });

    try {
      await ref.read(authProvider.notifier).sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _successMsg = 'Password reset email sent to $email.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMsg = friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  void _useAnotherEmail() {
    setState(() {
      _emailCtrl.clear();
      _errorMsg = null;
      _successMsg = null;
      _accountExistsEmail = null;
    });
    FocusScope.of(context).requestFocus(_emailFocus);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authLoading = ref.watch(authProvider).isLoading;
    final media = MediaQuery.of(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final allowAdaptiveScroll =
        media.size.height < 650 || media.textScaler.scale(16) > 19.2;
    final showPasswordGuidance = _passFocus.hasFocus;

    return PopScope(
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && keyboardOpen) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: OptivusTheme.authOverlayStyle,
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
              stops: [0.0, 0.45],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('signup-form-scroll'),
                    controller: _scrollController,
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
                        AnimatedContainer(
                          key: const Key('signup-logo'),
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

                        // Title
                        AnimatedContainer(
                          key: const Key('signup-title'),
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          height: keyboardOpen ? 22 : 28,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedDefaultTextStyle(
                              duration: OptivusMotion.standardDuration,
                              curve: Curves.easeInOutCubic,
                              style: TextStyle(
                                fontSize: keyboardOpen ? 18 : 22,
                                fontWeight: FontWeight.w900,
                                color: _kInk,
                                letterSpacing: -0.6,
                              ),
                              child: const Text(
                                'Create your Optivus account',
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: OptivusMotion.standardDuration,
                          curve: Curves.easeInOutCubic,
                          height: keyboardOpen ? 6 : 10,
                        ),

                        // Form panel
                        LiquidGlassPanel(
                          padding: AuthLayout.formPanelPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name
                              _FieldLabel('Full Name'),
                              const SizedBox(
                                height: AuthLayout.labelToFieldGap,
                              ),
                              AuthTextField(
                                controller: _nameCtrl,
                                focusNode: _nameFocus,
                                hint: 'Your full name',
                                icon: Icons.person_outline,
                                autofillHints: const [AutofillHints.name],
                                next: _emailFocus,
                              ),
                              if (_nameError != null)
                                _InlineFieldError(message: _nameError!),
                              const SizedBox(height: AuthLayout.fieldGap),

                              // Email
                              _FieldLabel('Email'),
                              const SizedBox(
                                height: AuthLayout.labelToFieldGap,
                              ),
                              AuthTextField(
                                controller: _emailCtrl,
                                focusNode: _emailFocus,
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
                                hint: 'Min 8 chars, capital, number, sign',
                                icon: Icons.lock_outline,
                                obscure: _obscurePass,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                next: _confirmFocus,
                                suffix: AuthEyeButton(
                                  obscure: _obscurePass,
                                  onToggle: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                ),
                              ),
                              if (_passwordError != null)
                                _InlineFieldError(message: _passwordError!),

                              // Live password rules panel
                              AnimatedSize(
                                duration: OptivusMotion.standardDuration,
                                curve: Curves.easeInOutCubic,
                                child: !showPasswordGuidance
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        key: const Key(
                                          'signup-password-guidance',
                                        ),
                                        padding: const EdgeInsets.only(top: 6),
                                        child: _PasswordRulesPanel(
                                          password: _passCtrl.text,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: AuthLayout.fieldGap),

                              // Confirm Password and its local validation
                              // move together above the keyboard.
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Confirm Password'),
                                  const SizedBox(
                                    height: AuthLayout.labelToFieldGap,
                                  ),
                                  AuthTextField(
                                    controller: _confirmCtrl,
                                    focusNode: _confirmFocus,
                                    hint: 'Repeat your password',
                                    icon: Icons.lock_outline,
                                    obscure: _obscureConfirm,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    onSubmit: (_) => FocusManager
                                        .instance
                                        .primaryFocus
                                        ?.unfocus(),
                                    suffix: AuthEyeButton(
                                      obscure: _obscureConfirm,
                                      onToggle: () => setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      ),
                                    ),
                                  ),
                                  if (_confirmationError != null)
                                    KeyedSubtree(
                                      key: const Key('signup-confirm-error'),
                                      child: _InlineFieldError(
                                        message: _confirmationError!,
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: AuthLayout.fieldGap),

                              // Terms
                              Text(
                                'By joining, you agree to our Terms of Service.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Error message
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 12),
                          _accountExistsEmail == null
                              ? _ErrorBanner(message: _errorMsg!)
                              : _AccountExistsBanner(
                                  message: _errorMsg!,
                                  resetLoading: _resetLoading,
                                  onLogin: () => context.go('/login'),
                                  onForgotPassword:
                                      _sendResetForExistingAccount,
                                  onUseAnotherEmail: _useAnotherEmail,
                                ),
                        ],

                        if (_successMsg != null) ...[
                          const SizedBox(height: 12),
                          _SuccessBanner(message: _successMsg!),
                        ],

                        // Primary Action Button (Create Account / Loading)
                        const SizedBox(height: 14),
                        if (_ctaRevealed || authLoading)
                          Padding(
                            key: const ValueKey('signup-primary-visible'),
                            padding: EdgeInsets.zero,
                            child: authLoading
                                ? _LoadingButton(operation: _authOperation)
                                : AppButton(
                                    key: const Key('signup-submit'),
                                    text: 'Create Account',
                                    enabled: _formReady,
                                    onPressed: _formReady
                                        ? _createAccount
                                        : null,
                                  ),
                          )
                        else
                          const SizedBox.shrink(
                            key: ValueKey('signup-primary-hidden'),
                          ),

                        const SizedBox(height: 24),
                      ],
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
// LIVE PASSWORD RULES PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordRulesPanel extends StatelessWidget {
  final String password;
  const _PasswordRulesPanel({required this.password});

  @override
  Widget build(BuildContext context) {
    final isValid = isOptivusPasswordValid(password);
    return ClipRRect(
      key: isValid
          ? const Key('signup-password-guidance-success')
          : const Key('signup-password-guidance-detailed'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.60),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isValid
                ? _kGreen.withValues(alpha: 0.35)
                : OptivusColors.borderNeutral.withValues(alpha: 0.50),
            width: 1,
          ),
        ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (isValid) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _kGreen,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      isValid
                          ? 'All password requirements met'
                          : 'Password requirements',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isValid ? _kGreen : _kSub,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: optivusPasswordRules.indexed.map((entry) {
                    final (index, rule) = entry;
                    final passed = rule.check(password);
                    return SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: passed ? _kGreen : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: passed
                                    ? _kGreen
                                    : _kSub.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: passed
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 9,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: passed
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: passed ? _kGreen : _kSub,
                              ),
                              child: Text(
                                _compactPasswordRuleLabels[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
    );
  }
}

class _AccountExistsBanner extends StatelessWidget {
  final String message;
  final bool resetLoading;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onUseAnotherEmail;

  const _AccountExistsBanner({
    required this.message,
    required this.resetLoading,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onUseAnotherEmail,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _kAmber.withValues(alpha: 0.38),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _kAmber,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kInk,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InlineAuthAction(
                  label: 'Log in',
                  icon: Icons.login_rounded,
                  onTap: onLogin,
                ),
                _InlineAuthAction(
                  label: resetLoading ? 'Sending...' : 'Forgot password',
                  icon: Icons.lock_reset_rounded,
                  onTap: resetLoading ? null : onForgotPassword,
                ),
                _InlineAuthAction(
                  label: 'Use another email',
                  icon: Icons.alternate_email_rounded,
                  onTap: onUseAnotherEmail,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAuthAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _InlineAuthAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: _kInk),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _kGreen.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: _kGreen,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING BUTTON — glass pill with wavy spinner, mirrors AppButton dimensions
// ─────────────────────────────────────────────────────────────────────────────
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
              color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WavyLoadingIndicator(size: 30, operation: operation),
              const SizedBox(width: 10),
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Creating account…',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
// FIELD LABEL
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
