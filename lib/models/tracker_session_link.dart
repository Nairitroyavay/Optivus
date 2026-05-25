/// Links a routine task to a tracker session for status synchronization.
///
/// When a tracker-linked routine task is started, a TrackerSessionLink
/// is created to track the connection between Routine and Tracker tabs.
class TrackerSessionLink {
  final String routineTaskId;
  final String
  trackerType; // meditation, workout, focus, money, hydration, smoking
  final String? sessionId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Duration? duration;
  final int? durationSeconds;
  final String status; // planned, active, completed, cancelled

  const TrackerSessionLink({
    required this.routineTaskId,
    required this.trackerType,
    this.sessionId,
    this.startedAt,
    this.completedAt,
    this.duration,
    this.durationSeconds,
    this.status = 'planned',
  });

  Duration? get effectiveDuration =>
      duration ??
      (durationSeconds == null ? null : Duration(seconds: durationSeconds!));

  TrackerSessionLink copyWith({
    String? routineTaskId,
    String? trackerType,
    String? sessionId,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? duration,
    int? durationSeconds,
    String? status,
  }) {
    return TrackerSessionLink(
      routineTaskId: routineTaskId ?? this.routineTaskId,
      trackerType: trackerType ?? this.trackerType,
      sessionId: sessionId ?? this.sessionId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routineTaskId': routineTaskId,
      'trackerType': trackerType,
      'sessionId': sessionId,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'duration': effectiveDuration?.inSeconds,
      'durationSeconds': durationSeconds,
      'status': status,
    };
  }

  factory TrackerSessionLink.fromMap(Map<String, dynamic> map) {
    return TrackerSessionLink(
      routineTaskId: map['routineTaskId'] as String? ?? '',
      trackerType: map['trackerType'] as String? ?? 'none',
      sessionId: map['sessionId'] as String?,
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      duration: map['duration'] != null
          ? Duration(seconds: (map['duration'] as num).toInt())
          : null,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      status: map['status'] as String? ?? 'planned',
    );
  }
}
