import 'package:optivus/models/onboarding_draft.dart';

enum BaseTimelineSection { classes, work, eating, fixed, skinCare }

enum BaseSetupOrigin {
  photo,
  generatedFromAnswers,
  manual,
  skipped,
  notConfigured,
}

class BaseTimelineSectionSnapshot {
  final BaseTimelineSection section;
  final BaseSetupOrigin origin;
  final bool configured;
  final List<TimelineBlockDraft> blocks;
  final String? sourceAssetId;
  final String? sourceR2Key;
  final Map<String, dynamic> sourceDetails;
  final String summary;

  const BaseTimelineSectionSnapshot({
    required this.section,
    required this.origin,
    required this.configured,
    required this.blocks,
    this.sourceAssetId,
    this.sourceR2Key,
    this.sourceDetails = const {},
    required this.summary,
  });

  bool get isConfigured => configured;

  String get displayName => switch (section) {
    BaseTimelineSection.classes => 'Classes',
    BaseTimelineSection.work => 'Work / Business',
    BaseTimelineSection.eating => 'Eating',
    BaseTimelineSection.fixed => 'Fixed',
    BaseTimelineSection.skinCare => 'Skin Care',
  };
}
