import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:optivus/core/widgets/liquid_chips.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart';
import 'meditation_mock_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. MeditationTargetCard
// ─────────────────────────────────────────────────────────────────────────────

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
        ? (completedMinutes / targetMinutes).clamp(0.0, 1.0)
        : 0.0;

    return TrackerGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 24,
      opacity: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s target',
                    style: TextStyle(
                      fontSize: 12,
                      color: OptivusColors.sub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$completedMinutes / $targetMinutes min',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildMiniChip('Streak $streakDays', OptivusColors.warning),
                  const SizedBox(width: 8),
                  _buildMiniChip('Calm', OptivusColors.purpleAccent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: OptivusColors.trackerAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. DurationSelector
// ─────────────────────────────────────────────────────────────────────────────

class DurationSelector extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onSelected;
  final bool enabled;

  const DurationSelector({
    super.key,
    required this.selectedDuration,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final durations = [1, 3, 5, 10];

    Widget content = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        ...durations.map((duration) {
          final isSelected = selectedDuration == duration;
          return LiquidChip(
            label: '$duration min',
            isSelected: isSelected,
            onTap: () => onSelected(duration),
            selectedColor: OptivusColors.trackerAccent,
          );
        }),
        LiquidChip(
          label: 'Custom',
          isSelected: ![1, 3, 5, 10].contains(selectedDuration),
          onTap: () {
            _showCustomDurationSheet(context);
          },
          selectedColor: OptivusColors.sub,
        ),
      ],
    );

    if (!enabled) {
      content = IgnorePointer(
        child: Opacity(
          opacity: 0.45,
          child: content,
        ),
      );
    }

    return content;
  }

  void _showCustomDurationSheet(BuildContext context) {
    final customOptions = [2, 7, 15, 20, 30];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: OptivusColors.trackerCardTint,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: customOptions.map((d) {
                  return LiquidChip(
                    label: '$d min',
                    isSelected: selectedDuration == d,
                    onTap: () {
                      onSelected(d);
                      Navigator.pop(context);
                    },
                    selectedColor: OptivusColors.trackerAccent,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. LiquidGlassBreathingOrb
// ─────────────────────────────────────────────────────────────────────────────

class LiquidGlassBreathingOrb extends StatefulWidget {
  final bool isRunning;
  final String currentPhase;
  final Color accentColor;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;
  final double size;

  const LiquidGlassBreathingOrb({
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
  State<LiquidGlassBreathingOrb> createState() =>
      _LiquidGlassBreathingOrbState();
}

class _LiquidGlassBreathingOrbState extends State<LiquidGlassBreathingOrb>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _liquidController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.inhaleSeconds),
    );
    _scaleAnimation = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    if (widget.isRunning) {
      _applyPhase(widget.currentPhase);
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassBreathingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle isRunning toggled off
    if (!widget.isRunning && oldWidget.isRunning) {
      _breathingController.stop();
      return;
    }

    // Handle isRunning toggled on
    if (widget.isRunning && !oldWidget.isRunning) {
      _applyPhase(widget.currentPhase);
      return;
    }

    // Handle phase change while running
    if (widget.isRunning &&
        widget.currentPhase != oldWidget.currentPhase) {
      _applyPhase(widget.currentPhase);
    }
  }

  void _applyPhase(String phase) {
    switch (phase) {
      case 'Inhale':
        _breathingController.duration =
            Duration(seconds: widget.inhaleSeconds);
        _breathingController.forward(from: _breathingController.value);
        break;
      case 'Hold':
        _breathingController.stop();
        break;
      case 'Exhale':
        _breathingController.duration =
            Duration(seconds: widget.exhaleSeconds);
        _breathingController.reverse(from: _breathingController.value);
        break;
      default:
        _breathingController.stop();
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _liquidController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimation,
        _liquidController,
        _shimmerController,
      ]),
      builder: (context, child) {
        final scale = widget.isRunning ? _scaleAnimation.value : 1.0;
        final rotation = _liquidController.value * 2 * math.pi;
        final shimmer = _shimmerController.value;

        return SizedBox(
          width: size + 40,
          height: size + 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── 0. Floating reflection ellipse beneath orb ──────────
              Positioned(
                bottom: 0,
                child: Container(
                  width: size * 0.55,
                  height: size * 0.08,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.04),
                    gradient: RadialGradient(
                      colors: [
                        widget.accentColor.withValues(alpha: 0.18),
                        widget.accentColor.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.08),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),

              // ── 1. Outer soft halo ─────────────────────────────────
              Positioned(
                top: 10,
                child: Container(
                  width: size + 24,
                  height: size + 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        widget.accentColor.withValues(alpha: 0.06),
                        OptivusColors.trackerAccent.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.6, 0.78, 0.9, 1.0],
                    ),
                  ),
                ),
              ),

              // ── 2. Main orb body ───────────────────────────────────
              Positioned(
                top: 22,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        // Drop shadow
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.2),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: OptivusColors.purpleAccent.withValues(alpha: 0.08),
                          blurRadius: 50,
                          spreadRadius: 6,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // ── A. Base iridescent core ──────────────────
                        ClipOval(
                          child: Stack(
                            children: [
                              // Rotating sweep gradient base
                              Container(
                                decoration: BoxDecoration(
                                  gradient: SweepGradient(
                                    center: Alignment.center,
                                    transform: GradientRotation(rotation),
                                    colors: [
                                      OptivusColors.trackerTop.withValues(alpha: 0.7),
                                      widget.accentColor.withValues(alpha: 0.5),
                                      OptivusColors.purpleAccent.withValues(alpha: 0.4),
                                      OptivusColors.blueAccent.withValues(alpha: 0.45),
                                      Colors.white.withValues(alpha: 0.5),
                                      OptivusColors.trackerTop.withValues(alpha: 0.7),
                                    ],
                                    stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                                  ),
                                ),
                              ),
                              // Inner organic swirl painter
                              CustomPaint(
                                size: Size(size, size),
                                painter: _OrbSwirlPainter(
                                  rotation: rotation,
                                  shimmer: shimmer,
                                  accentColor: widget.accentColor,
                                ),
                              ),
                              // Chromatic aberration — cyan offset circle
                              Transform.translate(
                                offset: Offset(
                                  12 * math.cos(rotation * 0.7),
                                  12 * math.sin(rotation * 0.7),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: Alignment(
                                        -0.3 + 0.15 * math.cos(rotation),
                                        -0.3 + 0.15 * math.sin(rotation),
                                      ),
                                      radius: 0.8,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.55),
                                        OptivusColors.trackerAccent.withValues(alpha: 0.3),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.35, 0.75],
                                    ),
                                  ),
                                ),
                              ),
                              // Chromatic aberration — purple offset
                              Transform.translate(
                                offset: Offset(
                                  -18 * math.cos(rotation * 1.2),
                                  -18 * math.sin(rotation * 1.2),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: const Alignment(0.35, 0.35),
                                      radius: 0.65,
                                      colors: [
                                        OptivusColors.purpleAccent.withValues(alpha: 0.35),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // White highlight blob drifting
                              Transform.translate(
                                offset: Offset(
                                  20 * math.cos(rotation * 0.5 + 1.5),
                                  20 * math.sin(rotation * 0.5 + 1.5),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: const Alignment(-0.2, -0.5),
                                      radius: 0.5,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.65),
                                        Colors.white.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.3, 0.7],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── B. Frosted glass blur ────────────────────
                        ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),

                        // ── C. Glass shell with depth ────────────────
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 1.8,
                            ),
                            gradient: RadialGradient(
                              center: const Alignment(-0.35, -0.35),
                              radius: 1.1,
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.08),
                                OptivusColors.trackerBottom.withValues(alpha: 0.12),
                                OptivusColors.ink.withValues(alpha: 0.05),
                              ],
                              stops: const [0.0, 0.3, 0.65, 1.0],
                            ),
                            boxShadow: [
                              // Inner white glow top-left
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.75),
                                blurRadius: 24,
                                spreadRadius: -8,
                                offset: const Offset(-8, -8),
                                blurStyle: BlurStyle.inner,
                              ),
                              // Inner accent glow bottom-right
                              BoxShadow(
                                color: widget.accentColor.withValues(alpha: 0.18),
                                blurRadius: 32,
                                spreadRadius: -10,
                                offset: const Offset(10, 10),
                                blurStyle: BlurStyle.inner,
                              ),
                              // Edge depth shadow
                              BoxShadow(
                                color: OptivusColors.ink.withValues(alpha: 0.04),
                                blurRadius: 16,
                                spreadRadius: -4,
                                offset: const Offset(4, 6),
                                blurStyle: BlurStyle.inner,
                              ),
                            ],
                          ),
                        ),

                        // ── D. Wide top specular crescent ────────────
                        Positioned(
                          top: 4,
                          left: size * 0.12,
                          right: size * 0.12,
                          height: size * 0.38,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(size * 0.5),
                                bottom: Radius.circular(size * 0.35),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.82),
                                  Colors.white.withValues(alpha: 0.25),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.35, 0.75],
                              ),
                            ),
                          ),
                        ),

                        // ── E. Shimmer highlight (shifts during hold) ─
                        Positioned(
                          top: size * 0.18,
                          left: size * (0.2 + 0.06 * math.sin(shimmer * 2 * math.pi)),
                          width: size * 0.3,
                          height: size * 0.12,
                          child: Transform.rotate(
                            angle: -0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(size * 0.06),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.45 + 0.15 * math.sin(shimmer * 2 * math.pi)),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── F. Edge rim highlight (thin white arc) ───
                        Positioned(
                          top: size * 0.06,
                          left: size * 0.25,
                          right: size * 0.25,
                          height: size * 0.06,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(size * 0.03),
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),

                        // ── G. Bottom caustic bounce ─────────────────
                        Positioned(
                          bottom: 4,
                          left: size * 0.22,
                          right: size * 0.22,
                          height: size * 0.1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(size * 0.25),
                                bottom: Radius.circular(size * 0.4),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
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
            ],
          ),
        );
      },
    );
  }
}

/// CustomPainter for the inner organic swirl effect inside the orb.
class _OrbSwirlPainter extends CustomPainter {
  final double rotation;
  final double shimmer;
  final Color accentColor;

  _OrbSwirlPainter({
    required this.rotation,
    required this.shimmer,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Clip to circle
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    // Draw 4 translucent flowing curves
    for (int i = 0; i < 4; i++) {
      final phase = rotation + (i * math.pi / 2);
      final path = Path();

      final startAngle = phase;
      final startR = radius * (0.3 + 0.15 * math.sin(shimmer * 2 * math.pi + i));
      final start = Offset(
        center.dx + startR * math.cos(startAngle),
        center.dy + startR * math.sin(startAngle),
      );

      final cp1 = Offset(
        center.dx + radius * 0.6 * math.cos(startAngle + 0.8),
        center.dy + radius * 0.7 * math.sin(startAngle + 0.6),
      );
      final cp2 = Offset(
        center.dx + radius * 0.5 * math.cos(startAngle + 1.5),
        center.dy + radius * 0.4 * math.sin(startAngle + 1.8),
      );
      final end = Offset(
        center.dx + radius * 0.35 * math.cos(startAngle + math.pi),
        center.dy + radius * 0.35 * math.sin(startAngle + math.pi),
      );

      path.moveTo(start.dx, start.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

      final colors = [
        Colors.white.withValues(alpha: 0.3),
        accentColor.withValues(alpha: 0.2),
        OptivusColors.purpleAccent.withValues(alpha: 0.18),
        OptivusColors.blueAccent.withValues(alpha: 0.15),
      ];

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..strokeWidth = radius * 0.18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbSwirlPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.shimmer != shimmer;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. TimerDisplay
// ─────────────────────────────────────────────────────────────────────────────

class TimerDisplay extends StatelessWidget {
  final int remainingSeconds;
  final String status;
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

    return Column(
      children: [
        Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: OptivusColors.ink,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status == 'running'
              ? currentPhase
              : '$sessionTypeName Meditation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color:
                status == 'running' ? OptivusColors.trackerAccent : OptivusColors.sub,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. MeditationMusicFilter
// ─────────────────────────────────────────────────────────────────────────────

class MeditationMusicFilter extends StatefulWidget {
  final List<MeditationSoundUiModel> sounds;
  final String selectedSoundId;
  final ValueChanged<String> onSelected;

  const MeditationMusicFilter({
    super.key,
    required this.sounds,
    required this.selectedSoundId,
    required this.onSelected,
  });

  @override
  State<MeditationMusicFilter> createState() => _MeditationMusicFilterState();
}

class _MeditationMusicFilterState extends State<MeditationMusicFilter>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  final LayerLink _link = LayerLink();

  String? _expandedCategoryId;
  String? _expandedSubCategoryId;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _closeDropdown(immediate: true);
    _anim.dispose();
    super.dispose();
  }

  void _openDropdown() {
    _expandedCategoryId = null;
    _expandedSubCategoryId = null;

    _overlay = OverlayEntry(
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeDropdown,
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: ScaleTransition(
                  scale: _fade,
                  alignment: Alignment.topRight,
                  child: _buildSheet(),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    _anim.forward();
  }

  void _closeDropdown({bool immediate = false}) async {
    if (_overlay == null) return;
    if (!immediate && mounted) {
      await _anim.reverse();
    }
    _overlay?.remove();
    _overlay = null;
  }

  void _selectTrack(String id) {
    _closeDropdown();
    widget.onSelected(id);
  }

  Widget _buildSheet() {
    const double outerR = 22.0;
    const double rim = 8.0;
    const double innerR = outerR - rim + 2;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final List<Widget> rows = [];

        // Silent row (always first)
        final silentSelected = widget.selectedSoundId == 'silent';
        rows.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectTrack('silent'),
            child: Container(
              color: silentSelected
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    const Text('🤫',
                        style: TextStyle(
                          fontSize: 15,
                          decoration: TextDecoration.none,
                        )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Silent',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: silentSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: OptivusColors.ink.withValues(
                            alpha: silentSelected ? 1.0 : 0.80,
                          ),
                          letterSpacing: -0.1,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (silentSelected)
                      Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: OptivusColors.ink.withValues(alpha: 0.85),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Categories
        for (final cat in mockMeditationCategories) {
          // Section header
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                cat.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          );

          final isCatExpanded = _expandedCategoryId == cat.id;

          // Category expand/collapse row
          rows.add(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setSheetState(() {
                  if (_expandedCategoryId == cat.id) {
                    _expandedCategoryId = null;
                    _expandedSubCategoryId = null;
                  } else {
                    _expandedCategoryId = cat.id;
                    _expandedSubCategoryId = null;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: OptivusColors.ink.withValues(alpha: 0.85),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Icon(
                      isCatExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: OptivusColors.ink.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (isCatExpanded) {
            final subCats = mockMeditationSubCategories
                .where((sc) => sc.categoryId == cat.id)
                .toList();

            for (final subCat in subCats) {
              final isSubExpanded =
                  _expandedSubCategoryId == subCat.id;

              // Subcategory row (indented)
              rows.add(
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setSheetState(() {
                      if (_expandedSubCategoryId == subCat.id) {
                        _expandedSubCategoryId = null;
                      } else {
                        _expandedSubCategoryId = subCat.id;
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 28,
                      right: 14,
                      top: 7,
                      bottom: 7,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subCat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: OptivusColors.ink.withValues(alpha: 0.75),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        Icon(
                          isSubExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: OptivusColors.ink.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (isSubExpanded) {
                final tracks = widget.sounds
                    .where((s) =>
                        s.isActive &&
                        s.categoryId == cat.id &&
                        s.subCategoryId == subCat.id)
                    .toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                for (final track in tracks) {
                  final isTrackSelected =
                      widget.selectedSoundId == track.id;
                  rows.add(
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectTrack(track.id),
                      child: Container(
                        color: isTrackSelected
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.transparent,
                        padding: const EdgeInsets.only(
                          left: 42,
                          right: 14,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              track.icon,
                              style: const TextStyle(
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isTrackSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: OptivusColors.ink.withValues(
                                    alpha:
                                        isTrackSelected ? 1.0 : 0.75,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              track.durationLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: OptivusColors.ink.withValues(alpha: 0.45),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            if (isTrackSelected) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: OptivusColors.ink.withValues(alpha: 0.85),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }
              }
            }
          }
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            width: 260,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(outerR),
              boxShadow: [
                BoxShadow(
                  color: OptivusColors.ink.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(outerR),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: rows,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(outerR),
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSound = widget.sounds.firstWhere(
      (s) => s.id == widget.selectedSoundId,
      orElse: () => const MeditationSoundUiModel(
        id: 'silent',
        categoryId: '',
        subCategoryId: '',
        title: 'Silent',
        icon: '🤫',
        durationLabel: '',
        sortOrder: 0,
        isActive: true,
        isAssetAvailable: false,
      ),
    );

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () => _overlay == null ? _openDropdown() : _closeDropdown(),
        child: Container(
          color: Colors.transparent,
          child: _MusicPill(
            title: selectedSound.title,
          ),
        ),
      ),
    );
  }
}

class _MusicPill extends StatelessWidget {
  final String title;
  const _MusicPill({required this.title});

  static const double outerR = 20.0;
  static const double rim = 7.0;
  static const double innerR = outerR - rim + 2; // 15

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: OptivusColors.ink.withValues(alpha: 0.14),
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
              // Inner transparent face
              Padding(
                padding: const EdgeInsets.all(rim),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(innerR),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.music_note_rounded,
                        size: 14,
                        color: OptivusColors.ink,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.ink,
                              letterSpacing: -0.2,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: OptivusColors.ink,
                      ),
                    ],
                  ),
                ),
              ),
              // Glass highlight overlay
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

// ─────────────────────────────────────────────────────────────────────────────
// 6. MeditationControlBar
// ─────────────────────────────────────────────────────────────────────────────

class MeditationControlBar extends StatelessWidget {
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback? onDone;
  final VoidCallback? onStartAnother;

  const MeditationControlBar({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onCancel,
    this.onDone,
    this.onStartAnother,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'ready' || status == 'cancelled') {
      return Center(
        child: _MeditationGlassButton(
          label: 'Start',
          onTap: onStart,
          isPrimary: true,
          color: OptivusColors.trackerAccent,
          fixedWidth: 160,
        ),
      );
    }

    if (status == 'running') {
      return Row(
        children: [
          Flexible(
            flex: 2,
            child: _MeditationGlassButton(
              label: 'Cancel',
              onTap: onCancel,
              isPrimary: false,
              color: OptivusColors.roseAccent,
              icon: Icons.close,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 3,
            child: _MeditationGlassButton(
              label: 'Pause',
              onTap: onPause,
              isPrimary: true,
              color: OptivusColors.trackerAccent,
              icon: Icons.pause,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: _MeditationGlassButton(
              label: 'Finish',
              onTap: onComplete,
              isPrimary: false,
              color: OptivusColors.mintAccent,
              icon: Icons.check,
            ),
          ),
        ],
      );
    }

    if (status == 'paused') {
      return Row(
        children: [
          Flexible(
            flex: 2,
            child: _MeditationGlassButton(
              label: 'Cancel',
              onTap: onCancel,
              isPrimary: false,
              color: OptivusColors.roseAccent,
              icon: Icons.close,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 3,
            child: _MeditationGlassButton(
              label: 'Resume',
              onTap: onResume,
              isPrimary: true,
              color: OptivusColors.trackerAccent,
              icon: Icons.play_arrow,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: _MeditationGlassButton(
              label: 'Finish',
              onTap: onComplete,
              isPrimary: false,
              color: OptivusColors.mintAccent,
              icon: Icons.check,
            ),
          ),
        ],
      );
    }

    if (status == 'completed') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 18, color: OptivusColors.mintAccent.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              const Text(
                'Session complete',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MeditationGlassButton(
                label: 'Done',
                onTap: onDone ?? () {},
                isPrimary: true,
                color: OptivusColors.trackerAccent,
                fixedWidth: 130,
              ),
              const SizedBox(width: 12),
              _MeditationGlassButton(
                label: 'Start Again',
                onTap: onStartAnother ?? () {},
                isPrimary: false,
                color: OptivusColors.sub,
                fixedWidth: 120,
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _MeditationGlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color color;
  final double? fixedWidth;
  final IconData? icon;

  const _MeditationGlassButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.color,
    this.fixedWidth,
    this.icon,
  });

  @override
  State<_MeditationGlassButton> createState() =>
      _MeditationGlassButtonState();
}

class _MeditationGlassButtonState extends State<_MeditationGlassButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: widget.fixedWidth,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isPrimary
                    ? null
                    : Colors.white.withValues(alpha: 0.15),
                gradient: widget.isPrimary
                    ? LinearGradient(
                        colors: [
                          widget.color,
                          widget.color.withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isPrimary
                      ? Colors.white.withValues(alpha: 0.4)
                      : widget.color.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: widget.isPrimary
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 17,
                          color: widget.isPrimary
                              ? Colors.white
                              : widget.color,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: widget.isPrimary
                              ? Colors.white
                              : widget.color,
                        ),
                      ),
                    ],
                  ),
                  // Specular highlight stripe for primary
                  if (widget.isPrimary)
                    Positioned(
                      top: 3,
                      left: 14,
                      right: 14,
                      height: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
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
// 7. Preserved settings sheet widgets (kept as-is)
// ─────────────────────────────────────────────────────────────────────────────

class SessionTypeSelector extends StatelessWidget {
  final List<MeditationSessionTypeUiModel> types;
  final String selectedTypeId;
  final ValueChanged<String> onSelected;

  const SessionTypeSelector({
    super.key,
    required this.types,
    required this.selectedTypeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SESSION TYPE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: OptivusColors.sub,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: types.map((type) {
              final isSelected = type.id == selectedTypeId;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onSelected(type.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? type.accentToken.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? type.accentToken
                            : Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: type.accentToken
                                    .withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(type.icon,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              type.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? type.accentToken
                                    : OptivusColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.description,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? type.accentToken
                                    .withValues(alpha: 0.8)
                                : OptivusColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class MeditationSettingsSheet extends StatelessWidget {
  final String selectedTypeId;
  final ValueChanged<String> onTypeSelected;

  const MeditationSettingsSheet({
    super.key,
    required this.selectedTypeId,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      height: media.size.height * 0.85,
      decoration: const BoxDecoration(
        color: OptivusColors.trackerCardTint,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Meditation Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.ink,
                  ),
                ),
                TrackerHeaderButton(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                media.padding.bottom + 24,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SessionTypeSelector(
                    types: mockMeditationSessionTypes,
                    selectedTypeId: selectedTypeId,
                    onSelected: onTypeSelected,
                  ),
                  const SizedBox(height: 32),
                  const ProgressSummary(),
                  const SizedBox(height: 32),
                  const WeeklyCalmPattern(),
                  const SizedBox(height: 32),
                  const RecentSessionsList(sessions: mockRecentSessions),
                  const SizedBox(height: 32),
                  const InsightCard(),
                  const SizedBox(height: 32),
                  const SettingsPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressSummary extends StatelessWidget {
  const ProgressSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROGRESS SUMMARY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: OptivusColors.sub,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('Today', '5 / 5 min', OptivusColors.trackerAccent),
            _buildStatCard('This week', '5 / 7 days', OptivusColors.purpleAccent),
            _buildStatCard('Total calm', '30 min', OptivusColors.blueAccent),
            _buildStatCard('Best streak', '7 days', OptivusColors.brandAccent),
            _buildStatCard('Current streak', '5 days', OptivusColors.mintAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color accent) {
    return TrackerGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: OptivusColors.sub,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyCalmPattern extends StatelessWidget {
  const WeeklyCalmPattern({super.key});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final minutes = [5, 5, 0, 5, 5, 0, 0];

    return TrackerGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Calm Pattern',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: OptivusColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final min = minutes[index];
              return Column(
                children: [
                  Container(
                    width: 24,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: min > 0
                        ? Container(
                            width: 24,
                            height: 60.0 * (min / 5).clamp(0.2, 1.0),
                            decoration: BoxDecoration(
                              color: OptivusColors.trackerAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          )
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: OptivusColors.sub,
                    ),
                  ),
                  Text(
                    min > 0 ? '${min}m' : '-',
                    style: const TextStyle(
                      fontSize: 10,
                      color: OptivusColors.ink,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class RecentSessionsList extends StatelessWidget {
  final List<MeditationSessionUiModel> sessions;

  const RecentSessionsList({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT SESSIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: OptivusColors.sub,
          ),
        ),
        const SizedBox(height: 12),
        ...sessions.map((session) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TrackerGlassCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      session.type == 'Calm'
                          ? '🧘'
                          : session.type == 'Focus'
                              ? '🎯'
                              : session.type == 'Sleep'
                                  ? '😴'
                                  : '🫂',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.type,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: OptivusColors.ink,
                          ),
                        ),
                        Text(
                          '${session.dateLabel} • ${session.durationMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OptivusColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: session.status == 'Completed'
                          ? OptivusColors.mintAccent.withValues(alpha: 0.15)
                          : OptivusColors.brandAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: session.status == 'Completed'
                            ? OptivusColors.mintAccent
                            : OptivusColors.brandAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      tint: OptivusColors.purpleAccent.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Sensei Insight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.purpleAccent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '"You do not need to fix the whole day. Calm your mind first."',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: OptivusColors.ink,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Today\'s Inner Peace proof is simple: sit still for five minutes.',
            style: TextStyle(
              fontSize: 13,
              color: OptivusColors.sub,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              LiquidChip(
                label: 'Ask Coach',
                isSelected: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ask Coach placeholder')),
                  );
                },
                selectedColor: OptivusColors.purpleAccent,
              ),
              const SizedBox(width: 12),
              LiquidChip(
                label: '1 min tiny',
                isSelected: false,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('1 min tiny placeholder'),
                    ),
                  );
                },
                selectedColor: OptivusColors.trackerAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsPreview extends StatelessWidget {
  const SettingsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SETTINGS & PREFERENCES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: OptivusColors.sub,
          ),
        ),
        const SizedBox(height: 12),
        TrackerGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSettingRow('Default duration', '5 min'),
              _buildSettingRow('Default session type', 'Calm'),
              _buildSettingRow('Breathing rhythm', '4-2-6'),
              _buildSettingRow('Reminder time', '08:00 AM', isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String title, String value,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OptivusColors.ink,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: OptivusColors.sub),
            ],
          ),
        ],
      ),
    );
  }
}
