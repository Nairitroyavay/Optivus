import 'dart:math' show pi;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class OnboardingSaveButton extends StatefulWidget {
  final bool isSaving;
  final bool isSaved;
  final bool enabled;
  final VoidCallback? onTap;

  const OnboardingSaveButton({
    super.key,
    required this.isSaving,
    required this.isSaved,
    required this.enabled,
    this.onTap,
  });

  @override
  State<OnboardingSaveButton> createState() => _OnboardingSaveButtonState();
}

class _OnboardingSaveButtonState extends State<OnboardingSaveButton>
    with TickerProviderStateMixin {
  static const double _height = 27;
  static const double _width = 60;

  late final AnimationController _spinController;
  late final AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant OnboardingSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaving != widget.isSaving ||
        oldWidget.isSaved != widget.isSaved) {
      _syncAnimations();
    }
    if (oldWidget.isSaved && !widget.isSaved) {
      _checkController.reset();
    }
  }

  void _syncAnimations() {
    if (widget.isSaving) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
      return;
    }

    if (_spinController.isAnimating) {
      _spinController.stop();
    }

    if (widget.isSaved) {
      _checkController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        widget.enabled &&
        !widget.isSaving &&
        !widget.isSaved &&
        widget.onTap != null;
    final success = widget.isSaved && !widget.isSaving;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? widget.onTap : null,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.46,
        child: SizedBox(
          width: _width,
          height: _height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_height / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  color: success
                      ? OptivusColors.success.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: success
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 2,
                      left: 6,
                      right: 6,
                      height: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.8),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _content(success),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(bool success) {
    if (widget.isSaving) {
      return SizedBox(
        key: const ValueKey('save_spinner'),
        width: 16,
        height: 16,
        child: AnimatedBuilder(
          animation: _spinController,
          builder: (context, _) {
            return CustomPaint(
              painter: _DualArcSpinnerPainter(
                rotation: _spinController.value * 2 * pi,
              ),
            );
          },
        ),
      );
    }

    if (success) {
      return AnimatedBuilder(
        key: const ValueKey('save_check'),
        animation: _checkController,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(16, 16),
            painter: _CheckmarkPainter(
              progress: Curves.easeOutBack.transform(_checkController.value),
            ),
          );
        },
      );
    }

    return const Text(
      'Save',
      key: ValueKey('save_text'),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
        letterSpacing: 0.1,
      ),
    );
  }
}

class _DualArcSpinnerPainter extends CustomPainter {
  final double rotation;

  const _DualArcSpinnerPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 1.5;
    const strokeWidth = 2.5;
    const arcSweep = 130.0 * (pi / 180.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final greenPaint = Paint()
      ..color = OptivusColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final bluePaint = Paint()
      ..color = const Color(0xFF00BFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, rotation, arcSweep, false, greenPaint);
    canvas.drawArc(rect, rotation + pi, arcSweep, false, bluePaint);
  }

  @override
  bool shouldRepaint(covariant _DualArcSpinnerPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;

  const _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OptivusColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p1 = Offset(size.width * 0.18, size.height * 0.52);
    final p2 = Offset(size.width * 0.42, size.height * 0.75);
    final p3 = Offset(size.width * 0.82, size.height * 0.28);

    final path = Path();
    if (progress <= 0.5) {
      final t = progress / 0.5;
      final current = Offset.lerp(p1, p2, t)!;
      path
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(current.dx, current.dy);
    } else {
      final t = (progress - 0.5) / 0.5;
      final current = Offset.lerp(p2, p3, t)!;
      path
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(current.dx, current.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
