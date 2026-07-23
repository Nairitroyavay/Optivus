import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exact Refractive Glass Input Bar
// ─────────────────────────────────────────────────────────────────────────────

class HeavyGlassInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;

  const HeavyGlassInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSend,
  });

  @override
  State<HeavyGlassInput> createState() => _HeavyGlassInputState();
}

class _HeavyGlassInputState extends State<HeavyGlassInput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
                        _buildIconBtn(Icons.add_rounded, 30),

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
                                        color: Color(0xFF64748B),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Type a message...',
                                        hintStyle: TextStyle(
                                          color: const Color(
                                            0xFF94A3B8,
                                          ).withValues(alpha: 0.9),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
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
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    left: 6,
                                  ),
                                  child: _buildSendBtn(),
                                )
                              : Padding(
                                  key: const ValueKey('mic'),
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    left: 6,
                                  ),
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
          child: Icon(icon, size: size, color: const Color(0xFF8E8E93)),
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
            colors: [Color(0xFFC084FC), Color(0xFF6366F1)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC084FC).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

Path getMorphingPillPath(
  Size size,
  double phase, {
  double ampTop = 4.0,
  double ampBot = 4.0,
  double topYOffset = 0.0,
  double botYOffset = 0.0,
  double phaseOffset = 0.0,
}) {
  final w = size.width;
  final h = size.height;
  final r = h / 2;
  final path = Path();
  final segments = 50;

  final startTopX = r;
  final endTopX = w - r;

  // Math for identical endcaps considering offsets
  // Default radius is 'r' for offset 0; adjusts mathematically when inset
  final arcRadius = Radius.circular(
    math.max(0.1, r - (topYOffset - botYOffset) / 2),
  );

  path.moveTo(startTopX, topYOffset);

  // Top wave (left to right)
  for (int i = 0; i <= segments; i++) {
    double t = i / segments;
    double x = startTopX + t * (endTopX - startTopX);

    // Attenuate zero-slope at connection points
    double attenuation = math.sin(t * math.pi);
    attenuation = attenuation * attenuation * (3 - 2 * attenuation);

    double wave =
        math.sin(t * math.pi * 3 + phase + phaseOffset) * 0.7 +
        math.cos(t * math.pi * 5 - phase * 1.3) * 0.3;

    double y = topYOffset + wave * ampTop * attenuation;
    if (i == 0 || i == segments) y = topYOffset; // Lock exact endpoints

    path.lineTo(x, y);
  }

  // Perfect right semi-circle
  path.arcToPoint(
    Offset(endTopX, h + botYOffset),
    radius: arcRadius,
    clockwise: true,
  );

  // Bottom wave (right to left)
  for (int i = segments; i >= 0; i--) {
    double t = i / segments;
    double x = startTopX + t * (endTopX - startTopX);

    double attenuation = math.sin(t * math.pi);
    attenuation = attenuation * attenuation * (3 - 2 * attenuation);

    double wave =
        math.sin(t * math.pi * 4 - phase + phaseOffset) * 0.7 +
        math.cos(t * math.pi * 6 + phase * 1.1) * 0.3;

    double y = h + botYOffset + wave * ampBot * attenuation;
    if (i == 0 || i == segments) y = h + botYOffset; // Lock exactly

    path.lineTo(x, y);
  }

  // Perfect left semi-circle
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
    // Dark shadow tracking the outer shape exactly
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
    final baseLayer = getMorphingPillPath(
      size,
      phase,
      ampTop: 5.0,
      ampBot: 5.0,
    );

    canvas.save();
    canvas.clipPath(baseLayer);

    // 1. Frost background inside the glass volume
    canvas.drawColor(Colors.white.withValues(alpha: 0.15), BlendMode.srcOver);

    // 2. Thick 3D glass edge deepening (inner shading)
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

    // Deep heavy flares on the left and right semi-circular ends
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

    // 3. Iridescent caustics
    // offset 3px inside logically, mimicking internal liquid reflections!
    final iridescencePath = getMorphingPillPath(
      size,
      phase,
      ampTop: 5.0,
      ampBot: 5.0,
      topYOffset: 3.0,
      botYOffset: -3.0,
    );
    canvas.drawPath(
      iridescencePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC084FC).withValues(alpha: 0.7), // Theme purple glow
            Colors.white.withValues(alpha: 0.2), // Transparent pass
            Colors.cyan.withValues(alpha: 0.5), // Fluid inner gradient
            const Color(0xFF9333EA).withValues(alpha: 0.6), // Darker coach vibe
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 4. Heavy white fluid reflections
    // Flowing independently mostly on top inner edge
    final topWhite = getMorphingPillPath(
      size,
      phase,
      ampTop: 6.0,
      ampBot: 4.0,
      topYOffset: 1.0,
      botYOffset: -1.0,
      phaseOffset: 0.5,
    );
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

    // Thin inner rim highlight (gives depth to the bottom edge)
    final botWhite = getMorphingPillPath(
      size,
      phase,
      ampTop: 4.0,
      ampBot: 6.0,
      topYOffset: 5.0,
      botYOffset: -5.0,
      phaseOffset: -0.5,
    );
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

    canvas.restore(); // end clipPath(baseLayer)

    // 5. Razor thin outer glass membrane sealing everything
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
            const Color(0xFFC084FC).withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.15),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant WavyGlassInputPainter old) => old.phase != phase;
}

class InnerCavityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );

    // Frost base
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Inner top shadow
    canvas.save();
    canvas.clipRRect(rrect);
    final topShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(rrect.shift(const Offset(0, -3)), topShadow);
    canvas.restore();

    // Bottom crisp white lip
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
    );
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
