import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'mind_note_editor_sheet.dart';
import 'mind_notebook_sheet.dart';
import 'mind_switch_sheet.dart';

class MindTimelineCard extends ConsumerWidget {
  const MindTimelineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(homeMindNoteProvider);
    final hasNotes = notes.isNotEmpty;
    final latestNote = hasNotes ? notes.first : null;

    return LiquidGlassPanel(
      padding: const EdgeInsets.all(24),
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
            const Text(
              'Most recent:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: OptivusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white),
              ),
              child: Text(
                '"${latestNote!.content}"',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: OptivusColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OptivusColors.brandAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const MindNoteEditorSheet(),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Thought',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (!hasNotes)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: OptivusColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const MindSwitchSheet(),
                    );
                  },
                  child: const Text(
                    'Mind Switch',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: OptivusColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const MindNotebookSheet(),
                  );
                },
                child: const Text(
                  'Open Notebook',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
