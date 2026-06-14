import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

class AiThinkingStage {
  final String title;
  final String detail;
  final IconData? icon;

  const AiThinkingStage({
    required this.title,
    required this.detail,
    this.icon,
  });
}

class AiThinkingCard extends StatefulWidget {
  final List<AiThinkingStage> stages;
  final List<String>? messages;
  final String title;
  final String statusLabel;
  final Color accent;
  final bool isActive;
  final Duration stageInterval;

  const AiThinkingCard({
    super.key,
    this.stages = const [],
    this.messages,
    this.title = 'Building your timeline',
    this.statusLabel = 'Working',
    required this.accent,
    required this.isActive,
    this.stageInterval = const Duration(seconds: 4),
  });

  @override
  State<AiThinkingCard> createState() => _AiThinkingCardState();
}

class _AiThinkingCardState extends State<AiThinkingCard>
    with SingleTickerProviderStateMixin {
  int _currentStageIndex = 0;
  int _elapsedSeconds = 0;
  Timer? _stageTimer;
  Timer? _reassuranceTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late final List<AiThinkingStage> _effectiveStages;

  @override
  void initState() {
    super.initState();
    if (widget.stages.isNotEmpty) {
      _effectiveStages = widget.stages;
    } else if (widget.messages != null && widget.messages!.isNotEmpty) {
      _effectiveStages = widget.messages!
          .map((m) => AiThinkingStage(title: m, detail: ''))
          .toList();
    } else {
      _effectiveStages = [const AiThinkingStage(title: 'Processing', detail: '')];
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
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
      _currentStageIndex = 0;
      _elapsedSeconds = 0;
    });

    _stageTimer = Timer.periodic(widget.stageInterval, (_) {
      if (!mounted) return;
      if (_effectiveStages.isEmpty) return;
      if (_currentStageIndex < _effectiveStages.length - 1) {
        setState(() {
          _currentStageIndex++;
        });
      }
    });

    _reassuranceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _cancelTimers() {
    _stageTimer?.cancel();
    _stageTimer = null;
    _reassuranceTimer?.cancel();
    _reassuranceTimer = null;
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

  Widget _buildTopRow() {
    return Row(
      children: [
        _buildAnimatedOrb(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            widget.statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: widget.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleContent() {
    if (_effectiveStages.isEmpty) return const SizedBox.shrink();
    final currentStage = _effectiveStages[_currentStageIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: Column(
        key: ValueKey<int>(_currentStageIndex),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (currentStage.icon != null) ...[
                Icon(currentStage.icon, size: 14, color: OptivusColors.textPrimary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  currentStage.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (currentStage.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              currentStage.detail,
              style: const TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w600,
                 color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomRail() {
    if (_effectiveStages.isEmpty) return const SizedBox.shrink();
    return Row(
      children: List.generate(_effectiveStages.length, (index) {
        final isActive = index <= _currentStageIndex;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            margin: EdgeInsets.only(right: index == _effectiveStages.length - 1 ? 0 : 4),
            height: 4,
            decoration: BoxDecoration(
              color: isActive 
                  ? widget.accent 
                  : OptivusColors.textSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isActive ? [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ] : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDelayHint() {
    if (_elapsedSeconds < 15) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Text(
          'Large images can take a little longer. Keep this screen open.',
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
    if (!widget.isActive) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: OnboardingGlassCard(
        tint: widget.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(),
              const SizedBox(height: 16),
              _buildMiddleContent(),
              const SizedBox(height: 16),
              _buildBottomRail(),
              _buildDelayHint(),
            ],
          ),
        ),
      ),
    );
  }
}
