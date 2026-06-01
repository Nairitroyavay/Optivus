// ignore_for_file: unused_field, unused_element, unused_local_variable, dead_code, dead_null_aware_expression
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

class BaseTimelineStep extends ConsumerStatefulWidget {
  const BaseTimelineStep({super.key});

  @override
  ConsumerState<BaseTimelineStep> createState() => _BaseTimelineStepState();
}

class _BaseTimelineStepState extends ConsumerState<BaseTimelineStep>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _mealCtrl = TextEditingController();
  final _fixedCtrl = TextEditingController();
  final _skinCtrl = TextEditingController();
  final _importTextCtrl = TextEditingController();

  int _day = 0;
  int _startHour = 9;
  int _startMinutePart = 0;
  int _endHour = 10;
  int _endMinutePart = 0;
  String _repeatMode = 'selected_day';
  Set<int> _customRepeatDays = {1};
  String _setupMode = 'Manual';
  String? _eatingMode;
  String? _businessMode;
  int? _workDurationMinutes;
  String? _workBestTime;
  String? _workPriority;
  bool _hardBlock = true;
  String? _editingItemId;

  static const _tabs = [
    'Classes',
    'Job / Work / Business',
    'Eating',
    'Fixed',
    'Skin Care',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          final tab = _tabs[_tabController.index];
          if (tab == 'Classes' || tab == 'Fixed') {
            _hardBlock = true;
          } else if (tab == 'Skin Care') {
            _hardBlock = false;
          } else if (tab == 'Job / Work / Business') {
            _hardBlock = _businessMode != 'flexible_business';
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timeline = ref.read(mockOnboardingProvider).draft.baseTimeline;
      final withDefaults = timeline.withRequiredFixedBlocks();
      if (withDefaults.blocks.length != timeline.blocks.length) {
        ref
            .read(mockOnboardingProvider.notifier)
            .updateDraft(
              (draft) => draft.copyWith(
                baseTimeline: withDefaults,
                clearFinalPreview: true,
              ),
            );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _mealCtrl.dispose();
    _fixedCtrl.dispose();
    _skinCtrl.dispose();
    _importTextCtrl.dispose();
    super.dispose();
  }

  bool _classesEnabled(String role) =>
      role == LifeRoleDraft.studentKey ||
      role == LifeRoleDraft.studentWorkingKey;

  bool _jobEnabled(String role) =>
      role == LifeRoleDraft.workingKey ||
      role == LifeRoleDraft.studentWorkingKey ||
      role == LifeRoleDraft.businessKey;

  bool _classesRequired(String role) => _classesEnabled(role);

  bool _jobRequired(String role) => _jobEnabled(role);

  bool _tabEnabledForIndex(int index, String role) {
    return switch (index) {
      0 => _classesEnabled(role),
      1 => _jobEnabled(role),
      _ => true,
    };
  }

  String _timeLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:00 ${hour >= 12 ? 'PM' : 'AM'}';
  }

  String _minuteLabel(int minute) {
    final clamped = minute.clamp(0, 24 * 60);
    if (clamped == 24 * 60) return '12:00 AM';
    final hour = clamped ~/ 60;
    final min = clamped % 60;
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${min.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  int _clampHour(num value, int min, int max) => value.clamp(min, max).toInt();

  List<int> _selectedRepeatDays() {
    return switch (_repeatMode) {
      'every_day' => const [1, 2, 3, 4, 5, 6, 7],
      'weekdays' => const [1, 2, 3, 4, 5],
      'custom' => (_customRepeatDays.toList()..sort()),
      _ => [_day + 1],
    };
  }

  void _syncRepeatModeFromDays(List<int> days) {
    final normalized = days.toSet();
    if (normalized.length == 7) {
      _repeatMode = 'every_day';
    } else if (normalized.length == 5 &&
        normalized.containsAll(const [1, 2, 3, 4, 5])) {
      _repeatMode = 'weekdays';
    } else if (normalized.length == 1) {
      _repeatMode = 'selected_day';
      _day = (normalized.first - 1).clamp(0, 6);
    } else {
      _repeatMode = 'custom';
      _customRepeatDays = normalized.isEmpty ? {_day + 1} : normalized;
    }
  }

  void _addRoutine(
    String type,
    TextEditingController controller,
    RoutineBlockType blockType,
  ) {
    final title = controller.text.trim();
    if (title.isEmpty) return;
    final startMinute = _startHour * 60 + _startMinutePart;
    final rawEndMinute = (_endHour * 60 + _endMinutePart).clamp(0, 24 * 60);
    final crossesMidnight = rawEndMinute < startMinute;
    final safeEndMinute = rawEndMinute == startMinute
        ? (startMinute + 60).clamp(1, 24 * 60)
        : rawEndMinute.clamp(0, 24 * 60);
    final mealEstimate = _mealEstimate(title);
    final id =
        _editingItemId ??
        'onboarding-$type-${DateTime.now().millisecondsSinceEpoch}';
    final block = TimelineBlockDraft(
      id: id,
      section: _sectionKey(type),
      title: title,
      startMinute: startMinute,
      endMinute: safeEndMinute,
      crossesMidnight: crossesMidnight,
      blockType: _draftBlockType(blockType),
      repeatDays: _selectedRepeatDays(),
      location: _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      mealCategory: type == 'Eating' ? title : null,
      calories: type == 'Eating' ? mealEstimate.$1 : null,
      protein: type == 'Eating' ? mealEstimate.$2 : null,
      skincareProducts: type == 'Skin Care' ? [title] : const [],
    );

    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: draft.baseTimeline.upsertBlock(block),
            clearFinalPreview: true,
          ),
        );

    setState(() {
      controller.clear();
      _locationCtrl.clear();
      _editingItemId = null;
      _endHour = _clampHour(safeEndMinute ~/ 60, 0, 24);
      _endMinutePart = safeEndMinute % 60;
    });
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }

  void _editItem(RoutineItem item) {
    final targetController = item.notes == 'Eating'
        ? _mealCtrl
        : item.notes == 'Fixed'
        ? _fixedCtrl
        : item.notes == 'Skin Care'
        ? _skinCtrl
        : _titleCtrl;

    setState(() {
      _editingItemId = item.id;
      targetController.text = item.title;
      _locationCtrl.text = item.location ?? '';
      _day = item.repeatDays.isEmpty
          ? 0
          : _clampHour(item.repeatDays.first - 1, 0, 6);
      _startHour = _clampHour(item.startMinute ~/ 60, 0, 23);
      _startMinutePart = item.startMinute % 60;
      _endHour = _clampHour(item.endMinute ~/ 60, 0, 24);
      _endMinutePart = item.endMinute % 60;
      _hardBlock = item.blockType == RoutineBlockType.hardBlock;
      _syncRepeatModeFromDays(item.repeatDays);
    });
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }

  void _copyToOtherDays(RoutineItem item) {
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: draft.baseTimeline.upsertBlock(
              _blockById(
                    item.id,
                    draft.baseTimeline.blocks,
                  )?.copyWith(repeatDays: const [1, 2, 3, 4, 5, 6, 7]) ??
                  _blockFromRoutine(
                    item,
                  ).copyWith(repeatDays: const [1, 2, 3, 4, 5, 6, 7]),
            ),
            clearFinalPreview: true,
          ),
        );
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final role = draft.lifeRole.lifeRole ?? '';
    _businessMode =
        draft.lifeRole.businessMode ?? draft.baseTimeline.businessMode;
    _workDurationMinutes = draft.baseTimeline.workDurationMinutes;
    _workBestTime = draft.baseTimeline.workBestTime;
    _workPriority = draft.baseTimeline.workPriority;
    _eatingMode = draft.baseTimeline.eatingMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingSectionTitle(
                title: 'Set Base Timeline',
                subtitle:
                    'Build the fixed anchors Optivus should schedule around.',
              ),
              const SizedBox(height: 12),
              _conflictResolver(),
              if (ref
                  .watch(mockOnboardingProvider)
                  .draft
                  .baseTimeline
                  .detectConflicts()
                  .isNotEmpty)
                const SizedBox(height: 12),
              OnboardingGlassCard(
                padding: const EdgeInsets.all(12),
                radius: 22,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _tabs.asMap().entries.map((e) {
                      final isSelected = _tabController.index == e.key;
                      final enabled = _tabEnabledForIndex(e.key, role);
                      return Padding(
                        padding: EdgeInsets.only(
                          right: e.key == _tabs.length - 1 ? 0 : 8,
                        ),
                        child: Opacity(
                          opacity: enabled ? 1 : 0.48,
                          child: OnboardingChip(
                            label: e.value,
                            selected: isSelected && enabled,
                            icon: enabled ? null : Icons.lock_rounded,
                            onTap: enabled
                                ? () => _tabController.animateTo(e.key)
                                : null,
                            accent: e.key == 0
                                ? OptivusColors.aquaAccent
                                : e.key == 1
                                ? OptivusColors.brandAccent
                                : e.key == 2
                                ? OptivusColors.brandAccent
                                : OptivusColors.aquaAccent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _section(
                enabled: _classesEnabled(role),
                requiredLabel: _classesRequired(role)
                    ? 'Required for your role'
                    : 'Disabled by current role',
                title: 'Classes',
                icon: Icons.school_rounded,
                accent: OptivusColors.aquaAccent,
                description: 'Set your fixed lecture and lab timings.',
                controller: _titleCtrl,
                controllerHint: 'Subject name, Lab, Lecture',
                addLabel: 'Add class',
                blockType: RoutineBlockType.hardBlock,
                filter: (item) => item.notes == 'Classes',
                chips: const [
                  'Subject name',
                  'Hard block',
                  'Soft block',
                  'Lecture',
                  'Lab',
                  'Practical',
                ],
              ),
              _section(
                enabled: _jobEnabled(role),
                requiredLabel: _jobRequired(role)
                    ? 'Required for your role'
                    : 'Disabled by current role',
                title: 'Job / Work / Business',
                icon: Icons.work_rounded,
                accent: OptivusColors.brandAccent,
                description:
                    'Set fixed shifts, flexible work windows, business duration, and best time.',
                controller: _titleCtrl,
                controllerHint: 'Office shift, client work, store hours',
                addLabel: 'Add work block',
                blockType: RoutineBlockType.hardBlock,
                filter: (item) => item.notes == 'Job / Work / Business',
                chips: const [
                  'Normal job schedule',
                  'Hard block',
                  'Soft block',
                  'Fixed',
                  'Flexible',
                  'Mixed',
                  'Priority',
                ],
                extra: role == LifeRoleDraft.businessKey
                    ? _businessModeSelector()
                    : null,
              ),
              _eatingSection(),
              _fixedSection(),
              _skinCareSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({
    required bool enabled,
    required String requiredLabel,
    required String title,
    required IconData icon,
    required Color accent,
    required String description,
    required TextEditingController controller,
    required String controllerHint,
    required String addLabel,
    required RoutineBlockType blockType,
    required bool Function(RoutineItem item) filter,
    required List<String> chips,
    Widget? extra,
  }) {
    final items = _draftRoutineItems().where(filter).toList();
    final sectionItems = items
        .where((item) => item.repeatDays.contains(_day + 1))
        .toList();

    return OnboardingScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _setupHeader(
            title,
            description,
            requiredLabel,
            icon,
            accent,
            enabled: enabled,
            itemCount: items.length,
          ),
          const SizedBox(height: 12),
          _dayChips(accent),
          const SizedBox(height: 12),
          _modeTabs(),
          const SizedBox(height: 12),
          _setupHeaderStrip('Set Your Weekly $title Schedule', accent),
          const SizedBox(height: 12),
          if (_setupMode != 'Manual') _importPreviewCard(),
          if (extra != null) ...[extra, const SizedBox(height: 12)],
          _routineSetupFrame(
            title: title == 'Classes'
                ? 'Your Fixed Classes'
                : 'Your Work / Business Anchors',
            subtitle: title == 'Classes'
                ? 'Stay on top of your semester with a clear timetable.'
                : 'Protect fixed shifts and flexible business windows.',
            items: sectionItems,
            accent: accent,
            emptyLabel: enabled
                ? 'Tap a glass plus row or use manual add below.'
                : 'This setup is disabled by your selected role.',
            onAddAtHour: enabled
                ? (hour) => setState(() {
                    _startHour = hour;
                    _endHour = _clampHour(hour + 1, 1, 24);
                  })
                : null,
          ),
          const SizedBox(height: 12),
          ...sectionItems.map((item) => _timelineItemCard(item, accent)),
          _manualAddCard(
            icon: icon,
            accent: accent,
            title: addLabel,
            hint: controllerHint,
            controller: controller,
            onAdd: enabled
                ? () => _addRoutine(
                    title,
                    controller,
                    _hardBlock
                        ? RoutineBlockType.hardBlock
                        : RoutineBlockType.softBlock,
                  )
                : null,
            chips: chips,
            location: title == 'Classes' || title == 'Job / Work / Business',
          ),
          const SizedBox(height: 12),
          _reviewCard(accent),
        ],
      ),
    );
  }

  List<RoutineItem> _draftRoutineItems() {
    final baseTimeline = ref.watch(mockOnboardingProvider).draft.baseTimeline;
    final conflicts = baseTimeline.detectConflicts();
    return baseTimeline.blocks.map((block) {
      final conflict = conflicts.where(
        (item) =>
            item.firstBlockId == block.id || item.secondBlockId == block.id,
      );
      final activeConflict = conflict.where((item) => !item.accepted);
      return _routineFromBlock(
        block,
        hasConflict: activeConflict.isNotEmpty,
        conflictMessage: activeConflict.isEmpty
            ? null
            : 'Real overlap with another timeline block.',
      );
    }).toList();
  }

  RoutineItem _routineFromBlock(
    TimelineBlockDraft block, {
    bool hasConflict = false,
    String? conflictMessage,
  }) {
    return RoutineItem(
      id: block.id,
      title: block.title,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      crossesMidnight: block.crossesMidnight,
      blockType: _routineBlockType(block.blockType),
      repeatDays: block.repeatDays,
      location: block.location,
      notes: _sectionLabel(block.section),
      mealCategory: block.mealCategory,
      dishes: block.dishes,
      caloriesEstimate: block.calories,
      proteinEstimate: block.protein,
      skincareProducts: block.skincareProducts,
      hasConflict: hasConflict,
      conflictMessage: conflictMessage,
    );
  }

  TimelineBlockDraft _blockFromRoutine(RoutineItem item) {
    return TimelineBlockDraft(
      id: item.id,
      section: _sectionKey(item.notes ?? 'Fixed'),
      title: item.title,
      startMinute: item.startMinute,
      endMinute: item.endMinute,
      crossesMidnight: item.crossesMidnight,
      repeatDays: item.repeatDays,
      location: item.location,
      blockType: _draftBlockType(item.blockType),
      mealCategory: item.mealCategory,
      dishes: item.dishes ?? const [],
      calories: item.caloriesEstimate,
      protein: item.proteinEstimate,
      skincareProducts: item.skincareProducts ?? const [],
    );
  }

  TimelineBlockDraft? _blockById(String id, List<TimelineBlockDraft> blocks) {
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  String _sectionKey(String label) {
    return switch (label) {
      'Classes' => 'classes',
      'Job / Work / Business' => 'job_work_business',
      'Eating' => 'eating',
      'Skin Care' => 'skin_care',
      _ => 'fixed',
    };
  }

  String _sectionLabel(String key) {
    return switch (key) {
      'classes' => 'Classes',
      'job_work_business' => 'Job / Work / Business',
      'eating' => 'Eating',
      'skin_care' => 'Skin Care',
      _ => 'Fixed',
    };
  }

  String _draftBlockType(RoutineBlockType type) {
    return switch (type) {
      RoutineBlockType.hardBlock => TimelineBlockDraft.hardBlockKey,
      RoutineBlockType.softBlock => TimelineBlockDraft.softBlockKey,
      RoutineBlockType.flexibleTask => TimelineBlockDraft.flexibleTaskKey,
      RoutineBlockType.checkIn => TimelineBlockDraft.checkInKey,
      _ => TimelineBlockDraft.flexibleTaskKey,
    };
  }

  RoutineBlockType _routineBlockType(String type) {
    return switch (type) {
      TimelineBlockDraft.hardBlockKey => RoutineBlockType.hardBlock,
      TimelineBlockDraft.softBlockKey => RoutineBlockType.softBlock,
      TimelineBlockDraft.checkInKey => RoutineBlockType.checkIn,
      _ => RoutineBlockType.flexibleTask,
    };
  }

  (double?, double?) _mealEstimate(String title) {
    final body = ref.read(mockOnboardingProvider).draft.bodyBasics;
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final dailyCalories = body.calorieEstimate ?? 0;
    final dailyProtein = body.proteinEstimate ?? 0;
    if (dailyCalories <= 0 || dailyProtein <= 0) return (null, null);

    final mealsPerDay = (base.mealsPerDay ?? 3).clamp(1, 6);
    final lower = title.toLowerCase();
    final calorieWeight = lower.contains('breakfast')
        ? 0.25
        : lower.contains('lunch')
        ? 0.35
        : lower.contains('dinner')
        ? 0.30
        : 1 / mealsPerDay;
    final proteinWeight = lower.contains('snack') ? 0.10 : calorieWeight;
    return (
      double.parse((dailyCalories * calorieWeight).toStringAsFixed(0)),
      double.parse((dailyProtein * proteinWeight).toStringAsFixed(0)),
    );
  }

  Widget _setupHeader(
    String title,
    String description,
    String requiredLabel,
    IconData icon,
    Color accent, {
    bool enabled = true,
    int itemCount = 0,
  }) {
    return OnboardingGlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OptivusColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                _SectionStatusRail(
                  accent: accent,
                  enabled: enabled,
                  status: requiredLabel,
                  count: itemCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayChips(Color accent) {
    return OnboardingGlassCard(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(
            _days.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index == _days.length - 1 ? 0 : 6,
              ),
              child: OnboardingDayDroplet(
                label: _days[index].toUpperCase(),
                selected: _day == index,
                color: accent,
                onTap: () => setState(() => _day = index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setupHeaderStrip(String label, Color accent) {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children:
                    [accent, OptivusColors.aquaAccent, const Color(0xFFFF88C9)]
                        .map(
                          (color) => Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    color.withValues(alpha: 0.10),
                                    color.withValues(alpha: 0.32),
                                    color.withValues(alpha: 0.10),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTabs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OnboardingChip(
          label: 'Manual add',
          selected: _setupMode == 'Manual',
          icon: Icons.edit_calendar_rounded,
          onTap: () => setState(() => _setupMode = 'Manual'),
        ),
        OnboardingChip(
          label: 'AI Text import preview',
          selected: _setupMode == 'AI Text',
          icon: Icons.text_fields_rounded,
          onTap: () {
            setState(() => _setupMode = 'AI Text');
            _savePendingImportChoice('AI Text');
          },
          accent: OptivusColors.aquaAccent,
        ),
        OnboardingChip(
          label: 'Photo Upload preview',
          selected: _setupMode == 'Photo Upload',
          icon: Icons.document_scanner_rounded,
          onTap: () {
            setState(() => _setupMode = 'Photo Upload');
            _savePendingImportChoice('Photo Upload');
          },
          accent: const Color(0xFFFF88C9),
        ),
      ],
    );
  }

  void _savePendingImportChoice(String mode) {
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: draft.baseTimeline.addPendingImport(
              _tabs[_tabController.index],
              mode,
            ),
          ),
        );
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }

  Widget _importPreviewCard() {
    final currentImport = _currentPendingImport();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OnboardingGlassCard(
        tint: OptivusColors.aquaAccent.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_fix_high_rounded,
                  color: OptivusColors.aquaAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _setupMode == 'AI Text'
                        ? 'Paste text for a local stub parse. No AI or backend call runs.'
                        : 'Pending upload object created. No photo picker, upload, or backend call runs.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (_setupMode == 'AI Text') ...[
              const SizedBox(height: 12),
              _glassTextField(
                controller: _importTextCtrl,
                hint: 'Paste timetable/menu/routine text',
                enabled: true,
              ),
              const SizedBox(height: 12),
              OnboardingActionPill(
                label: 'Parse for review',
                icon: Icons.rule_rounded,
                accent: OptivusColors.aquaAccent,
                selected: true,
                compact: true,
                onTap: _parseCurrentImportText,
              ),
            ],
            if (currentImport != null &&
                currentImport.parsedBlocks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Review parsed blocks',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...currentImport.parsedBlocks.map(
                (block) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_days[_clampHour((block.repeatDays.isEmpty ? 1 : block.repeatDays.first) - 1, 0, 6)]}: ${_minuteLabel(block.startMinute)} - ${_minuteLabel(block.endMinute)} ${block.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: OptivusColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              OnboardingActionPill(
                label: 'Apply reviewed blocks',
                icon: Icons.check_rounded,
                accent: OptivusColors.success,
                selected: true,
                compact: true,
                onTap: () => _applyCurrentImport(currentImport.id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PendingFutureImportDraft? _currentPendingImport() {
    final section = _tabs[_tabController.index];
    final imports = ref
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .pendingFutureImports;
    for (final entry in imports.reversed) {
      if (entry.section == section && entry.mode == _setupMode) {
        return entry;
      }
    }
    return null;
  }

  void _parseCurrentImportText() {
    final text = _importTextCtrl.text.trim();
    if (text.isEmpty) return;
    final section = _tabs[_tabController.index];
    final importId =
        '${section.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_ai_text';
    final title = text.split('\n').first.trim();
    final block = TimelineBlockDraft(
      id: 'import-$importId-${DateTime.now().millisecondsSinceEpoch}',
      section: _sectionKey(section),
      title: title.isEmpty ? '$section import' : title,
      startMinute: _startHour * 60 + _startMinutePart,
      endMinute: (_endHour * 60 + _endMinutePart).clamp(0, 24 * 60),
      crossesMidnight:
          (_endHour * 60 + _endMinutePart) <
          (_startHour * 60 + _startMinutePart),
      repeatDays: _selectedRepeatDays(),
      location: _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      blockType: section == 'Classes' || section == 'Job / Work / Business'
          ? TimelineBlockDraft.hardBlockKey
          : TimelineBlockDraft.softBlockKey,
      source: 'ai_import',
    );
    final entry = PendingFutureImportDraft(
      id: importId,
      section: section,
      mode: 'AI Text',
      createdAt: _currentPendingImport()?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      status: PendingFutureImportDraft.needsReviewStatus,
      pastedText: text,
      parsedBlocks: [block],
    );
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: draft.baseTimeline.upsertPendingImport(entry),
            clearFinalPreview: true,
          ),
        );
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }

  void _applyCurrentImport(String importId) {
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: draft.baseTimeline.applyPendingImport(importId),
            clearFinalPreview: true,
          ),
        );
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }

  Widget _businessModeSelector() {
    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business mode',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                      _TimelineOption('fixed_business', 'Fixed'),
                      _TimelineOption('flexible_business', 'Flexible'),
                      _TimelineOption('mixed_business', 'Mixed'),
                    ]
                    .map(
                      (mode) => OnboardingChip(
                        label: mode.label,
                        selected: _businessMode == mode.key,
                        onTap: () {
                          setState(() => _businessMode = mode.key);
                          ref
                              .read(mockOnboardingProvider.notifier)
                              .updateDraft(
                                (draft) => draft.copyWith(
                                  lifeRole: draft.lifeRole.copyWith(
                                    businessMode: mode.key,
                                  ),
                                  baseTimeline: draft.baseTimeline.copyWith(
                                    businessMode: mode.key,
                                  ),
                                  clearFinalPreview: true,
                                ),
                              );
                          ref
                              .read(mockOnboardingProvider.notifier)
                              .setStepDirty(4, true);
                        },
                      ),
                    )
                    .toList(),
          ),
          if (_businessMode != 'fixed_business' && _businessMode != null) ...[
            if (_businessMode == 'flexible_business') ...[
              const SizedBox(height: 12),
              const Text(
                'Flexible business mode stores duration, best time, and priority locally.',
                style: TextStyle(
                  fontSize: 11,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Duration',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                        _TimelineOption('30', '30 min'),
                        _TimelineOption('60', '1 hour'),
                        _TimelineOption('120', '2 hours'),
                        _TimelineOption('180', '3 hours'),
                      ]
                      .map(
                        (duration) => OnboardingChip(
                          label: duration.label,
                          selected:
                              _workDurationMinutes?.toString() == duration.key,
                          onTap: () {
                            final minutes = int.tryParse(duration.key);
                            setState(() => _workDurationMinutes = minutes);
                            ref
                                .read(mockOnboardingProvider.notifier)
                                .updateDraft(
                                  (draft) => draft.copyWith(
                                    baseTimeline: draft.baseTimeline.copyWith(
                                      workDurationMinutes: minutes,
                                    ),
                                    clearFinalPreview: true,
                                  ),
                                );
                            ref
                                .read(mockOnboardingProvider.notifier)
                                .setStepDirty(4, true);
                          },
                          accent: OptivusColors.brandAccent,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Best time',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                        _TimelineOption('morning', 'Morning'),
                        _TimelineOption('afternoon', 'Afternoon'),
                        _TimelineOption('evening', 'Evening'),
                        _TimelineOption('night', 'Night'),
                      ]
                      .map(
                        (time) => OnboardingChip(
                          label: time.label,
                          selected: _workBestTime == time.key,
                          onTap: () {
                            setState(() => _workBestTime = time.key);
                            ref
                                .read(mockOnboardingProvider.notifier)
                                .updateDraft(
                                  (draft) => draft.copyWith(
                                    baseTimeline: draft.baseTimeline.copyWith(
                                      workBestTime: time.key,
                                    ),
                                    clearFinalPreview: true,
                                  ),
                                );
                            ref
                                .read(mockOnboardingProvider.notifier)
                                .setStepDirty(4, true);
                          },
                          accent: OptivusColors.aquaAccent,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Priority',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                        _TimelineOption('low', 'Low'),
                        _TimelineOption('medium', 'Medium'),
                        _TimelineOption('high', 'High'),
                      ]
                      .map(
                        (priority) => OnboardingChip(
                          label: priority.label,
                          selected: _workPriority == priority.key,
                          onTap: () {
                            setState(() => _workPriority = priority.key);
                            ref
                                .read(mockOnboardingProvider.notifier)
                                .updateDraft(
                                  (draft) => draft.copyWith(
                                    baseTimeline: draft.baseTimeline.copyWith(
                                      workPriority: priority.key,
                                    ),
                                    clearFinalPreview: true,
                                  ),
                                );
                            ref
                                .read(mockOnboardingProvider.notifier)
                                .setStepDirty(4, true);
                          },
                          accent: OptivusColors.brandAccent,
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _presetActionGrid({
    required Color accent,
    required List<(String, IconData)> items,
    required ValueChanged<String> onSelect,
  }) {
    return OnboardingGlassCard(
      padding: const EdgeInsets.all(14),
      tint: accent.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick setup presets',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => OnboardingActionPill(
                    label: item.$1,
                    icon: item.$2,
                    accent: accent,
                    compact: true,
                    onTap: () => onSelect(item.$1),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _manualAddCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String hint,
    required TextEditingController controller,
    required VoidCallback? onAdd,
    required List<String> chips,
    bool location = false,
  }) {
    final isEditing = _editingItemId != null;

    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _glassTextField(
            controller: controller,
            hint: hint,
            enabled: onAdd != null,
          ),
          if (location) ...[
            const SizedBox(height: 10),
            _glassTextField(
              controller: _locationCtrl,
              hint: 'Location optional',
              enabled: onAdd != null,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _glassTimeField(
                  'Start',
                  _startHour,
                  _startMinutePart,
                  (v) => setState(() => _startHour = v),
                  (v) => setState(() => _startMinutePart = v),
                  accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _glassTimeField(
                  'End',
                  _endHour,
                  _endMinutePart,
                  (v) => setState(() => _endHour = v),
                  (v) => setState(() => _endMinutePart = v),
                  accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _repeatControls(accent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips.map((chip) {
              final isHardChip = chip == 'Hard block';
              final isSoftChip = chip == 'Soft block';
              final selected = isHardChip
                  ? _hardBlock
                  : isSoftChip
                  ? !_hardBlock
                  : chip == 'Fixed' ||
                        chip == 'Subject name' ||
                        chip == 'Home meal-time' ||
                        chip == 'Morning routine';
              return OnboardingChip(
                label: chip,
                selected: selected,
                onTap: isHardChip || isSoftChip
                    ? () => setState(() => _hardBlock = isHardChip)
                    : null,
                accent: isSoftChip
                    ? OptivusColors.aquaAccent
                    : OptivusColors.brandAccent,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: OnboardingActionPill(
              label: isEditing ? 'Update day block' : 'Add / update day block',
              icon: isEditing ? Icons.check_rounded : Icons.add_rounded,
              accent: accent,
              selected: true,
              onTap: onAdd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassTextField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.46,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.6),
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: OptivusColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: OptivusColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassTimeField(
    String label,
    int hour,
    int minute,
    ValueChanged<int> onHourChanged,
    ValueChanged<int> onMinuteChanged,
    Color accent,
  ) {
    void step(int delta) {
      final lower = 0;
      final upper = label == 'End' ? 24 : 23;
      onHourChanged(_clampHour(hour + delta, lower, upper));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: Column(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: OptivusColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _tinyStepButton(Icons.remove_rounded, () => step(-1), accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _minuteLabel(_clampHour(hour, 0, 24) * 60 + minute),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OptivusColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _tinyStepButton(Icons.add_rounded, () => step(1), accent),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 5,
                children: const [0, 15, 30, 45]
                    .map(
                      (value) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onMinuteChanged(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: minute == value
                                ? accent.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                          child: Text(
                            ':${value.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: minute == value
                                  ? accent
                                  : OptivusColors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _repeatControls(Color accent) {
    final options = const [
      _TimelineOption('selected_day', 'Selected day'),
      _TimelineOption('every_day', 'Every day'),
      _TimelineOption('weekdays', 'Weekdays'),
      _TimelineOption('custom', 'Custom days'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => OnboardingChip(
                  label: option.label,
                  selected: _repeatMode == option.key,
                  accent: accent,
                  onTap: () {
                    setState(() {
                      _repeatMode = option.key;
                      if (_repeatMode == 'custom' &&
                          _customRepeatDays.isEmpty) {
                        _customRepeatDays = {_day + 1};
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
        if (_repeatMode == 'custom') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_days.length, (index) {
              final day = index + 1;
              final selected = _customRepeatDays.contains(day);
              return OnboardingDayDroplet(
                label: _days[index].toUpperCase(),
                selected: selected,
                color: accent,
                onTap: () {
                  setState(() {
                    final next = Set<int>.from(_customRepeatDays);
                    selected ? next.remove(day) : next.add(day);
                    _customRepeatDays = next.isEmpty ? {day} : next;
                  });
                },
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _tinyStepButton(IconData icon, VoidCallback onTap, Color accent) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
        ),
        child: Icon(icon, size: 15, color: accent),
      ),
    );
  }

  Widget _routineSetupFrame({
    required String title,
    required String subtitle,
    required List<RoutineItem> items,
    required Color accent,
    required String emptyLabel,
    ValueChanged<int>? onAddAtHour,
  }) {
    const hourHeight = 42.0;
    const leftOffset = 58.0;
    final visible = [...items]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return OnboardingGlassCard(
      padding: EdgeInsets.zero,
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: OptivusColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: OptivusColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            height: 360,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0, 0.06, 0.92, 1],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 20, 12, 32),
                    child: SizedBox(
                      height: 24 * hourHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 48,
                            width: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  width: 1.1,
                                ),
                              ),
                            ),
                          ),
                          ...List.generate(24, (index) {
                            final hour = index;
                            if (hour % 3 != 0) return const SizedBox.shrink();
                            return Positioned(
                              top: index * hourHeight - 8,
                              left: 0,
                              width: 44,
                              child: Text(
                                _timeLabel(hour),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: OptivusColors.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            );
                          }),
                          if (visible.isEmpty)
                            Positioned(
                              left: leftOffset,
                              right: 0,
                              top: 7.5 * hourHeight,
                              child: _emptyTimelinePill(emptyLabel, accent),
                            )
                          else
                            ...visible.map(
                              (item) => _timelineBlock(
                                item,
                                accent,
                                hourHeight,
                                leftOffset,
                              ),
                            ),
                          if (visible.isEmpty)
                            ...[8, 13, 19].map(
                              (hour) => Positioned(
                                top: hour * hourHeight - 18,
                                left: leftOffset,
                                right: 0,
                                height: 36,
                                child: _timelineAddPill(
                                  hour,
                                  accent,
                                  onAddAtHour,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTimelinePill(String label, Color accent) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: OptivusColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _timelineAddPill(
    int hour,
    Color accent,
    ValueChanged<int>? onAddAtHour,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAddAtHour == null ? null : () => onAddAtHour(hour),
      child: Opacity(
        opacity: onAddAtHour == null ? 0.46 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(Icons.add_rounded, color: accent, size: 26),
              Positioned(left: -3, top: 5, child: _droplet(8)),
              Positioned(right: -2, bottom: -2, child: _droplet(12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineBlock(
    RoutineItem item,
    Color accent,
    double hourHeight,
    double leftOffset,
  ) {
    final start = item.startMinute / 60 * hourHeight;
    final height = (item.durationMinutes / 60 * hourHeight)
        .clamp(38.0, 130.0)
        .toDouble();
    final blockAccent = item.hasConflict ? OptivusColors.danger : accent;
    final dayLabel = item.repeatDays.isEmpty
        ? _days[_day]
        : _days[_clampHour(item.repeatDays.first - 1, 0, 6)];

    return Positioned(
      top: start,
      left: leftOffset,
      right: 0,
      height: height,
      child: GestureDetector(
        onTap: () => _editItem(item),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      blockAccent.withValues(alpha: 0.3),
                      blockAccent.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: blockAccent.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.9),
                      blurRadius: 12,
                      offset: const Offset(-4, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (item.notes == 'Eating')
                                      Text(
                                        item.mealCategory == 'Breakfast'
                                            ? '🥞'
                                            : (item.mealCategory == 'Lunch'
                                                  ? '🍛'
                                                  : '🍲'),
                                        style: const TextStyle(fontSize: 18),
                                      )
                                    else
                                      Icon(
                                        _iconForRoutine(item),
                                        color: blockAccent.withValues(
                                          alpha: 0.9,
                                        ),
                                        size: 20,
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF0F111A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.more_vert_rounded,
                                      color: Color(0xFF64748B),
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${_minuteLabel(item.startMinute)} - ${_minuteLabel(item.endMinute)}${item.crossesMidnight ? ' overnight' : ''}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        dayLabel,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    if (item.location != null &&
                                        item.location!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          item.location!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: -8, left: 0, right: 0, child: _tapeHandle()),
            Positioned(bottom: -8, left: 0, right: 0, child: _tapeHandle()),
          ],
        ),
      ),
    );
  }

  Widget _tapeHandle() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 56,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(),
              ),
            ),
          ),
          Positioned(right: -6, bottom: -4, child: _droplet(14)),
          Positioned(right: 4, top: -2, child: _droplet(8)),
          Positioned(left: 8, top: -5, child: _droplet(10)),
          Positioned(left: -4, bottom: 2, child: _droplet(6)),
        ],
      ),
    );
  }

  Widget _droplet(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: size * 0.15,
            bottom: size * 0.05,
            width: size * 0.7,
            height: size * 0.45,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: size * 0.08,
            left: size * 0.18,
            width: size * 0.35,
            height: size * 0.15,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(size),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForRoutine(RoutineItem item) {
    final text = '${item.title} ${item.notes ?? ''}'.toLowerCase();
    if (text.contains('sleep') || text.contains('bed')) {
      return Icons.bed_rounded;
    }
    if (text.contains('class') ||
        text.contains('lecture') ||
        text.contains('lab')) {
      return Icons.school_rounded;
    }
    if (text.contains('work') ||
        text.contains('job') ||
        text.contains('office') ||
        text.contains('business')) {
      return Icons.work_rounded;
    }
    if (text.contains('meal') ||
        text.contains('breakfast') ||
        text.contains('lunch') ||
        text.contains('dinner')) {
      return Icons.restaurant_rounded;
    }
    if (text.contains('skin') || text.contains('cleanser')) {
      return Icons.spa_rounded;
    }
    if (text.contains('bath') || text.contains('shower')) {
      return Icons.shower_rounded;
    }
    if (text.contains('travel')) return Icons.directions_bus_rounded;
    if (text.contains('prayer')) return Icons.self_improvement_rounded;
    if (text.contains('medication')) return Icons.medication_rounded;
    return Icons.schedule_rounded;
  }

  Widget _timelineItemCard(RoutineItem item, Color accent) {
    final start = _minuteLabel(item.startMinute);
    final end = _minuteLabel(item.endMinute);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OnboardingGlassCard(
        padding: const EdgeInsets.all(14),
        selected: item.hasConflict,
        tint: item.hasConflict
            ? OptivusColors.danger.withValues(alpha: 0.08)
            : null,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
              ),
              child: Icon(Icons.schedule_rounded, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$start to $end${item.crossesMidnight ? ' overnight' : ''} on ${_days[_clampHour(item.repeatDays.first - 1, 0, 6)]}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OnboardingIconPill(
              icon: Icons.copy_rounded,
              accent: accent,
              tooltip: 'Copy to other days',
              onTap: () => _copyToOtherDays(item),
            ),
            const SizedBox(width: 8),
            OnboardingIconPill(
              icon: Icons.edit_rounded,
              accent: accent,
              tooltip: 'Edit block',
              onTap: () => _editItem(item),
            ),
            const SizedBox(width: 8),
            OnboardingIconPill(
              icon: Icons.delete_outline_rounded,
              accent: OptivusColors.danger,
              tooltip: 'Delete block',
              onTap: () {
                ref
                    .read(mockOnboardingProvider.notifier)
                    .updateDraft(
                      (draft) => draft.copyWith(
                        baseTimeline: draft.baseTimeline.deleteBlock(item.id),
                        clearFinalPreview: true,
                      ),
                    );
                ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _eatingSection() {
    final meals = _draftRoutineItems()
        .where((item) => item.mealCategory != null || item.notes == 'Eating')
        .toList();
    final dayMeals = meals
        .where((item) => item.repeatDays.contains(_day + 1))
        .toList();
    final region = ref.watch(regionSettingsProvider);
    return OnboardingScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _setupHeader(
            'Eating',
            'Choose living context, meal timing, menu style, and mock calorie/protein estimates.',
            'Always required',
            Icons.restaurant_rounded,
            OptivusColors.success,
            itemCount: meals.length,
          ),
          const SizedBox(height: 12),
          _dayChips(OptivusColors.success),
          const SizedBox(height: 12),
          _modeTabs(),
          const SizedBox(height: 12),
          _setupHeaderStrip(
            'Set Your Daily Eating Routine',
            OptivusColors.success,
          ),
          const SizedBox(height: 12),
          if (_setupMode != 'Manual') _importPreviewCard(),
          OnboardingGlassCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _eatingModeOptions(region)
                  .map(
                    (mode) => OnboardingChip(
                      label: mode.label,
                      selected: _eatingMode == mode.key,
                      onTap: () {
                        setState(() => _eatingMode = mode.key);
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .updateDraft(
                              (draft) => draft.copyWith(
                                baseTimeline: draft.baseTimeline.copyWith(
                                  eatingMode: mode.key,
                                  clearMealPlanning:
                                      mode.key != 'flat' &&
                                      mode.key != 'staying_alone',
                                ),
                                clearFinalPreview: true,
                              ),
                            );
                        ref
                            .read(mockOnboardingProvider.notifier)
                            .setStepDirty(4, true);
                      },
                      accent: OptivusColors.success,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_eatingMode == 'flat' || _eatingMode == 'staying_alone') ...[
            const SizedBox(height: 12),
            _mealPlanningCard(),
          ],
          const SizedBox(height: 12),
          _routineSetupFrame(
            title: 'Your Fixed Meals',
            subtitle:
                'Maintain regular eating windows without requesting permissions or AI.',
            items: dayMeals,
            accent: OptivusColors.success,
            emptyLabel: 'No meals added yet',
            onAddAtHour: (hour) => setState(() {
              _startHour = hour;
              _endHour = _clampHour(hour + 1, 1, 24);
            }),
          ),
          const SizedBox(height: 12),
          ...dayMeals.map(
            (item) => _timelineItemCard(item, OptivusColors.success),
          ),
          _manualAddCard(
            icon: Icons.restaurant_rounded,
            accent: OptivusColors.success,
            title: _eatingMode == 'home'
                ? 'Add meal time'
                : 'Add menu / meal plan',
            hint:
                _eatingMode == 'hostel' ||
                    _eatingMode == 'pg' ||
                    _eatingMode == 'mess'
                ? _eatingHint(region)
                : 'Breakfast, lunch, dinner, or snack',
            controller: _mealCtrl,
            onAdd: () => _addRoutine(
              'Eating',
              _mealCtrl,
              _hardBlock
                  ? RoutineBlockType.hardBlock
                  : RoutineBlockType.softBlock,
            ),
            chips: const [
              'Home meal-time',
              'Hard block',
              'Soft block',
              'Menu style',
              'Mock kcal',
              'Mock protein',
            ],
          ),
          const SizedBox(height: 12),
          _reviewCard(OptivusColors.success),
        ],
      ),
    );
  }

  Widget _mealPlanningCard() {
    final base = ref.watch(mockOnboardingProvider).draft.baseTimeline;
    void update(BaseTimelineDraft next) {
      ref
          .read(mockOnboardingProvider.notifier)
          .updateDraft(
            (draft) =>
                draft.copyWith(baseTimeline: next, clearFinalPreview: true),
          );
      ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
    }

    return OnboardingGlassCard(
      tint: OptivusColors.success.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meal planning',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OnboardingChip(
                label: 'Plan meals',
                selected: base.shouldPlanMeals == true,
                accent: OptivusColors.success,
                onTap: () => update(base.copyWith(shouldPlanMeals: true)),
              ),
              OnboardingChip(
                label: 'Only remind me',
                selected: base.shouldPlanMeals == false,
                onTap: () => update(base.copyWith(shouldPlanMeals: false)),
              ),
            ],
          ),
          if (base.shouldPlanMeals == true) ...[
            const SizedBox(height: 12),
            _mealOptionRow(
              'Goal',
              const [
                _TimelineOption('maintain', 'Maintain'),
                _TimelineOption('fat_loss', 'Fat loss'),
                _TimelineOption('muscle_gain', 'Muscle gain'),
                _TimelineOption('gain_weight', 'Gain weight'),
              ],
              base.mealPlanningGoal,
              (key) => update(base.copyWith(mealPlanningGoal: key)),
            ),
            _mealOptionRow(
              'Food type',
              const [
                _TimelineOption('veg', 'Veg'),
                _TimelineOption('non_veg', 'Non-veg'),
                _TimelineOption('mixed', 'Mixed'),
                _TimelineOption('egg', 'Egg-based'),
                _TimelineOption('custom', 'Custom'),
              ],
              base.foodType,
              (key) => update(base.copyWith(foodType: key)),
            ),
            _mealOptionRow(
              'Budget',
              const [
                _TimelineOption('low', 'Low'),
                _TimelineOption('medium', 'Medium'),
                _TimelineOption('high', 'High'),
              ],
              base.mealBudget,
              (key) => update(base.copyWith(mealBudget: key)),
            ),
            _mealOptionRow(
              'Cooking',
              const [
                _TimelineOption('none', 'None'),
                _TimelineOption('basic', 'Basic'),
                _TimelineOption('good', 'Good'),
              ],
              base.cookingAbility,
              (key) => update(base.copyWith(cookingAbility: key)),
            ),
            _mealOptionRow(
              'Meals/day',
              const [
                _TimelineOption('2', '2'),
                _TimelineOption('3', '3'),
                _TimelineOption('4', '4'),
                _TimelineOption('5', '5'),
              ],
              base.mealsPerDay?.toString(),
              (key) => update(base.copyWith(mealsPerDay: int.tryParse(key))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mealOptionRow(
    String label,
    List<_TimelineOption> options,
    String? selectedKey,
    ValueChanged<String> onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => OnboardingChip(
                    label: option.label,
                    selected: selectedKey == option.key,
                    accent: OptivusColors.success,
                    onTap: () => onSelect(option.key),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _fixedSection() {
    final fixedItems = _draftRoutineItems()
        .where((item) => item.notes == 'Fixed')
        .toList();
    final dayFixedItems = fixedItems
        .where((item) => item.repeatDays.contains(_day + 1))
        .toList();

    return OnboardingScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _setupHeader(
            'Fixed',
            'Review previous timeline anchors and add prayer, travel, medication, family, tuition, house work, or other fixed blocks.',
            'Always required',
            Icons.lock_clock_rounded,
            const Color(0xFFFF9D5C),
            itemCount: fixedItems.length,
          ),
          const SizedBox(height: 12),
          OnboardingGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Previous timeline preview (Today)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ..._draftRoutineItems()
                    .where(
                      (item) =>
                          (item.notes == 'Classes' ||
                              item.notes == 'Job / Work / Business' ||
                              item.notes == 'Eating') &&
                          item.repeatDays.contains(_day + 1),
                    )
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${_minuteLabel(item.startMinute)} - ${_minuteLabel(item.endMinute)} : ${item.title}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _dayChips(const Color(0xFFFF9D5C)),
          const SizedBox(height: 12),
          _setupHeaderStrip(
            'Set Your Fixed Daily Anchors',
            const Color(0xFFFF9D5C),
          ),
          const SizedBox(height: 12),
          _routineSetupFrame(
            title: 'Your Fixed Anchors',
            subtitle:
                'Sleep, bath, travel, prayer, medication, family, tuition, and house work stay protected.',
            items: dayFixedItems,
            accent: const Color(0xFFFF9D5C),
            emptyLabel: 'Sleep, bath, and fixed anchors appear here',
            onAddAtHour: (hour) => setState(() {
              _startHour = hour;
              _endHour = _clampHour(hour + 1, 1, 24);
            }),
          ),
          const SizedBox(height: 12),
          ...dayFixedItems.map(
            (item) => _timelineItemCard(item, const Color(0xFFFF9D5C)),
          ),
          _presetActionGrid(
            accent: const Color(0xFFFF9D5C),
            items: const [
              ('Sleep preset', Icons.bed_rounded),
              ('Bath preset', Icons.shower_rounded),
              ('Prayer', Icons.self_improvement_rounded),
              ('Travel', Icons.directions_bus_rounded),
              ('Medication', Icons.medication_rounded),
              ('Family responsibility', Icons.family_restroom_rounded),
              ('Tuition', Icons.menu_book_rounded),
              ('House work', Icons.cleaning_services_rounded),
              ('Other', Icons.more_horiz_rounded),
            ],
            onSelect: (label) {
              setState(() {
                _fixedCtrl.text = label == 'Sleep preset'
                    ? 'Sleep'
                    : label == 'Bath preset'
                    ? 'Bath'
                    : label;
                _hardBlock = true;
                _repeatMode = 'every_day';
                if (label == 'Sleep preset') {
                  _editingItemId = BaseTimelineDraft.fixedSleepId;
                  _startHour = 23;
                  _startMinutePart = 30;
                  _endHour = 7;
                  _endMinutePart = 0;
                } else if (label == 'Bath preset') {
                  _editingItemId = BaseTimelineDraft.fixedBathId;
                  _startHour = 7;
                  _startMinutePart = 0;
                  _endHour = 7;
                  _endMinutePart = 30;
                } else {
                  _editingItemId = null;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          _manualAddCard(
            icon: Icons.lock_clock_rounded,
            accent: const Color(0xFFFF9D5C),
            title: 'Add fixed block',
            hint:
                'Prayer, Travel, Medication, Family responsibility, Tuition, House work, Other',
            controller: _fixedCtrl,
            onAdd: () =>
                _addRoutine('Fixed', _fixedCtrl, RoutineBlockType.hardBlock),
            chips: const [
              'Sleep preset',
              'Bath preset',
              'Hard block',
              'Conflict protected',
            ],
          ),
        ],
      ),
    );
  }

  Widget _skinCareSection() {
    final skinSkipped = ref
        .watch(mockOnboardingProvider)
        .draft
        .baseTimeline
        .skinCareSkipped;
    final skinItems = _draftRoutineItems()
        .where((item) => item.notes == 'Skin Care')
        .toList();
    final daySkinItems = skinItems
        .where((item) => item.repeatDays.contains(_day + 1))
        .toList();
    return OnboardingScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _setupHeader(
            'Skin Care',
            'Optional morning and night product steps as soft blocks.',
            'Optional / skippable',
            Icons.spa_rounded,
            OptivusColors.aquaAccent,
            itemCount: skinItems.length,
          ),
          const SizedBox(height: 12),
          OnboardingGlassCard(
            selected: skinSkipped,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    skinSkipped
                        ? 'Skin care skipped for now'
                        : 'Set morning or night skin care steps',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                OnboardingActionPill(
                  label: skinSkipped ? 'Undo skip' : 'Skip',
                  icon: skinSkipped
                      ? Icons.undo_rounded
                      : Icons.skip_next_rounded,
                  accent: OptivusColors.aquaAccent,
                  compact: true,
                  onTap: () {
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .updateDraft(
                          (draft) => draft.copyWith(
                            baseTimeline: draft.baseTimeline.copyWith(
                              skinCareSkipped: !skinSkipped,
                            ),
                            clearFinalPreview: true,
                          ),
                        );
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepDirty(4, true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!skinSkipped) ...[
            _dayChips(OptivusColors.aquaAccent),
            const SizedBox(height: 12),
            _modeTabs(),
            const SizedBox(height: 12),
            _setupHeaderStrip(
              'Set Your Fixed Skincare Routine',
              OptivusColors.aquaAccent,
            ),
            const SizedBox(height: 12),
            if (_setupMode != 'Manual') _importPreviewCard(),
            _routineSetupFrame(
              title: 'Your Skincare Schedule',
              subtitle:
                  'Morning and night product steps are soft blocks and can be skipped.',
              items: daySkinItems,
              accent: OptivusColors.aquaAccent,
              emptyLabel: 'No skin care steps yet',
              onAddAtHour: (hour) => setState(() {
                _startHour = hour;
                _endHour = _clampHour(hour + 1, 1, 24);
              }),
            ),
            const SizedBox(height: 12),
            ...daySkinItems.map(
              (item) => _timelineItemCard(item, OptivusColors.aquaAccent),
            ),
            _presetActionGrid(
              accent: OptivusColors.aquaAccent,
              items: const [
                ('Morning routine', Icons.wb_sunny_rounded),
                ('Night routine', Icons.nightlight_round),
                ('Cleanser', Icons.water_drop_rounded),
                ('Moisturizer', Icons.spa_rounded),
                ('Sunscreen', Icons.wb_sunny_outlined),
                ('Soft block', Icons.swap_horiz_rounded),
              ],
              onSelect: (label) {
                setState(() {
                  _skinCtrl.text = label;
                  _hardBlock = false;
                });
              },
            ),
            const SizedBox(height: 12),
            _manualAddCard(
              icon: Icons.spa_rounded,
              accent: OptivusColors.aquaAccent,
              title: 'Add product step',
              hint: 'Cleanser, moisturizer, sunscreen, retinol',
              controller: _skinCtrl,
              onAdd: () => _addRoutine(
                'Skin Care',
                _skinCtrl,
                RoutineBlockType.softBlock,
              ),
              chips: const [
                'Morning routine',
                'Night routine',
                'Product steps',
                'Soft block',
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewCard(Color accent) {
    return OnboardingGlassCard(
      tint: accent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview / review',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manual entries stay local in mock onboarding state. Imported AI/photo review is represented as frontend preview UI only.',
            style: TextStyle(
              fontSize: 11,
              color: OptivusColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OnboardingChip(
                label: 'Edit',
                selected: false,
                icon: Icons.edit_rounded,
              ),
              OnboardingChip(
                label: 'Delete',
                selected: false,
                icon: Icons.delete_outline_rounded,
              ),
              OnboardingChip(
                label: 'Copy to other days',
                selected: false,
                icon: Icons.copy_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conflictResolver() {
    final conflicts = ref
        .watch(mockOnboardingProvider)
        .draft
        .baseTimeline
        .detectConflicts();
    if (conflicts.isEmpty) return const SizedBox.shrink();

    return OnboardingGlassCard(
      tint: OptivusColors.danger.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.report_problem_rounded,
                color: OptivusColors.danger,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Conflict resolver',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Real overlaps appear here. Hard-block conflicts must be moved, edited, softened, or explicitly kept.',
            style: TextStyle(
              fontSize: 11,
              color: OptivusColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...conflicts.map(_conflictCard),
        ],
      ),
    );
  }

  Widget _conflictCard(TimelineConflictDraft conflict) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color:
              (conflict.isBlocking
                      ? OptivusColors.danger
                      : OptivusColors.success)
                  .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${conflict.firstTitle} overlaps ${conflict.secondTitle} on ${_days[_clampHour(conflict.day - 1, 0, 6)]}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OnboardingChip(
                  label: conflict.accepted ? 'Kept safely' : 'Keep both',
                  selected: conflict.accepted,
                  accent: OptivusColors.success,
                  onTap: () {
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .updateDraft(
                          (draft) => draft.copyWith(
                            baseTimeline: draft.baseTimeline.acceptConflict(
                              conflict.key,
                            ),
                            clearFinalPreview: true,
                          ),
                        );
                    ref
                        .read(mockOnboardingProvider.notifier)
                        .setStepDirty(4, true);
                  },
                ),
                OnboardingChip(
                  label: 'Move item',
                  selected: false,
                  onTap: () => _editBlockById(conflict.secondBlockId),
                ),
                OnboardingChip(
                  label: 'Edit block',
                  selected: false,
                  onTap: () => _editBlockById(conflict.firstBlockId),
                ),
                OnboardingChip(
                  label: 'Mark soft/flexible',
                  selected: false,
                  accent: OptivusColors.aquaAccent,
                  onTap: () => _markBlockSoft(conflict.secondBlockId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editBlockById(String id) {
    final block = _blockById(
      id,
      ref.read(mockOnboardingProvider).draft.baseTimeline.blocks,
    );
    if (block != null) _editItem(_routineFromBlock(block));
  }

  List<_TimelineOption> _eatingModeOptions(RegionSettings region) {
    if (region.foodVocabularyMode == FoodVocabularyMode.india) {
      return const [
        _TimelineOption('home', 'Home'),
        _TimelineOption('hostel', 'Hostel'),
        _TimelineOption('pg', 'PG'),
        _TimelineOption('flat', 'Flat / rented room'),
        _TimelineOption('mess', 'Mess'),
        _TimelineOption('staying_alone', 'Staying alone'),
        _TimelineOption('mixed', 'Mixed'),
      ];
    }
    if (region.foodVocabularyMode == FoodVocabularyMode.japan) {
      return const [
        _TimelineOption('home', 'Home'),
        _TimelineOption('hostel', 'Dorm'),
        _TimelineOption('flat', 'Apartment'),
        _TimelineOption('mess', 'Cafeteria'),
        _TimelineOption('pg', 'Convenience store / outside food'),
        _TimelineOption('mixed', 'Mixed'),
      ];
    }
    return const [
      _TimelineOption('home', 'Home'),
      _TimelineOption('hostel', 'Dorm / Hostel'),
      _TimelineOption('pg', 'Shared apartment'),
      _TimelineOption('flat', 'Alone / Studio'),
      _TimelineOption('mess', 'Cafeteria / Dining hall'),
      _TimelineOption('staying_alone', 'Meal plan'),
      _TimelineOption('mixed', 'Mixed'),
    ];
  }

  String _eatingHint(RegionSettings region) {
    return region.foodVocabularyMode == FoodVocabularyMode.india
        ? 'Mess menu item or meal slot'
        : 'Dining hall, meal plan, or cafeteria item';
  }

  void _markBlockSoft(String id) {
    ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
      final block = _blockById(id, draft.baseTimeline.blocks);
      if (block == null) return draft;
      return draft.copyWith(
        baseTimeline: draft.baseTimeline.upsertBlock(
          block.copyWith(blockType: TimelineBlockDraft.softBlockKey),
        ),
        clearFinalPreview: true,
      );
    });
    ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);
  }
}

class _SectionStatusRail extends StatelessWidget {
  final Color accent;
  final bool enabled;
  final String status;
  final int count;

  const _SectionStatusRail({
    required this.accent,
    required this.enabled,
    required this.status,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OnboardingChip(
          label: status,
          selected: enabled,
          accent: enabled ? accent : OptivusColors.textSecondary,
        ),
        OnboardingChip(
          label: count == 0
              ? 'No blocks yet'
              : '$count block${count == 1 ? '' : 's'}',
          selected: count > 0,
          accent: accent,
        ),
        OnboardingChip(
          label: 'Local mock only',
          selected: true,
          icon: Icons.lock_outline_rounded,
          accent: OptivusColors.aquaAccent,
        ),
      ],
    );
  }
}

class _TimelineOption {
  final String key;
  final String label;

  const _TimelineOption(this.key, this.label);
}
