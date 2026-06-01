enum CoachSessionType {
  askAnything,
  todayPlan,
  recoverMissedTask,
  improveRoutine,
  calmSupport,
  focusSupport,
  weeklyReview,
  goalReview,
  trackerInsight,
  mindNoteDiscussion,
  generalChat,
}

enum CoachResponseBlockType {
  text,
  actionCard,
  routineSuggestionCard,
  trackerActionCard,
  goalProofCard,
  recoveryCard,
  mindNoteCard,
}

class CoachResponseBlock {
  final CoachResponseBlockType type;
  final String? heading;
  final String? body;
  final String? buttonLabel;
  final String? payload;

  CoachResponseBlock({
    required this.type,
    this.heading,
    this.body,
    this.buttonLabel,
    this.payload,
  });
}

class CoachMessage {
  final String id;
  final bool isFromCoach;
  final String content;
  final String timestamp;
  final List<CoachResponseBlock> blocks;

  CoachMessage({
    required this.id,
    required this.isFromCoach,
    required this.content,
    required this.timestamp,
    List<CoachResponseBlock>? blocks,
  }) : blocks = blocks ?? const [];
}

class CoachSession {
  final String id;
  final String title;
  final CoachSessionType type;
  final String coachName;
  final String coachStyle;
  final List<CoachMessage> messages;
  final String createdAt;

  CoachSession({
    required this.id,
    required this.title,
    required this.type,
    required this.coachName,
    required this.coachStyle,
    required this.messages,
    required this.createdAt,
  });

  CoachSession copyWith({
    String? id,
    String? title,
    CoachSessionType? type,
    String? coachName,
    String? coachStyle,
    List<CoachMessage>? messages,
    String? createdAt,
  }) {
    return CoachSession(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      coachName: coachName ?? this.coachName,
      coachStyle: coachStyle ?? this.coachStyle,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CoachPreferences {
  final String name;
  final String style;
  final bool allowRoutineContext;
  final bool allowTrackerContext;
  final bool allowGoalsContext;
  final bool allowProfileContext;
  final bool shareSelectedNotesOnly;

  CoachPreferences({
    this.name = 'Coach',
    this.style = 'Supportive',
    this.allowRoutineContext = true,
    this.allowTrackerContext = true,
    this.allowGoalsContext = true,
    this.allowProfileContext = true,
    this.shareSelectedNotesOnly = true,
  });

  CoachPreferences copyWith({
    String? name,
    String? style,
    bool? allowRoutineContext,
    bool? allowTrackerContext,
    bool? allowGoalsContext,
    bool? allowProfileContext,
    bool? shareSelectedNotesOnly,
  }) {
    return CoachPreferences(
      name: name ?? this.name,
      style: style ?? this.style,
      allowRoutineContext: allowRoutineContext ?? this.allowRoutineContext,
      allowTrackerContext: allowTrackerContext ?? this.allowTrackerContext,
      allowGoalsContext: allowGoalsContext ?? this.allowGoalsContext,
      allowProfileContext: allowProfileContext ?? this.allowProfileContext,
      shareSelectedNotesOnly:
          shareSelectedNotesOnly ?? this.shareSelectedNotesOnly,
    );
  }
}
