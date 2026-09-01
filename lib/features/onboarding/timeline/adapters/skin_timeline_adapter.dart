import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../../../models/onboarding_draft.dart';
import '../../steps/onboarding_base_timeline_helpers.dart';
import '../../steps/onboarding_step_7_skin_care_scheduler.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_style.dart';
import '../widgets/timeline_edit_sheet_shell.dart';
import 'timeline_feature_adapter.dart';

/// Feature adapter for Skin Care schedule items.
class SkinTimelineAdapter
    implements TimelineFeatureAdapter<TimelineBlockDraft> {
  final Color accent;

  const SkinTimelineAdapter({this.accent = OptivusColors.roseAccent});

  @override
  List<TimelineEntry> toEntries(TimelineBlockDraft block) {
    return [
      TimelineEntry(
        id: block.id,
        sourceId: block.id,
        startMinute: block.startMinute,
        endMinute: block.endMinute,
        repeatDays: block.repeatDays,
        title: block.title,
        subtitle: block.skincareProducts.isNotEmpty
            ? block.skincareProducts.first
            : (block.skincareSteps.isNotEmpty
                  ? block.skincareSteps.first
                  : null),
        category: TimelineCategory.skinCare,
        isEditable: true,
        adapterKey: 'skin_care',
        minHeight:
            72.0 +
            (block.skincareProducts.length +
                    block.skincareSteps.length +
                    block.skincareMissingItems.length) *
                22.0,
      ),
    ];
  }

  @override
  TimelineEntryStyle styleForEntry(TimelineEntry entry) {
    return TimelineEntryStyle(
      accentColor: accent,
      icon: Icons.spa_rounded,
      badgeLabel: 'Skin Care',
      tags: entry.subtitle != null ? [entry.subtitle!] : const [],
    );
  }

  @override
  Future<void> onEditRequested(
    BuildContext context,
    TimelineEntry entry,
    VoidCallback onUpdated,
  ) async {}

  /// Opens the shared edit sheet for a skin care block.
  static Future<bool?> showSkinEditSheet({
    required BuildContext context,
    required TimelineBlockDraft block,
    required Future<bool> Function(TimelineBlockDraft updated) onSave,
    Color accent = OptivusColors.roseAccent,
  }) {
    final titleCtrl = TextEditingController(text: block.title);
    final startTimeCtrl = TextEditingController(
      text: onboardingTimeLabel(block.startMinute),
    );
    final productsCtrl = TextEditingController(
      text: block.skincareProducts.join('\n'),
    );
    final stepsCtrl = TextEditingController(
      text: block.skincareSteps.join('\n'),
    );
    final selectedDays = Set<int>.from(
      block.repeatDays.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : block.repeatDays,
    );
    final formKey = GlobalKey<FormState>();

    return TimelineEditSheetShell.show<bool>(
      context: context,
      title: 'Edit Skin Care Block',
      subtitle: 'Duration stays fixed at 15 minutes',
      accent: accent,
      onSave: () async {
        if (!formKey.currentState!.validate()) return false;
        final title = titleCtrl.text.trim();
        if (title.isEmpty) {
          throw Exception('Routine title is required.');
        }

        final parsedStart = _parseClockMinute(startTimeCtrl.text);
        if (parsedStart == null) {
          throw Exception('Use a valid start time like 7:45 AM.');
        }
        if (parsedStart + onboarding7SkinCareDurationMinutes > 24 * 60) {
          throw Exception('Choose a time before midnight.');
        }
        if (selectedDays.isEmpty) {
          throw Exception('Select at least one repeat day.');
        }

        final parsedProducts = productsCtrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final parsedSteps = stepsCtrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (parsedProducts.isEmpty && parsedSteps.isEmpty) {
          throw Exception('Add at least one product or routine step.');
        }

        final updated = block.copyWith(
          title: title,
          startMinute: parsedStart,
          endMinute: parsedStart + onboarding7SkinCareDurationMinutes,
          repeatDays: selectedDays.toList()..sort(),
          skincareProducts: parsedProducts,
          skincareSteps: parsedSteps,
        );

        return await onSave(updated);
      },
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'ROUTINE TITLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-skin-title-field'),
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Morning Face Routine',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Start Time
                  const Text(
                    'START TIME (15 MIN FIXED DURATION)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-skin-start-time-field'),
                    controller: startTimeCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. 7:45 AM',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.6),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time_rounded),
                        onPressed: () async {
                          final currentMin =
                              _parseClockMinute(startTimeCtrl.text) ?? 8 * 60;
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: currentMin ~/ 60,
                              minute: currentMin % 60,
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              startTimeCtrl.text = onboardingTimeLabel(
                                picked.hour * 60 + picked.minute,
                              );
                            });
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Products
                  const Text(
                    'PRODUCTS (ONE PER LINE)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-skin-products-field'),
                    controller: productsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g.\nCleanser\nMoisturizer\nSunscreen',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Steps
                  const Text(
                    'STEPS (ONE PER LINE)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('timeline-edit-skin-steps-field'),
                    controller: stepsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'e.g.\nWash with lukewarm water\nApply moisturizer',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Repeat Days
                  const Text(
                    'REPEAT DAYS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      final dayName = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][index];
                      final isSelected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(dayName),
                        selected: isSelected,
                        selectedColor: accent.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else if (selectedDays.length > 1) {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static int? _parseClockMinute(String text) {
    final clean = text.trim().toUpperCase();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$',
    ).firstMatch(clean);
    if (match == null) return null;
    var h = int.tryParse(match.group(1) ?? '') ?? -1;
    final m = int.tryParse(match.group(2) ?? '') ?? -1;
    final ampm = match.group(3);

    if (m < 0 || m > 59) return null;
    if (ampm != null) {
      if (h < 1 || h > 12) return null;
      if (ampm == 'AM') {
        h = (h == 12) ? 0 : h;
      } else {
        h = (h == 12) ? 12 : h + 12;
      }
    } else {
      if (h < 0 || h > 23) return null;
    }
    return h * 60 + m;
  }
}
