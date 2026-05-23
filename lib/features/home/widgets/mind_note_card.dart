import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/mind_note.dart';
import 'package:optivus/state/mock_app_state.dart';

/// Displays a single mind note card with type/intensity badges,
/// share with coach, and delete functionality.
class MindNoteCard extends ConsumerWidget {
  final MindNote note;
  const MindNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.notes;

    switch (note.type) {
      case MindNoteType.idea:
        typeColor = const Color(0xFFFFB830);
        typeIcon = Icons.lightbulb_outline;
        break;
      case MindNoteType.decision:
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.check_circle_outline;
        break;
      case MindNoteType.overthinking:
        typeColor = const Color(0xFFEF4444);
        typeIcon = Icons.warning_amber;
        break;
      case MindNoteType.existential:
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.psychology;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.bubble_chart;
    }

    Color intensityColor = Colors.grey;
    switch (note.intensity) {
      case MindNoteIntensity.low:
        intensityColor = const Color(0xFF10B981);
        break;
      case MindNoteIntensity.medium:
        intensityColor = const Color(0xFFF59E0B);
        break;
      case MindNoteIntensity.high:
        intensityColor = const Color(0xFFEF4444);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(typeIcon,
                            color: typeColor == const Color(0xFFDCCBFF)
                                ? Colors.deepPurple
                                : typeColor,
                            size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        note.type.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: typeColor == const Color(0xFFDCCBFF)
                              ? Colors.deepPurple
                              : typeColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: intensityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note.intensity.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: intensityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    note.content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withValues(alpha: 0.4),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 12, color: OptivusColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    note.timestamp,
                    style: const TextStyle(
                        fontSize: 10,
                        color: OptivusColors.textSecondary,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      ref
                          .read(mockMindNoteProvider.notifier)
                          .toggleShareWithCoach(note.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(note.isSharedWithCoach
                              ? 'Unshared with AI Coach.'
                              : 'Shared with AI Coach for timeline audits.'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            note.isSharedWithCoach
                                ? Icons.cloud_done
                                : Icons.cloud_upload_outlined,
                            size: 14,
                            color: note.isSharedWithCoach
                                ? OptivusColors.success
                                : OptivusColors.brandAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            note.isSharedWithCoach
                                ? 'Shared'
                                : 'Share with Coach',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: note.isSharedWithCoach
                                  ? OptivusColors.success
                                  : OptivusColors.brandAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: OptivusColors.danger),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref
                          .read(mockMindNoteProvider.notifier)
                          .deleteMindNote(note.id);
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
