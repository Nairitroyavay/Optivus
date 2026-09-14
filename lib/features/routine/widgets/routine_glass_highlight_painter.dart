import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// GlassHighlightPainter — outer/inner sweeps + rainbow prism corner.
/// Reusable 3D glass highlight painter for routine widgets and liquid glass pills.
class GlassHighlightPainter extends CustomPainter {
  final double outerR;
  final double innerR;
  final double rim;

  const GlassHighlightPainter({
    required this.outerR,
    required this.innerR,
    required this.rim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(outerR),
    );

    final innerRect = Rect.fromLTWH(
      rim,
      rim,
      size.width - rim * 2,
      size.height - rim * 2,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerR),
    );

    // Outer Edge White Sweep (Top left)
    final outerSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.transparent, Colors.white24],
        stops: [0.0, 0.4, 1.0],
      ).createShader(outerRect);
    canvas.drawRRect(outerRRect, outerSweepPaint);

    // Inner Edge Sweep
    final innerSweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.1),
        ],
      ).createShader(innerRect);
    canvas.drawRRect(innerRRect, innerSweepPaint);

    // Thick Glare inside the rim (top-left)
    final glarePath = Path()
      ..addArc(
        Rect.fromLTWH(rim * 0.4, rim * 0.4, outerR * 2.5, outerR * 2.5),
        3.14,
        1.57,
      );
    canvas.drawPath(
      glarePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 0.7
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Rainbow prism at bottom-right corner of the rim
    final donut = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outerRRect),
      Path()..addRRect(innerRRect),
    );
    canvas.save();
    canvas.clipPath(donut);

    // White base glow
    canvas.drawCircle(
      Offset(size.width - rim * 1.5, size.height - rim * 1.5),
      25,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Blue prism
    canvas.drawCircle(
      Offset(size.width - 5, size.height - 15),
      20,
      Paint()
        ..color = OptivusColors.routinePrismBlue.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Amber prism
    canvas.drawCircle(
      Offset(size.width - 25, size.height - 5),
      20,
      Paint()
        ..color = OptivusColors.routinePrismYellow.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Pink prism
    canvas.drawCircle(
      Offset(size.width - 15, size.height - 30),
      20,
      Paint()
        ..color = OptivusColors.routinePrismPink.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Inner shadow for refraction depth
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rim * 1.8
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.6, 1.0],
        ).createShader(outerRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlassHighlightPainter oldDelegate) {
    return outerR != oldDelegate.outerR || rim != oldDelegate.rim;
  }
}
