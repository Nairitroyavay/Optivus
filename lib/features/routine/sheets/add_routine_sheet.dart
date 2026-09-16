import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/add_routine_mapper.dart';
import 'package:optivus/features/routine/services/add_routine_validator.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

/// Shows the production Add Routine bottom sheet.
void showAddRoutineSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const AddRoutineSheet(),
  );
}

class AddRoutineSheet extends ConsumerStatefulWidget {
  const AddRoutineSheet({super.key});

  @override
  ConsumerState<AddRoutineSheet> createState() => _AddRoutineSheetState();
}

class _AddRoutineSheetState extends ConsumerState<AddRoutineSheet> {
  bool _typeSelected = false;
  late AddRoutineDraft _draft;

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _subtasksController;
  late final TextEditingController _stepsController;
  late final TextEditingController _dishesController;

  // Rich structured controllers
  late final TextEditingController _professorController;
  late final TextEditingController _courseCodeController;
  late final TextEditingController _classTypeController;
  late final TextEditingController _sectionController;
  late final TextEditingController _classLocationController;

  late final TextEditingController _workRoleController;
  late final TextEditingController _workOrgController;
  late final TextEditingController _workDeptController;
  late final TextEditingController _workContextTypeController;
  late final TextEditingController _workModeController;
  late final TextEditingController _workBlockKindController;
  late final TextEditingController _workLocationController;

  bool _showMoreDetails = false;
  String? _error;
  bool _saving = false;
  bool _saveFailed = false;

  late final TextEditingController _mealSlotController;
  late final TextEditingController _mealCategoryController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;

  late final TextEditingController _skinSlotController;
  late final TextEditingController _skinStepsController;
  late final TextEditingController _skinProductsController;
  late final TextEditingController _skinMissingController;

  @override
  void initState() {
    super.initState();
    final selectedDay = ref.read(routineNotifierProvider).selectedDay;
    _draft = AddRoutineDraft.initial(initialDate: selectedDay);

    _titleController = TextEditingController(text: _draft.title);
    _notesController = TextEditingController(text: _draft.notes);
    _subtasksController = TextEditingController();
    _stepsController = TextEditingController();
    _dishesController = TextEditingController();

    _professorController = TextEditingController();
    _courseCodeController = TextEditingController();
    _classTypeController = TextEditingController();
    _sectionController = TextEditingController();
    _classLocationController = TextEditingController();

    _workRoleController = TextEditingController();
    _workOrgController = TextEditingController();
    _workDeptController = TextEditingController();
    _workContextTypeController = TextEditingController();
    _workModeController = TextEditingController();
    _workBlockKindController = TextEditingController();
    _workLocationController = TextEditingController();

    _mealSlotController = TextEditingController();
    _mealCategoryController = TextEditingController();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();

    _skinSlotController = TextEditingController();
    _skinStepsController = TextEditingController();
    _skinProductsController = TextEditingController();
    _skinMissingController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtasksController.dispose();
    _stepsController.dispose();
    _dishesController.dispose();

    _professorController.dispose();
    _courseCodeController.dispose();
    _classTypeController.dispose();
    _sectionController.dispose();
    _classLocationController.dispose();

    _workRoleController.dispose();
    _workOrgController.dispose();
    _workDeptController.dispose();
    _workContextTypeController.dispose();
    _workModeController.dispose();
    _workBlockKindController.dispose();
    _workLocationController.dispose();

    _mealSlotController.dispose();
    _mealCategoryController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();

    _skinSlotController.dispose();
    _skinStepsController.dispose();
    _skinProductsController.dispose();
    _skinMissingController.dispose();

    super.dispose();
  }

  void _syncControllersFromDraft() {
    _titleController.text = _draft.title;
    _notesController.text = _draft.notes;

    switch (_draft.type) {
      case AddRoutineType.flexible:
        _subtasksController.text = _draft.flexibleState.subtasks.join('\n');
        break;
      case AddRoutineType.habit:
        _subtasksController.text = _draft.habitState.subtasks.join('\n');
        _stepsController.text = _draft.habitState.steps.join('\n');
        break;
      case AddRoutineType.tracker:
        _subtasksController.text = _draft.trackerState.subtasks.join('\n');
        break;
      case AddRoutineType.fixed:
        _stepsController.text = _draft.fixedState.steps.join('\n');
        _dishesController.text = _draft.fixedState.dishes.join('\n');
        _professorController.text = _draft.fixedState.professor ?? '';
        _courseCodeController.text = _draft.fixedState.courseCode ?? '';
        _classTypeController.text = _draft.fixedState.classType ?? '';
        _sectionController.text = _draft.fixedState.sectionLabel ?? '';
        _classLocationController.text = _draft.fixedState.classLocation ?? '';

        _workRoleController.text = _draft.fixedState.workRole ?? '';
        _workOrgController.text = _draft.fixedState.workOrganization ?? '';
        _workDeptController.text =
            _draft.fixedState.workDepartmentOrProject ?? '';
        _workContextTypeController.text =
            _draft.fixedState.workContextType ?? '';
        _workModeController.text = _draft.fixedState.workMode ?? '';
        _workBlockKindController.text = _draft.fixedState.workBlockKind ?? '';
        _workLocationController.text = _draft.fixedState.workLocation ?? '';

        _mealSlotController.text = _draft.fixedState.mealSlot ?? '';
        _mealCategoryController.text = _draft.fixedState.mealCategory ?? '';
        _caloriesController.text = _draft.fixedState.caloriesEstimate != null
            ? _draft.fixedState.caloriesEstimate!.toStringAsFixed(0)
            : '';
        _proteinController.text = _draft.fixedState.proteinEstimate != null
            ? _draft.fixedState.proteinEstimate!.toStringAsFixed(0)
            : '';

        _skinSlotController.text = _draft.fixedState.skincareSlotLabel ?? '';
        _skinStepsController.text = _draft.fixedState.steps.join('\n');
        _skinProductsController.text =
            _draft.fixedState.skincareProducts.join('\n');
        _skinMissingController.text =
            _draft.fixedState.skincareMissingItems.join('\n');
        break;
      case AddRoutineType.checkin:
      case AddRoutineType.money:
        break;
    }
  }

  void _selectType(AddRoutineType type) {
    setState(() {
      _typeSelected = true;
      _draft = _draft.switchType(type);
      _syncControllersFromDraft();
      _error = null;
    });
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
                    Icons.add_circle,
                    size: 22,
                    color: OptivusColors.routineAccent,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Add to Routine',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!_typeSelected) _buildTypeGrid() else _buildForm(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final itemWidth = (availableWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AddRoutineType.values.map((type) {
            return GestureDetector(
              onTap: () => _selectType(type),
              child: Container(
                width: itemWidth.clamp(130.0, 400.0),
                constraints: const BoxConstraints(minHeight: 88),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: type.color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(type.icon, size: 26, color: type.color),
                    const SizedBox(height: 8),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: type.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildForm() {
    final type = _draft.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _saveFailed ? null : () => setState(() => _typeSelected = false),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
        ),
        AbsorbPointer(
          absorbing: _saveFailed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              _textField(
                controller: _titleController,
                label: 'Title',
                hint: _hintForType(type),
                onChanged: (val) => _draft = _draft.copyWith(title: val),
              ),
              const SizedBox(height: 12),
              _buildScheduleModeSelector(),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_draft.scheduleMode == AddRoutineScheduleMode.once) ...[
                    Expanded(child: _dateTile()),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: _timeTile()),
                ],
              ),
              if (_draft.scheduleMode == AddRoutineScheduleMode.weekly) ...[
                const SizedBox(height: 12),
                _repeatSelector(),
              ],
              const SizedBox(height: 10),
              _durationTile(),
              const SizedBox(height: 12),
              if (type == AddRoutineType.fixed) _fixedBlockFields(),
              if (type == AddRoutineType.tracker) _trackerFields(),
              if (type == AddRoutineType.checkin) _checkInFields(),
              if (type == AddRoutineType.money) _moneyFields(),
              if (type == AddRoutineType.habit) _habitFields(),
              if (type == AddRoutineType.flexible) _flexibleFields(),
              const SizedBox(height: 12),
              _textField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Optional notes',
                maxLines: 3,
                onChanged: (val) => _draft = _draft.copyWith(notes: val),
              ),
              if (type == AddRoutineType.flexible ||
                  type == AddRoutineType.tracker ||
                  type == AddRoutineType.habit) ...[
                const SizedBox(height: 12),
                _textField(
                  controller: _subtasksController,
                  label: 'Subtasks',
                  hint: 'One subtask per line',
                  maxLines: 4,
                  onChanged: (val) {
                    final lines = _lines(val);
                    if (type == AddRoutineType.flexible) {
                      _draft = _draft.copyWith(
                        flexibleState:
                            _draft.flexibleState.copyWith(subtasks: lines),
                      );
                    } else if (type == AddRoutineType.habit) {
                      _draft = _draft.copyWith(
                        habitState: _draft.habitState.copyWith(subtasks: lines),
                      );
                    } else if (type == AddRoutineType.tracker) {
                      _draft = _draft.copyWith(
                        trackerState:
                            _draft.trackerState.copyWith(subtasks: lines),
                      );
                    }
                  },
                ),
              ],
              if (type == AddRoutineType.habit) ...[
                const SizedBox(height: 12),
                _textField(
                  controller: _stepsController,
                  label: 'Steps',
                  hint: 'One step per line',
                  maxLines: 4,
                  onChanged: (val) {
                    final lines = _lines(val);
                    _draft = _draft.copyWith(
                      habitState: _draft.habitState.copyWith(steps: lines),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (_saveFailed) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('add-routine-failed-warning'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OptivusColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: OptivusColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: OptivusColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ??
                        'Save failed. Form fields are read-only to prevent saving stale data. Retry or discard to continue.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_error != null) ...[
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
        if (_saveFailed) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('add-routine-discard-button'),
                  onPressed: _saving ? null : _discardFailedCreate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OptivusColors.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.danger,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('add-routine-retry-button'),
                  onPressed: _saving ? null : _retryFailedOperation,
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
                      : const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _findFreeSlot,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OptivusColors.routineAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Find free slot',
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
                      : const Text(
                          'Save at this time',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScheduleModeButton(
              label: 'One time',
              isSelected:
                  _draft.scheduleMode == AddRoutineScheduleMode.once,
              onTap: () {
                setState(() {
                  _draft = _draft.copyWith(
                    scheduleMode: AddRoutineScheduleMode.once,
                    repeatDays: const [],
                  );
                  _error = null;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ScheduleModeButton(
              label: 'Weekly',
              isSelected:
                  _draft.scheduleMode == AddRoutineScheduleMode.weekly,
              onTap: () {
                setState(() {
                  // Default to today's weekday if empty
                  final defaultDay = _draft.date.weekday;
                  _draft = _draft.copyWith(
                    scheduleMode: AddRoutineScheduleMode.weekly,
                    repeatDays: _draft.repeatDays.isEmpty
                        ? [defaultDay]
                        : _draft.repeatDays,
                  );
                  _error = null;
                });
              },
            ),
          ),
        ],
      ),
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
                value: _draft.priority,
                values: RoutinePriority.values,
                labelFor: (value) =>
                    value == RoutinePriority.mustDo ? 'Must do' : 'Good to do',
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(priority: value),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stringTile(
                label: 'Best time',
                value: _draft.bestTime ?? 'Morning',
                values: const [
                  'Morning',
                  'Afternoon',
                  'Evening',
                  'Night',
                  'Anytime',
                ],
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(bestTime: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _enumTile<RoutineCategory>(
          label: 'Category',
          value: _draft.flexibleState.category,
          values: const [
            RoutineCategory.habit,
            RoutineCategory.identity,
            RoutineCategory.health,
            RoutineCategory.focus,
            RoutineCategory.meditation,
            RoutineCategory.hydration,
          ],
          labelFor: (value) => value.name,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              flexibleState: _draft.flexibleState.copyWith(category: value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _habitFields() {
    final habitState = _draft.habitState;
    return Column(
      children: [
        _enumTile<RoutineCategory>(
          label: 'Category',
          value: habitState.category,
          values: const [
            RoutineCategory.habit,
            RoutineCategory.identity,
            RoutineCategory.health,
            RoutineCategory.focus,
            RoutineCategory.meditation,
            RoutineCategory.hydration,
          ],
          labelFor: (value) => value.name,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              habitState: habitState.copyWith(category: value),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _enumTile<RoutinePriority>(
                label: 'Priority',
                value: _draft.priority,
                values: RoutinePriority.values,
                labelFor: (value) =>
                    value == RoutinePriority.mustDo ? 'Must do' : 'Good to do',
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(priority: value),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stringTile(
                label: 'Best time',
                value: _draft.bestTime ?? 'Morning',
                values: const [
                  'Morning',
                  'Afternoon',
                  'Evening',
                  'Night',
                  'Anytime',
                ],
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(bestTime: value),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _enumTile<TrackerType>(
          label: 'Tracker linked',
          value: habitState.trackerType,
          values: const [
            TrackerType.none,
            TrackerType.meditation,
            TrackerType.focus,
            TrackerType.workout,
            TrackerType.hydration,
          ],
          labelFor: (value) => value == TrackerType.none ? 'No' : value.name,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              habitState: habitState.copyWith(trackerType: value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fixedBlockFields() {
    final fixed = _draft.fixedState;
    return Column(
      children: [
        _stringTile(
          label: 'Type',
          value: fixed.kind,
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
            final isHard =
                value == 'Class' ||
                value == 'Job' ||
                value == 'Sleep' ||
                value == 'Travel';
            setState(() {
              _draft = _draft.copyWith(
                fixedState: fixed.copyWith(kind: value, hardBlock: isHard),
              );
              _syncControllersForFixedKind(value);
            });
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          value: fixed.hardBlock,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              fixedState: fixed.copyWith(hardBlock: value),
            ),
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeTrackColor: OptivusColors.blockHard,
          title: const Text(
            'Hard block',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        if (fixed.kind == 'Class' ||
            fixed.kind == 'Job' ||
            fixed.kind == 'Eating' ||
            fixed.kind == 'Skin Care') ...[
          const SizedBox(height: 6),
          _buildMoreDetailsSection(fixed.kind),
        ],
      ],
    );
  }

  void _syncControllersForFixedKind(String newKind) {
    if (newKind != 'Class') {
      _courseCodeController.clear();
      _professorController.clear();
      _classTypeController.clear();
      _sectionController.clear();
      _classLocationController.clear();
    }
    if (newKind != 'Job' && newKind != 'Work') {
      _workRoleController.clear();
      _workOrgController.clear();
      _workDeptController.clear();
      _workContextTypeController.clear();
      _workModeController.clear();
      _workBlockKindController.clear();
      _workLocationController.clear();
    }
    if (newKind != 'Eating' && newKind != 'Meal') {
      _mealSlotController.clear();
      _mealCategoryController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _dishesController.clear();
    }
    if (newKind != 'Skin Care' && newKind != 'Skincare') {
      _skinSlotController.clear();
      _skinStepsController.clear();
      _skinProductsController.clear();
      _skinMissingController.clear();
    }
  }

  Widget _buildMoreDetailsSection(String kind) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showMoreDetails = !_showMoreDetails),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _showMoreDetails
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: OptivusColors.routineAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  _showMoreDetails
                      ? 'Hide $kind details'
                      : 'More $kind details (optional)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.routineAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showMoreDetails) ...[
          const SizedBox(height: 8),
          if (kind == 'Class') ...[
            _textField(
              controller: _courseCodeController,
              label: 'Course code',
              hint: 'e.g. CS101',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(courseCode: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _professorController,
              label: 'Professor / Instructor',
              hint: 'e.g. Dr. Alan Turing',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(professor: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _classTypeController,
              label: 'Class type',
              hint: 'e.g. Lecture, Lab, Seminar',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(classType: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _sectionController,
              label: 'Section',
              hint: 'e.g. Sec 01',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(sectionLabel: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _classLocationController,
              label: 'Class location',
              hint: 'e.g. Hall B / Zoom link',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(classLocation: val),
              ),
            ),
          ] else if (kind == 'Job') ...[
            _textField(
              controller: _workRoleController,
              label: 'Role',
              hint: 'e.g. Software Engineer',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(workRole: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _workOrgController,
              label: 'Organization / Company',
              hint: 'e.g. Acme Corp',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(workOrganization: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _workDeptController,
              label: 'Department / Project',
              hint: 'e.g. Core Infrastructure',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState:
                    _draft.fixedState.copyWith(workDepartmentOrProject: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _workContextTypeController,
              label: 'Context type',
              hint: 'e.g. Deep work, Meeting, Admin',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(workContextType: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _workModeController,
              label: 'Work mode',
              hint: 'e.g. Remote, On-site, Hybrid',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(workMode: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _workBlockKindController,
              label: 'Work block kind',
              hint: 'e.g. Focus time, Sync',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(workBlockKind: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _workLocationController,
              label: 'Work location',
              hint: 'e.g. Office 4F / Remote',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(workLocation: val),
              ),
            ),
          ] else if (kind == 'Eating') ...[
            _textField(
              controller: _mealSlotController,
              label: 'Meal slot',
              hint: 'e.g. Breakfast, Lunch, Dinner',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(mealSlot: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _mealCategoryController,
              label: 'Category',
              hint: 'e.g. Home cooked, Restaurant',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(mealCategory: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _caloriesController,
              label: 'Estimated calories (kcal)',
              hint: 'e.g. 600',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(
                  caloriesEstimate: double.tryParse(val.trim()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _proteinController,
              label: 'Estimated protein (g)',
              hint: 'e.g. 35',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(
                  proteinEstimate: double.tryParse(val.trim()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _dishesController,
              label: 'Dishes / Foods (one per line)',
              hint: 'e.g. Oatmeal\nBanana\nWhey protein',
              maxLines: 3,
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(dishes: _lines(val)),
              ),
            ),
          ] else if (kind == 'Skin Care') ...[
            _textField(
              controller: _skinSlotController,
              label: 'Slot label',
              hint: 'e.g. Morning Routine, Night Routine',
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(skincareSlotLabel: val),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _skinStepsController,
              label: 'Steps (one per line)',
              hint: 'e.g. Cleanser\nToner\nMoisturizer',
              maxLines: 3,
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(steps: _lines(val)),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _skinProductsController,
              label: 'Products (one per line)',
              hint: 'e.g. CeraVe Cleanser\nSunscreen SPF 50',
              maxLines: 3,
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState:
                    _draft.fixedState.copyWith(skincareProducts: _lines(val)),
              ),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: _skinMissingController,
              label: 'Missing items (one per line)',
              hint: 'e.g. Retinol serum',
              maxLines: 2,
              onChanged: (val) => _draft = _draft.copyWith(
                fixedState: _draft.fixedState.copyWith(
                  skincareMissingItems: _lines(val),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _trackerFields() {
    return _enumTile<TrackerType>(
      label: 'Tracker task',
      value: _draft.trackerState.trackerType,
      values: const [
        TrackerType.meditation,
        TrackerType.focus,
        TrackerType.workout,
        TrackerType.hydration,
      ],
      labelFor: (value) => value.name,
      onChanged: (value) {
        setState(() {
          _draft = _draft.copyWith(
            trackerState: _draft.trackerState.copyWith(trackerType: value),
          );
        });
      },
    );
  }

  Widget _checkInFields() {
    const options = ['Smoking', 'Alcohol', 'Junk food'];
    final currentChoice = options.contains(_draft.checkInState.checkInType)
        ? _draft.checkInState.checkInType
        : options.first;

    return _stringTile(
      label: 'Bad habit check-in',
      value: currentChoice,
      values: options,
      onChanged: (value) {
        setState(() {
          _draft = _draft.copyWith(
            title: value,
            checkInState: _draft.checkInState.copyWith(checkInType: value),
          );
          _titleController.text = value;
        });
      },
    );
  }

  Widget _moneyFields() {
    return const _InfoBox(
      text:
          'This creates a Routine money task. Start opens the authorized Tracker Money System.',
    );
  }

  Widget _repeatSelector() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat weekdays',
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
            final selected = _draft.repeatDays.contains(day);
            return GestureDetector(
              onTap: () {
                setState(() {
                  final updatedDays = List<int>.from(_draft.repeatDays);
                  if (selected) {
                    updatedDays.remove(day);
                  } else {
                    updatedDays.add(day);
                  }
                  updatedDays.sort();
                  _draft = _draft.copyWith(repeatDays: updatedDays);
                  _error = null;
                });
              },
              child: Container(
                width: 36,
                height: 36,
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
          '${TimelineUtils.getShortDayName(_draft.date.weekday)} ${_draft.date.day}/${_draft.date.month}',
      icon: Icons.calendar_today_rounded,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _draft.date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() {
            _draft = _draft.copyWith(date: picked);
          });
        }
      },
    );
  }

  Widget _timeTile() {
    return _PickerTile(
      label: 'Start time',
      value: _draft.startTime.format(context),
      icon: Icons.schedule_rounded,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _draft.startTime,
        );
        if (picked != null) {
          setState(() {
            _draft = _draft.copyWith(startTime: picked);
          });
        }
      },
    );
  }

  Widget _durationTile() {
    return _PickerTile(
      label: 'Duration',
      value: TimelineUtils.formatDuration(_draft.durationMinutes),
      icon: Icons.timelapse_rounded,
      onTap: _showDurationPicker,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => setState(() {
              final newDur = (_draft.durationMinutes - 5)
                  .clamp(1, 24 * 60)
                  .toInt();
              _draft = _draft.copyWith(durationMinutes: newDur);
            }),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: OptivusColors.textSecondary,
          ),
          IconButton(
            onPressed: () => setState(() {
              final newDur = (_draft.durationMinutes + 5)
                  .clamp(1, 24 * 60)
                  .toInt();
              _draft = _draft.copyWith(durationMinutes: newDur);
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
                        final isSelected = _draft.durationMinutes == mins;
                        return ActionChip(
                          label: Text(
                            TimelineUtils.formatDuration(mins),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? OptivusColors.routineAccent
                                  : OptivusColors.textPrimary,
                            ),
                          ),
                          backgroundColor: isSelected
                              ? OptivusColors.routineAccent.withValues(
                                  alpha: 0.15,
                                )
                              : Colors.grey.shade100,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onPressed: () {
                            setState(() {
                              _draft = _draft.copyWith(durationMinutes: mins);
                            });
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
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    final isReadOnly = readOnly || _saveFailed;
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      maxLines: maxLines,
      onChanged: isReadOnly ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isReadOnly
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.6),
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

  void _findFreeSlot() {
    if (_saving) return;
    final isSleep =
        _draft.type == AddRoutineType.fixed && _draft.fixedState.kind == 'Sleep';
    if (isSleep) {
      setState(
        () => _error =
            'Sleep blocks are typically scheduled during overnight rest hours outside the daytime planning window. Please choose your sleep hours manually.',
      );
      return;
    }
    final itemCandidate = AddRoutineMapper.toRoutineItem(_draft);
    final slot = _draft.scheduleMode == AddRoutineScheduleMode.weekly &&
            _draft.repeatDays.isNotEmpty
        ? ref.read(routineNotifierProvider.notifier).findWeeklyFreeSlot(
              item: itemCandidate,
              repeatDays: _draft.repeatDays,
              baseDate: _draft.date,
              durationMinutes: _draft.durationMinutes,
            )
        : ref.read(routineNotifierProvider.notifier).findFreeSlot(
              item: itemCandidate,
              date: _draft.date,
              durationMinutes: _draft.durationMinutes,
            );
    if (slot == null) {
      setState(
        () => _error = _draft.scheduleMode == AddRoutineScheduleMode.weekly &&
                _draft.repeatDays.isNotEmpty
            ? 'No common free slot was found across your selected weekdays. You can still choose a time manually.'
            : 'No open slot found. You can still choose any time manually.',
      );
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        startTime: TimeOfDay(hour: slot ~/ 60, minute: slot % 60),
      );
      _error = null;
    });
  }

  Future<void> _discardFailedCreate() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(routineNotifierProvider.notifier)
        .discardFailedCreate(_draft.id);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveFailed = false;
      _error = null;
    });
    Navigator.of(context).pop();
  }

  Future<void> _retryFailedOperation() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(routineNotifierProvider.notifier)
        .retryFailedOperation(_draft.id);
    if (!mounted) return;
    if (result.outcome == RoutineWriteOutcome.saved ||
        result.outcome == RoutineWriteOutcome.noOp) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _saveFailed = true;
      _error = result.message ?? 'Retry failed. Please adjust the form or discard.';
    });
  }

  Future<void> _save() async {
    // ignore: avoid_print
    print('DEBUG: _save called! _saving=$_saving');
    if (_saving) return;

    if (_draft.type == AddRoutineType.fixed &&
        _draft.fixedState.kind == 'Eating') {
      final calStr = _caloriesController.text.trim();
      if (calStr.isNotEmpty && double.tryParse(calStr) == null) {
        setState(() => _error = 'Estimated calories must be a valid number.');
        return;
      }
      final protStr = _proteinController.text.trim();
      if (protStr.isNotEmpty && double.tryParse(protStr) == null) {
        setState(() => _error = 'Estimated protein must be a valid number.');
        return;
      }
    }

    // Ensure title controller text is current
    final currentDraft = _draft.copyWith(
      title: _titleController.text,
      notes: _notesController.text,
    );

    final validationError = AddRoutineValidator.validate(currentDraft);
    // ignore: avoid_print
    print('DEBUG _save: validationError=$validationError');
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    if (_saveFailed) {
      await ref
          .read(routineNotifierProvider.notifier)
          .discardFailedCreate(_draft.id);
    }

    final item = AddRoutineMapper.toRoutineItem(currentDraft);
    // ignore: avoid_print
    print('DEBUG _save: mapped item title=${item.title}, date=${item.date}, repeatRule=${item.repeatRule}');
    setState(() {
      _saving = true;
      _error = null;
    });

    final RoutineWriteResult result = await ref
        .read(routineNotifierProvider.notifier)
        .addItem(item);
    // ignore: avoid_print
    print('DEBUG _save: addItem result outcome=${result.outcome}, message=${result.message}, validation=${result.validation?.userSafeMessage}');

    if (!mounted) return;
    if (result.outcome == RoutineWriteOutcome.saved ||
        result.outcome == RoutineWriteOutcome.noOp) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = false;
      _saveFailed = true;
      _error =
          result.validation?.userSafeMessage ??
          result.message ??
          'Failed to save item. Please adjust the form and retry.';
    });
  }

  String _hintForType(AddRoutineType type) {
    return switch (type) {
      AddRoutineType.fixed => 'e.g., Class, Job, Sleep',
      AddRoutineType.habit => 'e.g., Reading, Journaling',
      AddRoutineType.tracker => 'e.g., Meditation, Workout',
      AddRoutineType.checkin => 'e.g., Smoking',
      AddRoutineType.money => 'e.g., Tiny money save',
      AddRoutineType.flexible => 'e.g., Morning Study',
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

class _ScheduleModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScheduleModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? OptivusColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : OptivusColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
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
                mainAxisAlignment: MainAxisAlignment.center,
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
      constraints: const BoxConstraints(minHeight: 48),
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
