import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

class AiThinkingCard extends StatefulWidget {
  final List<String> messages;
  final Color accent;
  final bool isActive;
  final Duration messageInterval;
  final Duration reassuranceInterval;

  const AiThinkingCard({
    super.key,
    required this.messages,
    required this.accent,
    required this.isActive,
    this.messageInterval = const Duration(milliseconds: 2000),
    this.reassuranceInterval = const Duration(seconds: 1),
  });

  @override
  State<AiThinkingCard> createState() => _AiThinkingCardState();
}

class _AiThinkingCardState extends State<AiThinkingCard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _elapsedSeconds = 0;
  Timer? _messageTimer;
  Timer? _reassuranceTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
      _resetAndStartTimers();
    }
  }

  @override
  void didUpdateWidget(covariant AiThinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
      _resetAndStartTimers();
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _cancelTimers();
    }
  }

  void _resetAndStartTimers() {
    _cancelTimers();
    setState(() {
      _currentIndex = 0;
      _elapsedSeconds = 0;
    });

    _messageTimer = Timer.periodic(widget.messageInterval, (_) {
      if (!mounted) return;
      if (widget.messages.isEmpty) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.messages.length;
      });
    });

    _reassuranceTimer = Timer.periodic(widget.reassuranceInterval, (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _cancelTimers() {
    _messageTimer?.cancel();
    _messageTimer = null;
    _reassuranceTimer?.cancel();
    _reassuranceTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    _pulseController.dispose();
    super.dispose();
  }

  String get _reassuranceText {
    if (_elapsedSeconds < 6) {
      return 'This usually takes a few moments.';
    } else if (_elapsedSeconds < 12) {
      return 'Still reading the details — timetable and meal photos can take longer.';
    } else if (_elapsedSeconds < 20) {
      return 'AI is checking the structure carefully.';
    } else {
      return 'Almost there. Please don\'t close the app.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    final currentMessage = widget.messages.isNotEmpty 
        ? widget.messages[_currentIndex] 
        : 'AI is thinking...';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 110),
      child: OnboardingGlassCard(
        tint: widget.accent.withValues(alpha: 0.07),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final double opacity = 0.45 + (_pulseAnimation.value * 0.55);
                  return Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accent.withValues(alpha: opacity),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: opacity * 0.5),
                          blurRadius: 8 * opacity,
                          spreadRadius: 2 * opacity,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final slideIn = Tween<Offset>(
                        begin: const Offset(0.0, 0.15),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slideIn,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      currentMessage,
                      key: ValueKey<int>(_currentIndex),
                      softWrap: true,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _reassuranceText,
                      key: ValueKey<String>(_reassuranceText),
                      softWrap: true,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
