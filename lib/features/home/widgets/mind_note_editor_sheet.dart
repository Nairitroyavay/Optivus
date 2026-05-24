import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'home_glass_widgets.dart';

class MindNoteEditorSheet extends ConsumerStatefulWidget {
  const MindNoteEditorSheet({super.key});

  @override
  ConsumerState<MindNoteEditorSheet> createState() =>
      _MindNoteEditorSheetState();
}

class _MindNoteEditorSheetState extends ConsumerState<MindNoteEditorSheet> {
  final _controller = TextEditingController();
  MindNoteType _selectedType = MindNoteType.overthinking;
  MindNoteIntensity _selectedIntensity = MindNoteIntensity.medium;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveNote({bool sendToCoach = false}) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref
        .read(homeMindNoteProvider.notifier)
        .addNote(text, _selectedType, _selectedIntensity);

    // If we wanted to immediately share it
    if (sendToCoach) {
      // Find the newly added note (it will be first)
      final notes = ref.read(homeMindNoteProvider);
      if (notes.isNotEmpty) {
        ref
            .read(homeMindNoteProvider.notifier)
            .toggleShareWithCoach(notes.first.id);
      }
      ref.read(appNavigationProvider.notifier).goToCoach();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note captured.')));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: OptivusColors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'What\'s running in your mind?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write one line. No need to make it perfect.',
                    hintStyle: TextStyle(
                      color: OptivusColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: MindNoteType.values.map((type) {
                      final isSelected = type == _selectedType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(type.name),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedType = type);
                            }
                          },
                          backgroundColor: Colors.white.withValues(alpha: 0.5),
                          selectedColor: OptivusColors.brandAccent.withValues(
                            alpha: 0.2,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? OptivusColors.brandAccent
                                : OptivusColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? OptivusColors.brandAccent
                                : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: MindNoteIntensity.values.map((intensity) {
                      final isSelected = intensity == _selectedIntensity;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(intensity.name),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedIntensity = intensity);
                            }
                          },
                          backgroundColor: Colors.white.withValues(alpha: 0.5),
                          selectedColor: const Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFFEF4444)
                                : OptivusColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFFEF4444)
                                : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: HomeActionPill(
                        label: 'Save',
                        selected: true,
                        onTap: () => _saveNote(sendToCoach: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: HomeActionPill(
                        label: 'Send to Coach',
                        onTap: () => _saveNote(sendToCoach: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: HomeActionPill(
                    label: 'Return to Focus',
                    compact: true,
                    onTap: () {
                      _saveNote(sendToCoach: false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Returning to focus...')),
                      );
                    },
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
