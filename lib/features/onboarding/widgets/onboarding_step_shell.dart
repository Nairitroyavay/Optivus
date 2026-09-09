import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_theme.dart';
import 'package:optivus/core/widgets/recoverable_error_views.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_action_bar.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_save_button.dart';

class LiquidGlassOnboardingIndicator extends StatefulWidget {
  final double page;
  final int count;
  final List<bool> completedSteps;
  final ValueChanged<int>? onDotTap;
  final ValueChanged<int>? onDragTarget;

  const LiquidGlassOnboardingIndicator({
    super.key,
    required this.page,
    required this.count,
    required this.completedSteps,
    this.onDotTap,
    this.onDragTarget,
  });

  @override
  State<LiquidGlassOnboardingIndicator> createState() =>
      _LiquidGlassOnboardingIndicatorState();
}

class _LiquidGlassOnboardingIndicatorState
    extends State<LiquidGlassOnboardingIndicator> {
  static const double _dotD = 5.0;
  double get _gap {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 360) return 6.0;
    if (width < 400) return 8.0;
    return 11.0;
  }

  static const double _pillH = 12.0;
  static const double _pillW = 18.0;
  static const double _padH = 9.0;
  static const double _padV = 5.0;

  bool _isDragging = false;
  double? _dragPage;

  double get _step => _dotD + _gap;
  double get _trackContentW => widget.count * _dotD + (widget.count - 1) * _gap;
  double get _trackW => _trackContentW + 2 * _padH;
  double get _trackH => _pillH + 2 * _padV;

  double _cx(int i) => _padH + _dotD / 2 + i * _step;

  double _pageForDragPosition(double dx) {
    return ((dx - _padH - _dotD / 2) / _step).clamp(
      0.0,
      (widget.count - 1).toDouble(),
    );
  }

  int _nearestDragIndex() {
    return (_dragPage ?? widget.page).round().clamp(0, widget.count - 1);
  }

  void _startDrag(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragPage = widget.page.clamp(0.0, (widget.count - 1).toDouble());
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    setState(() {
      _dragPage = _pageForDragPosition(details.localPosition.dx);
    });
  }

  void _finishDrag(DragEndDetails details) {
    final targetIndex = _nearestDragIndex();

    setState(() {
      _isDragging = false;
      _dragPage = null;
    });

    if (targetIndex != widget.page.round().clamp(0, widget.count - 1)) {
      widget.onDragTarget?.call(targetIndex);
    }
  }

  void _cancelDrag() {
    setState(() {
      _isDragging = false;
      _dragPage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayPage = _isDragging ? (_dragPage ?? widget.page) : widget.page;
    final double p = displayPage.clamp(0.0, (widget.count - 1).toDouble());
    final int from = p.floor().clamp(0, widget.count - 1);
    final int to = p.ceil().clamp(0, widget.count - 1);
    final double frac = p - from.toDouble();

    final double fromCX = _cx(from);
    final double toCX = _cx(to);
    final double leadT = Curves.easeInOutCubic.transform(
      (frac * 1.6).clamp(0.0, 1.0),
    );
    final double lagT = Curves.easeInOutCubic.transform(
      ((frac - 0.35) * 1.6).clamp(0.0, 1.0),
    );
    final bool movingRight = to >= from;

    final double pillLeft = movingRight
        ? (fromCX - _pillW / 2) + lagT * (toCX - fromCX)
        : (fromCX - _pillW / 2) + leadT * (toCX - fromCX);
    final double pillRight = movingRight
        ? (fromCX + _pillW / 2) + leadT * (toCX - fromCX)
        : (fromCX + _pillW / 2) + lagT * (toCX - fromCX);

    final double pillWidth = (pillRight - pillLeft).clamp(
      _pillH,
      double.infinity,
    );
    final double pillTopLocal = _trackH / 2 - _pillH / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _startDrag,
      onHorizontalDragUpdate: _updateDrag,
      onHorizontalDragEnd: _finishDrag,
      onHorizontalDragCancel: _cancelDrag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_trackH / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: _trackW,
            height: _trackH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_trackH / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Inner tube highlight for 3D depth
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_trackH / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.3),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Glossy top highlight for track
                Positioned(
                  top: 1.5,
                  left: 10,
                  right: 10,
                  height: 3.5,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                for (int i = 0; i < widget.count; i++)
                  Positioned(
                    left: _cx(i) - _dotD / 2,
                    top: _trackH / 2 - _dotD / 2,
                    width: _dotD,
                    height: _dotD,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.completedSteps[i]
                            ? OptivusColors.success.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                Positioned(
                  left: pillLeft,
                  top: pillTopLocal,
                  width: pillWidth,
                  height: _pillH,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      boxShadow: [
                        BoxShadow(
                          color: OptivusColors.success.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(_pillH / 2),
                            border: Border.all(
                              color: Colors.transparent,
                              width: 0.0,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Inner liquid color blob
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        OptivusColors.aquaAccent.withValues(
                                          alpha: 0.75,
                                        ),
                                        OptivusColors.success.withValues(
                                          alpha: 0.75,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // White top inner glow (3D curve)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.65),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5],
                                    ),
                                  ),
                                ),
                              ),
                              // Top glossy highlight
                              Positioned(
                                top: 1,
                                left: 6,
                                right: 6,
                                height: 3.5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.8),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (int i = 0; i < widget.count; i++)
                  Positioned(
                    left: _cx(i) - _step / 2,
                    top: 0,
                    width: _step,
                    height: _trackH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onDotTap?.call(i),
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

class OnboardingStepShell extends StatelessWidget {
  static const double headerHeight = 64;

  final int currentPage;
  final double pageOffset;
  final List<bool> completedSteps;
  final String? validationMessage;
  final RecoverableError? error;
  final VoidCallback? onRetry;
  final Widget child;
  final void Function(int) onDotTap;
  final ValueChanged<int> onIndicatorDraggedTo;
  final VoidCallback? onNext;
  final VoidCallback? onSave;
  final bool showSave;
  final bool isSaving;
  final bool isSaved;
  final bool saveEnabled;
  final String ctaLabel;
  final bool showPrimaryCta;
  final bool ctaEnabled;
  final bool ctaLoading;
  final Widget? topLeftOverlay;
  final List<OnboardingAction>? actions;

  const OnboardingStepShell({
    super.key,
    required this.currentPage,
    required this.pageOffset,
    required this.completedSteps,
    required this.validationMessage,
    this.error,
    this.onRetry,
    required this.child,
    required this.onDotTap,
    required this.onIndicatorDraggedTo,
    this.onNext,
    required this.onSave,
    required this.showSave,
    required this.isSaving,
    required this.isSaved,
    required this.saveEnabled,
    required this.ctaLabel,
    this.showPrimaryCta = true,
    required this.ctaEnabled,
    required this.ctaLoading,
    this.topLeftOverlay,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = media.size.height < 600 || media.size.width < 600;
    final responsiveHeaderH = isSmall ? 50.0 : headerHeight;

    final resolvedActions =
        actions ??
        <OnboardingAction>[
          OnboardingAction(
            kind: currentPage == OnboardingStepId.todayReady.index
                ? OnboardingActionKind.enterOptivus
                : OnboardingActionKind.next,
            label: ctaLabel,
            onPressed: onNext,
            visible: showPrimaryCta,
            enabled: ctaEnabled,
            operationState: ctaLoading
                ? OnboardingActionOperationState.active
                : OnboardingActionOperationState.idle,
          ),
        ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? OptivusTheme.darkOverlayStyle
          : OptivusTheme.onboardingOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      OptivusColors.onboardingDarkTop,
                      OptivusColors.onboardingDarkBottom,
                    ]
                  : [
                      OptivusColors.onboardingTop,
                      OptivusColors.onboardingBottom,
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: responsiveHeaderH,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 40,
                          child: topLeftOverlay != null
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: topLeftOverlay!,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: LiquidGlassOnboardingIndicator(
                                page: pageOffset,
                                count: completedSteps.length,
                                completedSteps: completedSteps,
                                onDotTap: onDotTap,
                                onDragTarget: onIndicatorDraggedTo,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: showSave
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: OnboardingSaveButton(
                                    isSaving: isSaving,
                                    isSaved: isSaved,
                                    enabled: saveEnabled,
                                    onTap: onSave,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: (error == null && validationMessage == null)
                      ? const SizedBox.shrink()
                      : RecoverableErrorBanner(
                          error:
                              error ??
                              RecoverableError(
                                category: RecoverableErrorCategory.validation,
                                publicMessage: validationMessage!,
                                severity: RecoverableErrorSeverity.error,
                                isBlocking: true,
                                retryAction: onRetry != null
                                    ? RecoverableRetryAction.retry
                                    : RecoverableRetryAction.none,
                                retrySafe: onRetry != null,
                                diagnosticCode:
                                    DiagnosticCodes.validationIncompleteStep,
                              ),
                          onRetry: onRetry,
                        ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: keyboardOpen
                              ? MediaQuery.viewInsetsOf(context).bottom
                              : 0,
                        ),
                        child: child,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: OnboardingActionBar(
                          actions: resolvedActions,
                          reserveHiddenSpace: true,
                          accessory:
                              currentPage == OnboardingStepId.welcome.index &&
                                  showPrimaryCta
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'By continuing, you agree to our Terms & Policy',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF6F737C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : null,
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
    );
  }
}
