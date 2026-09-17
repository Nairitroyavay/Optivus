import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

/// Calm, domain-specific AI processing view used during Base Timeline photo
/// analysis and plan generation.
class BaseTimelineAiThinkingView extends StatefulWidget {
  final String initialMessage;
  final List<String> progressMessages;
  final Duration messageInterval;
  final String? localPreviewPath;
  final String? assetId;
  final String? r2Key;
  final VoidCallback? onCancel;

  const BaseTimelineAiThinkingView({
    super.key,
    required this.initialMessage,
    this.progressMessages = const [
      'Reading timetable image...',
      'Finding class days and times...',
      'Extracting subjects and rooms...',
      'Structuring weekly schedule...',
    ],
    this.messageInterval = const Duration(milliseconds: 2000),
    this.localPreviewPath,
    this.assetId,
    this.r2Key,
    this.onCancel,
  });

  @override
  State<BaseTimelineAiThinkingView> createState() =>
      _BaseTimelineAiThinkingViewState();
}

class _BaseTimelineAiThinkingViewState
    extends State<BaseTimelineAiThinkingView> {
  late String _currentMessage;
  Timer? _timer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.initialMessage;
    if (widget.progressMessages.isNotEmpty) {
      _timer = Timer.periodic(widget.messageInterval, (timer) {
        if (!mounted) return;
        setState(() {
          _currentMessage = widget
              .progressMessages[_messageIndex % widget.progressMessages.length];
          _messageIndex++;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalThumb =
        widget.localPreviewPath != null &&
        File(widget.localPreviewPath!).existsSync();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: OnboardingGlassCard(
            radius: OptivusRadii.surfaceLarge,
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasLocalThumb) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        OptivusRadii.controlCompact,
                      ),
                      border: Border.all(
                        color: OptivusColors.blueAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(OptivusRadii.sm),
                      child: Image.file(
                        File(widget.localPreviewPath!),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        cacheWidth: 156,
                      ),
                    ),
                  ),
                ],
                const _OrbWidget(),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _currentMessage,
                    key: ValueKey<String>(_currentMessage),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: OptivusColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.4,
                    ),
                  ),
                ),
                if (widget.onCancel != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: OptivusColors.textSecondary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OptivusRadii.controlCompact),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: OptivusColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Practical, responsive upload progress view used while uploading timetable image.
class BaseTimelineUploadView extends StatelessWidget {
  final String? localPreviewPath;
  final String title;
  final String subtitle;

  const BaseTimelineUploadView({
    super.key,
    this.localPreviewPath,
    this.title = 'Uploading timetable photo...',
    this.subtitle = 'Encrypting and uploading to private storage...',
  });

  @override
  Widget build(BuildContext context) {
    final hasLocalThumb =
        localPreviewPath != null && File(localPreviewPath!).existsSync();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: OnboardingGlassCard(
            radius: OptivusRadii.surfaceLarge,
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasLocalThumb) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        OptivusRadii.controlCompact,
                      ),
                      border: Border.all(
                        color: OptivusColors.blueAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(OptivusRadii.sm),
                      child: Image.file(
                        File(localPreviewPath!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cacheWidth: 168,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: OptivusColors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        OptivusRadii.controlCompact,
                      ),
                      border: Border.all(
                        color: OptivusColors.blueAccent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: OptivusColors.blueAccent,
                      size: 28,
                    ),
                  ),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OptivusColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OptivusColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      OptivusColors.blueAccent,
                    ),
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

class _OrbWidget extends StatefulWidget {
  const _OrbWidget();

  @override
  State<_OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<_OrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_controller.value);
        return CustomPaint(
          size: const Size(72, 72),
          painter: _OrbPainter(progress: t),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;

  _OrbPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer faint breathing ring
    final outerRadius = 28.0 + progress * 6.0;
    final outerPaint = Paint()
      ..color = OptivusColors.blueAccent.withValues(
        alpha: 0.10 + progress * 0.08,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, outerRadius, outerPaint);

    // Mid ring
    final midRadius = 20.0 + progress * 3.0;
    final midPaint = Paint()
      ..color = OptivusColors.routineAccent.withValues(
        alpha: 0.20 + progress * 0.12,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, midRadius, midPaint);

    // Core glowing orb
    final coreRadius = 12.0 + progress * 2.0;
    final coreGradient = RadialGradient(
      colors: [
        OptivusColors.aquaAccent.withValues(alpha: 0.95),
        OptivusColors.blueAccent.withValues(alpha: 0.8),
      ],
    );
    final corePaint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: center, radius: coreRadius),
      );
    canvas.drawCircle(center, coreRadius, corePaint);
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
