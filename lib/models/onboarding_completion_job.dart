import 'package:cloud_firestore/cloud_firestore.dart';

enum OnboardingCompletionStage {
  validateInput,
  persistDraft,
  verifyDraft,
  persistBundle,
  verifyBundle,
  reconcileRoutines,
  verifyRoutines,
  projectRoutineHistory,
  verifyRoutineHistory,
  reconcileHabitSystems,
  verifyHabitSystems,
  reloadControllers,
  verifyFrontendState,
  finalizeProfile,
  completed;

  // Source-compatible aliases for callers compiled against the pre-v2 model.
  // They serialize to the canonical v2 values above and are never accepted by
  // Firestore Rules as separate enum strings.
  @Deprecated('Use validateInput')
  static const init = validateInput;
  @Deprecated('Use reconcileRoutines')
  static const projectRoutines = reconcileRoutines;
  @Deprecated('Use reconcileHabitSystems')
  static const projectHabits = reconcileHabitSystems;
  @Deprecated('Use finalizeProfile')
  static const updateProfile = finalizeProfile;
}

enum OnboardingJobStatus {
  pending,
  running,
  retryableFailure,
  fatalFailure,
  completed;

  @Deprecated('Use running')
  static const inProgress = running;
  @Deprecated('Use retryableFailure or fatalFailure')
  static const failed = retryableFailure;
}

class OnboardingCompletionFailure {
  final String code;
  final OnboardingCompletionStage stage;
  final bool retryable;
  final String publicMessageKey;
  final String diagnosticCategory;
  final String safeCauseType;
  final List<String> failedEntityIds;
  final DateTime occurredAt;

  const OnboardingCompletionFailure({
    required this.code,
    required this.stage,
    required this.retryable,
    required this.publicMessageKey,
    required this.diagnosticCategory,
    this.safeCauseType = 'unknown',
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
  String get safeCauseType => failure.safeCauseType;
  List<String> get failedEntityIds => failure.failedEntityIds;

  @override
  String toString() =>
      'OnboardingCompletionFailureException(${failure.code}, ${failure.stage.name})';
}

class OnboardingCompletionJob {
  static const int currentSchemaVersion = 3;

  final String jobId;
  final String ownerUid;
  final OnboardingJobStatus status;
  final OnboardingCompletionStage stage;
  final Map<String, bool> stagesCompleted;
  final String sourceFingerprint;
  final int draftRevision;
  final int retryCount;

  // Kept in memory/read compatibility for legacy tests and documents. It is
  // sanitized and deliberately omitted from canonical Firestore writes.
  final String? lastError;
  final String? lastFailureCode;
  final String? lastFailureStage;
  final bool? retryable;
  final String? publicMessageKey;
  final String? diagnosticCategory;
  final String? safeCauseType;
  final List<String> failedEntityIds;
  final DateTime? lastFailureOccurredAt;

  final List<String> expectedRoutineIds;
  final List<String> appliedRoutineIds;
  final List<String> existingRoutineIds;
  final List<String> repairedRoutineIds;
  final List<String> failedRoutineIds;
  final List<String> expectedHistoryIds;
  final List<String> appliedHistoryIds;
  final List<String> existingHistoryIds;
  final List<String> repairedHistoryIds;
  final List<String> failedHistoryIds;
  final List<String> expectedHabitIds;
  final List<String> appliedHabitIds;
  final List<String> existingHabitIds;
  final List<String> repairedHabitIds;
  final List<String> failedHabitIds;
  final List<String> expectedAcceptanceIds;
  final List<String> appliedAcceptanceIds;
  final List<String> existingAcceptanceIds;
  final List<String> repairedAcceptanceIds;
  final List<String> failedAcceptanceIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int schemaVersion;

  OnboardingCompletionJob({
    required this.jobId,
    String? ownerUid,
    String? uid,
    this.status = OnboardingJobStatus.pending,
    this.stage = OnboardingCompletionStage.validateInput,
    this.stagesCompleted = const {},
    this.sourceFingerprint = '',
    this.draftRevision = 1,
    this.retryCount = 0,
    this.lastError,
    this.lastFailureCode,
    this.lastFailureStage,
    this.retryable,
    this.publicMessageKey,
    this.diagnosticCategory,
    this.safeCauseType,
    this.failedEntityIds = const [],
    this.lastFailureOccurredAt,
    this.expectedRoutineIds = const [],
    this.appliedRoutineIds = const [],
    this.existingRoutineIds = const [],
    this.repairedRoutineIds = const [],
    this.failedRoutineIds = const [],
    this.expectedHistoryIds = const [],
    this.appliedHistoryIds = const [],
    this.existingHistoryIds = const [],
    this.repairedHistoryIds = const [],
    this.failedHistoryIds = const [],
    this.expectedHabitIds = const [],
    this.appliedHabitIds = const [],
    this.existingHabitIds = const [],
    this.repairedHabitIds = const [],
    this.failedHabitIds = const [],
    this.expectedAcceptanceIds = const [],
    this.appliedAcceptanceIds = const [],
    this.existingAcceptanceIds = const [],
    this.repairedAcceptanceIds = const [],
    this.failedAcceptanceIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.schemaVersion = currentSchemaVersion,
  }) : assert(ownerUid != null || uid != null),
       ownerUid = ownerUid ?? uid!;

  @Deprecated('Use ownerUid')
  String get uid => ownerUid;

  List<String> get createdRoutineIds => appliedRoutineIds;
  List<String> get createdHabitIds => appliedHabitIds;

  bool isStageCompleted(OnboardingCompletionStage value) {
    return stagesCompleted[value.name] == true;
  }

  OnboardingCompletionJob copyWith({
    String? jobId,
    String? ownerUid,
    String? uid,
    OnboardingJobStatus? status,
    OnboardingCompletionStage? stage,
    Map<String, bool>? stagesCompleted,
    String? sourceFingerprint,
    int? draftRevision,
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
    String? lastFailureCode,
    String? lastFailureStage,
    bool? retryable,
    String? publicMessageKey,
    String? diagnosticCategory,
    String? safeCauseType,
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
    List<String>? existingHistoryIds,
    List<String>? repairedHistoryIds,
    List<String>? failedHistoryIds,
    List<String>? expectedHabitIds,
    List<String>? appliedHabitIds,
    List<String>? existingHabitIds,
    List<String>? repairedHabitIds,
    List<String>? failedHabitIds,
    List<String>? expectedAcceptanceIds,
    List<String>? appliedAcceptanceIds,
    List<String>? existingAcceptanceIds,
    List<String>? repairedAcceptanceIds,
    List<String>? failedAcceptanceIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? schemaVersion,
  }) {
    return OnboardingCompletionJob(
      jobId: jobId ?? this.jobId,
      ownerUid: ownerUid ?? uid ?? this.ownerUid,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      stagesCompleted: stagesCompleted ?? this.stagesCompleted,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      draftRevision: draftRevision ?? this.draftRevision,
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
      safeCauseType: clearLastFailure
          ? null
          : (safeCauseType ?? this.safeCauseType),
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
      existingHistoryIds: existingHistoryIds ?? this.existingHistoryIds,
      repairedHistoryIds: repairedHistoryIds ?? this.repairedHistoryIds,
      failedHistoryIds: failedHistoryIds ?? this.failedHistoryIds,
      expectedHabitIds: expectedHabitIds ?? this.expectedHabitIds,
      appliedHabitIds: appliedHabitIds ?? this.appliedHabitIds,
      existingHabitIds: existingHabitIds ?? this.existingHabitIds,
      repairedHabitIds: repairedHabitIds ?? this.repairedHabitIds,
      failedHabitIds: failedHabitIds ?? this.failedHabitIds,
      expectedAcceptanceIds:
          expectedAcceptanceIds ?? this.expectedAcceptanceIds,
      appliedAcceptanceIds: appliedAcceptanceIds ?? this.appliedAcceptanceIds,
      existingAcceptanceIds:
          existingAcceptanceIds ?? this.existingAcceptanceIds,
      repairedAcceptanceIds:
          repairedAcceptanceIds ?? this.repairedAcceptanceIds,
      failedAcceptanceIds: failedAcceptanceIds ?? this.failedAcceptanceIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'ownerUid': ownerUid,
      'status': status.name,
      'stage': stage.name,
      'stagesCompleted': stagesCompleted,
      'sourceFingerprint': sourceFingerprint,
      'draftRevision': draftRevision,
      'retryCount': retryCount,
      if (lastFailureCode != null) 'failureCode': lastFailureCode,
      if (lastFailureStage != null) 'failureStage': lastFailureStage,
      if (retryable != null) 'retryable': retryable,
      if (publicMessageKey != null) 'publicMessageKey': publicMessageKey,
      if (diagnosticCategory != null) 'diagnosticCategory': diagnosticCategory,
      if (safeCauseType != null) 'safeCauseType': safeCauseType,
      'failedEntityIds': _sortedUnique(failedEntityIds),
      if (lastFailureOccurredAt != null)
        'failureOccurredAt': lastFailureOccurredAt!.toIso8601String(),
      'expectedRoutineIds': _sortedUnique(expectedRoutineIds),
      'createdRoutineIds': _sortedUnique(appliedRoutineIds),
      'existingRoutineIds': _sortedUnique(existingRoutineIds),
      'repairedRoutineIds': _sortedUnique(repairedRoutineIds),
      'failedRoutineIds': _sortedUnique(failedRoutineIds),
      'expectedHistoryIds': _sortedUnique(expectedHistoryIds),
      'appliedHistoryIds': _sortedUnique(appliedHistoryIds),
      'existingHistoryIds': _sortedUnique(existingHistoryIds),
      'repairedHistoryIds': _sortedUnique(repairedHistoryIds),
      'failedHistoryIds': _sortedUnique(failedHistoryIds),
      'expectedHabitIds': _sortedUnique(expectedHabitIds),
      'createdHabitIds': _sortedUnique(appliedHabitIds),
      'existingHabitIds': _sortedUnique(existingHabitIds),
      'repairedHabitIds': _sortedUnique(repairedHabitIds),
      'failedHabitIds': _sortedUnique(failedHabitIds),
      'expectedAcceptanceIds': _sortedUnique(expectedAcceptanceIds),
      'appliedAcceptanceIds': _sortedUnique(appliedAcceptanceIds),
      'existingAcceptanceIds': _sortedUnique(existingAcceptanceIds),
      'repairedAcceptanceIds': _sortedUnique(repairedAcceptanceIds),
      'failedAcceptanceIds': _sortedUnique(failedAcceptanceIds),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map['createdAt'] = Timestamp.fromDate(createdAt);
    map['updatedAt'] = Timestamp.fromDate(updatedAt);
    if (lastFailureOccurredAt != null) {
      map['failureOccurredAt'] = Timestamp.fromDate(lastFailureOccurredAt!);
    }
    if (completedAt != null) {
      map['completedAt'] = Timestamp.fromDate(completedAt!);
    }
    return map;
  }

  factory OnboardingCompletionJob.fromMap(Map<String, dynamic> map) {
    final stagesRaw = map['stagesCompleted'];
    final stagesCompleted = <String, bool>{};
    if (stagesRaw is Map) {
      for (final entry in stagesRaw.entries) {
        final key = _migrateStageName(entry.key.toString());
        if (entry.value == true) stagesCompleted[key] = true;
      }
    }
    return OnboardingCompletionJob(
      jobId: map['jobId'] as String? ?? 'current',
      ownerUid: map['ownerUid'] as String? ?? map['uid'] as String? ?? '',
      status: _parseStatus(map['status']),
      stage: _parseStage(map['stage']),
      stagesCompleted: stagesCompleted,
      sourceFingerprint: map['sourceFingerprint'] as String? ?? '',
      draftRevision: (map['draftRevision'] as num?)?.toInt() ?? 1,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError'] as String?,
      lastFailureCode:
          map['failureCode'] as String? ?? map['lastFailureCode'] as String?,
      lastFailureStage:
          map['failureStage'] as String? ?? map['lastFailureStage'] as String?,
      retryable: map['retryable'] as bool?,
      publicMessageKey: map['publicMessageKey'] as String?,
      diagnosticCategory: map['diagnosticCategory'] as String?,
      safeCauseType: map['safeCauseType'] as String?,
      failedEntityIds: _parseStringList(map['failedEntityIds']),
      lastFailureOccurredAt: _parseDateTime(
        map['failureOccurredAt'] ?? map['lastFailureOccurredAt'],
      ),
      expectedRoutineIds: _parseStringList(map['expectedRoutineIds']),
      appliedRoutineIds: _parseStringList(
        map['createdRoutineIds'] ?? map['appliedRoutineIds'],
      ),
      existingRoutineIds: _parseStringList(map['existingRoutineIds']),
      repairedRoutineIds: _parseStringList(map['repairedRoutineIds']),
      failedRoutineIds: _parseStringList(map['failedRoutineIds']),
      expectedHistoryIds: _parseStringList(map['expectedHistoryIds']),
      appliedHistoryIds: _parseStringList(map['appliedHistoryIds']),
      existingHistoryIds: _parseStringList(map['existingHistoryIds']),
      repairedHistoryIds: _parseStringList(map['repairedHistoryIds']),
      failedHistoryIds: _parseStringList(map['failedHistoryIds']),
      expectedHabitIds: _parseStringList(map['expectedHabitIds']),
      appliedHabitIds: _parseStringList(
        map['createdHabitIds'] ?? map['appliedHabitIds'],
      ),
      existingHabitIds: _parseStringList(map['existingHabitIds']),
      repairedHabitIds: _parseStringList(map['repairedHabitIds']),
      failedHabitIds: _parseStringList(map['failedHabitIds']),
      expectedAcceptanceIds: _parseStringList(map['expectedAcceptanceIds']),
      appliedAcceptanceIds: _parseStringList(map['appliedAcceptanceIds']),
      existingAcceptanceIds: _parseStringList(map['existingAcceptanceIds']),
      repairedAcceptanceIds: _parseStringList(map['repairedAcceptanceIds']),
      failedAcceptanceIds: _parseStringList(map['failedAcceptanceIds']),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      completedAt: _parseDateTime(map['completedAt']),
      schemaVersion:
          (map['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }

  static OnboardingCompletionStage _parseStage(Object? raw) {
    final migrated = _migrateStageName(raw?.toString() ?? 'validateInput');
    return OnboardingCompletionStage.values.firstWhere(
      (value) => value.name == migrated,
      orElse: () => OnboardingCompletionStage.validateInput,
    );
  }

  static OnboardingJobStatus _parseStatus(Object? raw) {
    return switch (raw?.toString()) {
      'inProgress' || 'in_progress' || 'running' => OnboardingJobStatus.running,
      'failed' || 'retryableFailure' => OnboardingJobStatus.retryableFailure,
      'fatalFailure' => OnboardingJobStatus.fatalFailure,
      'completed' => OnboardingJobStatus.completed,
      _ => OnboardingJobStatus.pending,
    };
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

String _migrateStageName(String raw) {
  return switch (raw) {
    'init' => 'validateInput',
    'projectRoutines' => 'reconcileRoutines',
    'projectHabits' => 'reconcileHabitSystems',
    'updateProfile' => 'finalizeProfile',
    _ => raw,
  };
}

List<String> _sortedUnique(Iterable<String> values) {
  return values.where((value) => value.trim().isNotEmpty).toSet().toList()
    ..sort();
}
