import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/coach_models.dart';

/// Single chat bubble for either coach or user messages.
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
    final isCoach = message.isFromCoach;
    return Align(
      alignment: isCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Column(
          crossAxisAlignment:
              isCoach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCoach
                    ? const Color(0xFFDCCBFF).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isCoach
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                  bottomRight: isCoach
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                ),
                border: Border.all(
                  color: isCoach
                      ? const Color(0xFFDCCBFF)
                      : OptivusColors.borderSoft,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                      height: 1.35,
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
            const SizedBox(height: 4),
            Text(
              message.timestamp,
              style: const TextStyle(
                  fontSize: 9,
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
