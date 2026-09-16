import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Interactive review sheet for meals extracted from a menu or meal plan photo.
///
/// Displays all extracted candidates with their detected timing, days, and dishes.
/// Flags items that need attention (e.g. missing days, dishes, or invalid time)
/// and allows inline fixes before committing them to the timeline.
class EatingImportReviewSheet extends StatefulWidget {
  final List<TimelineBlockDraft> initialBlocks;
  final ValueChanged<List<TimelineBlockDraft>> onApply;
  final VoidCallback onCancel;

  const EatingImportReviewSheet({
    super.key,
    required this.initialBlocks,
    required this.onApply,
    required this.onCancel,
  });

  static Future<List<TimelineBlockDraft>?> show(
    BuildContext context, {
    required List<TimelineBlockDraft> candidates,
  }) {
    return showModalBottomSheet<List<TimelineBlockDraft>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => EatingImportReviewSheet(
        initialBlocks: candidates,
        onApply: (blocks) => Navigator.pop(ctx, blocks),
        onCancel: () => Navigator.pop(ctx, null),
      ),
    );
  }

  @override
  State<EatingImportReviewSheet> createState() =>
      _EatingImportReviewSheetState();
}

class _EatingImportReviewSheetState extends State<EatingImportReviewSheet> {
  late List<TimelineBlockDraft> _blocks;

  @override
  void initState() {
    super.initState();
    // Preserve extracted repeat days truthfully. Never invent fake repeat days!
    _blocks = widget.initialBlocks.map((b) {
      final validDays = b.repeatDays
          .where((d) => d >= 1 && d <= 7)
          .toSet()
          .toList()
        ..sort();
      var dishes = b.dishes;
      if (dishes.isEmpty && b.title.trim().isNotEmpty) {
        dishes = [b.title.trim()];
      }
      return b.copyWith(repeatDays: validDays, dishes: dishes);
    }).toList();
  }

  bool get _hasInvalidCandidates => _blocks.any((b) {
        final hasDishes = b.dishes.isNotEmpty;
        final hasDays = b.repeatDays.isNotEmpty;
        final isValidTime = b.endMinute > b.startMinute &&
            b.startMinute >= 0 &&
            b.endMinute <= 1440;
        final hasTitle = b.title.trim().isNotEmpty;
        return !hasDishes || !hasDays || !isValidTime || !hasTitle;
      });

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
    });
  }

  void _editBlock(int index) {
    final block = _blocks[index];
    final titleCtrl = TextEditingController(text: block.title);
    final dishesCtrl = TextEditingController(text: block.dishes.join('\n'));
    var startMin = block.startMinute;
    var endMin = block.endMinute;
    final selectedDays = Set<int>.from(block.repeatDays);

    showDialog<TimelineBlockDraft>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Edit Extracted Meal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Meal Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dishesCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Dishes (one per line)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: startMin ~/ 60,
                              minute: startMin % 60,
                            ),
                          );
                          if (picked != null) {
                            setDlgState(() => startMin = picked.hour * 60 + picked.minute);
                          }
                        },
                        child: Text(EatingPresentationUtils.formatTime(startMin)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: endMin ~/ 60,
                              minute: endMin % 60,
                            ),
                          );
                          if (picked != null) {
                            setDlgState(() => endMin = picked.hour * 60 + picked.minute);
                          }
                        },
                        child: Text(EatingPresentationUtils.formatTime(endMin)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'REPEAT DAYS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(
                          const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1],
                        ),
                        selected: selectedDays.contains(d),
                        selectedColor: OptivusColors.roseAccent.withValues(alpha: 0.18),
                        onSelected: (sel) {
                          setDlgState(() {
                            if (sel) {
                              selectedDays.add(d);
                            } else {
                              selectedDays.remove(d);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                final dishes = dishesCtrl.text
                    .split('\n')
                    .map((d) => d.trim())
                    .where((d) => d.isNotEmpty)
                    .toList();
                final updated = block.copyWith(
                  title: title,
                  dishes: dishes.isNotEmpty ? dishes : [title],
                  startMinute: startMin,
                  endMinute: endMin > startMin ? endMin : startMin + 30,
                  repeatDays: selectedDays.toList()..sort(),
                );
                Navigator.pop(dlgCtx, updated);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    ).then((updated) {
      if (updated != null) {
        setState(() {
          _blocks[index] = updated;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      bottom: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: OptivusColors.roseAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Extracted Meals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_blocks.length} meals detected from photo',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Candidate list
              Expanded(
                child: _blocks.isEmpty
                    ? const Center(
                        child: Text(
                          'No meals to review.',
                          style: TextStyle(
                            color: OptivusColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _blocks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final b = _blocks[index];
                          final hasDishes = b.dishes.isNotEmpty;
                          final hasDays = b.repeatDays.isNotEmpty;
                          final isValidTime = b.endMinute > b.startMinute &&
                              b.startMinute >= 0 &&
                              b.endMinute <= 1440;
                          final hasTitle = b.title.trim().isNotEmpty;
                          final needsAttention = !hasDishes || !hasDays || !isValidTime || !hasTitle;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _editBlock(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: needsAttention
                                        ? OptivusColors.warning.withValues(alpha: 0.5)
                                        : OptivusColors.borderSubtle,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  b.title.isEmpty ? 'Untitled meal' : b.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: b.title.isEmpty
                                                        ? OptivusColors.warning
                                                        : OptivusColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (needsAttention)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: OptivusColors.warning.withValues(alpha: 0.14),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Needs Review',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: OptivusColors.warning,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${EatingPresentationUtils.formatTimeRange(b.startMinute, b.endMinute)} · ${b.repeatDays.length} days/week',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: OptivusColors.textSecondary,
                                            ),
                                          ),
                                          if (b.dishes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              b.dishes.join(', '),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: OptivusColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (!hasDays) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Days: Missing — Tap to choose days',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: OptivusColors.warning,
                                              ),
                                            ),
                                          ],
                                          if (!isValidTime) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Time: Invalid — Tap to fix time',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: OptivusColors.warning,
                                              ),
                                            ),
                                          ],
                                          if (!hasDishes) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Dishes: Missing — Tap to add dishes',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: OptivusColors.warning,
                                              ),
                                            ),
                                          ],
                                          if (!hasTitle) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Title: Missing — Tap to add title',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: OptivusColors.warning,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 18),
                                      color: OptivusColors.roseAccent,
                                      onPressed: () => _editBlock(index),
                                      tooltip: 'Edit meal',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                      color: OptivusColors.textSecondary,
                                      onPressed: () => _removeBlock(index),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),

              if (_hasInvalidCandidates) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Please resolve flagged issues before applying to schedule.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.warning,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: (_blocks.isEmpty || _hasInvalidCandidates)
                          ? null
                          : () => widget.onApply(_blocks),
                      style: FilledButton.styleFrom(
                        backgroundColor: OptivusColors.roseAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply to Schedule',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
