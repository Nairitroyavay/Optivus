import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_filter_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_block_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_form_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/day_selector_chips.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/time_range_picker_row.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';

class SkinCareRoutineSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const SkinCareRoutineSetupScreen({super.key, this.onBack});

  @override
  ConsumerState<SkinCareRoutineSetupScreen> createState() =>
      _SkinCareRoutineSetupScreenState();
}

class _SkinCareRoutineSetupScreenState
    extends ConsumerState<SkinCareRoutineSetupScreen> {
  void _showForm({RoutineItem? existingItem}) {
    final isEdit = existingItem != null;
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');

    // We can extract steps into a text field separated by commas
    final stepsCtrl = TextEditingController(
      text: existingItem?.steps?.join(', ') ?? '',
    );

    TimeOfDay startTime = existingItem != null
        ? TimeOfDay(
            hour: existingItem.startMinute ~/ 60,
            minute: existingItem.startMinute % 60,
          )
        : const TimeOfDay(hour: 8, minute: 0);

    TimeOfDay endTime = existingItem != null
        ? TimeOfDay(
            hour: existingItem.endMinute ~/ 60,
            minute: existingItem.endMinute % 60,
          )
        : const TimeOfDay(hour: 8, minute: 15);

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
              title: isEdit ? 'Edit Skin Care' : 'Add Skin Care',
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
                  setModal(() => errorMsg = 'Title is required.');
                  return;
                }
                if (selectedDays.isEmpty) {
                  setModal(() => errorMsg = 'Select at least one day.');
                  return;
                }

                final startMin = startTime.hour * 60 + startTime.minute;
                final endMin = endTime.hour * 60 + endTime.minute;

                final rawSteps = stepsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final item =
                    existingItem?.copyWith(
                      title: title,
                      notes: notesCtrl.text.trim(),
                      steps: rawSteps,
                      startMinute: startMin,
                      endMinute: endMin,
                      repeatDays: selectedDays,
                      crossesMidnight: endMin <= startMin,
                    ) ??
                    RoutineItem(
                      id: 'skincare_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      startMinute: startMin,
                      endMinute: endMin,
                      crossesMidnight: endMin <= startMin,
                      repeatDays: selectedDays,
                      steps: rawSteps,
                      notes: notesCtrl.text.trim(),
                      category: RoutineCategory.skinCare,
                      blockType: RoutineBlockType.softBlock,
                      source: RoutineSource.manual,
                      hardBlock: false,
                    );

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
                    label: 'Routine Name (e.g. Morning Glow)',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Time Window',
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
                  const SizedBox(height: 24),
                  _TextField(
                    controller: stepsCtrl,
                    label: 'Steps (comma separated)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _TextField(controller: notesCtrl, label: 'Notes (optional)'),
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
    final skinCare = BaseTimelineFilterUtils.getSkinCareItems(allItems);
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
          'Skin Care Routine',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: skinCare.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.face_retouching_natural_rounded,
                    size: 64,
                    color: OptivusColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No skin care sets yet.',
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
                    child: const Text('Add Skin Care'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
              children: skinCare
                  .map(
                    (s) => BaseTimelineBlockCard(
                      item: s,
                      onTap: () => _showForm(existingItem: s),
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: skinCare.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(bottom: fabBottomOffset),
              child: FloatingActionButton.extended(
                onPressed: _showForm,
                backgroundColor: OptivusColors.routineAccent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Add Skin Care',
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
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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
