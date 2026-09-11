import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';

void showAddRoutineSheet(
  BuildContext context,
  WidgetRef ref, {
  RoutineItem? editItem,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddRoutineSheetBody(editItem: editItem),
  );
}

class _AddRoutineSheetBody extends ConsumerStatefulWidget {
  final RoutineItem? editItem;

  const _AddRoutineSheetBody({this.editItem});

  @override
  ConsumerState<_AddRoutineSheetBody> createState() =>
      _AddRoutineSheetBodyState();
}

class _AddRoutineSheetBodyState extends ConsumerState<_AddRoutineSheetBody> {
  String? _mode;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _subtasksController;
  late final TextEditingController _stepsController;
  late final TextEditingController _dishesController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late int _durationMinutes;
  late RoutinePriority _priority;
  late RoutineCategory _category;
  late TrackerType _trackerType;
  late bool _hard;

  late List<int> _repeatDays;
  late String _bestTime;
  String _fixedKind = 'Class';
  String? _error;
  bool _saving = false;

  bool get _editing => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _mode = item == null ? null : _modeForBlockType(item.blockType);
    _titleController = TextEditingController(text: item?.title ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _subtasksController = TextEditingController(
      text: item?.subtasks?.join('\n') ?? '',
    );
    _stepsController = TextEditingController(
      text: item?.displaySteps?.join('\n') ?? '',
    );
    _dishesController = TextEditingController(
      text: item?.dishes?.join('\n') ?? '',
    );
    _date = item?.date ?? ref.read(routineNotifierProvider).selectedDay;
    _startTime = TimeOfDay(
      hour: (item?.startMinute ?? 8 * 60) ~/ 60,
      minute: (item?.startMinute ?? 8 * 60) % 60,
    );
    _durationMinutes = item?.durationMinutes.clamp(1, 24 * 60).toInt() ?? 30;
    _priority = item?.priority ?? RoutinePriority.goodToDo;
    _category = item?.category ?? RoutineCategory.habit;
    _trackerType = item?.trackerType ?? TrackerType.none;
    _hard = item?.isHardBlock ?? false;

    _repeatDays = List<int>.from(item?.repeatDays ?? const []);
    _bestTime = item?.bestTime ?? 'Morning';

    if (item != null &&
        (item.blockType == RoutineBlockType.hardBlock ||
            item.blockType == RoutineBlockType.softBlock)) {
      _fixedKind = _kindForCategory(item.category);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtasksController.dispose();
    _stepsController.dispose();
    _dishesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OptivusColors.routineSheetTop,
                OptivusColors.routineSheetBottom,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _editing ? Icons.edit_calendar_rounded : Icons.add_circle,
                    size: 22,
                    color: OptivusColors.routineAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editing ? 'Edit Routine Item' : 'Add to Routine',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_mode == null) _buildTypeGrid() else _buildForm(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeGrid() {
    final categories = [
      _Cat(
        'Flexible Task',
        Icons.task_alt,
        OptivusColors.blockFlex,
        'flexible',
      ),
      _Cat('Fixed Block', Icons.lock_outline, OptivusColors.blockHard, 'fixed'),
      _Cat('Habit', Icons.repeat_rounded, OptivusColors.blockSoft, 'habit'),
      _Cat('Tracker Task', Icons.timer, OptivusColors.blockTracker, 'tracker'),
      _Cat(
        'Check-in',
        Icons.check_circle_outline,
        OptivusColors.blockCheckIn,
        'checkin',
      ),
      _Cat(
        'Money Saving Task',
        Icons.savings,
        OptivusColors.blockMoney,
        'money',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((cat) {
        return GestureDetector(
          onTap: () => setState(() {
            _mode = cat.key;
            _applyModeDefaults(cat.key);
          }),
          child: Container(
            width: (MediaQuery.of(context).size.width - 52) / 2,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cat.color.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(cat.icon, size: 26, color: cat.color),
                const SizedBox(height: 8),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cat.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildForm() {
    final mode = _mode!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_editing)
          GestureDetector(
            onTap: () => setState(() => _mode = null),
            child: const Row(
              children: [
                Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: OptivusColors.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        if (!_editing) const SizedBox(height: 14),
        _textField(
          controller: _titleController,
          label: 'Title',
          hint: _hintForMode(mode),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _dateTile()),
            const SizedBox(width: 10),
            Expanded(child: _timeTile()),
          ],
        ),
        const SizedBox(height: 10),
        _durationTile(),
        const SizedBox(height: 12),
        if (mode == 'fixed') _fixedBlockFields(),
        if (mode == 'tracker') _trackerFields(),
        if (mode == 'checkin') _checkInFields(),
        if (mode == 'money') _moneyFields(),
        if (mode == 'habit') _habitFields(),
        if (mode == 'flexible') _flexibleFields(),
        const SizedBox(height: 12),
        _repeatSelector(),
        const SizedBox(height: 12),
        _textField(
          controller: _notesController,
          label: 'Notes',
          hint: 'Optional notes',
          maxLines: 3,
        ),
        if (mode == 'flexible' || mode == 'tracker' || mode == 'habit') ...[
          const SizedBox(height: 12),
          _textField(
            controller: _subtasksController,
            label: 'Subtasks',
            hint: 'One subtask per line',
            maxLines: 4,
          ),
        ],
        if (mode == 'fixed' && _category == RoutineCategory.skinCare ||
            mode == 'habit') ...[
          const SizedBox(height: 12),
          _textField(
            controller: _stepsController,
            label: 'Steps',
            hint: 'One step per line',
            maxLines: 4,
          ),
        ],
        if (_category == RoutineCategory.eating) ...[
          const SizedBox(height: 12),
          _textField(
            controller: _dishesController,
            label: 'Dishes',
            hint: 'One dish per line',
            maxLines: 4,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OptivusColors.danger,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _letAiPlace,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: OptivusColors.routineAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Let AI place it',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.routineAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OptivusColors.routineAccent,
                  disabledBackgroundColor: OptivusColors.disabled,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _editing ? 'Save changes' : 'Save at this time',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _flexibleFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _enumTile<RoutinePriority>(
                label: 'Priority',
                value: _priority,
                values: RoutinePriority.values,
                labelFor: (value) =>
                    value == RoutinePriority.mustDo ? 'Must do' : 'Good to do',
                onChanged: (value) => setState(() => _priority = value),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stringTile(
                label: 'Best time',
                value: _bestTime,
                values: const [
                  'Morning',
                  'Afternoon',
                  'Evening',
                  'Night',
                  'Anytime',
                ],
                onChanged: (value) => setState(() => _bestTime = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _categoryTile(),
      ],
    );
  }

  Widget _habitFields() {
    return Column(
      children: [
        _categoryTile(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _enumTile<RoutinePriority>(
                label: 'Priority',
                value: _priority,
                values: RoutinePriority.values,
                labelFor: (value) =>
                    value == RoutinePriority.mustDo ? 'Must do' : 'Good to do',
                onChanged: (value) => setState(() => _priority = value),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stringTile(
                label: 'Best time',
                value: _bestTime,
                values: const [
                  'Morning',
                  'Afternoon',
                  'Evening',
                  'Night',
                  'Anytime',
                ],
                onChanged: (value) => setState(() => _bestTime = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _enumTile<TrackerType>(
          label: 'Tracker linked',
          value: _trackerType,
          values: const [
            TrackerType.none,
            TrackerType.meditation,
            TrackerType.focus,
            TrackerType.workout,
            TrackerType.hydration,
          ],
          labelFor: (value) => value == TrackerType.none ? 'No' : value.name,
          onChanged: (value) => setState(() => _trackerType = value),
        ),
      ],
    );
  }

  Widget _fixedBlockFields() {
    return Column(
      children: [
        _stringTile(
          label: 'Type',
          value: _fixedKind,
          values: const [
            'Class',
            'Job',
            'Eating',
            'Sleep',
            'Skin Care',
            'Bath',
            'Travel',
            'Prayer',
            'Tuition',
            'Other',
          ],
          onChanged: (value) {
            setState(() {
              _fixedKind = value;
              _category = _categoryForFixedKind(value);
              _hard =
                  value == 'Class' ||
                  value == 'Job' ||
                  value == 'Sleep' ||
                  value == 'Travel';
            });
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          value: _hard,
          onChanged: (value) => setState(() => _hard = value),
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeTrackColor: OptivusColors.blockHard,
          title: const Text(
            'Hard block',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _trackerFields() {
    return _enumTile<TrackerType>(
      label: 'Tracker task',
      value: _trackerType == TrackerType.none
          ? TrackerType.meditation
          : _trackerType,
      values: const [
        TrackerType.meditation,
        TrackerType.focus,
        TrackerType.workout,
        TrackerType.hydration,
        TrackerType.money,
        TrackerType.smoking,
      ],
      labelFor: (value) => value.name,
      onChanged: (value) {
        setState(() {
          _trackerType = value;
          _category = switch (value) {
            TrackerType.meditation => RoutineCategory.meditation,
            TrackerType.hydration => RoutineCategory.hydration,
            TrackerType.money => RoutineCategory.finance,
            TrackerType.focus => RoutineCategory.focus,
            TrackerType.smoking => RoutineCategory.badHabit,
            TrackerType.workout => RoutineCategory.health,
            TrackerType.none => RoutineCategory.health,
          };
        });
      },
    );
  }

  Widget _checkInFields() {
    final options = const [
      'Smoking',
      'Alcohol',
      'Junk food',
      'Water',
      'Sleep quality',
      'Stress',
      'Manual saving',
    ];
    return _stringTile(
      label: 'Check-in type',
      value: options.contains(_titleController.text)
          ? _titleController.text
          : options.first,
      values: options,
      onChanged: (value) {
        setState(() {
          _titleController.text = value;
          _category = value == 'Water'
              ? RoutineCategory.hydration
              : value == 'Manual saving'
              ? RoutineCategory.finance
              : RoutineCategory.badHabit;
        });
      },
    );
  }

  Widget _moneyFields() {
    return const _InfoBox(
      text:
          'This creates a Routine money task. Start opens Tracker Money System.',
    );
  }

  Widget _categoryTile() {
    return _enumTile<RoutineCategory>(
      label: 'Category',
      value: _category,
      values: const [
        RoutineCategory.classBlock,
        RoutineCategory.job,
        RoutineCategory.eating,
        RoutineCategory.fixed,
        RoutineCategory.skinCare,
        RoutineCategory.habit,
        RoutineCategory.identity,
        RoutineCategory.finance,
        RoutineCategory.health,
        RoutineCategory.focus,
        RoutineCategory.meditation,
        RoutineCategory.hydration,
      ],
      labelFor: (value) => value.name,
      onChanged: (value) => setState(() => _category = value),
    );
  }

  Widget _repeatSelector() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          children: List.generate(7, (index) {
            final day = index + 1;
            final selected = _repeatDays.contains(day);
            return GestureDetector(
              onTap: () => setState(() {
                selected ? _repeatDays.remove(day) : _repeatDays.add(day);
                _repeatDays.sort();
              }),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? OptivusColors.ink
                      : Colors.white.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : OptivusColors.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _dateTile() {
    return _PickerTile(
      label: 'Date',
      value:
          '${TimelineUtils.getShortDayName(_date.weekday)} ${_date.day}/${_date.month}',
      icon: Icons.calendar_today_rounded,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _date = picked);
      },
    );
  }

  Widget _timeTile() {
    return _PickerTile(
      label: 'Start time',
      value: _startTime.format(context),
      icon: Icons.schedule_rounded,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _startTime,
        );
        if (picked != null) setState(() => _startTime = picked);
      },
    );
  }

  Widget _durationTile() {
    return _PickerTile(
      label: 'Duration',
      value: TimelineUtils.formatDuration(_durationMinutes),
      icon: Icons.timelapse_rounded,
      onTap: _showDurationPicker,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => setState(() {
              _durationMinutes = (_durationMinutes - 5)
                  .clamp(1, 24 * 60)
                  .toInt();
            }),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: OptivusColors.textSecondary,
          ),
          IconButton(
            onPressed: () => setState(() {
              _durationMinutes = (_durationMinutes + 5)
                  .clamp(1, 24 * 60)
                  .toInt();
            }),
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: OptivusColors.routineAccent,
          ),
        ],
      ),
    );
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.72),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + media.padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Duration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 480]
                      .map((mins) {
                        return ActionChip(
                          label: Text(
                            TimelineUtils.formatDuration(mins),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _durationMinutes == mins
                                  ? OptivusColors.routineAccent
                                  : OptivusColors.textPrimary,
                            ),
                          ),
                          backgroundColor: _durationMinutes == mins
                              ? OptivusColors.routineAccent.withValues(
                                  alpha: 0.15,
                                )
                              : Colors.grey.shade100,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onPressed: () {
                            setState(() => _durationMinutes = mins);
                            Navigator.of(ctx).pop();
                          },
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _enumTile<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return _DropTile<T>(
      label: label,
      value: value,
      values: values,
      labelFor: labelFor,
      onChanged: onChanged,
    );
  }

  Widget _stringTile({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return _DropTile<String>(
      label: label,
      value: value,
      values: values,
      labelFor: (value) => value,
      onChanged: onChanged,
    );
  }

  int get _startMinute => _startTime.hour * 60 + _startTime.minute;

  RoutineItem _draftItem() {
    final mode = _mode ?? 'flexible';
    final blockType = _blockTypeForMode(mode);
    final start = _startMinute;
    final endRaw = start + _durationMinutes;
    final crossesMidnight = endRaw > 1440;
    final end = crossesMidnight
        ? (endRaw - 1440).clamp(0, 1440).toInt()
        : endRaw.clamp(1, 1440).toInt();

    final endDate = crossesMidnight && _repeatDays.isEmpty
        ? TimelineUtils.dateOnly(_date).add(const Duration(days: 1))
        : null;

    final subtasks = _lines(_subtasksController.text);
    final steps = _lines(_stepsController.text);
    final dishes = _lines(_dishesController.text);
    return RoutineItem(
      id:
          widget.editItem?.id ??
          'routine-${DateTime.now().millisecondsSinceEpoch}',
      userId: widget.editItem?.userId,
      title: _titleController.text.trim(),
      date: _repeatDays.isEmpty ? TimelineUtils.dateOnly(_date) : null,
      endDate: endDate,
      startMinute: start,
      endMinute: end,
      crossesMidnight: crossesMidnight,
      endsNextDay: crossesMidnight,
      repeatDays: _repeatDays,
      blockType: blockType,
      category: _category,
      source: widget.editItem?.source ?? RoutineSource.manual,
      status: widget.editItem?.status ?? RoutineStatus.planned,
      priority: _priority,
      isTrackerLinked:
          blockType == RoutineBlockType.trackerTask ||
          blockType == RoutineBlockType.moneyTask ||
          _trackerType != TrackerType.none,
      trackerType: blockType == RoutineBlockType.moneyTask
          ? TrackerType.money
          : _trackerType,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      subtasks: subtasks.isEmpty ? null : subtasks,
      subtasksCompleted: subtasks.isEmpty
          ? null
          : List<bool>.filled(subtasks.length, false),
      steps: steps.isEmpty ? null : steps,
      dishes: dishes.isEmpty ? null : dishes,
      hardBlock: _hard,
      repeatRule: _repeatDays.isEmpty ? 'once' : 'weekly',
      createdAt: widget.editItem?.createdAt,
    );
  }

  void _letAiPlace() {
    if (_saving) return;
    final draft = _draftItem();
    final slot = ref
        .read(routineNotifierProvider.notifier)
        .findFreeSlot(
          item: draft,
          date: _date,
          durationMinutes: _durationMinutes,
        );
    if (slot == null) {
      setState(
        () =>
            _error =
                'No open slot found. You can still choose any time manually.',
      );
      return;
    }
    setState(() {
      _startTime = TimeOfDay(hour: slot ~/ 60, minute: slot % 60);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final item = _draftItem();
    setState(() {
      _saving = true;
      _error = null;
    });
    RoutineWriteResult result;
    if (_editing) {
      result = await ref
          .read(routineNotifierProvider.notifier)
          .updateItem(item);
    } else {
      result = await ref.read(routineNotifierProvider.notifier).addItem(item);
    }
    if (!mounted) return;
    if (result.outcome == RoutineWriteOutcome.saved ||
        result.outcome == RoutineWriteOutcome.noOp) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error =
          result.validation?.userSafeMessage ??
          result.message ??
          'Failed to save item. Please adjust the form and retry.';
    });
  }

  String? _validate() {
    if (_titleController.text.trim().isEmpty) return 'Title is required.';
    if (_durationMinutes <= 0) return 'Duration must be greater than 0.';
    final endRaw = _startMinute + _durationMinutes;
    if (endRaw > 1440 && _fixedKind != 'Sleep') {
      return 'Only Sleep blocks typically cross midnight. Adjust the time or set type to Sleep.';
    }
    return null;
  }

  void _applyModeDefaults(String mode) {
    switch (mode) {
      case 'fixed':
        _durationMinutes = 60;
        _hard = true;
        _category = RoutineCategory.classBlock;
        _fixedKind = 'Class';
        break;
      case 'habit':
        _durationMinutes = 15;
        _category = RoutineCategory.habit;
        break;
      case 'tracker':
        _durationMinutes = 10;
        _trackerType = TrackerType.meditation;
        _category = RoutineCategory.meditation;
        break;
      case 'checkin':
        _durationMinutes = 5;
        _category = RoutineCategory.badHabit;
        if (_titleController.text.isEmpty) _titleController.text = 'Smoking';
        break;
      case 'money':
        _durationMinutes = 5;
        _category = RoutineCategory.finance;
        _trackerType = TrackerType.money;
        if (_titleController.text.isEmpty) {
          _titleController.text = 'Tiny money save';
        }
        break;
      default:
        _durationMinutes = 30;
        _category = RoutineCategory.habit;
    }
  }

  RoutineBlockType _blockTypeForMode(String mode) {
    return switch (mode) {
      'fixed' =>
        _hard ? RoutineBlockType.hardBlock : RoutineBlockType.softBlock,
      'habit' =>
        _trackerType == TrackerType.none
            ? RoutineBlockType.flexibleTask
            : RoutineBlockType.trackerTask,
      'tracker' => RoutineBlockType.trackerTask,
      'checkin' => RoutineBlockType.checkIn,
      'money' => RoutineBlockType.moneyTask,
      _ => RoutineBlockType.flexibleTask,
    };
  }

  String _modeForBlockType(RoutineBlockType blockType) {
    return switch (blockType) {
      RoutineBlockType.hardBlock => 'fixed',
      RoutineBlockType.softBlock => 'fixed',
      RoutineBlockType.flexibleTask => 'flexible',
      RoutineBlockType.trackerTask => 'tracker',
      RoutineBlockType.checkIn => 'checkin',
      RoutineBlockType.moneyTask => 'money',
    };
  }

  RoutineCategory _categoryForFixedKind(String kind) {
    return switch (kind) {
      'Class' || 'Tuition' => RoutineCategory.classBlock,
      'Job' => RoutineCategory.job,
      'Eating' => RoutineCategory.eating,
      'Sleep' => RoutineCategory.sleep,
      'Skin Care' => RoutineCategory.skinCare,
      'Bath' || 'Travel' || 'Prayer' => RoutineCategory.fixed,
      _ => RoutineCategory.fixed,
    };
  }

  String _kindForCategory(RoutineCategory category) {
    return switch (category) {
      RoutineCategory.classBlock => 'Class',
      RoutineCategory.job => 'Job',
      RoutineCategory.eating => 'Eating',
      RoutineCategory.sleep => 'Sleep',
      RoutineCategory.skinCare => 'Skin Care',
      RoutineCategory.fixed => 'Bath', // Default for fixed
      _ => 'Other',
    };
  }

  String _hintForMode(String mode) {
    return switch (mode) {
      'fixed' => 'e.g., Class, Job, Sleep',
      'habit' => 'e.g., Reading, Journaling',
      'tracker' => 'e.g., Meditation, Workout',
      'checkin' => 'e.g., Smoking',
      'money' => 'e.g., Tiny money save',
      _ => 'e.g., Morning Study',
    };
  }

  List<String> _lines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  final String key;

  const _Cat(this.label, this.icon, this.color, this.key);
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: OptivusColors.routineAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _DropTile<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  const _DropTile({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: values
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    '$label: ${labelFor(item)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OptivusColors.routineAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textBody,
        ),
      ),
    );
  }
}
