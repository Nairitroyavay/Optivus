import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/coach/widgets/coach_bottom_sheets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exact Refractive Glass Input Bar
// ─────────────────────────────────────────────────────────────────────────────

class CoachInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasText;
  final VoidCallback onSend;

  const CoachInputField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hasText,
    required this.onSend,
  });

  @override
  State<CoachInputField> createState() => _CoachInputFieldState();
}

class _CoachInputFieldState extends State<CoachInputField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final phase = _anim.value * math.pi * 2;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: 66,
            child: CustomPaint(
              painter: OuterShadowWavyPainter(phase),
              child: ClipPath(
                clipper: WavyClipper(phase),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: CustomPaint(
                    painter: WavyGlassInputPainter(phase),
                    child: Row(
                      children: [
                        // --- Left '+' Icon ---
                        const SizedBox(width: 4),
                        _buildPlusBtn(),

                        // --- Inner Cavity ---
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: CustomPaint(
                              painter: InnerCavityPainter(),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: widget.controller,
                                      focusNode: widget.focusNode,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => widget.onSend(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: OptivusColors.textBody,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Type a message...',
                                        hintStyle: TextStyle(
                                          color: OptivusColors.textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- Right Icon (Mic / Send) ---
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: widget.hasText
                              ? Padding(
                                  key: const ValueKey('send'),
                                  padding:
                                      const EdgeInsets.only(right: 6, left: 6),
                                  child: _buildSendBtn(),
                                )
                              : Padding(
                                  key: const ValueKey('mic'),
                                  padding:
                                      const EdgeInsets.only(right: 6, left: 6),
                                  child: _buildIconBtn(Icons.mic_rounded, 26),
                                ),
                        ),
                      ],
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

  Widget _buildPlusBtn() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        CoachBottomSheets.showInputPlusMenuSheet(context);
      },
      child: Container(
        width: 48,
        height: 48,
        color: Colors.transparent,
        child: const Center(
          child: Icon(Icons.add_rounded, size: 30, color: OptivusColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, double size) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 48,
        height: 48,
        color: Colors.transparent,
        child: Center(
          child: Icon(icon, size: size, color: OptivusColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildSendBtn() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onSend();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [OptivusColors.coachAccent, OptivusColors.brandAccent],
          ),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.coachAccent.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Center(
          child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

Path getMorphingPillPath(Size size, double phase,
    {double ampTop = 4.0,
    double ampBot = 4.0,
    double topYOffset = 0.0,
    double botYOffset = 0.0,
    double phaseOffset = 0.0}) {
  final w = size.width;
  final h = size.height;
  final r = h / 2;
  final path = Path();
  final segments = 50;

  final startTopX = r;
  final endTopX = w - r;

  final arcRadius =
      Radius.circular(math.max(0.1, r - (topYOffset - botYOffset) / 2));

  path.moveTo(startTopX, topYOffset);

  for (int i = 0; i <= segments; i++) {
    double t = i / segments;
    double x = startTopX + t * (endTopX - startTopX);

    double attenuation = math.sin(t * math.pi);
    attenuation = attenuation * attenuation * (3 - 2 * attenuation);

    double wave = math.sin(t * math.pi * 3 + phase + phaseOffset) * 0.7 +
        math.cos(t * math.pi * 5 - phase * 1.3) * 0.3;

    double y = topYOffset + wave * ampTop * attenuation;
    if (i == 0 || i == segments) y = topYOffset; 

    path.lineTo(x, y);
  }

  path.arcToPoint(
    Offset(endTopX, h + botYOffset),
    radius: arcRadius,
    clockwise: true,
  );

  for (int i = segments; i >= 0; i--) {
    double t = i / segments;
    double x = startTopX + t * (endTopX - startTopX);

    double attenuation = math.sin(t * math.pi);
    attenuation = attenuation * attenuation * (3 - 2 * attenuation);

    double wave = math.sin(t * math.pi * 4 - phase + phaseOffset) * 0.7 +
        math.cos(t * math.pi * 6 + phase * 1.1) * 0.3;

    double y = h + botYOffset + wave * ampBot * attenuation;
    if (i == 0 || i == segments) y = h + botYOffset; 

    path.lineTo(x, y);
  }

  path.arcToPoint(
    Offset(startTopX, topYOffset),
    radius: arcRadius,
    clockwise: true,
  );

  path.close();
  return path;
}

class WavyClipper extends CustomClipper<Path> {
  final double phase;
  WavyClipper(this.phase);
  @override
  Path getClip(Size size) =>
      getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);
  @override
  bool shouldReclip(covariant WavyClipper old) => old.phase != phase;
}

class OuterShadowWavyPainter extends CustomPainter {
  final double phase;
  OuterShadowWavyPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final path = getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.08), 16, true);
  }

  @override
  bool shouldRepaint(covariant OuterShadowWavyPainter old) =>
      old.phase != phase;
}

class WavyGlassInputPainter extends CustomPainter {
  final double phase;
  WavyGlassInputPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final baseLayer =
        getMorphingPillPath(size, phase, ampTop: 5.0, ampBot: 5.0);

    canvas.save();
    canvas.clipPath(baseLayer);

    canvas.drawColor(Colors.white.withValues(alpha: 0.15), BlendMode.srcOver);

    canvas.drawPath(
      baseLayer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.08),
          ],
        ).createShader(rect),
    );

    final sideRefraction = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: 0.14),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.14),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(rect);
    canvas.drawPath(baseLayer, sideRefraction);

    final iridescencePath = getMorphingPillPath(size, phase,
        ampTop: 5.0, ampBot: 5.0, topYOffset: 3.0, botYOffset: -3.0);
    canvas.drawPath(
      iridescencePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OptivusColors.coachAccent.withValues(alpha: 0.7), 
            Colors.white.withValues(alpha: 0.2), 
            OptivusColors.aquaAccent.withValues(alpha: 0.5), 
            OptivusColors.coachAccent.withValues(alpha: 0.6), 
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    final topWhite = getMorphingPillPath(size, phase,
        ampTop: 6.0,
        ampBot: 4.0,
        topYOffset: 1.0,
        botYOffset: -1.0,
        phaseOffset: 0.5);
    canvas.drawPath(
      topWhite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(rect),
    );

    final botWhite = getMorphingPillPath(size, phase,
        ampTop: 4.0,
        ampBot: 6.0,
        topYOffset: 5.0,
        botYOffset: -5.0,
        phaseOffset: -0.5);
    canvas.drawPath(
      botWhite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.1, 0.5, 0.9],
        ).createShader(rect),
    );

    canvas.restore(); 

    canvas.drawPath(
      baseLayer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            OptivusColors.coachAccent.withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.15),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant WavyGlassInputPainter old) =>
      old.phase != phase;
}

class InnerCavityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    canvas.drawRRect(
        rrect, Paint()..color = Colors.white.withValues(alpha: 0.15));

    canvas.save();
    canvas.clipRRect(rrect);
    final topShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rrect.shift(const Offset(0, -3)), topShadow);
    canvas.restore();

    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));
    final bottomLip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRRect(rrect, bottomLip);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
