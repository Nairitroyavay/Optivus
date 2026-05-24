import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'home_glass_widgets.dart';

class MindNotebookSheet extends ConsumerWidget {
  const MindNotebookSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(homeMindNoteProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Mind Notebook',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notes.isEmpty
                    ? const Center(
                        child: Text(
                          'Your notebook is empty.',
                          style: TextStyle(
                            color: OptivusColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          // Grouping by date isn't fully implemented in mock, but we can display the date per card
                          return _buildNoteCard(context, ref, note);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, WidgetRef ref, HomeMindNote note) {
    final h = note.createdAt.hour;
    final m = note.createdAt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final timeStr = '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    final isShared = note.visibility == MindNoteVisibility.sharedWithCoach;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${note.type.name} • ${note.intensity.name}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.brandAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${note.content}"',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              HomeActionPill(
                label: 'Open',
                compact: true,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              HomeActionPill(
                label: isShared ? 'Shared' : 'Send to Coach',
                icon: isShared ? Icons.check : Icons.send,
                compact: true,
                selected: isShared ? false : true,
                accent: isShared ? OptivusColors.success : OptivusColors.brandAccent,
                onTap: () {
                  ref
                      .read(homeMindNoteProvider.notifier)
                      .toggleShareWithCoach(note.id);
                  if (!isShared) {
                    Navigator.pop(context);
                    ref.read(appNavigationProvider.notifier).goToCoach();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
