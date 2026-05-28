import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_filter_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_conflict_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_block_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_form_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/day_selector_chips.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/time_range_picker_row.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';

class FixedRoutineSetupScreen extends ConsumerStatefulWidget {
  const FixedRoutineSetupScreen({super.key});

  @override
  ConsumerState<FixedRoutineSetupScreen> createState() => _FixedRoutineSetupScreenState();
}

class _FixedRoutineSetupScreenState extends ConsumerState<FixedRoutineSetupScreen> {
  void _showForm({RoutineItem? existingItem}) {
    final isEdit = existingItem != null;
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    
    String fixedType = 'fixed';
    if (existingItem != null && existingItem.category == RoutineCategory.sleep) {
      fixedType = 'sleep';
    } else if (existingItem != null && existingItem.title.toLowerCase().contains('bath')) {
      fixedType = 'bath';
    } else if (existingItem != null && existingItem.title.toLowerCase().contains('travel')) {
      fixedType = 'travel';
    }

    TimeOfDay startTime = existingItem != null
        ? TimeOfDay(hour: existingItem.startMinute ~/ 60, minute: existingItem.startMinute % 60)
        : const TimeOfDay(hour: 22, minute: 30);

    TimeOfDay endTime = existingItem != null
        ? TimeOfDay(hour: existingItem.endMinute ~/ 60, minute: existingItem.endMinute % 60)
        : const TimeOfDay(hour: 6, minute: 30);

    List<int> selectedDays = existingItem?.repeatDays ?? [];
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            final isOvernight = (endTime.hour * 60 + endTime.minute) <= (startTime.hour * 60 + startTime.minute);

            return BaseTimelineFormSheet(
              title: isEdit ? 'Edit Fixed Block' : 'Add Fixed Block',
              isEdit: isEdit,
              onDelete: isEdit
                  ? () {
                      ref.read(routineNotifierProvider.notifier).deleteItem(existingItem.id);
                      Navigator.pop(ctx);
                    }
                  : null,
              onSave: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  setModal(() => errorMsg = 'Title is required.');
                  return;
                }
                if (selectedDays.isEmpty) {
                  setModal(() => errorMsg = 'Select at least one day.');
                  return;
                }

                final startMin = startTime.hour * 60 + startTime.minute;
                final endMin = endTime.hour * 60 + endTime.minute;
                final category = fixedType == 'sleep' ? RoutineCategory.sleep : RoutineCategory.fixed;

                final item = existingItem?.copyWith(
                      title: title,
                      startMinute: startMin,
                      endMinute: endMin,
                      repeatDays: selectedDays,
                      crossesMidnight: isOvernight,
                      category: category,
                      blockType: RoutineBlockType.hardBlock,
                      hardBlock: true,
                    ) ??
                    RoutineItem(
                      id: 'fixed_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      startMinute: startMin,
                      endMinute: endMin,
                      crossesMidnight: isOvernight,
                      repeatDays: selectedDays,
                      category: category,
                      blockType: RoutineBlockType.hardBlock,
                      source: RoutineSource.manual,
                      hardBlock: true,
                    );

                final allItems = ref.read(routineNotifierProvider).items;
                final conflicts = BaseTimelineConflictUtils.findConflicts(item, allItems);
                if (conflicts.isNotEmpty) {
                  setModal(() => errorMsg = 'Conflict detected with ${conflicts.first.title}.');
                  return;
                }

                if (isEdit) {
                  ref.read(routineNotifierProvider.notifier).updateItem(item);
                } else {
                  ref.read(routineNotifierProvider.notifier).addItem(item);
                }

                Navigator.pop(ctx);
              },
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TextField(controller: titleCtrl, label: 'Block Title (e.g. Sleep, Bath, Commute)'),
                  const SizedBox(height: 16),
                  const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TypeChip(label: 'Sleep', selected: fixedType == 'sleep', onTap: () => setModal(() => fixedType = 'sleep')),
                      _TypeChip(label: 'Bath', selected: fixedType == 'bath', onTap: () => setModal(() => fixedType = 'bath')),
                      _TypeChip(label: 'Travel', selected: fixedType == 'travel', onTap: () => setModal(() => fixedType = 'travel')),
                      _TypeChip(label: 'Other Fixed', selected: fixedType == 'fixed', onTap: () => setModal(() => fixedType = 'fixed')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  TimeRangePickerRow(
                    startTime: startTime,
                    endTime: endTime,
                    onStartTimeChanged: (time) => setModal(() => startTime = time),
                    onEndTimeChanged: (time) => setModal(() => endTime = time),
                  ),
                  if (isOvernight)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('🌙 This block crosses midnight (overnight)', style: TextStyle(fontSize: 12, color: OptivusColors.routineAccent, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 24),
                  const Text('Repeat Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  DaySelectorChips(
                    selectedDays: selectedDays,
                    onChanged: (days) => setModal(() => selectedDays = days),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 24),
                    Text(errorMsg!, style: const TextStyle(color: OptivusColors.danger, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(routineNotifierProvider).items;
    final fixedItems = BaseTimelineFilterUtils.getFixedItems(allItems);

    return Scaffold(
      backgroundColor: OptivusColors.routineBgBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: OptivusColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Fixed Blocks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: fixedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule_rounded, size: 64, color: OptivusColors.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'No fixed blocks set yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: OptivusColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _showForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.routineAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add Fixed Block'),
                  )
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: fixedItems.map((f) => BaseTimelineBlockCard(
                item: f,
                onTap: () => _showForm(existingItem: f),
              )).toList(),
            ),
      floatingActionButton: fixedItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showForm,
              backgroundColor: OptivusColors.routineAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Fixed Block', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TextField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: OptivusColors.textSecondary),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? OptivusColors.routineAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? OptivusColors.routineAccent : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? OptivusColors.routineAccent : OptivusColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
