import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart'
    show GlassHighlightPainter;
import 'package:optivus/features/tracker/widgets/tracker_components.dart';

import 'meditation_mock_data.dart';

enum MeditationStatus { ready, running, paused, completed }

class MeditationTargetCard extends StatelessWidget {
  final int targetMinutes;
  final int completedMinutes;
  final int streakDays;

  const MeditationTargetCard({
    super.key,
    required this.targetMinutes,
    required this.completedMinutes,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetMinutes > 0
        ? (completedMinutes / targetMinutes).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight <= 78;
        return TrackerGlassCard(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 7 : 9,
          ),
          radius: 24,
          opacity: 0.72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Today\'s target',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: OptivusColors.sub,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$completedMinutes / $targetMinutes min',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 16 : 17,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.ink,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniTargetChip(
                        label: 'Streak $streakDays',
                        color: OptivusColors.warning,
                      ),
                      const SizedBox(width: 8),
                      const _MiniTargetChip(
                        label: 'Calm',
                        color: OptivusColors.purpleAccent,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: compact ? 6 : 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 4,
                  color: Colors.white.withValues(alpha: 0.52),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            OptivusColors.trackerAccent,
                            OptivusColors.blueAccent.withValues(alpha: 0.86),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniTargetChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTargetChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class MeditationDurationSelector extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onSelected;
  final bool enabled;
  final double chipHeight;

  const MeditationDurationSelector({
    super.key,
    required this.selectedDuration,
    required this.onSelected,
    this.enabled = true,
    this.chipHeight = 36,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MeditationDurationChip(
          label: '1 min',
          width: 54,
          height: chipHeight,
          isSelected: selectedDuration == 1,
          onTap: enabled ? () => onSelected(1) : null,
        ),
        const SizedBox(width: 7),
        MeditationDurationChip(
          label: '3 min',
          width: 56,
          height: chipHeight,
          isSelected: selectedDuration == 3,
          onTap: enabled ? () => onSelected(3) : null,
        ),
        const SizedBox(width: 7),
        MeditationDurationChip(
          label: '5 min',
          width: 56,
          height: chipHeight,
          isSelected: selectedDuration == 5,
          onTap: enabled ? () => onSelected(5) : null,
        ),
        const SizedBox(width: 7),
        MeditationDurationChip(
          label: '10 min',
          width: 66,
          height: chipHeight,
          isSelected: selectedDuration == 10,
          onTap: enabled ? () => onSelected(10) : null,
        ),
        const SizedBox(width: 7),
        MeditationDurationChip(
          label: 'Custom',
          width: 78,
          height: chipHeight,
          isSelected: !const [1, 3, 5, 10].contains(selectedDuration),
          onTap: enabled ? () => _showCustomDurationSheet(context) : null,
        ),
      ],
    );

    Widget content = SizedBox(
      height: chipHeight,
      width: double.infinity,
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: row),
      ),
    );

    if (!enabled) {
      content = Opacity(opacity: 0.45, child: IgnorePointer(child: content));
    }

    return content;
  }

  void _showCustomDurationSheet(BuildContext context) {
    const customOptions = [2, 7, 15, 20, 30];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: OptivusColors.ink.withValues(alpha: 0.08),
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: _GlassBottomSheetFrame(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Select duration',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final duration in customOptions)
                          MeditationDurationChip(
                            label: '$duration min',
                            width: 82,
                            height: 38,
                            isSelected: selectedDuration == duration,
                            onTap: () {
                              onSelected(duration);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlassBottomSheetFrame extends StatelessWidget {
  final Widget child;

  const _GlassBottomSheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    const outerR = 28.0;
    const rim = 8.0;
    const innerR = outerR - rim + 2;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: OptivusColors.ink.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(outerR),
                  ),
                ),
              ),
              child,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlassHighlightPainter(
                      outerR: outerR,
                      innerR: innerR,
                      rim: rim,
                    ),
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

class MeditationDurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const MeditationDurationChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.width = 64,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isSelected
              ? OptivusColors.trackerAccent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: isSelected
                ? OptivusColors.trackerAccent.withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.82),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: OptivusColors.trackerAccent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: isSelected ? OptivusColors.ink : OptivusColors.sub,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class AiLiquidMeditationOrb extends StatefulWidget {
  final bool isRunning;
  final String currentPhase;
  final Color accentColor;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;
  final double size;

  const AiLiquidMeditationOrb({
    super.key,
    required this.isRunning,
    required this.currentPhase,
    required this.accentColor,
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
    this.size = 200,
  });

  @override
  State<AiLiquidMeditationOrb> createState() => _AiLiquidMeditationOrbState();
}

class _AiLiquidMeditationOrbState extends State<AiLiquidMeditationOrb>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController.unbounded(vsync: this, value: 1.0);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );

    if (widget.isRunning) {
      _startShimmer();
      _applyPhase(widget.currentPhase);
    }
  }

  @override
  void didUpdateWidget(covariant AiLiquidMeditationOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isRunning) {
      _scaleController.stop();
      _shimmerController.stop();
      if (widget.currentPhase == 'ready') {
        _scaleController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    _startShimmer();
    if (!oldWidget.isRunning ||
        widget.currentPhase != oldWidget.currentPhase ||
        widget.inhaleSeconds != oldWidget.inhaleSeconds ||
        widget.exhaleSeconds != oldWidget.exhaleSeconds) {
      _applyPhase(widget.currentPhase);
    }
  }

  void _startShimmer() {
    if (!_shimmerController.isAnimating) {
      _shimmerController.repeat();
    }
  }

  void _applyPhase(String phase) {
    if (phase == 'Inhale') {
      _scaleController.animateTo(
        1.08,
        duration: Duration(seconds: math.max(1, widget.inhaleSeconds)),
        curve: Curves.easeInOutSine,
      );
    } else if (phase == 'Hold') {
      _scaleController.animateTo(
        1.075,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else if (phase == 'Exhale') {
      _scaleController.animateTo(
        0.94,
        duration: Duration(seconds: math.max(1, widget.exhaleSeconds)),
        curve: Curves.easeInOutSine,
      );
    } else {
      _scaleController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final frameWidth = size + 52;
    final frameHeight = size + 48;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _shimmerController]),
      builder: (context, child) {
        final rotation = _shimmerController.value * math.pi * 2;
        final holdPulse = widget.isRunning && widget.currentPhase == 'Hold'
            ? math.sin(rotation * 2.0) * 0.003
            : 0.0;
        final scale = (_scaleController.value + holdPulse).clamp(0.90, 1.10);

        return SizedBox(
          width: frameWidth,
          height: frameHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                child: Container(
                  width: size * 0.70,
                  height: size * 0.14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.08),
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF182FA7).withValues(alpha: 0.16),
                        OptivusColors.trackerAccent.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
              Container(
                width: size * 1.18,
                height: size * 1.18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: OptivusColors.trackerAccent.withValues(
                        alpha: widget.isRunning ? 0.16 : 0.10,
                      ),
                      blurRadius: size * 0.28,
                      spreadRadius: size * 0.02,
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: scale.toDouble(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    children: [
                      ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _AiOrbBodyPainter(
                                rotation: rotation,
                                accentColor: widget.accentColor,
                              ),
                            ),
                            CustomPaint(
                              painter: _AiOrbSwirlPainter(
                                rotation: rotation,
                                accentColor: widget.accentColor,
                              ),
                            ),
                            CustomPaint(
                              painter: _AiOrbFiberPainter(rotation: rotation),
                            ),
                            Align(
                              alignment: const Alignment(-0.42, -0.66),
                              child: Transform.rotate(
                                angle: -0.58,
                                child: Container(
                                  width: size * 0.43,
                                  height: size * 0.15,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      size * 0.08,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.90),
                                        Colors.white.withValues(alpha: 0.32),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: const Alignment(0.43, 0.70),
                              child: Transform.rotate(
                                angle: -0.28,
                                child: Container(
                                  width: size * 0.50,
                                  height: size * 0.08,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      size * 0.08,
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.32),
                                        Colors.white.withValues(alpha: 0.04),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: size * 0.20,
                              left: size * 0.25,
                              child: Container(
                                width: size * 0.08,
                                height: size * 0.08,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.52),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.34,
                                      ),
                                      blurRadius: size * 0.06,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OrbRimPainter(
                            shimmer: rotation,
                            accentColor: widget.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiOrbBodyPainter extends CustomPainter {
  final double rotation;
  final Color accentColor;

  const _AiOrbBodyPainter({required this.rotation, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.36, -0.42),
          radius: 1.03,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE7F3F7),
            Color(0xFFA4C1D9),
            Color(0xFF28BCD9),
            Color(0xFF182FA7),
            Color(0xFF111064),
            Color(0xFF02021B),
          ],
          stops: [0.0, 0.10, 0.23, 0.42, 0.64, 0.82, 1.0],
        ).createShader(rect),
    );

    canvas.drawCircle(
      Offset(center.dx - radius * 0.14, center.dy - radius * 0.05),
      radius * 0.72,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF28BCD9).withValues(alpha: 0.42),
                const Color(0xFF182FA7).withValues(alpha: 0.16),
                Colors.transparent,
              ],
              stops: const [0.0, 0.48, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(center.dx - radius * 0.12, center.dy),
                radius: radius * 0.78,
              ),
            ),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + radius * 0.32, center.dy + radius * 0.17),
        width: radius * 1.12,
        height: radius * 1.62,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF837DA7).withValues(alpha: 0.10),
            const Color(0xFF111064).withValues(alpha: 0.34),
            const Color(0xFF02021B).withValues(alpha: 0.62),
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.035),
    );

    canvas.drawCircle(
      Offset(
        center.dx + radius * 0.18 * math.cos(rotation * 0.8),
        center.dy + radius * 0.15 * math.sin(rotation * 0.8),
      ),
      radius * 0.46,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.20),
                accentColor.withValues(alpha: 0.16),
                Colors.transparent,
              ],
              stops: const [0.0, 0.44, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(center.dx, center.dy),
                radius: radius * 0.58,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _AiOrbBodyPainter oldDelegate) {
    return rotation != oldDelegate.rotation ||
        accentColor != oldDelegate.accentColor;
  }
}

class _AiOrbSwirlPainter extends CustomPainter {
  final double rotation;
  final Color accentColor;

  const _AiOrbSwirlPainter({required this.rotation, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.saveLayer(Offset.zero & size, Paint());

    final darkPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.36, 0.28),
        radius: 0.78,
        colors: [
          const Color(0xFF02021B).withValues(alpha: 0.86),
          const Color(0xFF111064).withValues(alpha: 0.72),
          const Color(0xFF182FA7).withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 0.78, 1.0],
      ).createShader(Offset.zero & size)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.09);
    final darkPath = Path()
      ..moveTo(
        center.dx - radius * 0.18 + radius * 0.08 * math.cos(rotation),
        center.dy + radius * 0.28 + radius * 0.05 * math.sin(rotation),
      )
      ..cubicTo(
        center.dx + radius * 0.44 + radius * 0.06 * math.cos(rotation + 0.8),
        center.dy - radius * 0.08 + radius * 0.05 * math.sin(rotation + 0.8),
        center.dx + radius * 0.74 + radius * 0.04 * math.cos(rotation + 1.7),
        center.dy + radius * 0.44 + radius * 0.05 * math.sin(rotation + 1.7),
        center.dx + radius * 0.22 + radius * 0.08 * math.cos(rotation + 2.6),
        center.dy + radius * 0.78 + radius * 0.04 * math.sin(rotation + 2.6),
      )
      ..cubicTo(
        center.dx - radius * 0.30 + radius * 0.05 * math.cos(rotation + 3.8),
        center.dy + radius * 0.66 + radius * 0.05 * math.sin(rotation + 3.8),
        center.dx - radius * 0.34 + radius * 0.06 * math.cos(rotation + 4.5),
        center.dy + radius * 0.34 + radius * 0.03 * math.sin(rotation + 4.5),
        center.dx - radius * 0.18 + radius * 0.08 * math.cos(rotation),
        center.dy + radius * 0.28 + radius * 0.05 * math.sin(rotation),
      );
    canvas.drawPath(darkPath, darkPaint);

    final cyanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.36),
          const Color(0xFF28BCD9).withValues(alpha: 0.62),
          const Color(0xFF182FA7).withValues(alpha: 0.26),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.72, 1.0],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.07);
    final cyanPath = Path()
      ..moveTo(
        center.dx - radius * 0.62 + radius * 0.05 * math.cos(rotation * 0.8),
        center.dy - radius * 0.05 + radius * 0.05 * math.sin(rotation * 0.8),
      )
      ..cubicTo(
        center.dx - radius * 0.24 + radius * 0.05 * math.cos(rotation + 1.1),
        center.dy - radius * 0.52 + radius * 0.04 * math.sin(rotation + 1.1),
        center.dx + radius * 0.42 + radius * 0.06 * math.cos(rotation + 2.1),
        center.dy - radius * 0.40 + radius * 0.05 * math.sin(rotation + 2.1),
        center.dx + radius * 0.36 + radius * 0.04 * math.cos(rotation + 2.8),
        center.dy + radius * 0.05 + radius * 0.04 * math.sin(rotation + 2.8),
      )
      ..cubicTo(
        center.dx + radius * 0.07 + radius * 0.04 * math.cos(rotation + 3.2),
        center.dy + radius * 0.28 + radius * 0.05 * math.sin(rotation + 3.2),
        center.dx - radius * 0.46 + radius * 0.04 * math.cos(rotation + 4.3),
        center.dy + radius * 0.27 + radius * 0.04 * math.sin(rotation + 4.3),
        center.dx - radius * 0.62 + radius * 0.05 * math.cos(rotation * 0.8),
        center.dy - radius * 0.05 + radius * 0.05 * math.sin(rotation * 0.8),
      );
    canvas.drawPath(cyanPath, cyanPaint);

    final rimRibbon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.34),
          const Color(0xFFA4C1D9).withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.025);
    final ribbon = Path()
      ..moveTo(center.dx - radius * 0.58, center.dy + radius * 0.18)
      ..cubicTo(
        center.dx - radius * 0.16,
        center.dy + radius * 0.02 + math.sin(rotation) * radius * 0.02,
        center.dx + radius * 0.12,
        center.dy + radius * 0.34,
        center.dx + radius * 0.54,
        center.dy + radius * 0.16,
      );
    canvas.drawPath(ribbon, rimRibbon);

    final accentPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.22),
              accentColor.withValues(alpha: 0.20),
              const Color(0xFFA4C1D9).withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.34, 0.62, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                center.dx - radius * 0.10 + radius * 0.12 * math.cos(rotation),
                center.dy - radius * 0.10 + radius * 0.10 * math.sin(rotation),
              ),
              radius: radius * 0.52,
            ),
          );
    canvas.drawCircle(
      Offset(
        center.dx - radius * 0.10 + radius * 0.12 * math.cos(rotation),
        center.dy - radius * 0.10 + radius * 0.10 * math.sin(rotation),
      ),
      radius * 0.52,
      accentPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AiOrbSwirlPainter oldDelegate) {
    return rotation != oldDelegate.rotation ||
        accentColor != oldDelegate.accentColor;
  }
}

class _AiOrbFiberPainter extends CustomPainter {
  final double rotation;

  const _AiOrbFiberPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..color = Colors.white.withValues(alpha: 0.13);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 7 + math.sin(rotation) * 0.08);

    for (double y = -radius + 6; y <= radius - 6; y += 5.0) {
      final xExtent = math.sqrt(math.max(0, radius * radius - y * y));
      final curve =
          (1 - y.abs() / radius) * radius * 0.05 * math.sin(rotation * 2 + y);
      final path = Path()
        ..moveTo(-xExtent, y)
        ..quadraticBezierTo(0, y + curve, xExtent, y);
      canvas.drawPath(path, linePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AiOrbFiberPainter oldDelegate) {
    return rotation != oldDelegate.rotation;
  }
}

class _OrbRimPainter extends CustomPainter {
  final double shimmer;
  final Color accentColor;

  const _OrbRimPainter({required this.shimmer, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = SweepGradient(
        transform: GradientRotation(shimmer * 0.18),
        colors: [
          Colors.white.withValues(alpha: 0.82),
          const Color(0xFF28BCD9).withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.10),
          accentColor.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.62),
        ],
        stops: const [0.0, 0.25, 0.48, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius - 1.2, rimPaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.28);
    canvas.drawCircle(center, radius - 5.0, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbRimPainter oldDelegate) {
    return shimmer != oldDelegate.shimmer ||
        accentColor != oldDelegate.accentColor;
  }
}

class TimerDisplay extends StatelessWidget {
  final int remainingSeconds;
  final MeditationStatus status;
  final String currentPhase;
  final String sessionTypeName;
  final double fontSize;

  const TimerDisplay({
    super.key,
    required this.remainingSeconds,
    required this.status,
    required this.currentPhase,
    required this.sessionTypeName,
    this.fontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    final subtitle = switch (status) {
      MeditationStatus.ready => '$sessionTypeName Meditation',
      MeditationStatus.running => currentPhase,
      MeditationStatus.paused => '$sessionTypeName Meditation',
      MeditationStatus.completed => 'Meditation completed',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$minutes:$seconds',
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: OptivusColors.ink.withValues(alpha: 0.90),
            letterSpacing: 1.5,
            height: 1.0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: status == MeditationStatus.running
                ? OptivusColors.trackerAccent
                : OptivusColors.sub,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class MeditationMusicFilter extends StatefulWidget {
  final List<MeditationSoundUiModel> sounds;
  final String selectedSoundId;
  final ValueChanged<String> onSelected;
  final double width;

  const MeditationMusicFilter({
    super.key,
    required this.sounds,
    required this.selectedSoundId,
    required this.onSelected,
    this.width = 160,
  });

  @override
  State<MeditationMusicFilter> createState() => _MeditationMusicFilterState();
}

class _MeditationMusicFilterState extends State<MeditationMusicFilter>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  String? _expandedCategoryId;
  String? _expandedSubCategoryId;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _anim.dispose();
    super.dispose();
  }

  void _openDropdown() {
    _closeDropdown(immediate: true);
    _expandedCategoryId = null;
    _expandedSubCategoryId = null;
    _anim.value = 0;

    final overlay = OverlayEntry(
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeDropdown,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.transparent)),
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: StatefulBuilder(
                  builder: (context, overlaySetState) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _keepDropdownOpen,
                      child: ScaleTransition(
                        scale: _fade,
                        alignment: Alignment.topRight,
                        child: _buildDropdownMenu(overlaySetState),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    _overlay = overlay;
    Overlay.of(context).insert(overlay);
    _anim.forward();
  }

  void _keepDropdownOpen() {}

  void _closeDropdown({bool immediate = false}) {
    final overlay = _overlay;
    if (overlay == null) return;
    _overlay = null;

    if (immediate || !mounted) {
      overlay.remove();
      return;
    }

    _anim.reverse().whenComplete(() {
      if (overlay.mounted) {
        overlay.remove();
      }
    });
  }

  void _selectTrack(String id) {
    widget.onSelected(id);
    _closeDropdown();
  }

  Widget _buildDropdownMenu(StateSetter overlaySetState) {
    const outerR = 22.0;
    const rim = 8.0;
    const innerR = outerR - rim + 2;
    final rows = <Widget>[
      _MusicDropdownRow(
        title: 'Silent',
        icon: Icons.volume_off_rounded,
        selected: widget.selectedSoundId == 'silent',
        onTap: () => _selectTrack('silent'),
      ),
      _MusicDivider(),
    ];

    for (final category in mockMeditationCategories) {
      final categoryExpanded = _expandedCategoryId == category.id;
      rows.add(
        _MusicDropdownRow(
          title: category.label,
          icon: _categoryIcon(category.id),
          expanded: categoryExpanded,
          isHeader: true,
          onTap: () {
            overlaySetState(() {
              if (_expandedCategoryId == category.id) {
                _expandedCategoryId = null;
                _expandedSubCategoryId = null;
              } else {
                _expandedCategoryId = category.id;
                _expandedSubCategoryId = null;
              }
            });
          },
        ),
      );

      if (!categoryExpanded) continue;

      final subCategories = mockMeditationSubCategories
          .where((sub) => sub.categoryId == category.id)
          .toList(growable: false);

      for (final subCategory in subCategories) {
        final subExpanded = _expandedSubCategoryId == subCategory.id;
        rows.add(
          _MusicDropdownRow(
            title: subCategory.label,
            icon: Icons.subdirectory_arrow_right_rounded,
            expanded: subExpanded,
            isSubHeader: true,
            onTap: () {
              overlaySetState(() {
                _expandedSubCategoryId =
                    _expandedSubCategoryId == subCategory.id
                    ? null
                    : subCategory.id;
              });
            },
          ),
        );

        if (!subExpanded) continue;

        final tracks =
            widget.sounds
                .where(
                  (sound) =>
                      sound.isActive &&
                      sound.categoryId == category.id &&
                      sound.subCategoryId == subCategory.id,
                )
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        for (final track in tracks) {
          rows.add(
            _MusicTrackRow(
              sound: track,
              selected: widget.selectedSoundId == track.id,
              onTap: () => _selectTrack(track.id),
            ),
          );
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 264,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.58,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerR),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.ink.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerR),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(outerR),
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(mainAxisSize: MainAxisSize.min, children: rows),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GlassHighlightPainter(
                        outerR: outerR,
                        innerR: innerR,
                        rim: rim,
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

  IconData _categoryIcon(String id) {
    return switch (id) {
      'healing_432hz' => Icons.graphic_eq_rounded,
      'nature_sounds' => Icons.water_drop_rounded,
      'ambient_atmospheric' => Icons.blur_on_rounded,
      _ => Icons.music_note_rounded,
    };
  }

  String _pillLabelFor(MeditationSoundUiModel sound) {
    if (sound.id == 'silent') return 'Silent';
    if (sound.subCategoryId == 'om_mantra') return 'Om';
    if (sound.categoryId == 'healing_432hz') return '432 Hz';
    if (sound.subCategoryId == 'rain_sounds') return 'Rain';
    if (sound.subCategoryId == 'ocean_water') return 'Ocean';
    return 'Ambient';
  }

  @override
  Widget build(BuildContext context) {
    final selectedSound = widget.sounds.firstWhere(
      (sound) => sound.id == widget.selectedSoundId,
      orElse: () => const MeditationSoundUiModel(
        id: 'silent',
        title: 'Silent',
        durationLabel: '',
        categoryId: 'none',
        subCategoryId: 'none',
        icon: '',
        isAssetAvailable: true,
      ),
    );

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _overlay == null ? _openDropdown() : _closeDropdown(),
        child: _MeditationMusicPill(
          label: _pillLabelFor(selectedSound),
          width: widget.width.clamp(150.0, 175.0).toDouble(),
        ),
      ),
    );
  }
}

class _MeditationMusicPill extends StatelessWidget {
  final String label;
  final double width;

  const _MeditationMusicPill({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    const outerR = 20.0;
    const rim = 7.0;
    const innerR = outerR - rim + 2;

    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: OptivusColors.ink.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(rim),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(innerR),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 15,
                        color: OptivusColors.ink.withValues(alpha: 0.86),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.ink,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 17,
                        color: OptivusColors.ink.withValues(alpha: 0.82),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GlassHighlightPainter(
                      outerR: outerR,
                      innerR: innerR,
                      rim: rim,
                    ),
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

class _MusicDropdownRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final bool? expanded;
  final bool isHeader;
  final bool isSubHeader;
  final VoidCallback onTap;

  const _MusicDropdownRow({
    required this.title,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.expanded,
    this.isHeader = false,
    this.isSubHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final left = isSubHeader ? 22.0 : 14.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.transparent,
        padding: EdgeInsets.fromLTRB(left, 9, 12, 9),
        child: Row(
          children: [
            Icon(
              icon,
              size: isHeader ? 16 : 15,
              color: OptivusColors.ink.withValues(
                alpha: isSubHeader ? 0.62 : 0.82,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isHeader ? 13 : 12.5,
                  fontWeight: isHeader || selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: OptivusColors.ink.withValues(
                    alpha: isSubHeader ? 0.72 : 0.90,
                  ),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (expanded != null)
              Icon(
                expanded!
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: OptivusColors.sub,
              ),
            if (selected)
              Icon(
                Icons.check_rounded,
                size: 15,
                color: OptivusColors.ink.withValues(alpha: 0.88),
              ),
          ],
        ),
      ),
    );
  }
}

class _MusicTrackRow extends StatelessWidget {
  final MeditationSoundUiModel sound;
  final bool selected;
  final VoidCallback onTap;

  const _MusicTrackRow({
    required this.sound,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected
            ? OptivusColors.trackerAccent.withValues(alpha: 0.12)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(36, 9, 12, 9),
        child: Row(
          children: [
            Text(
              sound.icon,
              style: const TextStyle(
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                sound.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: OptivusColors.ink.withValues(alpha: 0.84),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              sound.durationLabel,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OptivusColors.sub,
                decoration: TextDecoration.none,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_rounded,
                size: 15,
                color: OptivusColors.ink.withValues(alpha: 0.88),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MusicDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: Colors.white.withValues(alpha: 0.30),
      indent: 14,
      endIndent: 14,
    );
  }
}

class MeditationControlBar extends StatelessWidget {
  final MeditationStatus status;
  final double buttonHeight;
  final int completedDurationMinutes;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback? onDone;
  final VoidCallback? onStartAgain;

  const MeditationControlBar({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onCancel,
    this.buttonHeight = 46,
    this.completedDurationMinutes = 0,
    this.onDone,
    this.onStartAgain,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final gap = available < 340 ? 8.0 : 12.0;

        if (status == MeditationStatus.ready) {
          return Center(
            child: MeditationGlassButton(
              label: 'Start',
              onTap: onStart,
              isPrimary: true,
              color: OptivusColors.trackerAccent,
              width: available < 340 ? 150 : 158,
              height: buttonHeight,
            ),
          );
        }

        if (status == MeditationStatus.running ||
            status == MeditationStatus.paused) {
          final sideWidth = available < 330 ? 84.0 : 94.0;
          final primaryWidth = (available - sideWidth * 2 - gap * 2)
              .clamp(116.0, 142.0)
              .toDouble();

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MeditationGlassButton(
                label: 'Cancel',
                onTap: onCancel,
                color: OptivusColors.roseAccent,
                width: sideWidth,
                height: buttonHeight,
              ),
              SizedBox(width: gap),
              MeditationGlassButton(
                label: status == MeditationStatus.running ? 'Pause' : 'Resume',
                onTap: status == MeditationStatus.running ? onPause : onResume,
                isPrimary: true,
                color: OptivusColors.trackerAccent,
                width: primaryWidth,
                height: buttonHeight,
              ),
              SizedBox(width: gap),
              MeditationGlassButton(
                label: 'Finish',
                onTap: onComplete,
                color: OptivusColors.mintAccent,
                width: sideWidth,
                height: buttonHeight,
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Meditation completed',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: OptivusColors.ink,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$completedDurationMinutes min added',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: OptivusColors.sub,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MeditationGlassButton(
                    label: 'Done',
                    onTap: onDone ?? () {},
                    isPrimary: true,
                    color: OptivusColors.trackerAccent,
                    width: 126,
                    height: buttonHeight,
                  ),
                  SizedBox(width: gap),
                  MeditationGlassButton(
                    label: 'Start Again',
                    onTap: onStartAgain ?? () {},
                    color: OptivusColors.sub,
                    width: 126,
                    height: buttonHeight,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class MeditationGlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color color;
  final double width;
  final double height;

  const MeditationGlassButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.isPrimary = false,
    this.width = 120,
    this.height = 46,
  });

  @override
  State<MeditationGlassButton> createState() => _MeditationGlassButtonState();
}

class _MeditationGlassButtonState extends State<MeditationGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isPrimary
        ? OptivusColors.trackerAccent.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.76);
    final textColor = widget.isPrimary ? OptivusColors.ink : widget.color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color:
                    (widget.isPrimary
                            ? OptivusColors.trackerAccent
                            : OptivusColors.ink)
                        .withValues(alpha: widget.isPrimary ? 0.16 : 0.05),
                blurRadius: widget.isPrimary ? 18 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.isPrimary
                            ? OptivusColors.trackerAccent.withValues(
                                alpha: 0.18,
                              )
                            : Colors.white.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: 16,
                    right: 16,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.isPrimary
                              ? FontWeight.w900
                              : FontWeight.w800,
                          color: textColor,
                          decoration: TextDecoration.none,
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
    );
  }
}
