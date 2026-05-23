class OnboardingDraft {
  final bool welcomeSaved;
  final bool patiencePledgeAccepted;
  final String? patiencePledgeText;
  final LifeRoleDraft lifeRole;
  final BodyBasicsDraft bodyBasics;
  final BaseTimelineDraft baseTimeline;
  final bool badHabitsNotNow;
  final List<BadHabitDraft> badHabits;
  final bool goodHabitsNotNow;
  final List<GoodHabitDraft> goodHabits;
  final List<IdentityGoalDraft> identityGoals;
  final CoachSetupDraft coachSetup;
  final String? slipUpHandling;
  final NotificationSetupDraft notifications;
  final FinalTimelinePreview? finalPreview;

  const OnboardingDraft({
    this.welcomeSaved = false,
    this.patiencePledgeAccepted = false,
    this.patiencePledgeText,
    this.lifeRole = const LifeRoleDraft(),
    this.bodyBasics = const BodyBasicsDraft(),
    this.baseTimeline = const BaseTimelineDraft(),
    this.badHabitsNotNow = false,
    this.badHabits = const [],
    this.goodHabitsNotNow = false,
    this.goodHabits = const [],
    this.identityGoals = const [],
    this.coachSetup = const CoachSetupDraft(),
    this.slipUpHandling,
    this.notifications = const NotificationSetupDraft(),
    this.finalPreview,
  });

  factory OnboardingDraft.fromMap(Map<String, dynamic> map) {
    return OnboardingDraft(
      welcomeSaved: map['welcomeSaved'] as bool? ?? false,
      patiencePledgeAccepted: map['patiencePledgeAccepted'] as bool? ?? false,
      patiencePledgeText: map['patiencePledgeText'] as String?,
      lifeRole: map['lifeRole'] is Map
          ? LifeRoleDraft.fromMap(
              Map<String, dynamic>.from(map['lifeRole'] as Map),
            )
          : const LifeRoleDraft(),
      bodyBasics: map['bodyBasics'] is Map
          ? BodyBasicsDraft.fromMap(
              Map<String, dynamic>.from(map['bodyBasics'] as Map),
            )
          : const BodyBasicsDraft(),
      baseTimeline: map['baseTimeline'] is Map
          ? BaseTimelineDraft.fromMap(
              Map<String, dynamic>.from(map['baseTimeline'] as Map),
            )
          : const BaseTimelineDraft(),
      badHabitsNotNow: map['badHabitsNotNow'] as bool? ?? false,
      badHabits: _readList(
        map['badHabits'],
        (value) => BadHabitDraft.fromMap(value),
      ),
      goodHabitsNotNow: map['goodHabitsNotNow'] as bool? ?? false,
      goodHabits: _readList(
        map['goodHabits'],
        (value) => GoodHabitDraft.fromMap(value),
      ),
      identityGoals: _readList(
        map['identityGoals'],
        (value) => IdentityGoalDraft.fromMap(value),
      ),
      coachSetup: map['coachSetup'] is Map
          ? CoachSetupDraft.fromMap(
              Map<String, dynamic>.from(map['coachSetup'] as Map),
            )
          : const CoachSetupDraft(),
      slipUpHandling: map['slipUpHandling'] as String?,
      notifications: map['notifications'] is Map
          ? NotificationSetupDraft.fromMap(
              Map<String, dynamic>.from(map['notifications'] as Map),
            )
          : const NotificationSetupDraft(),
      finalPreview: map['finalPreview'] is Map
          ? FinalTimelinePreview.fromMap(
              Map<String, dynamic>.from(map['finalPreview'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'welcomeSaved': welcomeSaved,
    'patiencePledgeAccepted': patiencePledgeAccepted,
    'patiencePledgeText': patiencePledgeText,
    'lifeRole': lifeRole.toMap(),
    'bodyBasics': bodyBasics.toMap(),
    'baseTimeline': baseTimeline.toMap(),
    'badHabitsNotNow': badHabitsNotNow,
    'badHabits': badHabits.map((habit) => habit.toMap()).toList(),
    'goodHabitsNotNow': goodHabitsNotNow,
    'goodHabits': goodHabits.map((habit) => habit.toMap()).toList(),
    'identityGoals': identityGoals.map((goal) => goal.toMap()).toList(),
    'coachSetup': coachSetup.toMap(),
    'slipUpHandling': slipUpHandling,
    'notifications': notifications.toMap(),
    'finalPreview': finalPreview?.toMap(),
  };

  OnboardingDraft copyWith({
    bool? welcomeSaved,
    bool? patiencePledgeAccepted,
    String? patiencePledgeText,
    LifeRoleDraft? lifeRole,
    BodyBasicsDraft? bodyBasics,
    BaseTimelineDraft? baseTimeline,
    bool? badHabitsNotNow,
    List<BadHabitDraft>? badHabits,
    bool? goodHabitsNotNow,
    List<GoodHabitDraft>? goodHabits,
    List<IdentityGoalDraft>? identityGoals,
    CoachSetupDraft? coachSetup,
    String? slipUpHandling,
    NotificationSetupDraft? notifications,
    FinalTimelinePreview? finalPreview,
    bool clearPatiencePledgeText = false,
    bool clearSlipUpHandling = false,
    bool clearFinalPreview = false,
  }) {
    return OnboardingDraft(
      welcomeSaved: welcomeSaved ?? this.welcomeSaved,
      patiencePledgeAccepted:
          patiencePledgeAccepted ?? this.patiencePledgeAccepted,
      patiencePledgeText: clearPatiencePledgeText
          ? null
          : (patiencePledgeText ?? this.patiencePledgeText),
      lifeRole: lifeRole ?? this.lifeRole,
      bodyBasics: bodyBasics ?? this.bodyBasics,
      baseTimeline: baseTimeline ?? this.baseTimeline,
      badHabitsNotNow: badHabitsNotNow ?? this.badHabitsNotNow,
      badHabits: badHabits ?? this.badHabits,
      goodHabitsNotNow: goodHabitsNotNow ?? this.goodHabitsNotNow,
      goodHabits: goodHabits ?? this.goodHabits,
      identityGoals: identityGoals ?? this.identityGoals,
      coachSetup: coachSetup ?? this.coachSetup,
      slipUpHandling: clearSlipUpHandling
          ? null
          : (slipUpHandling ?? this.slipUpHandling),
      notifications: notifications ?? this.notifications,
      finalPreview: clearFinalPreview
          ? null
          : (finalPreview ?? this.finalPreview),
    );
  }

  String? validateStep(int step, List<bool> completedSteps) {
    switch (step) {
      case 0:
        return null;
      case 1:
        return patiencePledgeAccepted
            ? null
            : 'Please read and commit to the Patience Pledge to proceed.';
      case 2:
        return lifeRole.validate();
      case 3:
        return bodyBasics.validate();
      case 4:
        return baseTimeline.validateForRole(lifeRole.lifeRole);
      case 5:
        return badHabitsNotNow || badHabits.isNotEmpty
            ? null
            : 'Choose Not now or select at least one bad habit.';
      case 6:
        return goodHabitsNotNow || goodHabits.isNotEmpty
            ? null
            : 'Choose Not now or select at least one good habit.';
      case 7:
        return identityGoals.isNotEmpty
            ? null
            : 'Select at least one long-term identity goal.';
      case 8:
        return coachSetup.validate();
      case 9:
        return slipUpHandling == null
            ? 'Choose a slip-up handling style.'
            : null;
      case 10:
        return notifications.validate();
      case 11:
        if (!completedSteps.take(11).every((done) => done)) {
          return 'Complete and save all previous onboarding steps first.';
        }
        final preview = buildFinalPreview();
        if (preview.blockingWarnings.isNotEmpty) {
          return preview.blockingWarnings.first;
        }
        return null;
    }
    return null;
  }

  FinalTimelinePreview buildFinalPreview() {
    final conflicts = baseTimeline.detectConflicts();
    final warnings = <String>[
      for (final conflict in conflicts)
        if (conflict.isBlocking)
          'Resolve or accept the conflict between ${conflict.firstTitle} and ${conflict.secondTitle}.',
    ];

    final baseItems = baseTimeline.blocks
        .where((block) => !block.needsTimeConfirmation)
        .map(FinalTimelineItem.fromTimelineBlock)
        .toList();
    final systemItems = _identitySystemItems();
    final goodHabitItems = _goodHabitItems(baseItems);
    final badHabitItems = _badHabitCheckIns(baseItems);

    final items = [
      ...baseItems,
      ...goodHabitItems,
      ...badHabitItems,
      ...systemItems,
    ]..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    final dailyFlexibleMinutes = [
      ...goodHabitItems,
      ...systemItems,
    ].fold<int>(0, (sum, item) => sum + item.durationMinutes);
    final busyMinutes = baseItems.fold<int>(
      0,
      (sum, item) => item.blockType == TimelineBlockDraft.hardBlockKey
          ? sum + item.durationMinutes
          : sum,
    );
    if (busyMinutes + dailyFlexibleMinutes > 16 * 60) {
      warnings.add(
        'There may not be enough free time for every flexible habit.',
      );
    }

    return FinalTimelinePreview(
      items: items,
      warnings: warnings,
      duplicateSystemKeysSkipped: _duplicateSystemKeysSkipped(),
    );
  }

  List<FinalTimelineItem> _goodHabitItems(List<FinalTimelineItem> baseItems) {
    final blockedWindows = baseItems
        .where((item) => item.blockType == TimelineBlockDraft.hardBlockKey)
        .toList();
    var cursor = 6 * 60;

    return goodHabits.map((habit) {
      final duration = habit.durationMinutes;
      cursor = _nextFreeStart(cursor, duration, blockedWindows);
      final item = FinalTimelineItem(
        id: 'good-${habit.id}',
        title: habit.displayTitle,
        source: 'good_habit',
        startMinute: cursor,
        endMinute: cursor + duration,
        repeatDays: habit.repeatDays,
        blockType: habit.priority == GoodHabitDraft.mustDoPriority
            ? TimelineBlockDraft.flexibleTaskKey
            : TimelineBlockDraft.softBlockKey,
      );
      cursor += duration + 15;
      return item;
    }).toList();
  }

  List<FinalTimelineItem> _badHabitCheckIns(List<FinalTimelineItem> baseItems) {
    if (badHabitsNotNow || badHabits.isEmpty) return const [];
    final blockedWindows = baseItems
        .where((item) => item.blockType == TimelineBlockDraft.hardBlockKey)
        .toList();
    var cursor = 20 * 60;

    return badHabits.map((habit) {
      cursor = _nextFreeStart(cursor, 5, blockedWindows);
      final item = FinalTimelineItem(
        id: 'bad-check-${habit.id}',
        title: '${habit.displayName} check-in',
        source: 'bad_habit_check_in',
        startMinute: cursor,
        endMinute: cursor + 5,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.checkInKey,
      );
      cursor += 10;
      return item;
    }).toList();
  }

  List<FinalTimelineItem> _identitySystemItems() {
    final selectedSystemKeys = _dedupedIdentitySystemKeys();
    var cursor = 7 * 60;
    return selectedSystemKeys.map((systemKey) {
      final title = identitySystemTitle(systemKey);
      final item = FinalTimelineItem(
        id: 'identity-$systemKey',
        title: title,
        source: 'identity_system',
        startMinute: cursor,
        endMinute: cursor + 10,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.flexibleTaskKey,
      );
      cursor += 20;
      return item;
    }).toList();
  }

  List<String> _dedupedIdentitySystemKeys() {
    final keys = <String>{};
    for (final habit in goodHabits) {
      if (habit.habitKey == GoodHabitDraft.gymKey) keys.add('workout');
      if (habit.habitKey == GoodHabitDraft.meditationKey) {
        keys.add('meditation');
      }
      if (habit.habitKey == GoodHabitDraft.journalingKey) {
        keys.add('journaling');
      }
      if (habit.habitKey == GoodHabitDraft.languageLearningKey ||
          habit.subtypeKey == 'language') {
        keys.add('language_practice');
      }
      if (habit.subtypeKey == 'business_skill') keys.add('business_work');
    }
    if (badHabits.any((habit) => habit.dailySpend > 0)) {
      keys.add('bad_habit_money_saved');
    }
    for (final goal in identityGoals) {
      keys.addAll(goal.systemKeys);
    }
    return keys.toList();
  }

  List<String> _duplicateSystemKeysSkipped() {
    final raw = <String>[];
    for (final habit in goodHabits) {
      if (habit.habitKey == GoodHabitDraft.gymKey) raw.add('workout');
      if (habit.habitKey == GoodHabitDraft.meditationKey) raw.add('meditation');
      if (habit.habitKey == GoodHabitDraft.journalingKey) raw.add('journaling');
      if (habit.habitKey == GoodHabitDraft.languageLearningKey ||
          habit.subtypeKey == 'language') {
        raw.add('language_practice');
      }
      if (habit.subtypeKey == 'business_skill') raw.add('business_work');
    }
    if (badHabits.any((habit) => habit.dailySpend > 0)) {
      raw.add('bad_habit_money_saved');
    }
    for (final goal in identityGoals) {
      raw.addAll(goal.systemKeys);
    }

    final seen = <String>{};
    final duplicates = <String>{};
    for (final key in raw) {
      if (!seen.add(key)) duplicates.add(key);
    }
    return duplicates.toList();
  }

  static int _nextFreeStart(
    int desiredStart,
    int duration,
    List<FinalTimelineItem> blockedWindows,
  ) {
    var start = desiredStart;
    var moved = true;
    while (moved && start + duration <= 23 * 60) {
      moved = false;
      for (final block in blockedWindows) {
        final overlaps =
            start < block.endMinute && start + duration > block.startMinute;
        if (overlaps) {
          start = block.endMinute + 10;
          moved = true;
        }
      }
    }
    return start;
  }
}

class LifeRoleDraft {
  static const studentKey = 'student';
  static const workingKey = 'working';
  static const studentWorkingKey = 'student_working';
  static const businessKey = 'business';
  static const notStudentNotWorkingKey = 'not_student_not_working';

  final String? lifeRole;
  final String? workType;
  final String? businessMode;
  final String? exerciseLevel;
  final String? waterIntake;
  final String? stressLevel;
  final String? sleepQuality;

  const LifeRoleDraft({
    this.lifeRole,
    this.workType,
    this.businessMode,
    this.exerciseLevel,
    this.waterIntake,
    this.stressLevel,
    this.sleepQuality,
  });

  factory LifeRoleDraft.fromMap(Map<String, dynamic> map) {
    return LifeRoleDraft(
      lifeRole: map['lifeRole'] as String?,
      workType: map['workType'] as String?,
      businessMode: map['businessMode'] as String?,
      exerciseLevel: map['exerciseLevel'] as String?,
      waterIntake: map['waterIntake'] as String?,
      stressLevel: map['stressLevel'] as String?,
      sleepQuality: map['sleepQuality'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'lifeRole': lifeRole,
    'workType': workType,
    'businessMode': businessMode,
    'exerciseLevel': exerciseLevel,
    'waterIntake': waterIntake,
    'stressLevel': stressLevel,
    'sleepQuality': sleepQuality,
  };

  LifeRoleDraft copyWith({
    String? lifeRole,
    String? workType,
    String? businessMode,
    String? exerciseLevel,
    String? waterIntake,
    String? stressLevel,
    String? sleepQuality,
    bool clearWorkType = false,
    bool clearBusinessMode = false,
  }) {
    return LifeRoleDraft(
      lifeRole: lifeRole ?? this.lifeRole,
      workType: clearWorkType ? null : (workType ?? this.workType),
      businessMode: clearBusinessMode
          ? null
          : (businessMode ?? this.businessMode),
      exerciseLevel: exerciseLevel ?? this.exerciseLevel,
      waterIntake: waterIntake ?? this.waterIntake,
      stressLevel: stressLevel ?? this.stressLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
    );
  }

  bool get needsWorkType =>
      lifeRole == workingKey || lifeRole == studentWorkingKey;

  bool get needsBusinessMode => lifeRole == businessKey;

  bool get classesEnabled =>
      lifeRole == studentKey || lifeRole == studentWorkingKey;

  bool get jobEnabled =>
      lifeRole == workingKey ||
      lifeRole == studentWorkingKey ||
      lifeRole == businessKey;

  String? validate() {
    if (lifeRole == null) return 'Please select a lifestyle role.';
    if (needsWorkType && workType == null) {
      return 'Please select your work type.';
    }
    if (needsBusinessMode && businessMode == null) {
      return 'Please select your business schedule mode.';
    }
    if (exerciseLevel == null) return 'Please select your exercise level.';
    if (waterIntake == null) return 'Please select your water intake.';
    if (stressLevel == null) return 'Please select your stress level.';
    if (sleepQuality == null) return 'Please select your sleep quality.';
    return null;
  }
}

class BodyBasicsDraft {
  final String? ageRange;
  final double? heightCm;
  final double? weightKg;
  final String? gender;
  final double? bmiEstimate;
  final double? calorieEstimate;
  final double? proteinEstimate;
  final bool bodyDataCompleted;

  const BodyBasicsDraft({
    this.ageRange,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.bmiEstimate,
    this.calorieEstimate,
    this.proteinEstimate,
    this.bodyDataCompleted = false,
  });

  factory BodyBasicsDraft.fromMap(Map<String, dynamic> map) {
    return BodyBasicsDraft(
      ageRange: map['ageRange'] as String?,
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      gender: map['gender'] as String?,
      bmiEstimate: (map['bmiEstimate'] as num?)?.toDouble(),
      calorieEstimate: (map['calorieEstimate'] as num?)?.toDouble(),
      proteinEstimate: (map['proteinEstimate'] as num?)?.toDouble(),
      bodyDataCompleted: map['bodyDataCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'ageRange': ageRange,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'gender': gender,
    'bmiEstimate': bmiEstimate,
    'calorieEstimate': calorieEstimate,
    'proteinEstimate': proteinEstimate,
    'bodyDataCompleted': bodyDataCompleted,
  };

  BodyBasicsDraft copyWith({
    String? ageRange,
    double? heightCm,
    double? weightKg,
    String? gender,
    double? bmiEstimate,
    double? calorieEstimate,
    double? proteinEstimate,
    bool? bodyDataCompleted,
  }) {
    return BodyBasicsDraft(
      ageRange: ageRange ?? this.ageRange,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
      bmiEstimate: bmiEstimate ?? this.bmiEstimate,
      calorieEstimate: calorieEstimate ?? this.calorieEstimate,
      proteinEstimate: proteinEstimate ?? this.proteinEstimate,
      bodyDataCompleted: bodyDataCompleted ?? this.bodyDataCompleted,
    );
  }

  BodyBasicsDraft withEstimates() {
    final height = heightCm;
    final weight = weightKg;
    if (height == null || weight == null || height <= 0 || weight <= 0) {
      return copyWith(bodyDataCompleted: false);
    }
    final meters = height / 100.0;
    final bmi = weight / (meters * meters);
    final calories = weight * 24.0 * 1.3;
    final protein = weight * 2.0;
    return copyWith(
      bmiEstimate: double.parse(bmi.toStringAsFixed(1)),
      calorieEstimate: double.parse(calories.toStringAsFixed(0)),
      proteinEstimate: double.parse(protein.toStringAsFixed(0)),
      bodyDataCompleted:
          ageRange != null && gender != null && height > 0 && weight > 0,
    );
  }

  String? validate() {
    if (ageRange == null) return 'Please select your age range.';
    if (heightCm == null || heightCm! <= 0) {
      return 'Please set your height.';
    }
    if (weightKg == null || weightKg! <= 0) {
      return 'Please set your weight.';
    }
    if (gender == null) return 'Please select your gender.';
    return null;
  }
}

class BaseTimelineDraft {
  final List<TimelineBlockDraft> blocks;
  final String? businessMode;
  final String? workBestTime;
  final String? workPriority;
  final String? eatingMode;
  final bool? shouldPlanMeals;
  final String? mealPlanningGoal;
  final String? foodType;
  final String? mealBudget;
  final String? cookingAbility;
  final int? mealsPerDay;
  final bool skinCareSkipped;
  final List<String> pendingFutureImports;
  final List<String> acceptedConflictKeys;

  const BaseTimelineDraft({
    this.blocks = const [],
    this.businessMode,
    this.workBestTime,
    this.workPriority,
    this.eatingMode,
    this.shouldPlanMeals,
    this.mealPlanningGoal,
    this.foodType,
    this.mealBudget,
    this.cookingAbility,
    this.mealsPerDay,
    this.skinCareSkipped = false,
    this.pendingFutureImports = const [],
    this.acceptedConflictKeys = const [],
  });

  factory BaseTimelineDraft.fromMap(Map<String, dynamic> map) {
    return BaseTimelineDraft(
      blocks: _readList(
        map['blocks'],
        (value) => TimelineBlockDraft.fromMap(value),
      ),
      businessMode: map['businessMode'] as String?,
      workBestTime: map['workBestTime'] as String?,
      workPriority: map['workPriority'] as String?,
      eatingMode: map['eatingMode'] as String?,
      shouldPlanMeals: map['shouldPlanMeals'] as bool?,
      mealPlanningGoal: map['mealPlanningGoal'] as String?,
      foodType: map['foodType'] as String?,
      mealBudget: map['mealBudget'] as String?,
      cookingAbility: map['cookingAbility'] as String?,
      mealsPerDay: (map['mealsPerDay'] as num?)?.toInt(),
      skinCareSkipped: map['skinCareSkipped'] as bool? ?? false,
      pendingFutureImports: _readStringList(map['pendingFutureImports']),
      acceptedConflictKeys: _readStringList(map['acceptedConflictKeys']),
    );
  }

  Map<String, dynamic> toMap() => {
    'blocks': blocks.map((block) => block.toMap()).toList(),
    'businessMode': businessMode,
    'workBestTime': workBestTime,
    'workPriority': workPriority,
    'eatingMode': eatingMode,
    'shouldPlanMeals': shouldPlanMeals,
    'mealPlanningGoal': mealPlanningGoal,
    'foodType': foodType,
    'mealBudget': mealBudget,
    'cookingAbility': cookingAbility,
    'mealsPerDay': mealsPerDay,
    'skinCareSkipped': skinCareSkipped,
    'pendingFutureImports': pendingFutureImports,
    'acceptedConflictKeys': acceptedConflictKeys,
  };

  BaseTimelineDraft copyWith({
    List<TimelineBlockDraft>? blocks,
    String? businessMode,
    String? workBestTime,
    String? workPriority,
    String? eatingMode,
    bool? shouldPlanMeals,
    String? mealPlanningGoal,
    String? foodType,
    String? mealBudget,
    String? cookingAbility,
    int? mealsPerDay,
    bool? skinCareSkipped,
    List<String>? pendingFutureImports,
    List<String>? acceptedConflictKeys,
    bool clearMealPlanning = false,
  }) {
    return BaseTimelineDraft(
      blocks: blocks ?? this.blocks,
      businessMode: businessMode ?? this.businessMode,
      workBestTime: workBestTime ?? this.workBestTime,
      workPriority: workPriority ?? this.workPriority,
      eatingMode: eatingMode ?? this.eatingMode,
      shouldPlanMeals: clearMealPlanning
          ? null
          : (shouldPlanMeals ?? this.shouldPlanMeals),
      mealPlanningGoal: clearMealPlanning
          ? null
          : (mealPlanningGoal ?? this.mealPlanningGoal),
      foodType: clearMealPlanning ? null : (foodType ?? this.foodType),
      mealBudget: clearMealPlanning ? null : (mealBudget ?? this.mealBudget),
      cookingAbility: clearMealPlanning
          ? null
          : (cookingAbility ?? this.cookingAbility),
      mealsPerDay: clearMealPlanning ? null : (mealsPerDay ?? this.mealsPerDay),
      skinCareSkipped: skinCareSkipped ?? this.skinCareSkipped,
      pendingFutureImports: pendingFutureImports ?? this.pendingFutureImports,
      acceptedConflictKeys: acceptedConflictKeys ?? this.acceptedConflictKeys,
    );
  }

  BaseTimelineDraft upsertBlock(TimelineBlockDraft block) {
    final exists = blocks.any((item) => item.id == block.id);
    return copyWith(
      blocks: exists
          ? [
              for (final item in blocks)
                if (item.id == block.id) block else item,
            ]
          : [...blocks, block],
    );
  }

  BaseTimelineDraft deleteBlock(String id) {
    return copyWith(
      blocks: blocks.where((block) => block.id != id).toList(),
      acceptedConflictKeys: acceptedConflictKeys
          .where((key) => !key.contains(id))
          .toList(),
    );
  }

  BaseTimelineDraft addPendingImport(String section, String mode) {
    if (mode == 'Manual') return this;
    final key = '${section.toLowerCase().replaceAll(' ', '_')}:$mode';
    if (pendingFutureImports.contains(key)) return this;
    return copyWith(pendingFutureImports: [...pendingFutureImports, key]);
  }

  BaseTimelineDraft acceptConflict(String key) {
    if (acceptedConflictKeys.contains(key)) return this;
    return copyWith(acceptedConflictKeys: [...acceptedConflictKeys, key]);
  }

  List<TimelineConflictDraft> detectConflicts() {
    final conflicts = <TimelineConflictDraft>[];
    for (var i = 0; i < blocks.length; i++) {
      final first = blocks[i];
      if (first.needsTimeConfirmation) continue;
      for (var j = i + 1; j < blocks.length; j++) {
        final second = blocks[j];
        if (second.needsTimeConfirmation) continue;
        for (final day in first.repeatDays) {
          if (!second.repeatDays.contains(day)) continue;
          final overlaps =
              first.startMinute < second.endMinute &&
              first.endMinute > second.startMinute;
          if (!overlaps) continue;
          final key = TimelineConflictDraft.keyFor(first.id, second.id, day);
          final accepted = acceptedConflictKeys.contains(key);
          final hardConflict =
              first.blockType == TimelineBlockDraft.hardBlockKey &&
              second.blockType == TimelineBlockDraft.hardBlockKey;
          conflicts.add(
            TimelineConflictDraft(
              key: key,
              firstBlockId: first.id,
              secondBlockId: second.id,
              firstTitle: first.title,
              secondTitle: second.title,
              day: day,
              isHardConflict: hardConflict,
              accepted: accepted,
            ),
          );
        }
      }
    }
    return conflicts;
  }

  String? validateForRole(String? lifeRole) {
    final classesRequired =
        lifeRole == LifeRoleDraft.studentKey ||
        lifeRole == LifeRoleDraft.studentWorkingKey;
    final jobRequired =
        lifeRole == LifeRoleDraft.workingKey ||
        lifeRole == LifeRoleDraft.studentWorkingKey ||
        lifeRole == LifeRoleDraft.businessKey;
    if (lifeRole == null) {
      return 'Choose your role before setting the base timeline.';
    }
    if (classesRequired && !_hasConfirmedSection('classes')) {
      return 'Add at least one class block for your role.';
    }
    if (jobRequired && !_hasConfirmedSection('job_work_business')) {
      return 'Add at least one job/work/business block for your role.';
    }
    if (eatingMode == null) return 'Choose your eating mode.';
    if (!_hasConfirmedSection('eating')) {
      return 'Add at least one eating block.';
    }
    if (!_hasConfirmedSection('fixed')) {
      return 'Add at least one fixed block.';
    }
    final blocking = detectConflicts().where((conflict) => conflict.isBlocking);
    if (blocking.isNotEmpty) {
      return 'Resolve or explicitly keep hard-block timeline conflicts.';
    }
    return null;
  }

  bool _hasConfirmedSection(String section) {
    return blocks.any(
      (block) =>
          block.section == section &&
          !block.needsTimeConfirmation &&
          block.title.trim().isNotEmpty,
    );
  }
}

class TimelineBlockDraft {
  static const hardBlockKey = 'hard_block';
  static const softBlockKey = 'soft_block';
  static const flexibleTaskKey = 'flexible_task';
  static const checkInKey = 'check_in';

  final String id;
  final String section;
  final String title;
  final int startMinute;
  final int endMinute;
  final List<int> repeatDays;
  final String? location;
  final String blockType;
  final String source;
  final bool needsTimeConfirmation;
  final String? mealCategory;
  final List<String> dishes;
  final double? calories;
  final double? protein;
  final List<String> skincareProducts;

  const TimelineBlockDraft({
    required this.id,
    required this.section,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    required this.repeatDays,
    this.location,
    required this.blockType,
    this.source = 'manual',
    this.needsTimeConfirmation = false,
    this.mealCategory,
    this.dishes = const [],
    this.calories,
    this.protein,
    this.skincareProducts = const [],
  });

  factory TimelineBlockDraft.fromMap(Map<String, dynamic> map) {
    return TimelineBlockDraft(
      id: map['id'] as String? ?? '',
      section: map['section'] as String? ?? 'fixed',
      title: map['title'] as String? ?? '',
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      repeatDays: _readIntList(map['repeatDays']),
      location: map['location'] as String?,
      blockType: map['blockType'] as String? ?? softBlockKey,
      source: map['source'] as String? ?? 'manual',
      needsTimeConfirmation: map['needsTimeConfirmation'] as bool? ?? false,
      mealCategory: map['mealCategory'] as String?,
      dishes: _readStringList(map['dishes']),
      calories: (map['calories'] as num?)?.toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      skincareProducts: _readStringList(map['skincareProducts']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'section': section,
    'title': title,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'repeatDays': repeatDays,
    'location': location,
    'blockType': blockType,
    'source': source,
    'needsTimeConfirmation': needsTimeConfirmation,
    'mealCategory': mealCategory,
    'dishes': dishes,
    'calories': calories,
    'protein': protein,
    'skincareProducts': skincareProducts,
  };

  TimelineBlockDraft copyWith({
    String? id,
    String? section,
    String? title,
    int? startMinute,
    int? endMinute,
    List<int>? repeatDays,
    String? location,
    String? blockType,
    String? source,
    bool? needsTimeConfirmation,
    String? mealCategory,
    List<String>? dishes,
    double? calories,
    double? protein,
    List<String>? skincareProducts,
  }) {
    return TimelineBlockDraft(
      id: id ?? this.id,
      section: section ?? this.section,
      title: title ?? this.title,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      repeatDays: repeatDays ?? this.repeatDays,
      location: location ?? this.location,
      blockType: blockType ?? this.blockType,
      source: source ?? this.source,
      needsTimeConfirmation:
          needsTimeConfirmation ?? this.needsTimeConfirmation,
      mealCategory: mealCategory ?? this.mealCategory,
      dishes: dishes ?? this.dishes,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      skincareProducts: skincareProducts ?? this.skincareProducts,
    );
  }
}

class TimelineConflictDraft {
  final String key;
  final String firstBlockId;
  final String secondBlockId;
  final String firstTitle;
  final String secondTitle;
  final int day;
  final bool isHardConflict;
  final bool accepted;

  const TimelineConflictDraft({
    required this.key,
    required this.firstBlockId,
    required this.secondBlockId,
    required this.firstTitle,
    required this.secondTitle,
    required this.day,
    required this.isHardConflict,
    required this.accepted,
  });

  bool get isBlocking => isHardConflict && !accepted;

  factory TimelineConflictDraft.fromMap(Map<String, dynamic> map) {
    return TimelineConflictDraft(
      key: map['key'] as String? ?? '',
      firstBlockId: map['firstBlockId'] as String? ?? '',
      secondBlockId: map['secondBlockId'] as String? ?? '',
      firstTitle: map['firstTitle'] as String? ?? '',
      secondTitle: map['secondTitle'] as String? ?? '',
      day: (map['day'] as num?)?.toInt() ?? 1,
      isHardConflict: map['isHardConflict'] as bool? ?? false,
      accepted: map['accepted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'firstBlockId': firstBlockId,
    'secondBlockId': secondBlockId,
    'firstTitle': firstTitle,
    'secondTitle': secondTitle,
    'day': day,
    'isHardConflict': isHardConflict,
    'accepted': accepted,
  };

  static String keyFor(String firstId, String secondId, int day) {
    final ids = [firstId, secondId]..sort();
    return '${ids[0]}:${ids[1]}:$day';
  }
}

class BadHabitDraft {
  final String id;
  final String habitKey;
  final String displayName;
  final double dailySpend;
  final int lostTimeMinutes;
  final bool badHabitCheckInEnabled;
  final bool moneySavedTrackerEnabled;
  final bool relapseCravingAvoidedEnabled;
  final bool comebackSystemEnabled;

  const BadHabitDraft({
    required this.id,
    required this.habitKey,
    required this.displayName,
    this.dailySpend = 0,
    this.lostTimeMinutes = 0,
    this.badHabitCheckInEnabled = true,
    this.moneySavedTrackerEnabled = true,
    this.relapseCravingAvoidedEnabled = true,
    this.comebackSystemEnabled = true,
  });

  factory BadHabitDraft.fromMap(Map<String, dynamic> map) {
    return BadHabitDraft(
      id: map['id'] as String? ?? '',
      habitKey: map['habitKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      dailySpend: (map['dailySpend'] as num?)?.toDouble() ?? 0,
      lostTimeMinutes: (map['lostTimeMinutes'] as num?)?.toInt() ?? 0,
      badHabitCheckInEnabled: map['badHabitCheckInEnabled'] as bool? ?? true,
      moneySavedTrackerEnabled:
          map['moneySavedTrackerEnabled'] as bool? ?? true,
      relapseCravingAvoidedEnabled:
          map['relapseCravingAvoidedEnabled'] as bool? ?? true,
      comebackSystemEnabled: map['comebackSystemEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'habitKey': habitKey,
    'displayName': displayName,
    'dailySpend': dailySpend,
    'lostTimeMinutes': lostTimeMinutes,
    'badHabitCheckInEnabled': badHabitCheckInEnabled,
    'moneySavedTrackerEnabled': moneySavedTrackerEnabled,
    'relapseCravingAvoidedEnabled': relapseCravingAvoidedEnabled,
    'comebackSystemEnabled': comebackSystemEnabled,
  };

  BadHabitDraft copyWith({
    String? id,
    String? habitKey,
    String? displayName,
    double? dailySpend,
    int? lostTimeMinutes,
    bool? badHabitCheckInEnabled,
    bool? moneySavedTrackerEnabled,
    bool? relapseCravingAvoidedEnabled,
    bool? comebackSystemEnabled,
  }) {
    return BadHabitDraft(
      id: id ?? this.id,
      habitKey: habitKey ?? this.habitKey,
      displayName: displayName ?? this.displayName,
      dailySpend: dailySpend ?? this.dailySpend,
      lostTimeMinutes: lostTimeMinutes ?? this.lostTimeMinutes,
      badHabitCheckInEnabled:
          badHabitCheckInEnabled ?? this.badHabitCheckInEnabled,
      moneySavedTrackerEnabled:
          moneySavedTrackerEnabled ?? this.moneySavedTrackerEnabled,
      relapseCravingAvoidedEnabled:
          relapseCravingAvoidedEnabled ?? this.relapseCravingAvoidedEnabled,
      comebackSystemEnabled:
          comebackSystemEnabled ?? this.comebackSystemEnabled,
    );
  }
}

class GoodHabitDraft {
  static const gymKey = 'gym';
  static const skillPracticeKey = 'skill_practice';
  static const readingKey = 'reading';
  static const meditationKey = 'meditation';
  static const journalingKey = 'journaling';
  static const languageLearningKey = 'language_learning';
  static const customKey = 'custom';
  static const mustDoPriority = 'must_do';

  final String id;
  final String habitKey;
  final String displayName;
  final String? subtypeKey;
  final String? customSubtype;
  final int durationMinutes;
  final String frequency;
  final String bestTime;
  final String priority;
  final List<int> repeatDays;

  const GoodHabitDraft({
    required this.id,
    required this.habitKey,
    required this.displayName,
    this.subtypeKey,
    this.customSubtype,
    this.durationMinutes = 15,
    this.frequency = 'daily',
    this.bestTime = 'anytime',
    this.priority = 'good_to_do',
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
  });

  factory GoodHabitDraft.fromMap(Map<String, dynamic> map) {
    return GoodHabitDraft(
      id: map['id'] as String? ?? '',
      habitKey: map['habitKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      subtypeKey: map['subtypeKey'] as String?,
      customSubtype: map['customSubtype'] as String?,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 15,
      frequency: map['frequency'] as String? ?? 'daily',
      bestTime: map['bestTime'] as String? ?? 'anytime',
      priority: map['priority'] as String? ?? 'good_to_do',
      repeatDays: _readIntList(map['repeatDays']),
    );
  }

  String get displayTitle {
    final subtype = customSubtype ?? subtypeKey;
    if (subtype == null || subtype.isEmpty) return displayName;
    return '$displayName - ${subtype.replaceAll('_', ' ')}';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'habitKey': habitKey,
    'displayName': displayName,
    'subtypeKey': subtypeKey,
    'customSubtype': customSubtype,
    'durationMinutes': durationMinutes,
    'frequency': frequency,
    'bestTime': bestTime,
    'priority': priority,
    'repeatDays': repeatDays,
  };

  GoodHabitDraft copyWith({
    String? id,
    String? habitKey,
    String? displayName,
    String? subtypeKey,
    String? customSubtype,
    int? durationMinutes,
    String? frequency,
    String? bestTime,
    String? priority,
    List<int>? repeatDays,
  }) {
    return GoodHabitDraft(
      id: id ?? this.id,
      habitKey: habitKey ?? this.habitKey,
      displayName: displayName ?? this.displayName,
      subtypeKey: subtypeKey ?? this.subtypeKey,
      customSubtype: customSubtype ?? this.customSubtype,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      frequency: frequency ?? this.frequency,
      bestTime: bestTime ?? this.bestTime,
      priority: priority ?? this.priority,
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }
}

class IdentityGoalDraft {
  final String goalKey;
  final String displayName;
  final List<String> systemKeys;

  const IdentityGoalDraft({
    required this.goalKey,
    required this.displayName,
    required this.systemKeys,
  });

  factory IdentityGoalDraft.fromMap(Map<String, dynamic> map) {
    return IdentityGoalDraft(
      goalKey: map['goalKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      systemKeys: _readStringList(map['systemKeys']),
    );
  }

  Map<String, dynamic> toMap() => {
    'goalKey': goalKey,
    'displayName': displayName,
    'systemKeys': systemKeys,
  };
}

class CoachSetupDraft {
  final String? coachName;
  final String? customCoachName;
  final String? coachStyle;

  const CoachSetupDraft({
    this.coachName,
    this.customCoachName,
    this.coachStyle,
  });

  factory CoachSetupDraft.fromMap(Map<String, dynamic> map) {
    return CoachSetupDraft(
      coachName: map['coachName'] as String?,
      customCoachName: map['customCoachName'] as String?,
      coachStyle: map['coachStyle'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'coachName': coachName,
    'customCoachName': customCoachName,
    'coachStyle': coachStyle,
  };

  CoachSetupDraft copyWith({
    String? coachName,
    String? customCoachName,
    String? coachStyle,
    bool clearCustomCoachName = false,
  }) {
    return CoachSetupDraft(
      coachName: coachName ?? this.coachName,
      customCoachName: clearCustomCoachName
          ? null
          : (customCoachName ?? this.customCoachName),
      coachStyle: coachStyle ?? this.coachStyle,
    );
  }

  String? validate() {
    if (coachName == null || coachName!.trim().isEmpty) {
      return 'Choose a coach name.';
    }
    if (coachStyle == null) return 'Choose a coach style.';
    return null;
  }
}

class NotificationSetupDraft {
  final bool morningStartReminder;
  final bool nextTaskReminder;
  final bool eatingReminder;
  final bool badHabitCheckInReminder;
  final bool savingsReminder;
  final bool nightReflectionReminder;
  final String reminderIntensity;

  const NotificationSetupDraft({
    this.morningStartReminder = true,
    this.nextTaskReminder = true,
    this.eatingReminder = true,
    this.badHabitCheckInReminder = true,
    this.savingsReminder = false,
    this.nightReflectionReminder = true,
    this.reminderIntensity = 'medium',
  });

  factory NotificationSetupDraft.fromMap(Map<String, dynamic> map) {
    return NotificationSetupDraft(
      morningStartReminder: map['morningStartReminder'] as bool? ?? true,
      nextTaskReminder: map['nextTaskReminder'] as bool? ?? true,
      eatingReminder: map['eatingReminder'] as bool? ?? true,
      badHabitCheckInReminder: map['badHabitCheckInReminder'] as bool? ?? true,
      savingsReminder: map['savingsReminder'] as bool? ?? false,
      nightReflectionReminder: map['nightReflectionReminder'] as bool? ?? true,
      reminderIntensity: map['reminderIntensity'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() => {
    'morningStartReminder': morningStartReminder,
    'nextTaskReminder': nextTaskReminder,
    'eatingReminder': eatingReminder,
    'badHabitCheckInReminder': badHabitCheckInReminder,
    'savingsReminder': savingsReminder,
    'nightReflectionReminder': nightReflectionReminder,
    'reminderIntensity': reminderIntensity,
  };

  NotificationSetupDraft copyWith({
    bool? morningStartReminder,
    bool? nextTaskReminder,
    bool? eatingReminder,
    bool? badHabitCheckInReminder,
    bool? savingsReminder,
    bool? nightReflectionReminder,
    String? reminderIntensity,
  }) {
    return NotificationSetupDraft(
      morningStartReminder: morningStartReminder ?? this.morningStartReminder,
      nextTaskReminder: nextTaskReminder ?? this.nextTaskReminder,
      eatingReminder: eatingReminder ?? this.eatingReminder,
      badHabitCheckInReminder:
          badHabitCheckInReminder ?? this.badHabitCheckInReminder,
      savingsReminder: savingsReminder ?? this.savingsReminder,
      nightReflectionReminder:
          nightReflectionReminder ?? this.nightReflectionReminder,
      reminderIntensity: reminderIntensity ?? this.reminderIntensity,
    );
  }

  String? validate() {
    if (!const {'low', 'medium', 'high'}.contains(reminderIntensity)) {
      return 'Choose a reminder intensity.';
    }
    return null;
  }

  List<String> selectedLabels() {
    return [
      if (morningStartReminder) 'Morning start',
      if (nextTaskReminder) 'Next task',
      if (eatingReminder) 'Eating',
      if (badHabitCheckInReminder) 'Bad habit check-in',
      if (savingsReminder) 'Savings',
      if (nightReflectionReminder) 'Night reflection',
    ];
  }
}

class FinalTimelinePreview {
  final List<FinalTimelineItem> items;
  final List<String> warnings;
  final List<String> duplicateSystemKeysSkipped;

  const FinalTimelinePreview({
    this.items = const [],
    this.warnings = const [],
    this.duplicateSystemKeysSkipped = const [],
  });

  factory FinalTimelinePreview.fromMap(Map<String, dynamic> map) {
    return FinalTimelinePreview(
      items: _readList(
        map['items'],
        (value) => FinalTimelineItem.fromMap(value),
      ),
      warnings: _readStringList(map['warnings']),
      duplicateSystemKeysSkipped: _readStringList(
        map['duplicateSystemKeysSkipped'],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'items': items.map((item) => item.toMap()).toList(),
    'warnings': warnings,
    'duplicateSystemKeysSkipped': duplicateSystemKeysSkipped,
  };

  List<String> get blockingWarnings => warnings
      .where((warning) => warning.startsWith('Resolve or accept'))
      .toList();
}

class FinalTimelineItem {
  final String id;
  final String title;
  final String source;
  final int startMinute;
  final int endMinute;
  final List<int> repeatDays;
  final String blockType;

  const FinalTimelineItem({
    required this.id,
    required this.title,
    required this.source,
    required this.startMinute,
    required this.endMinute,
    required this.repeatDays,
    required this.blockType,
  });

  factory FinalTimelineItem.fromTimelineBlock(TimelineBlockDraft block) {
    return FinalTimelineItem(
      id: block.id,
      title: block.title,
      source: block.section,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      repeatDays: block.repeatDays,
      blockType: block.blockType,
    );
  }

  factory FinalTimelineItem.fromMap(Map<String, dynamic> map) {
    return FinalTimelineItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      source: map['source'] as String? ?? '',
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      repeatDays: _readIntList(map['repeatDays']),
      blockType: map['blockType'] as String? ?? TimelineBlockDraft.softBlockKey,
    );
  }

  int get durationMinutes => endMinute - startMinute;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'source': source,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'repeatDays': repeatDays,
    'blockType': blockType,
  };
}

String identitySystemTitle(String key) {
  return switch (key) {
    'save_10_day' => 'Save Rs 10/day',
    'bad_habit_money_saved' => 'Bad-habit money saved',
    'weekly_money_review' => 'Weekly money review',
    'workout' => 'Gym / workout',
    'sleep_routine' => 'Sleep routine',
    'protein_meal_reminder' => 'Protein / meal reminder',
    'non_negotiable_task' => 'One non-negotiable task',
    'wake_sleep_consistency' => 'Wake / sleep consistency',
    'daily_completion_score' => 'Daily completion score',
    'language_practice' => '10 min language practice',
    'five_words_daily' => 'Learn 5 words daily',
    'weekly_revision' => 'Weekly revision',
    'business_work' => '30 min business work',
    'weekly_planning' => 'Weekly planning',
    'project_tracker' => 'Idea / project tracker',
    'meditation' => 'Meditation',
    'journaling' => 'Journaling',
    'doom_scrolling_control' => 'Doom scrolling control',
    _ => key.replaceAll('_', ' '),
  };
}

List<T> _readList<T>(
  Object? value,
  T Function(Map<String, dynamic> value) parser,
) {
  return (value as List?)
          ?.whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList() ??
      <T>[];
}

List<String> _readStringList(Object? value) {
  return (value as List?)?.map((item) => item.toString()).toList() ??
      <String>[];
}

List<int> _readIntList(Object? value) {
  final list =
      (value as List?)
          ?.map((item) => (item as num?)?.toInt())
          .whereType<int>()
          .where((day) => day >= 1 && day <= 7)
          .toList() ??
      <int>[];
  return list.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : list;
}
