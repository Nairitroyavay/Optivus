import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'meditation_mock_data.dart';

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
    return TrackerGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 24,
      opacity: 0.7,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today\'s target',
                style: TextStyle(
                  fontSize: 12,
                  color: kSub,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '$completedMinutes / $targetMinutes min',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildMiniChip('Streak $streakDays', kAmber),
              const SizedBox(width: 8),
              _buildMiniChip('Calm', kPurple),
            ],
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
            color: kSub,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? type.accentToken.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? type.accentToken : Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: type.accentToken.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(type.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              type.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? type.accentToken : kInk,
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
                            color: isSelected ? type.accentToken.withValues(alpha: 0.8) : kSub,
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

class DurationSelector extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onSelected;

  const DurationSelector({
    super.key,
    required this.selectedDuration,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final durations = [1, 3, 5, 10];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        ...durations.map((duration) {
          final isSelected = selectedDuration == duration;
          return LiquidChip(
            label: '$duration min',
            selected: isSelected,
            onTap: () => onSelected(duration),
            accentColor: OptivusColors.trackerAccent,
          );
        }),
        LiquidChip(
          label: 'Custom',
          selected: ![1, 3, 5, 10].contains(selectedDuration),
          onTap: () {
             _showCustomDurationSheet(context);
          },
          accentColor: kSub,
        ),
      ],
    );
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kInk),
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
                     selected: selectedDuration == d, 
                     onTap: () {
                       onSelected(d);
                       Navigator.pop(context);
                     }, 
                     accentColor: OptivusColors.trackerAccent,
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

class LiquidGlassBreathingOrb extends StatefulWidget {
  final bool isRunning;
  final String currentPhase;
  final Color accentColor;

  const LiquidGlassBreathingOrb({
    super.key,
    required this.isRunning,
    required this.currentPhase,
    required this.accentColor,
  });

  @override
  State<LiquidGlassBreathingOrb> createState() => _LiquidGlassBreathingOrbState();
}

class _LiquidGlassBreathingOrbState extends State<LiquidGlassBreathingOrb> with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _liquidController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOutSine),
    );

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    if (widget.isRunning) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassBreathingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _startAnimation();
      } else {
        _breathingController.stop();
      }
    }
    
    if (widget.isRunning && widget.currentPhase != oldWidget.currentPhase) {
        if (widget.currentPhase == 'Breathe in') {
            _breathingController.forward();
        } else if (widget.currentPhase == 'Hold') {
            _breathingController.stop();
        } else if (widget.currentPhase == 'Breathe out') {
            _breathingController.reverse();
        } else if (widget.currentPhase == 'Rest') {
            _breathingController.stop();
        }
    }
  }

  void _startAnimation() {
      if (widget.currentPhase == 'Breathe in') {
          _breathingController.forward();
      } else if (widget.currentPhase == 'Breathe out') {
          _breathingController.reverse();
      } else if (!_breathingController.isAnimating) {
         _breathingController.repeat(reverse: true);
      }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _liquidController]),
      builder: (context, child) {
        final scale = widget.isRunning ? _scaleAnimation.value : 1.0;
        final rotation = _liquidController.value * 2 * math.pi;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Colorful caustics shadow cast downward
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.35),
                  blurRadius: 50,
                  spreadRadius: widget.isRunning ? 15 * _scaleAnimation.value : 5,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: kPurple.withValues(alpha: 0.15),
                  blurRadius: 80,
                  spreadRadius: 20,
                  offset: const Offset(0, 40),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Inner vibrant liquid core
                ClipOval(
                  child: Stack(
                    children: [
                      // Base iridescent gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            center: Alignment.center,
                            transform: GradientRotation(rotation),
                            colors: [
                              widget.accentColor,
                              kPurple,
                              kBlue,
                              widget.accentColor,
                            ],
                            stops: const [0.0, 0.33, 0.66, 1.0],
                          ),
                        ),
                      ),
                      // Floating blob 1
                      Transform.translate(
                        offset: Offset(40 * math.cos(rotation), 40 * math.sin(rotation)),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.5, -0.5),
                              radius: 0.8,
                              colors: [
                                Colors.white.withValues(alpha: 0.8),
                                widget.accentColor.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Floating blob 2
                      Transform.translate(
                        offset: Offset(-50 * math.cos(rotation * 1.5), -50 * math.sin(rotation * 1.5)),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(0.5, 0.5),
                              radius: 0.7,
                              colors: [
                                kPurple.withValues(alpha: 0.9),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Heavy Frosted glass blur effect for thick refraction
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                
                // 3D Glass Shell (Thick refractive edge & Ambient Occlusion)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2.0,
                    ),
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      radius: 1.05,
                      colors: [
                        Colors.white.withValues(alpha: 0.4), // Top left light hit
                        Colors.white.withValues(alpha: 0.0), // Transparent center
                        Colors.black.withValues(alpha: 0.5), // Bottom right ambient occlusion
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                    boxShadow: [
                      // Intense inner glow top-left
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.95),
                        blurRadius: 24,
                        spreadRadius: -6,
                        offset: const Offset(-8, -8),
                        blurStyle: BlurStyle.inner,
                      ),
                      // Inner cyan/purple glow
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: -10,
                        offset: const Offset(10, 10),
                        blurStyle: BlurStyle.inner,
                      ),
                      // Intense inner dark shadow bottom-right
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 35,
                        spreadRadius: -10,
                        offset: const Offset(15, 15),
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
                  ),
                ),

                // Primary Specular Highlight (Crisp top-left crescent)
                Positioned(
                  top: 6,
                  left: 24,
                  right: 24,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(120),
                        bottom: Radius.circular(80),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.8],
                      ),
                    ),
                  ),
                ),
                
                // Secondary Bounce Light (Bottom right curve)
                Positioned(
                  bottom: 6,
                  left: 36,
                  right: 36,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(80),
                        bottom: Radius.circular(120),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.5),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.9],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TimerDisplay extends StatelessWidget {
  final int remainingSeconds;
  final String status;
  final String currentPhase;
  final String sessionTypeName;

  const TimerDisplay({
    super.key,
    required this.remainingSeconds,
    required this.status,
    required this.currentPhase,
    required this.sessionTypeName,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Text(
          status == 'completed' ? '00:00' : '$minutes:$seconds',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: kInk,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status == 'running' ? currentPhase : '$sessionTypeName Meditation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: status == 'running' ? OptivusColors.trackerAccent : kSub,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class TrackerGlassHighlightPainter extends CustomPainter {
  final double radius;

  TrackerGlassHighlightPainter({this.radius = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.2),
        ],
        stops: const [0.0, 0.2, 0.8, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

class _MeditationMusicFilterState extends State<MeditationMusicFilter> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _closeDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  void _showDropdown() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final dropdownWidth = 240.0;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(size.width - dropdownWidth, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: _buildDropdownContent(dropdownWidth),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  Widget _buildDropdownContent(double width) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CustomPaint(
            painter: TrackerGlassHighlightPainter(radius: 20),
            child: ListView(
              padding: const EdgeInsets.all(8),
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildTrackItem(
                  id: 'silent',
                  title: 'Silent',
                  icon: '🤫',
                  isSelected: widget.selectedSoundId == 'silent',
                ),
                ...mockMeditationCategories.map((cat) {
                  final catTracks = widget.sounds.where((s) => s.categoryId == cat.id).toList();
                  if (catTracks.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(
                          cat.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: kSub,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...catTracks.map((track) => _buildTrackItem(
                            id: track.id,
                            title: track.title,
                            icon: track.icon,
                            isSelected: widget.selectedSoundId == track.id,
                          )),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackItem({required String id, required String title, required String icon, required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        widget.onSelected(id);
        _closeDropdown();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? OptivusColors.trackerAccent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kInk : kSub,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) const Icon(Icons.check, color: OptivusColors.trackerAccent, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _closeDropdown();
    super.dispose();
  }

  @override
  void didUpdateWidget(MeditationMusicFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSoundId != oldWidget.selectedSoundId && _isOpen) {
      _closeDropdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSound = widget.sounds.firstWhere(
      (s) => s.id == widget.selectedSoundId,
      orElse: () => MeditationSoundUiModel(
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
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CustomPaint(
                painter: TrackerGlassHighlightPainter(radius: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note_rounded, size: 14, color: kInk),
                    const SizedBox(width: 4),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        selectedSound.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(_isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: kInk),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kInk),
                ),
                LiquidIconBtn(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, media.padding.bottom + 24),
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

class MeditationControlBar extends StatelessWidget {
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const MeditationControlBar({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'ready' || status == 'cancelled') {
      return Center(
        child: LiquidButton(
          label: 'Start Session',
          onTap: onStart,
          color: OptivusColors.trackerAccent,
        ),
      );
    }

    if (status == 'running' || status == 'paused') {
      final isPaused = status == 'paused';
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSecondaryBtn(Icons.close, 'Cancel', onCancel, kRose),
          const SizedBox(width: 16),
          Expanded(
            child: LiquidButton(
              label: isPaused ? 'Resume' : 'Pause',
              onTap: isPaused ? onResume : onPause,
              color: isPaused ? kMint : kAmber,
              leading: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          _buildSecondaryBtn(Icons.check, 'Finish', onComplete, kMint),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSecondaryBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
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

class CompletionCard extends StatelessWidget {
  final int durationMinutes;
  final VoidCallback onDone;
  final VoidCallback onStartAnother;
  final VoidCallback onAddNote;

  const CompletionCard({
    super.key,
    required this.durationMinutes,
    required this.onDone,
    required this.onStartAnother,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      padding: const EdgeInsets.all(24),
      radius: 32,
      tint: OptivusColors.trackerCardTint,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kMint.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.check_circle, color: kMint, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Meditation Completed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$durationMinutes min calm time',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kSub,
            ),
          ),
          const SizedBox(height: 24),
          _buildSyncItem('Routine task completed', kMint),
          _buildSyncItem('Mind pillar updated', kPurple),
          _buildSyncItem('Inner Peace goal updated', kBlue),
          const SizedBox(height: 32),
          LiquidButton(
            label: 'Done',
            onTap: onDone,
            color: OptivusColors.trackerAccent,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onAddNote,
                child: const Text('Add note', style: TextStyle(color: kSub, fontWeight: FontWeight.bold)),
              ),
              const Text('•', style: TextStyle(color: kSub)),
              TextButton(
                onPressed: onStartAnother,
                child: const Text('Start another', style: TextStyle(color: kSub, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSyncItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kInk,
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
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('Today', '5 / 5 min', OptivusColors.trackerAccent),
            _buildStatCard('This week', '5 / 7 days', kPurple),
            _buildStatCard('Total calm', '30 min', kBlue),
            _buildStatCard('Best streak', '7 days', kAmber),
            _buildStatCard('Current streak', '5 days', kMint),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color accent) {
    return LiquidCard(
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
              color: kSub,
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

    return LiquidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Calm Pattern',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kInk,
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
                      color: kSub,
                    ),
                  ),
                  Text(
                    min > 0 ? '${min}m' : '-',
                    style: const TextStyle(
                      fontSize: 10,
                      color: kInk,
                    ),
                  )
                ],
              );
            }),
          )
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
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        ...sessions.map((session) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: LiquidCard(
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
                      session.type == 'Calm' ? '🧘' : session.type == 'Focus' ? '🎯' : session.type == 'Sleep' ? '😴' : '🫂',
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
                            color: kInk,
                          ),
                        ),
                        Text(
                          '${session.dateLabel} • ${session.durationMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: session.status == 'Completed' ? kMint.withValues(alpha: 0.15) : kAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: session.status == 'Completed' ? kMint : kAmber,
                      ),
                    ),
                  )
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
    return LiquidCard(
      tint: kPurple.withValues(alpha: 0.1),
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
                  color: kPurple.withValues(alpha: 0.8),
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
              color: kInk,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Today\'s Inner Peace proof is simple: sit still for five minutes.',
            style: TextStyle(
              fontSize: 13,
              color: kSub,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              LiquidChip(
                label: 'Ask Coach',
                selected: false,
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ask Coach placeholder')));
                },
                accentColor: kPurple,
              ),
              const SizedBox(width: 12),
              LiquidChip(
                label: '1 min tiny',
                selected: false,
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1 min tiny placeholder')));
                },
                accentColor: OptivusColors.trackerAccent,
              ),
            ],
          )
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
            color: kSub,
          ),
        ),
        const SizedBox(height: 12),
        LiquidCard(
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

  Widget _buildSettingRow(String title, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kInk,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: kSub,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: kSub),
            ],
          )
        ],
      ),
    );
  }
}
