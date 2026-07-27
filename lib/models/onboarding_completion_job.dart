import 'package:cloud_firestore/cloud_firestore.dart';

enum OnboardingCompletionStage {
  init,
  persistDraft,
  persistBundle,
  projectRoutines,
  projectHabits,
  updateProfile,
  completed,
}

enum OnboardingJobStatus { pending, inProgress, completed, failed }

class OnboardingCompletionFailure {
  final String code;
  final OnboardingCompletionStage stage;
  final bool retryable;
  final String publicMessageKey;
  final String diagnosticCategory;
  final List<String> failedEntityIds;
  final DateTime occurredAt;

  const OnboardingCompletionFailure({
    required this.code,
    required this.stage,
    required this.retryable,
    required this.publicMessageKey,
    required this.diagnosticCategory,
    required this.failedEntityIds,
    required this.occurredAt,
  });
}

class OnboardingCompletionFailureException implements Exception {
  final OnboardingCompletionFailure failure;

  const OnboardingCompletionFailureException(this.failure);

  String get code => failure.code;
  OnboardingCompletionStage get stage => failure.stage;
  bool get retryable => failure.retryable;
  String get publicMessageKey => failure.publicMessageKey;
  String get diagnosticCategory => failure.diagnosticCategory;
  List<String> get failedEntityIds => failure.failedEntityIds;

  @override
  String toString() =>
      'OnboardingCompletionFailureException(${failure.code}, ${failure.stage.name})';
}

class OnboardingCompletionJob {
  static const int currentSchemaVersion = 1;

  final String jobId;
  final String uid;
  final OnboardingJobStatus status;
  final OnboardingCompletionStage stage;
  final Map<String, bool> stagesCompleted;
  final String? sourceFingerprint;
  final int retryCount;
  final String? lastError;
  final String? lastFailureCode;
  final String? lastFailureStage;
  final bool? retryable;
  final String? publicMessageKey;
  final String? diagnosticCategory;
  final List<String> failedEntityIds;
  final DateTime? lastFailureOccurredAt;
  final List<String> expectedRoutineIds;
  final List<String> appliedRoutineIds;
  final List<String> existingRoutineIds;
  final List<String> repairedRoutineIds;
  final List<String> failedRoutineIds;
  final List<String> expectedHistoryIds;
  final List<String> appliedHistoryIds;
  final List<String> failedHistoryIds;
  final List<String> expectedHabitIds;
  final List<String> appliedHabitIds;
  final List<String> existingHabitIds;
  final List<String> repairedHabitIds;
  final List<String> failedHabitIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const OnboardingCompletionJob({
    required this.jobId,
    required this.uid,
    this.status = OnboardingJobStatus.pending,
    this.stage = OnboardingCompletionStage.init,
    this.stagesCompleted = const {},
    this.sourceFingerprint,
    this.retryCount = 0,
    this.lastError,
    this.lastFailureCode,
    this.lastFailureStage,
    this.retryable,
    this.publicMessageKey,
    this.diagnosticCategory,
    this.failedEntityIds = const [],
    this.lastFailureOccurredAt,
    this.expectedRoutineIds = const [],
    this.appliedRoutineIds = const [],
    this.existingRoutineIds = const [],
    this.repairedRoutineIds = const [],
    this.failedRoutineIds = const [],
    this.expectedHistoryIds = const [],
    this.appliedHistoryIds = const [],
    this.failedHistoryIds = const [],
    this.expectedHabitIds = const [],
    this.appliedHabitIds = const [],
    this.existingHabitIds = const [],
    this.repairedHabitIds = const [],
    this.failedHabitIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  bool isStageCompleted(OnboardingCompletionStage s) {
    return stagesCompleted[s.name] == true;
  }

  OnboardingCompletionJob copyWith({
    String? jobId,
    String? uid,
    OnboardingJobStatus? status,
    OnboardingCompletionStage? stage,
    Map<String, bool>? stagesCompleted,
    String? sourceFingerprint,
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
    String? lastFailureCode,
    String? lastFailureStage,
    bool? retryable,
    String? publicMessageKey,
    String? diagnosticCategory,
    List<String>? failedEntityIds,
    DateTime? lastFailureOccurredAt,
    bool clearLastFailure = false,
    List<String>? expectedRoutineIds,
    List<String>? appliedRoutineIds,
    List<String>? existingRoutineIds,
    List<String>? repairedRoutineIds,
    List<String>? failedRoutineIds,
    List<String>? expectedHistoryIds,
    List<String>? appliedHistoryIds,
    List<String>? failedHistoryIds,
    List<String>? expectedHabitIds,
    List<String>? appliedHabitIds,
    List<String>? existingHabitIds,
    List<String>? repairedHabitIds,
    List<String>? failedHabitIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? schemaVersion,
  }) {
    return OnboardingCompletionJob(
      jobId: jobId ?? this.jobId,
      uid: uid ?? this.uid,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      stagesCompleted: stagesCompleted ?? this.stagesCompleted,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      lastFailureCode: clearLastFailure
          ? null
          : (lastFailureCode ?? this.lastFailureCode),
      lastFailureStage: clearLastFailure
          ? null
          : (lastFailureStage ?? this.lastFailureStage),
      retryable: clearLastFailure ? null : (retryable ?? this.retryable),
      publicMessageKey: clearLastFailure
          ? null
          : (publicMessageKey ?? this.publicMessageKey),
      diagnosticCategory: clearLastFailure
          ? null
          : (diagnosticCategory ?? this.diagnosticCategory),
      failedEntityIds: clearLastFailure
          ? const []
          : (failedEntityIds ?? this.failedEntityIds),
      lastFailureOccurredAt: clearLastFailure
          ? null
          : (lastFailureOccurredAt ?? this.lastFailureOccurredAt),
      expectedRoutineIds: expectedRoutineIds ?? this.expectedRoutineIds,
      appliedRoutineIds: appliedRoutineIds ?? this.appliedRoutineIds,
      existingRoutineIds: existingRoutineIds ?? this.existingRoutineIds,
      repairedRoutineIds: repairedRoutineIds ?? this.repairedRoutineIds,
      failedRoutineIds: failedRoutineIds ?? this.failedRoutineIds,
      expectedHistoryIds: expectedHistoryIds ?? this.expectedHistoryIds,
      appliedHistoryIds: appliedHistoryIds ?? this.appliedHistoryIds,
      failedHistoryIds: failedHistoryIds ?? this.failedHistoryIds,
      expectedHabitIds: expectedHabitIds ?? this.expectedHabitIds,
      appliedHabitIds: appliedHabitIds ?? this.appliedHabitIds,
      existingHabitIds: existingHabitIds ?? this.existingHabitIds,
      repairedHabitIds: repairedHabitIds ?? this.repairedHabitIds,
      failedHabitIds: failedHabitIds ?? this.failedHabitIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'uid': uid,
      'status': status.name,
      'stage': stage.name,
      'stagesCompleted': stagesCompleted,
      if (sourceFingerprint != null) 'sourceFingerprint': sourceFingerprint,
      'retryCount': retryCount,
      if (lastError != null) 'lastError': lastError,
      if (lastFailureCode != null) 'lastFailureCode': lastFailureCode,
      if (lastFailureStage != null) 'lastFailureStage': lastFailureStage,
      if (retryable != null) 'retryable': retryable,
      if (publicMessageKey != null) 'publicMessageKey': publicMessageKey,
      if (diagnosticCategory != null)
        'diagnosticCategory': diagnosticCategory,
      'failedEntityIds': failedEntityIds,
      if (lastFailureOccurredAt != null)
        'lastFailureOccurredAt': lastFailureOccurredAt!.toIso8601String(),
      'expectedRoutineIds': expectedRoutineIds,
      'appliedRoutineIds': appliedRoutineIds,
      'existingRoutineIds': existingRoutineIds,
      'repairedRoutineIds': repairedRoutineIds,
      'failedRoutineIds': failedRoutineIds,
      'expectedHistoryIds': expectedHistoryIds,
      'appliedHistoryIds': appliedHistoryIds,
      'failedHistoryIds': failedHistoryIds,
      'expectedHabitIds': expectedHabitIds,
      'appliedHabitIds': appliedHabitIds,
      'existingHabitIds': existingHabitIds,
      'repairedHabitIds': repairedHabitIds,
      'failedHabitIds': failedHabitIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }

  factory OnboardingCompletionJob.fromMap(Map<String, dynamic> map) {
    final stagesRaw = map['stagesCompleted'];
    Map<String, bool> stagesCompleted = {};
    if (stagesRaw is Map) {
      stagesCompleted = Map<String, bool>.from(stagesRaw);
    }
    return OnboardingCompletionJob(
      jobId: map['jobId'] as String? ?? 'current',
      uid: map['uid'] as String? ?? '',
      status: _parseEnum(
        OnboardingJobStatus.values,
        map['status'],
        OnboardingJobStatus.pending,
      ),
      stage: _parseEnum(
        OnboardingCompletionStage.values,
        map['stage'],
        OnboardingCompletionStage.init,
      ),
      stagesCompleted: stagesCompleted,
      sourceFingerprint: map['sourceFingerprint'] as String?,
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
      lastFailureCode: map['lastFailureCode'] as String?,
      lastFailureStage: map['lastFailureStage'] as String?,
      retryable: map['retryable'] as bool?,
      publicMessageKey: map['publicMessageKey'] as String?,
      diagnosticCategory: map['diagnosticCategory'] as String?,
      failedEntityIds: _parseStringList(map['failedEntityIds']),
      lastFailureOccurredAt: _parseDateTime(map['lastFailureOccurredAt']),
      expectedRoutineIds: _parseStringList(map['expectedRoutineIds']),
      appliedRoutineIds: _parseStringList(map['appliedRoutineIds']),
      existingRoutineIds: _parseStringList(map['existingRoutineIds']),
      repairedRoutineIds: _parseStringList(map['repairedRoutineIds']),
      failedRoutineIds: _parseStringList(map['failedRoutineIds']),
      expectedHistoryIds: _parseStringList(map['expectedHistoryIds']),
      appliedHistoryIds: _parseStringList(map['appliedHistoryIds']),
      failedHistoryIds: _parseStringList(map['failedHistoryIds']),
      expectedHabitIds: _parseStringList(map['expectedHabitIds']),
      appliedHabitIds: _parseStringList(map['appliedHabitIds']),
      existingHabitIds: _parseStringList(map['existingHabitIds']),
      repairedHabitIds: _parseStringList(map['repairedHabitIds']),
      failedHabitIds: _parseStringList(map['failedHabitIds']),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      schemaVersion: map['schemaVersion'] as int? ?? currentSchemaVersion,
    );
  }

  static T _parseEnum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is String) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
    }
    return fallback;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const [];
    return List<String>.unmodifiable(
      value.whereType<String>().where((id) => id.trim().isNotEmpty),
    );
  }
}
