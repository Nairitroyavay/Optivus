enum MindNoteType {
  overthinking,
  idea,
  project,
  people,
  fear,
  regret,
  decision,
  existential,
  random,
}

enum MindNoteIntensity { low, medium, high }

class MindNote {
  final String id;
  final String content;
  final MindNoteType type;
  final MindNoteIntensity intensity;
  final String timestamp;
  final bool isSharedWithCoach;

  MindNote({
    required this.id,
    required this.content,
    required this.type,
    required this.intensity,
    required this.timestamp,
    this.isSharedWithCoach = false,
  });

  MindNote copyWith({
    String? id,
    String? content,
    MindNoteType? type,
    MindNoteIntensity? intensity,
    String? timestamp,
    bool? isSharedWithCoach,
  }) {
    return MindNote(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      timestamp: timestamp ?? this.timestamp,
      isSharedWithCoach: isSharedWithCoach ?? this.isSharedWithCoach,
    );
  }
}
