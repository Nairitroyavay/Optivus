import 'dart:math';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// A wavy-bordered text field inspired by the coach input reference.
/// Uses mathematical sine-wave clipping for a liquid feel.
/// Used in Coach chat, Mind note input, and custom goal input.
class LiquidWavyTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final VoidCallback? onSend;
  final Color accentColor;
  final int maxLines;

  const LiquidWavyTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Type a message...',
    this.onSend,
    this.accentColor = OptivusColors.coachAccent,
    this.maxLines = 1,
  });

  @override
  State<LiquidWavyTextField> createState() => _LiquidWavyTextFieldState();
}

class _LiquidWavyTextFieldState extends State<LiquidWavyTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return ClipPath(
          clipper: _WavyClipper(phase: _waveController.value * 2 * pi),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: widget.maxLines,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: OptivusColors.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: widget.onSend,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
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

class _WavyClipper extends CustomClipper<Path> {
  final double phase;
  _WavyClipper({required this.phase});

  @override
  Path getClip(Size size) {
    final path = Path();
    const waveAmplitude = 2.0;
    const waveFrequency = 3.0;

    // Top wavy edge
    path.moveTo(0, waveAmplitude);
    for (double x = 0; x <= size.width; x++) {
      final y =
          waveAmplitude *
          sin((x / size.width) * waveFrequency * 2 * pi + phase);
      path.lineTo(x, y + waveAmplitude);
    }

    // Right, bottom, left edges (straight)
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_WavyClipper oldClipper) => true;
}
