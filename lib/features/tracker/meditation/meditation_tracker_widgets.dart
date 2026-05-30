import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
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
      opacity: 0.72,
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
                color: Colors.white.withValues(alpha: 0.5),
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
// 2. MeditationDurationSelector & MeditationDurationChip
// ─────────────────────────────────────────────────────────────────────────────

class MeditationDurationSelector extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onSelected;
  final bool enabled;

  const MeditationDurationSelector({
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
          return MeditationDurationChip(
            label: '$duration min',
            isSelected: isSelected,
            onTap: enabled ? () => onSelected(duration) : null,
          );
        }),
        MeditationDurationChip(
          label: 'Custom',
          isSelected: ![1, 3, 5, 10].contains(selectedDuration),
          onTap: enabled
              ? () {
                  _showCustomDurationSheet(context);
                }
              : null,
        ),
      ],
    );

    if (!enabled) {
      content = Opacity(opacity: 0.45, child: IgnorePointer(child: content));
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
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                  return MeditationDurationChip(
                    label: '$d min',
                    isSelected: selectedDuration == d,
                    onTap: () {
                      onSelected(d);
                      Navigator.pop(context);
                    },
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

class MeditationDurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const MeditationDurationChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? OptivusColors.trackerAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? OptivusColors.trackerAccent
                : Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? OptivusColors.ink : OptivusColors.sub,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. AiLiquidMeditationOrb
// ─────────────────────────────────────────────────────────────────────────────

class AiLiquidMeditationOrb extends StatefulWidget {
  final bool isRunning;
  final String currentPhase; // 'ready', 'Inhale', 'Hold', 'Exhale'
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
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.inhaleSeconds > 0 ? widget.inhaleSeconds : 1),
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (widget.isRunning) {
      _applyPhase(widget.currentPhase);
    }
  }

  @override
  void didUpdateWidget(covariant AiLiquidMeditationOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isRunning && oldWidget.isRunning) {
      _breathingController.stop();
      if (widget.currentPhase == 'ready') {
        _breathingController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
        );
      }
      return;
    }

    if (widget.isRunning && !oldWidget.isRunning) {
      _applyPhase(widget.currentPhase);
      return;
    }

    if (widget.isRunning && widget.currentPhase != oldWidget.currentPhase) {
      _applyPhase(widget.currentPhase);
    }
  }

  void _applyPhase(String phase) {
    if (phase == 'Inhale') {
      _breathingController.duration = Duration(seconds: widget.inhaleSeconds);
      _breathingController.forward();
    } else if (phase == 'Hold') {
      _breathingController.stop();
    } else if (phase == 'Exhale') {
      _breathingController.duration = Duration(seconds: widget.exhaleSeconds);
      _breathingController.reverse();
    } else if (phase == 'ready') {
      _breathingController.stop();
      _breathingController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shimmerController]),
      builder: (context, child) {
        final scale = widget.isRunning
            ? _scaleAnimation.value
            : (widget.currentPhase == 'ready' ? 1.0 : _scaleAnimation.value);
        final shimmer = _shimmerController.value * 2 * math.pi;

        return SizedBox(
          width: size + 60,
          height: size + 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Reflection below
              Positioned(
                bottom: 10,
                child: Container(
                  width: size * 0.6,
                  height: size * 0.1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.05),
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF182FA7).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main Orb Container with Transform
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  child: Stack(
                    children: [
                      // Outer cyan glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF28BCD9).withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      
                      // Main sphere radial gradient (Base Layer)
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment.center,
                            colors: [
                              Color(0xFFFFFFFF), // White centerish
                              Color(0xFF28BCD9), // Cyan
                              Color(0xFF182FA7), // Deep blue
                              Color(0xFF02021B), // Navy edge
                            ],
                            stops: [0.0, 0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                      
                      // Inner liquid wave/swirl (CustomPainter)
                      ClipOval(
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _AiOrbSwirlPainter(
                            rotation: shimmer,
                          ),
                        ),
                      ),
                      
                      // Glass rim stroke
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2.0,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.8),
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 0.8, 1.0],
                          ),
                        ),
                      ),

                      // Top-left white highlight (specular reflection)
                      Positioned(
                        top: size * 0.12,
                        left: size * 0.15,
                        child: Transform.rotate(
                          angle: -math.pi / 4.5,
                          child: Container(
                            width: size * 0.35,
                            height: size * 0.12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(size * 0.1),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.9),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Secondary subtle highlight bottom right
                      Positioned(
                        bottom: size * 0.08,
                        right: size * 0.15,
                        child: Transform.rotate(
                          angle: -math.pi / 4.5,
                          child: Container(
                            width: size * 0.4,
                            height: size * 0.06,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(size * 0.05),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
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

class _AiOrbSwirlPainter extends CustomPainter {
  final double rotation;

  _AiOrbSwirlPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Use a blending mode to create the deep liquid feel
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Swirl 1: Deep Navy
    final paint1 = Paint()
      ..color = const Color(0xFF02021B).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      
    final path1 = Path();
    path1.moveTo(
      center.dx + radius * 0.8 * math.cos(rotation),
      center.dy + radius * 0.8 * math.sin(rotation),
    );
    path1.quadraticBezierTo(
      center.dx + radius * 0.9 * math.cos(rotation + math.pi / 2),
      center.dy + radius * 0.9 * math.sin(rotation + math.pi / 2),
      center.dx + radius * 0.2 * math.cos(rotation + math.pi),
      center.dy + radius * 0.2 * math.sin(rotation + math.pi),
    );
    path1.quadraticBezierTo(
      center.dx + radius * 0.1 * math.cos(rotation + 3 * math.pi / 2),
      center.dy + radius * 0.1 * math.sin(rotation + 3 * math.pi / 2),
      center.dx + radius * 0.8 * math.cos(rotation),
      center.dy + radius * 0.8 * math.sin(rotation),
    );
    canvas.drawPath(path1, paint1);

    // Swirl 2: Cyan
    final paint2 = Paint()
      ..color = const Color(0xFF28BCD9).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      
    final path2 = Path();
    path2.moveTo(
      center.dx + radius * 0.5 * math.cos(-rotation * 1.2),
      center.dy + radius * 0.5 * math.sin(-rotation * 1.2),
    );
    path2.quadraticBezierTo(
      center.dx + radius * 0.8 * math.cos(-rotation * 1.2 + math.pi / 2),
      center.dy + radius * 0.8 * math.sin(-rotation * 1.2 + math.pi / 2),
      center.dx + radius * 0.4 * math.cos(-rotation * 1.2 + math.pi),
      center.dy + radius * 0.4 * math.sin(-rotation * 1.2 + math.pi),
    );
    path2.quadraticBezierTo(
      center.dx + radius * 0.2 * math.cos(-rotation * 1.2 + 3 * math.pi / 2),
      center.dy + radius * 0.2 * math.sin(-rotation * 1.2 + 3 * math.pi / 2),
      center.dx + radius * 0.5 * math.cos(-rotation * 1.2),
      center.dy + radius * 0.5 * math.sin(-rotation * 1.2),
    );
    canvas.drawPath(path2, paint2);

    // Swirl 3: Soft Blue
    final paint3 = Paint()
      ..color = const Color(0xFFA4C1D9).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      
    canvas.drawCircle(
      Offset(
        center.dx + radius * 0.3 * math.cos(rotation * 2),
        center.dy + radius * 0.3 * math.sin(rotation * 2),
      ),
      radius * 0.4,
      paint3,
    );
    
    // Draw fine scanlines/fibers across the orb (subtle)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 6 + math.sin(rotation) * 0.1); // subtle rotation
    
    for (double y = -radius; y <= radius; y += 4) {
      final xExtent = math.sqrt(math.max(0, radius * radius - y * y));
      // Add slight curve based on y to make it spherical
      final curve = (1 - y.abs() / radius) * 10 * math.sin(rotation * 3 + y * 0.05);
      
      final path = Path();
      path.moveTo(-xExtent, y);
      path.quadraticBezierTo(0, y + curve, xExtent, y);
      canvas.drawPath(path, linePaint);
    }
    
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AiOrbSwirlPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
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

    String subtitle = '';
    if (status == 'ready' || status == 'paused') {
      subtitle = '$sessionTypeName Meditation';
    } else if (status == 'running') {
      subtitle = currentPhase;
    } else if (status == 'completed') {
      subtitle = 'Meditation completed';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: OptivusColors.ink.withValues(alpha: 0.90),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: status == 'running'
                ? OptivusColors.trackerAccent
                : OptivusColors.sub,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. MeditationMusicFilter & Pill & Painter
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
      duration: const Duration(milliseconds: 200),
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
              Positioned.fill(child: Container(color: Colors.transparent)),
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
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final List<Widget> rows = [];

        // Silent row
        final silentSelected = widget.selectedSoundId == 'silent';
        rows.add(
          _buildRow(
            title: 'Silent',
            icon: '🤫',
            isSelected: silentSelected,
            onTap: () => _selectTrack('silent'),
          ),
        );

        // Categories
        for (final cat in mockMeditationCategories) {
          final isCatExpanded = _expandedCategoryId == cat.id;

          rows.add(
            _buildRow(
              title: cat.label,
              isHeader: true,
              isExpanded: isCatExpanded,
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
            ),
          );

          if (isCatExpanded) {
            final subCats = mockMeditationSubCategories
                .where((sc) => sc.categoryId == cat.id)
                .toList();

            for (final subCat in subCats) {
              final isSubExpanded = _expandedSubCategoryId == subCat.id;

              rows.add(
                _buildRow(
                  title: subCat.label,
                  isSubHeader: true,
                  isExpanded: isSubExpanded,
                  onTap: () {
                    setSheetState(() {
                      if (_expandedSubCategoryId == subCat.id) {
                        _expandedSubCategoryId = null;
                      } else {
                        _expandedSubCategoryId = subCat.id;
                      }
                    });
                  },
                ),
              );

              if (isSubExpanded) {
                final tracks =
                    widget.sounds
                        .where(
                          (s) =>
                              s.isActive &&
                              s.categoryId == cat.id &&
                              s.subCategoryId == subCat.id,
                        )
                        .toList()
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                for (final track in tracks) {
                  final isTrackSelected = widget.selectedSoundId == track.id;
                  rows.add(
                    _buildRow(
                      title: track.title,
                      icon: track.icon,
                      duration: track.durationLabel,
                      isSelected: isTrackSelected,
                      isTrack: true,
                      onTap: () => _selectTrack(track.id),
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: OptivusColors.ink.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: rows,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow({
    required String title,
    String? icon,
    String? duration,
    bool isSelected = false,
    bool isHeader = false,
    bool isSubHeader = false,
    bool isTrack = false,
    bool? isExpanded,
    required VoidCallback onTap,
  }) {
    double leftPad = 16.0;
    if (isSubHeader) leftPad = 28.0;
    if (isTrack) leftPad = 40.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: isSelected
            ? OptivusColors.trackerAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        padding: EdgeInsets.only(left: leftPad, right: 16, top: 10, bottom: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Text(
                icon,
                style: const TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isHeader ? 14 : 13,
                  fontWeight: isSelected || isHeader
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: OptivusColors.ink.withValues(
                    alpha: isTrack && !isSelected ? 0.7 : 1.0,
                  ),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (duration != null) ...[
              const SizedBox(width: 8),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 11,
                  color: OptivusColors.sub,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
            if (isExpanded != null) ...[
              const SizedBox(width: 8),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 16,
                color: OptivusColors.sub,
              ),
            ],
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 16, color: OptivusColors.ink),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSound = widget.sounds.firstWhere(
      (s) => s.id == widget.selectedSoundId,
      orElse: () => const MeditationSoundUiModel(
        id: 'silent',
        title: 'Silent',
        durationLabel: '',
        categoryId: '',
        subCategoryId: '',
        icon: '🤫',
      ),
    );

    // Provide a compact label for the pill
    String pillLabel = selectedSound.title;
    if (pillLabel.contains('432 Hz')) {
      pillLabel = '432 Hz';
    } else if (pillLabel.contains('Rain')) {
      pillLabel = 'Rain';
    } else if (pillLabel.contains('Ocean')) {
      pillLabel = 'Ocean';
    } else if (pillLabel.contains('Om')) {
      pillLabel = 'Om';
    } else if (pillLabel.contains('Ambient')) {
      pillLabel = 'Ambient';
    } else if (pillLabel.contains('Silent')) {
      pillLabel = 'Silent';
    }

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () => _overlay == null ? _openDropdown() : _closeDropdown(),
        child: Container(
          width: 150,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note, size: 16, color: OptivusColors.ink),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  pillLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: OptivusColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. MeditationControlBar & MeditationGlassButton
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
        child: MeditationGlassButton(
          label: 'Start',
          onTap: onStart,
          isPrimary: true,
          color: OptivusColors.trackerAccent,
          fixedWidth: 150,
        ),
      );
    }

    if (status == 'running') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MeditationGlassButton(
            label: 'Cancel',
            onTap: onCancel,
            isPrimary: false,
            color: OptivusColors.roseAccent,
            fixedWidth: 95,
          ),
          const SizedBox(width: 12),
          MeditationGlassButton(
            label: 'Pause',
            onTap: onPause,
            isPrimary: true,
            color: OptivusColors.trackerAccent,
            fixedWidth: 135,
          ),
          const SizedBox(width: 12),
          MeditationGlassButton(
            label: 'Finish',
            onTap: onComplete,
            isPrimary: false,
            color: OptivusColors.mintAccent,
            fixedWidth: 95,
          ),
        ],
      );
    }

    if (status == 'paused') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MeditationGlassButton(
            label: 'Cancel',
            onTap: onCancel,
            isPrimary: false,
            color: OptivusColors.roseAccent,
            fixedWidth: 95,
          ),
          const SizedBox(width: 12),
          MeditationGlassButton(
            label: 'Resume',
            onTap: onResume,
            isPrimary: true,
            color: OptivusColors.trackerAccent,
            fixedWidth: 135,
          ),
          const SizedBox(width: 12),
          MeditationGlassButton(
            label: 'Finish',
            onTap: onComplete,
            isPrimary: false,
            color: OptivusColors.mintAccent,
            fixedWidth: 95,
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
              MeditationGlassButton(
                label: 'Done',
                onTap: onDone ?? () {},
                isPrimary: true,
                color: OptivusColors.trackerAccent,
                fixedWidth: 135,
              ),
              const SizedBox(width: 12),
              MeditationGlassButton(
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

class MeditationGlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color color;
  final double? fixedWidth;

  const MeditationGlassButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.color,
    this.fixedWidth,
  });

  @override
  State<MeditationGlassButton> createState() => _MeditationGlassButtonState();
}

class _MeditationGlassButtonState extends State<MeditationGlassButton> {
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
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.fixedWidth,
          height: 46,
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? widget.color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: widget.isPrimary
                  ? widget.color
                  : widget.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: widget.isPrimary ? FontWeight.w800 : FontWeight.w600,
              color: widget.isPrimary ? OptivusColors.ink : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
