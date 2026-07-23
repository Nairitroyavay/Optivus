import 'dart:ui';
import 'package:flutter/material.dart';

// ── iOS Liquid Glass Capsule Indicator ────────────────────────────────────────
class LiquidGlassIndicator extends StatelessWidget {
  final double page;
  final int count;
  final void Function(int)? onDotTap;

  const LiquidGlassIndicator({
    super.key,
    required this.page,
    required this.count,
    this.onDotTap,
  });

  static const double _dotD = 6.0;
  static const double _gap = 9.0;
  static const double _pillH = 13.0;
  static const double _pillW = 22.0;
  static const double _padH = 10.0;
  static const double _padV = 7.0;

  double get _step => _dotD + _gap;
  double get _trackContentW => count * _dotD + (count - 1) * _gap;
  double get _trackW => _trackContentW + 2 * _padH;
  double get _trackH => _pillH + 2 * _padV;

  double _cx(int i) => _padH + _dotD / 2 + i * _step;

  @override
  Widget build(BuildContext context) {
    final double p = page.clamp(0.0, (count - 1).toDouble());
    final int from = p.floor().clamp(0, count - 1);
    final int to = p.ceil().clamp(0, count - 1);
    final double frac = p - from.toDouble();

    final double fromCX = _cx(from);
    final double toCX = _cx(to);

    final double leadT = Curves.easeInOut.transform(
      (frac * 1.6).clamp(0.0, 1.0),
    );
    final double lagT = Curves.easeInOut.transform(
      ((frac - 0.35) * 1.6).clamp(0.0, 1.0),
    );
    final bool movingRight = to >= from;

    final double pillLeft = movingRight
        ? (fromCX - _pillW / 2) + lagT * (toCX - fromCX)
        : (fromCX - _pillW / 2) + leadT * (toCX - fromCX);
    final double pillRight = movingRight
        ? (fromCX + _pillW / 2) + leadT * (toCX - fromCX)
        : (fromCX + _pillW / 2) + lagT * (toCX - fromCX);

    final double pillWidth = (pillRight - pillLeft).clamp(
      _pillH,
      double.infinity,
    );
    final double pillTopLocal = _trackH / 2 - _pillH / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_trackH / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: _trackW,
          height: _trackH,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(_trackH / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.40),
              width: 1.0,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Dots
              for (int i = 0; i < count; i++)
                Positioned(
                  left: _cx(i) - _dotD / 2,
                  top: _trackH / 2 - _dotD / 2,
                  width: _dotD,
                  height: _dotD,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                ),

              // Liquid pill — uses the mint color (original: #89F4DD)
              Positioned(
                left: pillLeft,
                top: pillTopLocal,
                width: pillWidth,
                height: _pillH,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_pillH / 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC89F4DD), Color(0x8889F4DD)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.70),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF89F4DD).withValues(alpha: 0.40),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),

              // Tap areas
              for (int i = 0; i < count; i++)
                Positioned(
                  left: _cx(i) - _step / 2,
                  top: 0,
                  width: _step,
                  height: _trackH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDotTap?.call(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
