import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_filter_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_block_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_form_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/day_selector_chips.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/time_range_picker_row.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';

class EatingRoutineSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const EatingRoutineSetupScreen({super.key, this.onBack});

  @override
  ConsumerState<EatingRoutineSetupScreen> createState() =>
      _EatingRoutineSetupScreenState();
}

class _EatingRoutineSetupScreenState
    extends ConsumerState<EatingRoutineSetupScreen> {
  void _showForm({RoutineItem? existingItem}) {
    final isEdit = existingItem != null;
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final mealCategoryCtrl = TextEditingController(
      text: existingItem?.mealCategory ?? '',
    );
    final calCtrl = TextEditingController(
      text: existingItem?.caloriesEstimate?.toString() ?? '',
    );
    final proteinCtrl = TextEditingController(
      text: existingItem?.proteinEstimate?.toString() ?? '',
    );
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');

    TimeOfDay startTime = existingItem != null
        ? TimeOfDay(
            hour: existingItem.startMinute ~/ 60,
            minute: existingItem.startMinute % 60,
          )
        : const TimeOfDay(hour: 13, minute: 0);

    TimeOfDay endTime = existingItem != null
        ? TimeOfDay(
            hour: existingItem.endMinute ~/ 60,
            minute: existingItem.endMinute % 60,
          )
        : const TimeOfDay(hour: 13, minute: 30);

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
              title: isEdit ? 'Edit Meal' : 'Add Meal',
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
                  setModal(() => errorMsg = 'Meal title is required.');
                  return;
                }
                if (selectedDays.isEmpty) {
                  setModal(() => errorMsg = 'Select at least one day.');
                  return;
                }

                final startMin = startTime.hour * 60 + startTime.minute;
                final endMin = endTime.hour * 60 + endTime.minute;

                final cals = double.tryParse(calCtrl.text.trim());
                final protein = double.tryParse(proteinCtrl.text.trim());

                final item =
                    existingItem?.copyWith(
                      title: title,
                      mealCategory: mealCategoryCtrl.text.trim(),
                      caloriesEstimate: cals,
                      proteinEstimate: protein,
                      notes: notesCtrl.text.trim(),
                      startMinute: startMin,
                      endMinute: endMin,
                      repeatDays: selectedDays,
                      crossesMidnight: endMin <= startMin,
                    ) ??
                    RoutineItem(
                      id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      startMinute: startMin,
                      endMinute: endMin,
                      crossesMidnight: endMin <= startMin,
                      repeatDays: selectedDays,
                      mealCategory: mealCategoryCtrl.text.trim(),
                      caloriesEstimate: cals,
                      proteinEstimate: protein,
                      notes: notesCtrl.text.trim(),
                      category: RoutineCategory.eating,
                      blockType:
                          RoutineBlockType.softBlock, // Eating is usually soft
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
                    label: 'Meal Title (e.g. Lunch, Post-workout)',
                  ),
                  const SizedBox(height: 16),
                  _TextField(
                    controller: mealCategoryCtrl,
                    label: 'Meal Category (e.g. Breakfast)',
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
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller: calCtrl,
                          label: 'Calories',
                          isNum: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TextField(
                          controller: proteinCtrl,
                          label: 'Protein (g)',
                          isNum: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _TextField(
                    controller: notesCtrl,
                    label: 'Notes (e.g. Items/Dishes)',
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
    final meals = BaseTimelineFilterUtils.getEatingItems(allItems);

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
          'Eating Routine',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: meals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_outlined,
                    size: 64,
                    color: OptivusColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No eating windows set yet.',
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
                    child: const Text('Add Meal'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: meals
                  .map(
                    (m) => BaseTimelineBlockCard(
                      item: m,
                      onTap: () => _showForm(existingItem: m),
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: meals.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showForm,
              backgroundColor: OptivusColors.routineAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Meal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNum;

  const _TextField({
    required this.controller,
    required this.label,
    this.isNum = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
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
