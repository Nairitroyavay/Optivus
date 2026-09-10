import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_import_review.dart';

/// Current Step 4 local review state. The durable source remains
/// [BaseTimelineDraft] after the flow acknowledges an explicit save.
final onboardingClassTimelineProvider =
    StateProvider.autoDispose<List<ClassRoutineBlock>>((ref) => []);
final onboardingWorkTimelineProvider =
    StateProvider.autoDispose<List<ClassRoutineBlock>>((ref) => []);

class ScheduleSetupConfig {
  final String sectionLabel;
  final String timelineSection;
  final RoutineImportReviewSource source;
  final String setupTitle;
  final String headerPillTitle;
  final String mainTitle;
  final String subtitle;
  final String uploadTitle;
  final String uploadSubtitle;
  final String clearFailureText;
  final String uploadValidationText;
  final String editTitle;
  final String subjectLabel;
  final String subjectRequiredText;
  final String endAfterStartText;
  final String durationTooLongText;
  final IconData icon;
  final Color accent;
  final Color titleAccent;
  final List<Color> colorCycle;

  const ScheduleSetupConfig({
    required this.sectionLabel,
    required this.timelineSection,
    required this.source,
    required this.setupTitle,
    required this.headerPillTitle,
    required this.mainTitle,
    required this.subtitle,
    required this.uploadTitle,
    required this.uploadSubtitle,
    required this.clearFailureText,
    required this.uploadValidationText,
    required this.editTitle,
    required this.subjectLabel,
    required this.subjectRequiredText,
    required this.endAfterStartText,
    required this.durationTooLongText,
    required this.icon,
    required this.accent,
    required this.titleAccent,
    required this.colorCycle,
  });

  static const classSetup = ScheduleSetupConfig(
    sectionLabel: onboardingSectionClasses,
    timelineSection: 'classes',
    source: RoutineImportReviewSource.classes,
    setupTitle: 'CLASS SETUP',
    headerPillTitle: 'Set Your Weekly Class Schedule',
    mainTitle: 'Your Fixed Classes.',
    subtitle: 'Stay on top of your semester with a clear timetable.',
    uploadTitle: 'Upload your class timetable',
    uploadSubtitle: 'Use a clear photo of your weekly class schedule.',
    clearFailureText: 'We couldn’t detect classes clearly.',
    uploadValidationText: 'Upload your class timetable to continue.',
    editTitle: 'Edit Class',
    subjectLabel: 'Subject',
    subjectRequiredText: 'Subject is required.',
    endAfterStartText: 'Classes must end after they start on the same day.',
    durationTooLongText:
        'That class duration looks too long. Use a normal class window.',
    icon: Icons.school_rounded,
    accent: OptivusColors.aquaAccent,
    titleAccent: OptivusColors.aquaAccent,
    colorCycle: [
      Color(0xFF378ADD),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFF43F5E),
    ],
  );

  static const workSetup = ScheduleSetupConfig(
    sectionLabel: onboardingSectionWork,
    timelineSection: 'job_work_business',
    source: RoutineImportReviewSource.work,
    setupTitle: 'WORK SETUP',
    headerPillTitle: 'Set Your Weekly Work Schedule',
    mainTitle: 'Your Fixed Work Blocks.',
    subtitle: 'Protect your work hours so Optivus can schedule around them.',
    uploadTitle: 'Upload your work schedule',
    uploadSubtitle:
        'Use a clear photo of shifts, office hours, client hours, or your business schedule.',
    clearFailureText: 'We couldn’t detect work blocks clearly.',
    uploadValidationText: 'Upload work schedule to continue.',
    editTitle: 'Edit Work Block',
    subjectLabel: 'Work block',
    subjectRequiredText: 'Work block title is required.',
    endAfterStartText: 'Work blocks must end after they start on the same day.',
    durationTooLongText:
        'That work block duration looks too long. Use a normal work window.',
    icon: Icons.work_rounded,
    accent: OptivusColors.aquaAccent,
    titleAccent: OptivusColors.aquaAccent,
    colorCycle: [
      Color(0xFFF59E0B),
      Color(0xFFFF9560),
      Color(0xFFE0B51F),
      Color(0xFF60B8FF),
      Color(0xFF10B981),
    ],
  );
}

class ClassRoutineBlock {
  final String id;
  final String subject;
  final String room;
  final String professor;
  final int startMinute;
  final int endMinute;
  final List<int> repeatDays;
  final IconData? icon;
  final Color? color;
  final bool hasTopTape;
  final bool hasBottomTape;
  final bool reminderEnabled;
  final String? suggestionId;

  int? get weekday => repeatDays.isEmpty ? null : repeatDays.first;
  int get durationMinutes => (endMinute - startMinute).clamp(1, 24 * 60);

  String get displayStartTime => TimelineUtils.formatMinute(startMinute);
  String get displayEndTime => TimelineUtils.formatMinute(endMinute);

  ClassRoutineBlock({
    required this.id,
    required this.subject,
    this.room = '',
    this.professor = '',
    required this.startMinute,
    required this.endMinute,
    this.repeatDays = const [1],
    this.icon,
    this.color,
    this.hasTopTape = false,
    this.hasBottomTape = false,
    this.reminderEnabled = false,
    this.suggestionId,
  });

  ClassRoutineBlock copyWith({
    String? id,
    String? subject,
    String? room,
    String? professor,
    int? startMinute,
    int? endMinute,
    List<int>? repeatDays,
    IconData? icon,
    Color? color,
    bool? hasTopTape,
    bool? hasBottomTape,
    bool? reminderEnabled,
    String? suggestionId,
  }) {
    return ClassRoutineBlock(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      room: room ?? this.room,
      professor: professor ?? this.professor,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      repeatDays: repeatDays ?? this.repeatDays,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      hasTopTape: hasTopTape ?? this.hasTopTape,
      hasBottomTape: hasBottomTape ?? this.hasBottomTape,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      suggestionId: suggestionId ?? this.suggestionId,
    );
  }
}

/// Keeps the visible Step 4 color contract aligned with section list order.
List<ClassRoutineBlock> normalizeScheduleBlockColors(
  List<ClassRoutineBlock> blocks,
  ScheduleSetupConfig config,
) {
  return List<ClassRoutineBlock>.unmodifiable([
    for (final entry in blocks.indexed)
      entry.$2.copyWith(
        color: config.colorCycle[entry.$1 % config.colorCycle.length],
      ),
  ]);
}
