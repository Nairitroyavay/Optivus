class UserProfile {
  final String id;
  final String email;
  final String displayName;

  // Lifestyle Role
  final String lifeRole; // e.g. Student, Working Person, etc.
  final String? workingExtra; // e.g. Full-time, Remote, Shift work, Freelancer
  final String? businessMode; // e.g. Fixed hours, Flexible work, Mixed

  // Lifestyle Attributes
  final String exerciseLevel;
  final String waterIntake;
  final String stressLevel;
  final String sleepQuality;

  // Body Basics
  final String ageRange;
  final double height; // cm or feet/inches representation
  final double weight; // kg or lb
  final String gender;

  // Estimates
  final double bmiEstimate;
  final double calorieEstimate;
  final double proteinEstimate;

  // Onboarding Status
  final bool hasCompletedOnboarding;
  final int onboardingStep;

  // Selected Coach Preferences
  final String coachName;
  final String coachStyle;
  final String slipUpStyle;

  UserProfile({
    this.id = 'mock-user-123',
    this.email = 'user@optivus.app',
    this.displayName = 'Member',
    this.lifeRole = '',
    this.workingExtra,
    this.businessMode,
    this.exerciseLevel = '',
    this.waterIntake = '',
    this.stressLevel = '',
    this.sleepQuality = '',
    this.ageRange = '',
    this.height = 0.0,
    this.weight = 0.0,
    this.gender = '',
    this.bmiEstimate = 0.0,
    this.calorieEstimate = 0.0,
    this.proteinEstimate = 0.0,
    this.hasCompletedOnboarding = false,
    this.onboardingStep = 0,
    this.coachName = '',
    this.coachStyle = '',
    this.slipUpStyle = '',
  });

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? lifeRole,
    String? workingExtra,
    String? businessMode,
    String? exerciseLevel,
    String? waterIntake,
    String? stressLevel,
    String? sleepQuality,
    String? ageRange,
    double? height,
    double? weight,
    String? gender,
    double? bmiEstimate,
    double? calorieEstimate,
    double? proteinEstimate,
    bool? hasCompletedOnboarding,
    int? onboardingStep,
    String? coachName,
    String? coachStyle,
    String? slipUpStyle,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      lifeRole: lifeRole ?? this.lifeRole,
      workingExtra: workingExtra ?? this.workingExtra,
      businessMode: businessMode ?? this.businessMode,
      exerciseLevel: exerciseLevel ?? this.exerciseLevel,
      waterIntake: waterIntake ?? this.waterIntake,
      stressLevel: stressLevel ?? this.stressLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      ageRange: ageRange ?? this.ageRange,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      bmiEstimate: bmiEstimate ?? this.bmiEstimate,
      calorieEstimate: calorieEstimate ?? this.calorieEstimate,
      proteinEstimate: proteinEstimate ?? this.proteinEstimate,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      coachName: coachName ?? this.coachName,
      coachStyle: coachStyle ?? this.coachStyle,
      slipUpStyle: slipUpStyle ?? this.slipUpStyle,
    );
  }
}
