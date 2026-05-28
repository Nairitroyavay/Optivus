import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/coach_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared Constants & Geometry
// ─────────────────────────────────────────────────────────────────────────────

const double _kR = 24.0;
const double _kTailW = 32.0;
const double _kTailH = 22.0;
const double _kTailX = 26.0;

Path _buildBubblePath(Size size, {required bool isUser}) {
  final w = size.width;
  final bH = size.height - _kTailH;
  final r = _kR;

  final double tailEdgeOffset = isUser ? w - _kTailX : _kTailX;
  final double tailTipX =
      isUser ? tailEdgeOffset + _kTailW * 0.5 : tailEdgeOffset - _kTailW * 0.5;

  final p = Path();

  p.moveTo(r, 0);
  p.lineTo(w - r, 0);
  p.quadraticBezierTo(w, 0, w, r);
  p.lineTo(w, bH - r);
  p.quadraticBezierTo(w, bH, w - r, bH);

  if (isUser) {
    p.lineTo(tailEdgeOffset, bH);
    p.cubicTo(
      tailEdgeOffset + 2,
      bH,
      tailTipX - 2,
      bH + _kTailH * 0.8,
      tailTipX,
      bH + _kTailH,
    );
    p.cubicTo(
      tailTipX - 10,
      bH + _kTailH * 0.5,
      tailEdgeOffset - _kTailW + 8,
      bH,
      tailEdgeOffset - _kTailW,
      bH,
    );
    p.lineTo(r, bH);
  } else {
    p.lineTo(tailEdgeOffset + _kTailW, bH);
    p.cubicTo(
      tailEdgeOffset + _kTailW - 8,
      bH,
      tailTipX + 10,
      bH + _kTailH * 0.5,
      tailTipX,
      bH + _kTailH,
    );
    p.cubicTo(
      tailTipX + 2,
      bH + _kTailH * 0.8,
      tailEdgeOffset - 2,
      bH,
      tailEdgeOffset,
      bH,
    );
    p.lineTo(r, bH);
  }

  p.quadraticBezierTo(0, bH, 0, bH - r);
  p.lineTo(0, r);
  p.quadraticBezierTo(0, 0, r, 0);
  p.close();

  return p;
}

// ─────────────────────────────────────────────────────────────────────────────
// Heavy 3D Liquid Glass Painter
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleShadowPainter extends CustomPainter {
  final bool isUser;
  const _BubbleShadowPainter({required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBubblePath(size, isUser: isUser);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.12), 12, true);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.04), 4, true);
  }

  @override
  bool shouldRepaint(covariant _BubbleShadowPainter old) =>
      old.isUser != isUser;
}

class _HeavyGlassPainter extends CustomPainter {
  final bool isUser;
  const _HeavyGlassPainter({required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBubblePath(size, isUser: isUser);
    final rect = Offset.zero & size;

    canvas.save();
    canvas.clipPath(path);

    canvas.saveLayer(rect, Paint());

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.4),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.clear
        ..color = Colors.black,
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.1),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 1.0),
            Colors.white.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect),
    );

    canvas.restore(); 

    final lensPath = Path();
    lensPath.moveTo(0, size.height * 0.35);
    lensPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.05,
      size.width,
      size.height * 0.30,
    );
    lensPath.lineTo(size.width, 0);
    lensPath.lineTo(0, 0);
    lensPath.close();

    canvas.drawPath(
      lensPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    final sw = size.width * 0.6;
    final sh = 6.0;
    final sx = (size.width - sw) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sx, 4, sw, sh),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeavyGlassPainter old) => old.isUser != isUser;
}

class _BubbleClipper extends CustomClipper<Path> {
  final bool isUser;
  const _BubbleClipper({required this.isUser});

  @override
  Path getClip(Size size) => _buildBubblePath(size, isUser: isUser);
  @override
  bool shouldReclip(covariant _BubbleClipper old) => old.isUser != isUser;
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Components
// ─────────────────────────────────────────────────────────────────────────────

class CoachMessageBubble extends StatelessWidget {
  final CoachMessage message;
  final Widget Function(CoachResponseBlock block)? onBuildActionCard;

  const CoachMessageBubble({
    super.key,
    required this.message,
    this.onBuildActionCard,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = !message.isFromCoach;
    const contentPad = EdgeInsets.fromLTRB(22, 16, 22, 16 + _kTailH);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            CustomPaint(
              painter: _BubbleShadowPainter(isUser: isUser),
              foregroundPainter: _HeavyGlassPainter(isUser: isUser),
              child: ClipPath(
                clipper: _BubbleClipper(isUser: isUser),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: isUser 
                      ? OptivusColors.glassFill 
                      : OptivusColors.coachTop.withValues(alpha: 0.2),
                    padding: contentPad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: OptivusColors.textPrimary,
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (message.blocks.isNotEmpty && onBuildActionCard != null) ...[
                          const SizedBox(height: 12),
                          for (final block in message.blocks)
                            onBuildActionCard!(block),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.timestamp,
              style: const TextStyle(
                  fontSize: 10,
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});
  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CustomPaint(
        painter: const _BubbleShadowPainter(isUser: false),
        foregroundPainter: const _HeavyGlassPainter(isUser: false),
        child: ClipPath(
          clipper: const _BubbleClipper(isUser: false),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: OptivusColors.coachTop.withValues(alpha: 0.2),
              padding: const EdgeInsets.fromLTRB(26, 20, 26, 20 + _kTailH),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, child) {
                      final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
                      final bounce = math.sin(t * math.pi);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 10,
                        height: 10,
                        transform: Matrix4.translationValues(0, -bounce * 6, 0),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: OptivusColors.textSecondary
                                .withValues(alpha: 0.4 + bounce * 0.6)),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
