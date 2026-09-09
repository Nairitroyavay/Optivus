/// Semantic identity and canonical persisted order for the current onboarding
/// product. Firestore continues to store numeric progression fields.
enum OnboardingStepId {
  welcome('Welcome'),
  patience('Patience'),
  roleLifestyle('Role / Lifestyle'),
  bodyBasics('Body Basics'),
  classesJob('Classes & Job'),
  eating('Eating'),
  fixedSchedule('Fixed Schedule'),
  skinCare('Skin Care'),
  badHabits('Bad Habits'),
  goodHabits('Good Habits'),
  identityGoals('Identity Goals'),
  coachSetup('Coach Setup'),
  slipUp('Slip-up'),
  notifications('Notifications'),
  todayReady('Today Ready');

  const OnboardingStepId(this.label);

  final String label;

  /// Version of the frozen durable-completion contract owned by this step.
  /// Interactive screen validation may evolve independently. Breaking a
  /// persisted completion contract requires a new version and migration.
  int get durableCompletionContractVersion => 1;

  static OnboardingStepId? fromIndex(int index) {
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// The single current 15-page product order.
const List<OnboardingStepId> currentOnboardingStepOrder =
    OnboardingStepId.values;

/// Explicit historical 12-page identity mapping. Legacy step 4 was the
/// combined Base Timeline boundary and maps to the first page of its current
/// four-page replacement.
OnboardingStepId? legacyOnboardingIndexToCurrentStepId(int legacyIndex) {
  return switch (legacyIndex) {
    0 => OnboardingStepId.welcome,
    1 => OnboardingStepId.patience,
    2 => OnboardingStepId.roleLifestyle,
    3 => OnboardingStepId.bodyBasics,
    4 => OnboardingStepId.classesJob,
    5 => OnboardingStepId.badHabits,
    6 => OnboardingStepId.goodHabits,
    7 => OnboardingStepId.identityGoals,
    8 => OnboardingStepId.coachSetup,
    9 => OnboardingStepId.slipUp,
    10 => OnboardingStepId.notifications,
    11 => OnboardingStepId.todayReady,
    _ => null,
  };
}
