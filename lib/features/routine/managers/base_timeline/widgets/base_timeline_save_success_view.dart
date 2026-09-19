import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';

/// Reusable animated save-success confirmation screen across Base Timeline domains.
class BaseTimelineSaveSuccessView extends StatefulWidget {
  final VoidCallback onComplete;
  final String title;
  final String subtitle;
  final Color accent;
  final Duration entranceDuration;
  final Duration holdDuration;
  Duration get totalDuration => entranceDuration + holdDuration;

  const BaseTimelineSaveSuccessView({
    super.key,
    required this.onComplete,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.entranceDuration = const Duration(milliseconds: 350),
    this.holdDuration = const Duration(milliseconds: 650),
  });

  @override
  State<BaseTimelineSaveSuccessView> createState() =>
      _BaseTimelineSaveSuccessViewState();
}

class _BaseTimelineSaveSuccessViewState
    extends State<BaseTimelineSaveSuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _didTriggerComplete = false;
  bool _reducedMotion = false;
  bool _hasFiredHaptic = false;

  void _triggerComplete() {
    if (_didTriggerComplete || !mounted) return;
    _didTriggerComplete = true;
    widget.onComplete();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );

    final totalMs = widget.totalDuration.inMilliseconds;
    final entranceMs = widget.entranceDuration.inMilliseconds;
    final entranceEnd = totalMs > 0
        ? (entranceMs / totalMs).clamp(0.0, 1.0)
        : 1.0;

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        0.0,
        (entranceEnd * 0.9).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        0.0,
        (entranceEnd * 0.6).clamp(0.0, 1.0),
        curve: Curves.easeIn,
      ),
    );

    _controller.addStatusListener((status) {
      if (!_reducedMotion && status == AnimationStatus.completed) {
        _triggerComplete();
      }
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      if (!_reducedMotion) {
        _reducedMotion = true;
        _controller.stop();
        _controller.value = 1.0;
        if (widget.holdDuration == Duration.zero) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerComplete();
          });
        } else {
          Future.delayed(widget.holdDuration, () {
            if (mounted) _triggerComplete();
          });
        }
      }
    } else if (!_hasFiredHaptic) {
      _hasFiredHaptic = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassFill = isDark
        ? OptivusColors.darkGlassFill
        : Colors.white.withValues(alpha: 0.08);
    final borderColor = widget.accent.withValues(alpha: isDark ? 0.35 : 0.30);

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OptivusRadii.surfaceLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              decoration: BoxDecoration(
                color: glassFill,
                borderRadius: BorderRadius.circular(OptivusRadii.surfaceLarge),
                border: Border.all(color: borderColor, width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: isDark ? 0.04 : 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: widget.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: OptivusColors.textSecondary,
                        height: 1.3,
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

    return SafeArea(
      child: Center(
        child: _reducedMotion
            ? card
            : FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(scale: _scaleAnimation, child: card),
              ),
      ),
    );
  }
}
