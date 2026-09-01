import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

class AiGenerationStatusView extends StatefulWidget {
  final AiGenerationState state;
  final String title;
  final String detail;
  final Color accent;
  final VoidCallback? onRetry;
  final Duration dotInterval;
  final Duration firstLongWaitDelay;
  final Duration secondLongWaitDelay;

  const AiGenerationStatusView({
    super.key,
    required this.state,
    required this.title,
    required this.detail,
    required this.accent,
    this.onRetry,
    this.dotInterval = const Duration(milliseconds: 500),
    this.firstLongWaitDelay = const Duration(seconds: 10),
    this.secondLongWaitDelay = const Duration(seconds: 20),
  });

  @override
  State<AiGenerationStatusView> createState() => _AiGenerationStatusViewState();
}

class _AiGenerationStatusViewState extends State<AiGenerationStatusView>
    with SingleTickerProviderStateMixin {
  int _dotCount = 0;
  int _elapsedSeconds = 0;
  Timer? _dotTimer;
  Timer? _elapsedTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    if (widget.state.isActive) {
      _pulseController.repeat(reverse: true);
      _resetAndStartTimers();
    }
  }

  @override
  void didUpdateWidget(covariant AiGenerationStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isActive && !oldWidget.state.isActive) {
      _pulseController.repeat(reverse: true);
      _resetAndStartTimers();
    } else if (!widget.state.isActive && oldWidget.state.isActive) {
      _pulseController.stop();
      _cancelTimers();
    }
  }

  void _resetAndStartTimers() {
    _cancelTimers();
    setState(() {
      _dotCount = 1;
      _elapsedSeconds = 0;
    });

    _dotTimer = Timer.periodic(widget.dotInterval, (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount % 4) + 1;
      });
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _cancelTimers() {
    _dotTimer?.cancel();
    _dotTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedOrb() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final double opacity = 0.5 + (_pulseAnimation.value * 0.5);
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accent.withValues(alpha: 0.15),
            border: Border.all(
              color: widget.accent.withValues(alpha: opacity),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: opacity * 0.4),
                blurRadius: 10 * opacity,
                spreadRadius: 2 * opacity,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDelayHint() {
    if (_elapsedSeconds < widget.firstLongWaitDelay.inSeconds) {
      return const SizedBox.shrink();
    }

    final hint = _elapsedSeconds < widget.secondLongWaitDelay.inSeconds
        ? 'Detailed photos can take a little longer'
        : 'Still working. Keep this screen open';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Text(
          hint,
          key: ValueKey(hint),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: OptivusColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.isActive &&
        widget.state.phase != AiGenerationPhase.error) {
      return const SizedBox.shrink();
    }

    if (widget.state.phase == AiGenerationPhase.error) {
      return ConstrainedBox(
        key: const ValueKey('ai-generation-status-region'),
        constraints: const BoxConstraints(minWidth: 200, minHeight: 88),
        child: OnboardingGlassCard(
          tint: widget.accent.withValues(alpha: 0.04),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: widget.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.state.error?.message ??
                      'Something went wrong. Try again.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
              if (widget.state.canRetry && widget.onRetry != null)
                Semantics(
                  button: true,
                  label: 'Retry AI generation',
                  child: TextButton(
                    onPressed: widget.onRetry,
                    child: const Text('Retry'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final dots = '.' * _dotCount;

    return ConstrainedBox(
      key: const ValueKey('ai-generation-status-region'),
      constraints: const BoxConstraints(minWidth: 200, minHeight: 88),
      child: OnboardingGlassCard(
        tint: widget.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimatedOrb(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.title}$dots',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        if (widget.detail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.detail,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              _buildDelayHint(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified thinking & lifecycle card.
class AiThinkingCard extends StatelessWidget {
  final String title;
  final String detail;
  final Color accent;
  final bool? isActive;
  final AiGenerationState? state;
  final VoidCallback? onRetry;
  final Duration dotInterval;
  final Duration firstLongWaitDelay;
  final Duration secondLongWaitDelay;

  const AiThinkingCard({
    super.key,
    required this.title,
    required this.detail,
    required this.accent,
    this.isActive,
    this.state,
    this.onRetry,
    this.dotInterval = const Duration(milliseconds: 500),
    this.firstLongWaitDelay = const Duration(seconds: 10),
    this.secondLongWaitDelay = const Duration(seconds: 20),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveState =
        state ??
        AiGenerationState(
          phase: (isActive ?? false)
              ? AiGenerationPhase.generating
              : AiGenerationPhase.idle,
          operationId: (isActive ?? false) ? 'compatibility' : null,
          attempt: (isActive ?? false) ? 1 : 0,
        );
    return AiGenerationStatusView(
      title: title,
      detail: detail,
      accent: accent,
      state: effectiveState,
      onRetry: onRetry,
      dotInterval: dotInterval,
      firstLongWaitDelay: firstLongWaitDelay,
      secondLongWaitDelay: secondLongWaitDelay,
    );
  }
}
