import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/coach_models.dart';

/// Renders an inline action card inside a coach message bubble.
/// Displays a heading, body, and CTA button for different response block types.
class CoachActionCard extends StatelessWidget {
  final CoachResponseBlock block;
  final VoidCallback? onPressed;

  const CoachActionCard({super.key, required this.block, this.onPressed});

  @override
  Widget build(BuildContext context) {
    IconData cardIcon = Icons.stars;
    Color blockColor = OptivusColors.brandAccent;

    switch (block.type) {
      case CoachResponseBlockType.routineSuggestionCard:
        cardIcon = Icons.lock_reset;
        blockColor = OptivusColors.success;
        break;
      case CoachResponseBlockType.trackerActionCard:
        cardIcon = Icons.local_drink_outlined;
        blockColor = OptivusColors.brandAccent;
        break;
      case CoachResponseBlockType.goalProofCard:
        cardIcon = Icons.verified_user;
        blockColor = OptivusColors.warning;
        break;
      case CoachResponseBlockType.mindNoteCard:
        cardIcon = Icons.bubble_chart;
        blockColor = OptivusColors.coachAccent;
        break;
      default:
        cardIcon = Icons.stars;
        blockColor = OptivusColors.brandAccent;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blockColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(cardIcon, color: blockColor, size: 16),
              const SizedBox(width: 8),
              Text(
                block.heading ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: blockColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            block.body ?? '',
            style: const TextStyle(
              fontSize: 10,
              height: 1.3,
              color: OptivusColors.textBody,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blockColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
            ),
            onPressed: onPressed,
            child: Text(
              block.buttonLabel ?? 'Confirm',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
