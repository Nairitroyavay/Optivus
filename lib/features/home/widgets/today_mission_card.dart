import 'dart:math';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'home_glass_widgets.dart';
import 'sheets/mission_detail_sheet.dart';

class TodayMissionCard extends StatefulWidget {
  final HomeMissionSummary summary;

  const TodayMissionCard({super.key, required this.summary});

  @override
  State<TodayMissionCard> createState() => _TodayMissionCardState();
}

class _TodayMissionCardState extends State<TodayMissionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnim.forward();
  }

  @override
  void didUpdateWidget(covariant TodayMissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.percentage != widget.summary.percentage) {
      _ringAnim.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ringAnim.dispose();
    super.dispose();
  }

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textSecondary.withValues(alpha: 0.9),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final totalTasks = summary.actionsTotal;
    final completedTasks = summary.actionsDone;
    // Fallback to a mock planned minutes if not available in summary directly
    final completedMinutes = summary.focusMinutes;
    final progress = summary.percentage;

    return GestureDetector(
      onTap: () {
        MissionDetailSheet.show(context);
      },
      child: HomeGlassCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Mission",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.textPrimary,
                ),
              ),
              _GlassOrb(
                size: 34,
                colors: [const Color(0xFFD0D8E8), const Color(0xFFB0B8CC)],
                child: const Icon(
                  Icons.track_changes_outlined,
                  size: 16,
                  color: OptivusColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (context, child) => _MissionRing(
              progress: progress * _ringAnim.value,
              isLoading: false,
            ),
          ),
          const SizedBox(height: 20),
          if (totalTasks == 0)
            const Text(
              'No mission tasks scheduled yet',
              style: TextStyle(
                fontSize: 13,
                color: OptivusColors.textSecondary,
              ),
            )
          else
            const Text(
              'Identity-weighted progress',
              style: TextStyle(
                fontSize: 13,
                color: OptivusColors.textSecondary,
              ),
            ),
          const SizedBox(height: 14),
          // Stat pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statPill('Actions', '$completedTasks/$totalTasks'),
              _statPill('Focus', '${completedMinutes}m'),
              _statPill('Saved', '₹${summary.moneySaved}'),
              _statPill('Avoided', '${summary.badHabitsAvoided}'),
            ],
          ),
        ],
      ),
    ));
  }
}

class _GlassOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;
  final Widget child;

  const _GlassOrb({
    required this.size,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _MissionRing extends StatelessWidget {
  final double progress;
  final bool isLoading;

  const _MissionRing({required this.progress, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLoading)
            const CircularProgressIndicator(color: OptivusColors.homeAccent)
          else ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.0),
                    const Color(0xFFF36F78).withValues(alpha: 0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  bgColor: Colors.white.withValues(alpha: 0.25),
                  progressColor: const Color(0xFFF36F78),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  'Complete',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color progressColor;

  _RingPainter({
    required this.progress,
    required this.bgColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [
          progressColor.withValues(alpha: 0.25),
          progressColor.withValues(alpha: 0.7),
          progressColor,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * pi * progress;
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.progressColor != progressColor;
  }
}
