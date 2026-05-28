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

class WorkRoutineSetupScreen extends ConsumerStatefulWidget {
  const WorkRoutineSetupScreen({super.key});

  @override
  ConsumerState<WorkRoutineSetupScreen> createState() => _WorkRoutineSetupScreenState();
}

class _WorkRoutineSetupScreenState extends ConsumerState<WorkRoutineSetupScreen> {
  void _showForm({RoutineItem? existingItem}) {
    final isEdit = existingItem != null;
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final locCtrl = TextEditingController(text: existingItem?.location ?? '');
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');

    String workMode = existingItem != null && existingItem.blockType == RoutineBlockType.softBlock ? 'flexible' : 'fixed';

    TimeOfDay startTime = existingItem != null
        ? TimeOfDay(hour: existingItem.startMinute ~/ 60, minute: existingItem.startMinute % 60)
        : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endTime = existingItem != null
        ? TimeOfDay(hour: existingItem.endMinute ~/ 60, minute: existingItem.endMinute % 60)
        : const TimeOfDay(hour: 17, minute: 0);

    List<int> selectedDays = existingItem?.repeatDays ?? [];
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return BaseTimelineFormSheet(
              title: isEdit ? 'Edit Work Block' : 'Add Work Block',
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
                  setModal(() => errorMsg = 'Work title is required.');
                  return;
                }
                if (selectedDays.isEmpty) {
                  setModal(() => errorMsg = 'Select at least one day.');
                  return;
                }

                final startMin = startTime.hour * 60 + startTime.minute;
                final endMin = endTime.hour * 60 + endTime.minute;
                final bType = workMode == 'fixed' ? RoutineBlockType.hardBlock : RoutineBlockType.softBlock;

                final item = existingItem?.copyWith(
                      title: title,
                      location: locCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      startMinute: startMin,
                      endMinute: endMin,
                      repeatDays: selectedDays,
                      crossesMidnight: endMin <= startMin,
                      blockType: bType,
                      hardBlock: bType == RoutineBlockType.hardBlock,
                    ) ??
                    RoutineItem(
                      id: 'work_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      startMinute: startMin,
                      endMinute: endMin,
                      crossesMidnight: endMin <= startMin,
                      repeatDays: selectedDays,
                      location: locCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      category: RoutineCategory.job,
                      blockType: bType,
                      source: RoutineSource.manual,
                      hardBlock: bType == RoutineBlockType.hardBlock,
                    );

                if (item.isHardBlock) {
                  final allItems = ref.read(routineNotifierProvider).items;
                  final conflicts = BaseTimelineConflictUtils.findConflicts(item, allItems);
                  if (conflicts.isNotEmpty) {
                    setModal(() => errorMsg = 'Conflict detected with ${conflicts.first.title}.');
                    return;
                  }
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
                  _TextField(controller: titleCtrl, label: 'Work Title (e.g. Office, Client Call)'),
                  const SizedBox(height: 16),
                  
                  // Work Mode
                  const Text('Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fixed', label: Text('Fixed')),
                      ButtonSegment(value: 'flexible', label: Text('Flexible / Mixed')),
                    ],
                    selected: {workMode},
                    onSelectionChanged: (set) => setModal(() => workMode = set.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      selectedBackgroundColor: OptivusColors.routineAccent.withValues(alpha: 0.2),
                      selectedForegroundColor: OptivusColors.routineAccent,
                    ),
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
                  const SizedBox(height: 24),
                  const Text('Repeat Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  DaySelectorChips(
                    selectedDays: selectedDays,
                    onChanged: (days) => setModal(() => selectedDays = days),
                  ),
                  const SizedBox(height: 24),
                  _TextField(controller: locCtrl, label: 'Location (optional)'),
                  const SizedBox(height: 16),
                  _TextField(controller: notesCtrl, label: 'Notes (optional)'),
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
    final work = BaseTimelineFilterUtils.getWorkItems(allItems);

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
          'Work Routine',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: work.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.work_outline_rounded, size: 64, color: OptivusColors.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'No work blocks set yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: OptivusColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _showForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.routineAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add Work Block'),
                  )
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: work.map((w) => BaseTimelineBlockCard(
                item: w,
                onTap: () => _showForm(existingItem: w),
              )).toList(),
            ),
      floatingActionButton: work.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showForm,
              backgroundColor: OptivusColors.routineAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Work Block', style: TextStyle(fontWeight: FontWeight.bold)),
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
