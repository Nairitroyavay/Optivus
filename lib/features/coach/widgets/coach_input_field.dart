import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Iridescent wave-adorned text input field for the Coach chat.
/// Contains the animated sine-wave painter and the text field + send button.
class CoachInputField extends StatelessWidget {
  final TextEditingController controller;
  final Animation<double> waveAnimation;
  final ValueChanged<String> onSend;
  final VoidCallback onChanged;

  const CoachInputField({
    super.key,
    required this.controller,
    required this.waveAnimation,
    required this.onSend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dynamic math sine wave painter
                AnimatedBuilder(
                  animation: waveAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, 36),
                      painter: IridescentWavePainter(
                        phase: waveAnimation.value * 2 * math.pi,
                        isTyping: controller.text.isNotEmpty,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                // Input row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Talk to Aura Coach...',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.9),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: OptivusColors.borderSoft),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: OptivusColors.brandAccent),
                          ),
                        ),
                        onChanged: (_) => onChanged(),
                        onSubmitted: onSend,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            OptivusColors.brandAccent,
                            OptivusColors.aquaAccent,
                          ],
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send,
                            color: Colors.white, size: 18),
                        onPressed: () => onSend(controller.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Iridescent Siri-style mathematical wavy sine painter.
/// Extracted from coach_tab.dart for reuse.
class IridescentWavePainter extends CustomPainter {
  final double phase;
  final bool isTyping;

  IridescentWavePainter({required this.phase, required this.isTyping});

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    final double width = size.width;

    final double amplitude = isTyping ? 14.0 : 5.0;
    final double frequency = isTyping ? 0.04 : 0.02;

    _drawSingleWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amp: amplitude,
      freq: frequency,
      phaseOffset: phase,
      colors: [const Color(0xFFE0B51F), const Color(0xFF7BE6DC)],
      strokeWidth: 2.5,
    );

    _drawSingleWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amp: amplitude * 0.7,
      freq: frequency * 1.3,
      phaseOffset: phase + math.pi / 2,
      colors: [const Color(0xFF7BE6DC), const Color(0xFFDCCBFF)],
      strokeWidth: 1.5,
    );

    _drawSingleWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amp: amplitude * 0.4,
      freq: frequency * 0.8,
      phaseOffset: phase + math.pi,
      colors: [const Color(0xFFDCCBFF), const Color(0xFFFFB6DC)],
      strokeWidth: 1.0,
    );
  }

  void _drawSingleWave({
    required Canvas canvas,
    required double width,
    required double midY,
    required double amp,
    required double freq,
    required double phaseOffset,
    required List<Color> colors,
    required double strokeWidth,
  }) {
    final path = Path();
    path.moveTo(0, midY);

    for (double x = 0; x <= width; x += 3) {
      final double taper = math.sin((x / width) * math.pi);
      final double y =
          midY + math.sin(x * freq + phaseOffset) * amp * taper;
      path.lineTo(x, y);
    }

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(colors: colors)
          .createShader(Rect.fromLTWH(0, 0, width, 36));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant IridescentWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isTyping != isTyping;
  }
}
