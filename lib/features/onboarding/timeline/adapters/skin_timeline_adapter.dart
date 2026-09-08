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
    int? Function(TimelineBlockDraft candidate)? findFreeStart,
    bool Function(TimelineBlockDraft candidate)? hasConflict,
    String? Function(TimelineBlockDraft candidate)? validateBlock,
    Color accent = OptivusColors.roseAccent,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SkinCareBlockEditSheet(
        block: block,
        accent: accent,
        onSave: onSave,
        findFreeStart: findFreeStart,
        hasConflict: hasConflict,
        validateBlock: validateBlock,
      ),
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

class _SkinCareBlockEditSheet extends StatefulWidget {
  final TimelineBlockDraft block;
  final Future<bool> Function(TimelineBlockDraft updated) onSave;
  final int? Function(TimelineBlockDraft candidate)? findFreeStart;
  final bool Function(TimelineBlockDraft candidate)? hasConflict;
  final String? Function(TimelineBlockDraft candidate)? validateBlock;
  final Color accent;

  const _SkinCareBlockEditSheet({
    required this.block,
    required this.onSave,
    required this.accent,
    this.findFreeStart,
    this.hasConflict,
    this.validateBlock,
  });

  @override
  State<_SkinCareBlockEditSheet> createState() =>
      _SkinCareBlockEditSheetState();
}

class _SkinCareBlockEditSheetState extends State<_SkinCareBlockEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _productsCtrl;
  late final TextEditingController _stepsCtrl;
  final _formKey = GlobalKey<FormState>();
  late final Set<int> _selectedDays;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.block.title);
    _startTimeCtrl = TextEditingController(
      text: onboardingTimeLabel(widget.block.startMinute),
    );
    _productsCtrl = TextEditingController(
      text: widget.block.skincareProducts.join('\n'),
    );
    _stepsCtrl = TextEditingController(
      text: widget.block.skincareSteps.join('\n'),
    );
    _selectedDays = {
      ...widget.block.repeatDays.where((day) => day >= 1 && day <= 7),
    };
    if (_selectedDays.isEmpty) {
      _selectedDays.addAll(const [1, 2, 3, 4, 5, 6, 7]);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startTimeCtrl.dispose();
    _productsCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  TimelineBlockDraft _candidateFromInputs() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      throw Exception('Routine title is required.');
    }

    final parsedStart = SkinTimelineAdapter._parseClockMinute(
      _startTimeCtrl.text,
    );
    if (parsedStart == null) {
      throw Exception('Use a valid start time like 7:45 AM.');
    }
    if (parsedStart + onboarding7SkinCareDurationMinutes > 24 * 60) {
      throw Exception('Choose a time before midnight.');
    }
    if (_selectedDays.isEmpty) {
      throw Exception('Select at least one repeat day.');
    }

    final parsedProducts = _productsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final parsedSteps = _stepsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parsedProducts.isEmpty && parsedSteps.isEmpty) {
      throw Exception('Add at least one product or routine step.');
    }

    return widget.block.copyWith(
      title: title,
      startMinute: parsedStart,
      endMinute: parsedStart + onboarding7SkinCareDurationMinutes,
      repeatDays: _selectedDays.toList()..sort(),
      skincareProducts: parsedProducts,
      skincareSteps: parsedSteps,
    );
  }

  Future<bool> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_localError != null) {
      setState(() => _localError = null);
    }
    final candidate = _candidateFromInputs();
    if (widget.validateBlock != null) {
      final validationError = widget.validateBlock!(candidate);
      if (validationError != null) {
        throw Exception(validationError);
      }
    }
    if (widget.hasConflict?.call(candidate) == true) {
      throw Exception(
        'That time overlaps another onboarding block. Choose a free 15-minute slot.',
      );
    }
    return widget.onSave(candidate);
  }

  void _findFreeTime() {
    final findFreeStart = widget.findFreeStart;
    if (findFreeStart == null) return;
    TimelineBlockDraft candidate;
    try {
      candidate = _candidateFromInputs();
    } catch (error) {
      setState(() {
        _localError = error
            .toString()
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .trim();
      });
      return;
    }
    final freeStart = findFreeStart(candidate);
    if (freeStart == null) {
      setState(() {
        _localError = 'No free 15-minute skin-care slot was found.';
      });
      return;
    }
    if (_localError != null) {
      _localError = null;
    }
    setState(() {
      _startTimeCtrl.text = onboardingTimeLabel(freeStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return TimelineEditSheetShell(
      title: 'Edit Skin Care Block',
      subtitle: 'Duration stays fixed at 15 minutes',
      accent: accent,
      saveButtonKey: const ValueKey('onboarding-step7-edit-save-button'),
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_localError != null) ...[
              Container(
                key: const ValueKey('onboarding-step7-edit-error'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: OptivusColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: OptivusColors.danger.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  _localError!,
                  style: const TextStyle(
                    color: OptivusColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _SkinEditLabel('ROUTINE TITLE'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('onboarding-step7-edit-title-field'),
              controller: _titleCtrl,
              decoration: _skinEditInputDecoration(
                accent: accent,
                hintText: 'e.g. Morning Face Routine',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _SkinEditLabel('START TIME (15 MIN FIXED DURATION)'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('onboarding-step7-edit-start-time-field'),
              controller: _startTimeCtrl,
              decoration: _skinEditInputDecoration(
                accent: accent,
                hintText: 'e.g. 7:45 AM',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time_rounded),
                  onPressed: () async {
                    final currentMin =
                        SkinTimelineAdapter._parseClockMinute(
                          _startTimeCtrl.text,
                        ) ??
                        8 * 60;
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: currentMin ~/ 60,
                        minute: currentMin % 60,
                      ),
                    );
                    if (!mounted || picked == null) return;
                    setState(() {
                      _startTimeCtrl.text = onboardingTimeLabel(
                        picked.hour * 60 + picked.minute,
                      );
                    });
                  },
                ),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            if (widget.findFreeStart != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('onboarding-step7-find-free-time-button'),
                onPressed: _findFreeTime,
                icon: const Icon(Icons.manage_search_rounded, size: 18),
                label: const Text('Find free time'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.55)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SkinEditLabel('PRODUCTS (ONE PER LINE)'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('onboarding-step7-edit-products-field'),
              controller: _productsCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: _skinEditInputDecoration(
                accent: accent,
                hintText: 'e.g.\nCleanser\nMoisturizer\nSunscreen',
              ),
            ),
            const SizedBox(height: 16),
            _SkinEditLabel('STEPS (ONE PER LINE)'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('onboarding-step7-edit-steps-field'),
              controller: _stepsCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: _skinEditInputDecoration(
                accent: accent,
                hintText: 'e.g.\nWash with lukewarm water\nApply moisturizer',
              ),
            ),
            const SizedBox(height: 16),
            _SkinEditLabel('REPEAT DAYS'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (index) {
                final day = index + 1;
                final dayName = const [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ][index];
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  key: ValueKey('onboarding-step7-edit-day-$day'),
                  label: Text(dayName),
                  selected: isSelected,
                  selectedColor: accent.withValues(alpha: 0.25),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else if (_selectedDays.length > 1) {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinEditLabel extends StatelessWidget {
  final String text;

  const _SkinEditLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: OptivusColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

InputDecoration _skinEditInputDecoration({
  required Color accent,
  required String hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.6),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
    ),
  );
}
