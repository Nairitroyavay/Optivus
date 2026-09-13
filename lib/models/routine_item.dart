import 'package:cloud_firestore/cloud_firestore.dart';

// ── Item Type (block category) ──────────────────────────────
enum RoutineBlockType {
  hardBlock, // Non-negotiable: Class, Shift work, Travel, sleep
  softBlock, // Movable/soft: Eating, Skincare, Family task, walk
  flexibleTask, // Movable habits: Reading, Language, Study
  trackerTask, // Timed tracker items: Workout, Meditation, Focus session
  checkIn, // Manual loggers: Smoking check, alcohol avoid, Hydration logs
  moneyTask, // Region-aware tiny saving task
}

class RoutineConflictAllowance {
  final String canonicalPairId;
  final String evaluatedDateKey;
  final String conflictType;
  final String scheduleFingerprint;
  final int schemaVersion;

  const RoutineConflictAllowance({
    required this.canonicalPairId,
    required this.evaluatedDateKey,
    required this.conflictType,
    required this.scheduleFingerprint,
    this.schemaVersion = 1,
  });

  Map<String, dynamic> toMap() => {
    'canonicalPairId': canonicalPairId,
    'evaluatedDateKey': evaluatedDateKey,
    'conflictType': conflictType,
    'scheduleFingerprint': scheduleFingerprint,
    'schemaVersion': schemaVersion,
  };

  factory RoutineConflictAllowance.fromMap(Map<String, dynamic> map) {
    return RoutineConflictAllowance(
      canonicalPairId: map['canonicalPairId'] as String? ?? '',
      evaluatedDateKey: map['evaluatedDateKey'] as String? ?? '',
      conflictType: map['conflictType'] as String? ?? '',
      scheduleFingerprint: map['scheduleFingerprint'] as String? ?? '',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

// ── Category ────────────────────────────────────────────────
enum RoutineCategory {
  classBlock,
  job,
  eating,
  fixed,
  skinCare,
  sleep,
  habit,
  badHabit,
  identity,
  finance,
  health,
  focus,
  meditation,
  hydration,
  screenTime,
}

// ── Source ───────────────────────────────────────────────────
enum RoutineSource {
  onboarding,
  manual,
  aiSuggestion,
  tracker,
  imported,
  baseTimeline,
}

// ── Status ──────────────────────────────────────────────────
enum RoutineStatus {
  planned,
  active,
  inTracker,
  completed,
  skipped,
  missed,
  moved,
}

// ── Priority ────────────────────────────────────────────────
enum RoutinePriority { mustDo, goodToDo }

// ── Tracker Type ────────────────────────────────────────────
enum TrackerType { meditation, workout, focus, money, hydration, smoking, none }

// ── RoutineItem ─────────────────────────────────────────────
class RoutineItem {
  static const int currentSchemaVersion = 1;

  final String id;
  final String? userId;
  final int schemaVersion;
  final String? onboardingProjectionId;
  final String? onboardingSourceItemId;

  /// Stable source-authored visual identity for onboarding-projected items.
  /// Examples: `class:0`, `work:2`, `eating:default`.
  final String? onboardingVisualStyleKey;
  final String? createdByOperationId;
  final String? lastMutationOperationId;
  final String title;
  final DateTime? date;
  final DateTime? endDate; // Non-null for overnight items
  final int startMinute; // Minutes since midnight
  final int endMinute; // Minutes since midnight
  final bool crossesMidnight;
  final bool endsNextDay;
  final bool isContinuation; // True for next-day continuation segments
  final List<int> repeatDays; // 1 = Monday, 7 = Sunday
  final String? location;
  final RoutineBlockType blockType;
  final RoutineCategory category;
  final RoutineSource source;
  final RoutineStatus status;
  final RoutinePriority priority;
  final bool isTrackerLinked;
  final TrackerType trackerType;
  final String? notes;
  final String? bestTime;
  final String? baseTimelineSection;

  // Custom metadata based on types
  final List<String>? subtasks;
  final List<bool>? subtasksCompleted;

  // Generic steps (skin care, etc.)
  final List<String>? steps;

  // Eating / Meal specific lists
  final String? mealCategory; // Breakfast, Lunch, Snacks, Dinner
  final String? mealSlot;
  final List<String>? dishes;
  final double? caloriesEstimate;
  final double? proteinEstimate;

  // Skincare specific details (kept for backward compat, prefer `steps`)
  final List<String>? skincareProducts;
  final List<String>? skincareMissingItems;
  final String? skincareSlotLabel;

  // Structured Class details
  final String? professor;
  final String? courseCode;
  final String? classType;
  final String? sectionLabel;

  // Block configuration
  final bool hardBlock;
  final List<String> allowedOverlaps; // Legacy string-based IDs
  final List<RoutineConflictAllowance> allowedConflicts;
  final String? repeatRule;

  // Status attributes
  final bool isCompleted;
  final bool isMissed;
  final bool hasConflict;
  final String? conflictMessage;
  final bool undoToPlannedAllowed;
  final DateTime? startedAt;
  final int? countdownDurationSeconds;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  RoutineItem({
    required this.id,
    this.userId,
    this.schemaVersion = currentSchemaVersion,
    this.onboardingProjectionId,
    this.onboardingSourceItemId,
    this.onboardingVisualStyleKey,
    this.createdByOperationId,
    this.lastMutationOperationId,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    required this.blockType,
    this.date,
    this.endDate,
    this.crossesMidnight = false,
    this.endsNextDay = false,
    this.isContinuation = false,
    List<int>? repeatDays,
    this.location,
    this.category = RoutineCategory.fixed,
    this.source = RoutineSource.manual,
    this.status = RoutineStatus.planned,
    this.priority = RoutinePriority.goodToDo,
    this.isTrackerLinked = false,
    this.trackerType = TrackerType.none,
    this.notes,
    this.bestTime,
    this.baseTimelineSection,
    this.subtasks,
    this.subtasksCompleted,
    this.steps,
    this.mealCategory,
    this.mealSlot,
    this.dishes,
    this.caloriesEstimate,
    this.proteinEstimate,
    this.skincareProducts,
    this.skincareMissingItems,
    this.skincareSlotLabel,
    this.professor,
    this.courseCode,
    this.classType,
    this.sectionLabel,
    this.hardBlock = false,
    this.allowedOverlaps = const [],
    this.allowedConflicts = const [],
    this.repeatRule,
    this.isCompleted = false,
    this.isMissed = false,
    this.hasConflict = false,
    this.conflictMessage,
    this.undoToPlannedAllowed = false,
    this.startedAt,
    this.countdownDurationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : repeatDays = repeatDays ?? const [1, 2, 3, 4, 5, 6, 7],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get durationMinutes {
    if (crossesMidnight || endsNextDay || endMinute <= startMinute) {
      return (24 * 60 - startMinute) + endMinute;
    }
    return endMinute - startMinute;
  }

  /// Effective end minute within same day (for rendering purposes).
  /// If crosses midnight, clamp to 1440 for today's rendering.
  int get effectiveEndMinute {
    if (crossesMidnight || endsNextDay || endMinute <= startMinute) {
      return 1440; // midnight end on same-day view
    }
    return endMinute;
  }

  /// Whether this item is an overnight block (crosses midnight).
  bool get isOvernight =>
      crossesMidnight || endsNextDay || endMinute <= startMinute;

  /// Layout-only normalized end minute (adds 1440 for overnight items).
  int get normalizedEndMinuteForLayout =>
      isOvernight ? endMinute + 1440 : endMinute;

  /// Duration in minutes for layout, accounting for overnight crossing.
  int get durationMinutesForLayout =>
      normalizedEndMinuteForLayout - startMinute;

  /// Whether this is a hard-type block (hard_block or configured as hardBlock).
  bool get isHardBlock => blockType == RoutineBlockType.hardBlock || hardBlock;

  /// Get the display steps: prefer steps, fall back to skincareProducts.
  List<String>? get displaySteps => steps ?? skincareProducts;

  /// Short status label for card display.
  String get statusLabel {
    switch (status) {
      case RoutineStatus.planned:
        return 'Planned';
      case RoutineStatus.active:
        return 'Active';
      case RoutineStatus.inTracker:
        return 'In progress in Tracker';
      case RoutineStatus.completed:
        return 'Completed';
      case RoutineStatus.skipped:
        return 'Skipped';
      case RoutineStatus.missed:
        return 'Missed';
      case RoutineStatus.moved:
        return 'Moved';
    }
  }

  /// Block type label for card display.
  String get blockTypeLabel {
    switch (blockType) {
      case RoutineBlockType.hardBlock:
        return 'Hard block';
      case RoutineBlockType.softBlock:
        return 'Soft block';
      case RoutineBlockType.flexibleTask:
        return 'Flexible';
      case RoutineBlockType.trackerTask:
        return 'Tracker task';
      case RoutineBlockType.checkIn:
        return 'Check-in';
      case RoutineBlockType.moneyTask:
        return 'Money System';
    }
  }

  /// Priority label for card display.
  String get priorityLabel {
    switch (priority) {
      case RoutinePriority.mustDo:
        return 'Must do';
      case RoutinePriority.goodToDo:
        return 'Good to do';
    }
  }

  RoutineItem copyWith({
    String? id,
    String? userId,
    int? schemaVersion,
    String? onboardingProjectionId,
    String? onboardingSourceItemId,
    String? onboardingVisualStyleKey,
    String? createdByOperationId,
    String? lastMutationOperationId,
    String? title,
    DateTime? date,
    DateTime? endDate,
    int? startMinute,
    int? endMinute,
    bool? crossesMidnight,
    bool? endsNextDay,
    bool? isContinuation,
    List<int>? repeatDays,
    String? location,
    RoutineBlockType? blockType,
    RoutineCategory? category,
    RoutineSource? source,
    RoutineStatus? status,
    RoutinePriority? priority,
    bool? isTrackerLinked,
    TrackerType? trackerType,
    String? notes,
    bool clearNotes = false,
    String? bestTime,
    String? baseTimelineSection,
    bool clearBaseTimelineSection = false,
    List<String>? subtasks,
    List<bool>? subtasksCompleted,
    List<String>? steps,
    String? mealCategory,
    String? mealSlot,
    List<String>? dishes,
    double? caloriesEstimate,
    double? proteinEstimate,
    List<String>? skincareProducts,
    List<String>? skincareMissingItems,
    String? skincareSlotLabel,
    String? professor,
    String? courseCode,
    String? classType,
    String? sectionLabel,
    bool? hardBlock,
    List<String>? allowedOverlaps,
    List<RoutineConflictAllowance>? allowedConflicts,
    String? repeatRule,
    bool? isCompleted,
    bool? isMissed,
    bool? hasConflict,
    String? conflictMessage,
    bool clearConflict = false,
    bool? undoToPlannedAllowed,
    DateTime? startedAt,
    int? countdownDurationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoutineItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      onboardingProjectionId:
          onboardingProjectionId ?? this.onboardingProjectionId,
      onboardingSourceItemId:
          onboardingSourceItemId ?? this.onboardingSourceItemId,
      onboardingVisualStyleKey:
          onboardingVisualStyleKey ?? this.onboardingVisualStyleKey,
      createdByOperationId: createdByOperationId ?? this.createdByOperationId,
      lastMutationOperationId:
          lastMutationOperationId ?? this.lastMutationOperationId,
      title: title ?? this.title,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      crossesMidnight: crossesMidnight ?? this.crossesMidnight,
      endsNextDay: endsNextDay ?? this.endsNextDay,
      isContinuation: isContinuation ?? this.isContinuation,
      repeatDays: repeatDays ?? this.repeatDays,
      location: location ?? this.location,
      blockType: blockType ?? this.blockType,
      category: category ?? this.category,
      source: source ?? this.source,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isTrackerLinked: isTrackerLinked ?? this.isTrackerLinked,
      trackerType: trackerType ?? this.trackerType,
      notes: clearNotes ? null : (notes ?? this.notes),
      bestTime: bestTime ?? this.bestTime,
      baseTimelineSection: clearBaseTimelineSection
          ? null
          : (baseTimelineSection ?? this.baseTimelineSection),
      subtasks: subtasks ?? this.subtasks,
      subtasksCompleted: subtasksCompleted ?? this.subtasksCompleted,
      steps: steps ?? this.steps,
      mealCategory: mealCategory ?? this.mealCategory,
      mealSlot: mealSlot ?? this.mealSlot,
      dishes: dishes ?? this.dishes,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
      proteinEstimate: proteinEstimate ?? this.proteinEstimate,
      skincareProducts: skincareProducts ?? this.skincareProducts,
      skincareMissingItems: skincareMissingItems ?? this.skincareMissingItems,
      skincareSlotLabel: skincareSlotLabel ?? this.skincareSlotLabel,
      professor: professor ?? this.professor,
      courseCode: courseCode ?? this.courseCode,
      classType: classType ?? this.classType,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      hardBlock: hardBlock ?? this.hardBlock,
      allowedOverlaps: allowedOverlaps ?? this.allowedOverlaps,
      allowedConflicts: allowedConflicts ?? this.allowedConflicts,
      repeatRule: repeatRule ?? this.repeatRule,
      isCompleted: isCompleted ?? this.isCompleted,
      isMissed: isMissed ?? this.isMissed,
      hasConflict: clearConflict ? false : (hasConflict ?? this.hasConflict),
      conflictMessage: clearConflict
          ? null
          : (conflictMessage ?? this.conflictMessage),
      undoToPlannedAllowed: undoToPlannedAllowed ?? this.undoToPlannedAllowed,
      startedAt: startedAt ?? this.startedAt,
      countdownDurationSeconds:
          countdownDurationSeconds ?? this.countdownDurationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // ── Backend-ready serialization ───────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'schemaVersion': schemaVersion,
      'onboardingProjectionId': onboardingProjectionId,
      'onboardingSourceItemId': onboardingSourceItemId,
      'onboardingVisualStyleKey': onboardingVisualStyleKey,
      'createdByOperationId': createdByOperationId,
      'lastMutationOperationId': lastMutationOperationId,
      'title': title,
      'date': date?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'startMinute': startMinute,
      'endMinute': endMinute,
      'crossesMidnight': crossesMidnight,
      'endsNextDay': endsNextDay,
      'isContinuation': isContinuation,
      'repeatDays': repeatDays,
      'location': location,
      'blockType': blockType.name,
      'category': category.name,
      'source': source.name,
      'status': status.name,
      'priority': priority.name,
      'isTrackerLinked': isTrackerLinked,
      'trackerType': trackerType.name,
      'notes': notes,
      'bestTime': bestTime,
      'baseTimelineSection': baseTimelineSection,
      'subtasks': subtasks,
      'subtasksCompleted': subtasksCompleted,
      'steps': steps,
      'mealCategory': mealCategory,
      'mealSlot': mealSlot,
      'dishes': dishes,
      'caloriesEstimate': caloriesEstimate,
      'proteinEstimate': proteinEstimate,
      'skincareProducts': skincareProducts,
      'skincareMissingItems': skincareMissingItems,
      'skincareSlotLabel': skincareSlotLabel,
      'professor': professor,
      'courseCode': courseCode,
      'classType': classType,
      'sectionLabel': sectionLabel,
      'hardBlock': hardBlock,
      'allowedOverlaps': allowedOverlaps,
      'allowedConflicts': allowedConflicts.map((c) => c.toMap()).toList(),
      'repeatRule': repeatRule,
      'isCompleted': isCompleted,
      'isMissed': isMissed,
      'hasConflict': hasConflict,
      'conflictMessage': conflictMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap({String ownerUid = ''}) {
    final effectiveOwner = ownerUid.isNotEmpty ? ownerUid : (userId ?? '');
    return {
      'id': id,
      if (effectiveOwner.isNotEmpty) 'ownerUid': effectiveOwner,
      'title': title.trim(),
      'category': category.name,
      'source': source.name,
      'blockType': blockType.name,
      'priority': priority.name,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'repeatRule':
          repeatRule ??
          (date != null && repeatDays.isEmpty ? 'once' : 'weekly'),
      'repeatDays': [...repeatDays]..sort(),
      if (date != null)
        'dateKey':
            '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'endDateKey':
            '${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
      'crossesMidnight': crossesMidnight,
      'endsNextDay': endsNextDay,
      if (location != null && location!.trim().isNotEmpty)
        'location': location!.trim(),
      'isTrackerLinked': isTrackerLinked,
      'trackerType': trackerType.name,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (bestTime != null && bestTime!.trim().isNotEmpty)
        'bestTime': bestTime!.trim(),
      if (baseTimelineSection != null && baseTimelineSection!.trim().isNotEmpty)
        'baseTimelineSection': baseTimelineSection!.trim(),
      if (subtasks != null) 'subtasks': List<String>.from(subtasks!),
      if (steps != null) 'steps': List<String>.from(steps!),
      if (mealCategory != null && mealCategory!.trim().isNotEmpty)
        'mealCategory': mealCategory!.trim(),
      if (mealSlot != null && mealSlot!.trim().isNotEmpty)
        'mealSlot': mealSlot!.trim(),
      if (dishes != null) 'dishes': List<String>.from(dishes!),
      if (caloriesEstimate != null) 'caloriesEstimate': caloriesEstimate,
      if (proteinEstimate != null) 'proteinEstimate': proteinEstimate,
      if (skincareProducts != null)
        'skincareProducts': List<String>.from(skincareProducts!),
      if (skincareMissingItems != null)
        'skincareMissingItems': List<String>.from(skincareMissingItems!),
      if (skincareSlotLabel != null && skincareSlotLabel!.trim().isNotEmpty)
        'skincareSlotLabel': skincareSlotLabel!.trim(),
      if (professor != null && professor!.trim().isNotEmpty)
        'professor': professor!.trim(),
      if (courseCode != null && courseCode!.trim().isNotEmpty)
        'courseCode': courseCode!.trim(),
      if (classType != null && classType!.trim().isNotEmpty)
        'classType': classType!.trim(),
      if (sectionLabel != null && sectionLabel!.trim().isNotEmpty)
        'sectionLabel': sectionLabel!.trim(),
      'hardBlock': hardBlock,
      'allowedConflicts': allowedConflicts.map((c) => c.toMap()).toList(),
      if (onboardingProjectionId != null &&
          onboardingProjectionId!.trim().isNotEmpty)
        'onboardingProjectionId': onboardingProjectionId,
      if (onboardingSourceItemId != null &&
          onboardingSourceItemId!.trim().isNotEmpty)
        'onboardingSourceItemId': onboardingSourceItemId,
      if (onboardingVisualStyleKey != null &&
          onboardingVisualStyleKey!.trim().isNotEmpty)
        'onboardingVisualStyleKey': onboardingVisualStyleKey!.trim(),
      if (createdByOperationId != null &&
          createdByOperationId!.trim().isNotEmpty)
        'createdByOperationId': createdByOperationId,
      if (lastMutationOperationId != null &&
          lastMutationOperationId!.trim().isNotEmpty)
        'lastMutationOperationId': lastMutationOperationId,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
      'schemaVersion': currentSchemaVersion,
    };
  }

  factory RoutineItem.fromMap(Map<String, dynamic> map) {
    return RoutineItem(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String?,
      schemaVersion:
          (map['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      onboardingProjectionId: map['onboardingProjectionId'] as String?,
      onboardingSourceItemId: map['onboardingSourceItemId'] as String?,
      onboardingVisualStyleKey: map['onboardingVisualStyleKey'] as String?,
      createdByOperationId: map['createdByOperationId'] as String?,
      lastMutationOperationId: map['lastMutationOperationId'] as String?,
      title: map['title'] as String? ?? '',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String)
          : null,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'] as String)
          : null,
      crossesMidnight: map['crossesMidnight'] as bool? ?? false,
      endsNextDay: map['endsNextDay'] as bool? ?? false,
      isContinuation: map['isContinuation'] as bool? ?? false,
      repeatDays:
          (map['repeatDays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      location: map['location'] as String?,
      blockType: _parseEnum(
        RoutineBlockType.values,
        map['blockType'] as String?,
        fallback: RoutineBlockType.flexibleTask,
      ),
      category: _parseEnum(
        RoutineCategory.values,
        map['category'] as String?,
        fallback: RoutineCategory.fixed,
      ),
      source: _parseEnum(
        RoutineSource.values,
        map['source'] as String?,
        fallback: RoutineSource.manual,
      ),
      status: _parseEnum(
        RoutineStatus.values,
        map['status'] as String?,
        fallback: RoutineStatus.planned,
      ),
      priority: _parseEnum(
        RoutinePriority.values,
        map['priority'] as String?,
        fallback: RoutinePriority.goodToDo,
      ),
      isTrackerLinked: map['isTrackerLinked'] as bool? ?? false,
      trackerType: _parseEnum(
        TrackerType.values,
        map['trackerType'] as String?,
        fallback: TrackerType.none,
      ),
      notes: map['notes'] as String?,
      bestTime: map['bestTime'] as String?,
      baseTimelineSection: map['baseTimelineSection'] as String?,
      subtasks: (map['subtasks'] as List?)?.cast<String>(),
      subtasksCompleted: (map['subtasksCompleted'] as List?)?.cast<bool>(),
      steps: (map['steps'] as List?)?.cast<String>(),
      mealCategory: map['mealCategory'] as String?,
      mealSlot: map['mealSlot'] as String?,
      dishes: (map['dishes'] as List?)?.cast<String>(),
      caloriesEstimate: (map['caloriesEstimate'] as num?)?.toDouble(),
      proteinEstimate: (map['proteinEstimate'] as num?)?.toDouble(),
      skincareProducts: (map['skincareProducts'] as List?)?.cast<String>(),
      skincareMissingItems: (map['skincareMissingItems'] as List?)
          ?.cast<String>(),
      skincareSlotLabel: map['skincareSlotLabel'] as String?,
      professor: (map['professor'] ?? map['instructor']) as String?,
      courseCode: map['courseCode'] as String?,
      classType: map['classType'] as String?,
      sectionLabel: (map['sectionLabel'] ?? map['classSection']) as String?,
      hardBlock: map['hardBlock'] as bool? ?? false,
      allowedOverlaps:
          (map['allowedOverlaps'] as List?)?.cast<String>() ?? const [],
      allowedConflicts:
          (map['allowedConflicts'] as List?)
              ?.map(
                (e) =>
                    RoutineConflictAllowance.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      repeatRule: map['repeatRule'] as String?,
      isCompleted: map['isCompleted'] as bool? ?? false,
      isMissed: map['isMissed'] as bool? ?? false,
      hasConflict: map['hasConflict'] as bool? ?? false,
      conflictMessage: map['conflictMessage'] as String?,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Safe enum parser: returns fallback for unknown values.
T _parseEnum<T extends Enum>(
  List<T> values,
  String? name, {
  required T fallback,
}) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
