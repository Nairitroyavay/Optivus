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
      if (status == AnimationStatus.completed) {
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
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(OptivusRadii.surfaceLarge),
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              color: widget.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Center(
        child: _reducedMotion
            ? card
            : FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: card,
                ),
              ),
      ),
    );
  }
}
