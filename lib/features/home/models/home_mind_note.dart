import 'package:flutter/foundation.dart';

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

enum MindNoteVisibility { private, sharedWithCoach }

@immutable
class HomeMindNote {
  final String id;
  final MindNoteType type;
  final MindNoteIntensity intensity;
  final MindNoteVisibility visibility;
  final String content;
  final DateTime createdAt;

  const HomeMindNote({
    required this.id,
    required this.type,
    required this.intensity,
    required this.visibility,
    required this.content,
    required this.createdAt,
  });

  HomeMindNote copyWith({
    String? id,
    MindNoteType? type,
    MindNoteIntensity? intensity,
    MindNoteVisibility? visibility,
    String? content,
    DateTime? createdAt,
  }) {
    return HomeMindNote(
      id: id ?? this.id,
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      visibility: visibility ?? this.visibility,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
