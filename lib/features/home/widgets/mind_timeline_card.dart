import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'home_glass_widgets.dart';
import 'mind_note_editor_sheet.dart';
import 'mind_notebook_sheet.dart';
import 'mind_switch_sheet.dart';
import 'package:optivus/app/app_navigation_controller.dart';

class MindTimelineCard extends ConsumerWidget {
  const MindTimelineCard({super.key});

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final min = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(homeMindNoteProvider);
    final hasNotes = notes.isNotEmpty;
    final latestNote = hasNotes ? notes.first : null;

    return HomeGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mind Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              if (hasNotes)
                Text(
                  '${notes.length} thoughts today',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasNotes) ...[
            const Text(
              'Overthinking started?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Notice it. Name it. Write it. Return to focus.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 12,
                  color: OptivusColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(latestNote!.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: OptivusColors.coachAccent.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _capitalize(latestNote.type.name),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.coachAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: latestNote.intensity == MindNoteIntensity.high
                              ? Colors.red.withValues(alpha: 0.1)
                              : OptivusColors.homeAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _capitalize(latestNote.intensity.name),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color:
                                latestNote.intensity == MindNoteIntensity.high
                                ? Colors.red
                                : OptivusColors.homeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${latestNote.content}"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: OptivusColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HomeActionPill(
                label: 'Add Thought',
                icon: Icons.add,
                compact: true,
                selected: true,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const MindNoteEditorSheet(),
                  );
                },
              ),
              HomeActionPill(
                label: 'Mind Switch',
                compact: true,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const MindSwitchSheet(),
                  );
                },
              ),
              HomeActionPill(
                label: 'Open Notebook',
                compact: true,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const MindNotebookSheet(),
                  );
                },
              ),
              if (hasNotes)
                HomeActionPill(
                  label: 'Send to Coach',
                  compact: true,
                  onTap: () {
                    ref.read(appNavigationProvider.notifier).goToCoach();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
