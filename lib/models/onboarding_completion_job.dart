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
}
