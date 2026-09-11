import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Calm, domain-specific AI processing view used during Base Timeline photo
/// analysis and plan generation.
class BaseTimelineAiThinkingView extends StatefulWidget {
  final String initialMessage;
  final List<String> progressMessages;
  final Duration messageInterval;

  const BaseTimelineAiThinkingView({
    super.key,
    required this.initialMessage,
    this.progressMessages = const [],
    this.messageInterval = const Duration(seconds: 3),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OptivusColors.borderStandard, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    OptivusColors.routineAccent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(
                  _currentMessage,
                  key: ValueKey<String>(_currentMessage),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OptivusColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
