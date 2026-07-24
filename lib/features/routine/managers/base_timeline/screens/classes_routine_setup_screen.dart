import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_filter_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_conflict_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_block_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_form_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/day_selector_chips.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/time_range_picker_row.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';

class ClassesRoutineSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const ClassesRoutineSetupScreen({super.key, this.onBack});

  @override
  ConsumerState<ClassesRoutineSetupScreen> createState() =>
      _ClassesRoutineSetupScreenState();
}

class _ClassesRoutineSetupScreenState
    extends ConsumerState<ClassesRoutineSetupScreen> {
  void _showForm({RoutineItem? existingItem}) {
    final isEdit = existingItem != null;
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final roomCtrl = TextEditingController(text: existingItem?.location ?? '');
    final profCtrl = TextEditingController(text: existingItem?.notes ?? '');

    TimeOfDay startTime = existingItem != null
        ? TimeOfDay(
            hour: existingItem.startMinute ~/ 60,
            minute: existingItem.startMinute % 60,
          )
        : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endTime = existingItem != null
        ? TimeOfDay(
            hour: existingItem.endMinute ~/ 60,
            minute: existingItem.endMinute % 60,
          )
        : const TimeOfDay(hour: 10, minute: 0);

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
              title: isEdit ? 'Edit Class' : 'Add Class',
              isEdit: isEdit,
              onDelete: isEdit
                  ? () {
                      ref
                          .read(routineNotifierProvider.notifier)
                          .deleteItem(existingItem.id);
                      Navigator.pop(ctx);
                    }
                  : null,
              onSave: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  setModal(() => errorMsg = 'Class title is required.');
                  return;
                }
                if (selectedDays.isEmpty) {
                  setModal(() => errorMsg = 'Select at least one day.');
                  return;
                }

                final startMin = startTime.hour * 60 + startTime.minute;
                final endMin = endTime.hour * 60 + endTime.minute;

                final item =
                    existingItem?.copyWith(
                      title: title,
                      location: roomCtrl.text.trim(),
                      notes: profCtrl.text.trim(),
                      startMinute: startMin,
                      endMinute: endMin,
                      repeatDays: selectedDays,
                      crossesMidnight: endMin <= startMin,
                    ) ??
                    RoutineItem(
                      id: 'class_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      startMinute: startMin,
                      endMinute: endMin,
                      crossesMidnight: endMin <= startMin,
                      repeatDays: selectedDays,
                      location: roomCtrl.text.trim(),
                      notes: profCtrl.text.trim(),
                      category: RoutineCategory.classBlock,
                      blockType: RoutineBlockType.hardBlock,
                      source: RoutineSource.manual,
                      hardBlock: true,
                    );

                final allItems = ref.read(routineNotifierProvider).items;
                final conflicts = BaseTimelineConflictUtils.findConflicts(
                  item,
                  allItems,
                  day: ref.read(routineNotifierProvider).selectedDay,
                );
                if (conflicts.isNotEmpty) {
                  setModal(
                    () => errorMsg =
                        'Conflict detected with ${conflicts.first.title}. Adjust times or days.',
                  );
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
                  _TextField(
                    controller: titleCtrl,
                    label: 'Class / Subject Name',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller: roomCtrl,
                          label: 'Room (optional)',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TextField(
                          controller: profCtrl,
                          label: 'Professor (optional)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TimeRangePickerRow(
                    startTime: startTime,
                    endTime: endTime,
                    onStartTimeChanged: (time) =>
                        setModal(() => startTime = time),
                    onEndTimeChanged: (time) => setModal(() => endTime = time),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Repeat Days',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  DaySelectorChips(
                    selectedDays: selectedDays,
                    onChanged: (days) => setModal(() => selectedDays = days),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: OptivusColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
    final classes = BaseTimelineFilterUtils.getClasses(allItems);
    final bottomReserve = liquidTabBarReserve(context) + 40;
    final fabBottomOffset = (liquidTabBarReserve(context) - 88)
        .clamp(24.0, 96.0)
        .toDouble();

    return Scaffold(
      backgroundColor: widget.onBack == null
          ? OptivusColors.routineBgBottom
          : Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: OptivusColors.textPrimary,
          ),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Classes Routine',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: OptivusColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No classes set yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _showForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.routineAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add Class'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
              children: classes
                  .map(
                    (c) => BaseTimelineBlockCard(
                      item: c,
                      onTap: () => _showForm(existingItem: c),
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: classes.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(bottom: fabBottomOffset),
              child: FloatingActionButton.extended(
                onPressed: _showForm,
                backgroundColor: OptivusColors.routineAccent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Add Class',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
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
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: OptivusColors.textPrimary,
      ),
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
