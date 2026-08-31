import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  static const int currentSchemaVersion = 1;

  final String uid;
  final String email;
  final String displayName;
  final String accountStatus;
  final int schemaVersion;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Onboarding Status
  final bool onboardingInputCompleted;
  final String onboardingProjectionStatus;
  final int onboardingStep;

  bool get onboardingCompleted =>
      onboardingInputCompleted && onboardingProjectionStatus == 'completed';

  // Lifestyle Role
  final String lifeRole;
  final String? workingExtra;
  final String? businessMode;

  // Lifestyle Attributes
  final String exerciseLevel;
  final String waterIntake;
  final String stressLevel;
  final String sleepQuality;

  // Body Basics
  final String ageRange;
  final double height;
  final double weight;
  final String gender;

  // Estimates
  final double bmiEstimate;
  final double calorieEstimate;
  final double proteinEstimate;

  // Selected Coach Preferences
  final String coachName;
  final String coachStyle;
  final String slipUpStyle;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.accountStatus = 'active',
    this.schemaVersion = currentSchemaVersion,
    this.createdAt,
    this.updatedAt,
    bool? onboardingInputCompleted,
    String? onboardingProjectionStatus,
    bool onboardingCompleted = false,
    this.onboardingStep = 0,
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
    this.coachName = '',
    this.coachStyle = '',
    this.slipUpStyle = '',
  }) : onboardingInputCompleted =
           onboardingInputCompleted ?? (onboardingCompleted || false),
       onboardingProjectionStatus =
           onboardingProjectionStatus ??
           (onboardingCompleted ? 'completed' : 'none');

  factory UserProfile.empty({
    required String uid,
    String email = '',
    String displayName = '',
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      accountStatus: 'active',
      onboardingInputCompleted: false,
      onboardingProjectionStatus: 'none',
      onboardingCompleted: false,
      onboardingStep: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'accountStatus': accountStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'schemaVersion': schemaVersion,
      'onboardingInputCompleted': onboardingInputCompleted,
      'onboardingProjectionStatus': onboardingProjectionStatus,
      'onboardingCompleted': onboardingCompleted,
      'onboardingStep': onboardingStep,
      'lifeRole': lifeRole,
      if (workingExtra != null) 'workingExtra': workingExtra,
      if (businessMode != null) 'businessMode': businessMode,
      'exerciseLevel': exerciseLevel,
      'waterIntake': waterIntake,
      'stressLevel': stressLevel,
      'sleepQuality': sleepQuality,
      'ageRange': ageRange,
      'height': height,
      'weight': weight,
      'gender': gender,
      'bmiEstimate': bmiEstimate,
      'calorieEstimate': calorieEstimate,
      'proteinEstimate': proteinEstimate,
      'coachName': coachName,
      'coachStyle': coachStyle,
      'slipUpStyle': slipUpStyle,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'accountStatus': accountStatus,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'schemaVersion': schemaVersion,
      'onboardingInputCompleted': onboardingInputCompleted,
      'onboardingProjectionStatus': onboardingProjectionStatus,
      'onboardingCompleted': onboardingCompleted,
      'onboardingStep': onboardingStep,
      'lifeRole': lifeRole,
      if (workingExtra != null) 'workingExtra': workingExtra,
      if (businessMode != null) 'businessMode': businessMode,
      'exerciseLevel': exerciseLevel,
      'waterIntake': waterIntake,
      'stressLevel': stressLevel,
      'sleepQuality': sleepQuality,
      'ageRange': ageRange,
      'height': height,
      'weight': weight,
      'gender': gender,
      'bmiEstimate': bmiEstimate,
      'calorieEstimate': calorieEstimate,
      'proteinEstimate': proteinEstimate,
      'coachName': coachName,
      'coachStyle': coachStyle,
      'slipUpStyle': slipUpStyle,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final legacyCompleted = map['onboardingCompleted'] as bool? ?? false;
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      accountStatus: map['accountStatus'] as String? ?? 'active',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAt: _dateTimeFromMapValue(map['createdAt']),
      updatedAt: _dateTimeFromMapValue(map['updatedAt']),
      onboardingInputCompleted:
          map['onboardingInputCompleted'] as bool? ?? legacyCompleted,
      onboardingProjectionStatus:
          map['onboardingProjectionStatus'] as String? ??
          (legacyCompleted ? 'completed' : 'none'),
      onboardingCompleted: legacyCompleted,
      onboardingStep: map['onboardingStep'] as int? ?? 0,
      lifeRole: map['lifeRole'] as String? ?? '',
      workingExtra: map['workingExtra'] as String?,
      businessMode: map['businessMode'] as String?,
      exerciseLevel: map['exerciseLevel'] as String? ?? '',
      waterIntake: map['waterIntake'] as String? ?? '',
      stressLevel: map['stressLevel'] as String? ?? '',
      sleepQuality: map['sleepQuality'] as String? ?? '',
      ageRange: map['ageRange'] as String? ?? '',
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      gender: map['gender'] as String? ?? '',
      bmiEstimate: (map['bmiEstimate'] as num?)?.toDouble() ?? 0.0,
      calorieEstimate: (map['calorieEstimate'] as num?)?.toDouble() ?? 0.0,
      proteinEstimate: (map['proteinEstimate'] as num?)?.toDouble() ?? 0.0,
      coachName: map['coachName'] as String? ?? '',
      coachStyle: map['coachStyle'] as String? ?? '',
      slipUpStyle: map['slipUpStyle'] as String? ?? '',
    );
  }

  factory UserProfile.fromFirestoreMap(Map<String, dynamic> map) {
    return UserProfile.fromMap(map);
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? accountStatus,
    int? schemaVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? onboardingInputCompleted,
    String? onboardingProjectionStatus,
    bool? onboardingCompleted,
    int? onboardingStep,
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
    String? coachName,
    String? coachStyle,
    String? slipUpStyle,
  }) {
    final nextInputCompleted =
        onboardingInputCompleted ??
        onboardingCompleted ??
        this.onboardingInputCompleted;
    final nextProjectionStatus =
        onboardingProjectionStatus ??
        (onboardingCompleted != null
            ? (onboardingCompleted ? 'completed' : 'none')
            : this.onboardingProjectionStatus);
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      accountStatus: accountStatus ?? this.accountStatus,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onboardingInputCompleted: nextInputCompleted,
      onboardingProjectionStatus: nextProjectionStatus,
      onboardingStep: onboardingStep ?? this.onboardingStep,
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
      coachName: coachName ?? this.coachName,
      coachStyle: coachStyle ?? this.coachStyle,
      slipUpStyle: slipUpStyle ?? this.slipUpStyle,
    );
  }
}

DateTime? _dateTimeFromMapValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
