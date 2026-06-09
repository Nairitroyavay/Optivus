import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

// ---------------------------------------------------------------------------
// Photo slot model — tracks one uploaded photo with its label & section.
// ---------------------------------------------------------------------------
class _PhotoSlot {
  final UploadedAsset asset;
  final String label;
  final RoutineImportReviewSource source;
  final UploadedAssetPurpose purpose;

  const _PhotoSlot({
    required this.asset,
    required this.label,
    required this.source,
    required this.purpose,
  });

  _PhotoSlot copyWith({
    UploadedAsset? asset,
    String? label,
    RoutineImportReviewSource? source,
    UploadedAssetPurpose? purpose,
  }) {
    return _PhotoSlot(
      asset: asset ?? this.asset,
      label: label ?? this.label,
      source: source ?? this.source,
      purpose: purpose ?? this.purpose,
    );
  }
}

@visibleForTesting
class Onboarding4UploadTargetSpec {
  final RoutineImportReviewSource source;
  final UploadedAssetPurpose purpose;
  final String thumbnailLabel;
  final String title;

  const Onboarding4UploadTargetSpec({
    required this.source,
    required this.purpose,
    required this.thumbnailLabel,
    required this.title,
  });
}

class _UploadTarget {
  final RoutineImportReviewSource source;
  final UploadedAssetPurpose purpose;
  final String thumbnailLabel;
  final String title;
  final IconData icon;

  const _UploadTarget({
    required this.source,
    required this.purpose,
    required this.thumbnailLabel,
    required this.title,
    required this.icon,
  });

  factory _UploadTarget.fromSpec(Onboarding4UploadTargetSpec spec) {
    return _UploadTarget(
      source: spec.source,
      purpose: spec.purpose,
      thumbnailLabel: spec.thumbnailLabel,
      title: spec.title,
      icon: spec.source == RoutineImportReviewSource.classes
          ? Icons.school_rounded
          : spec.thumbnailLabel == 'Business'
          ? Icons.business_center_rounded
          : Icons.work_rounded,
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline range helper (duplicated from the old widget since it's private)
// ---------------------------------------------------------------------------
class _TimelineRange {
  final int startHour;
  final int endHour;

  const _TimelineRange({required this.startHour, required this.endHour});

  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
  int get hourCount => (endHour - startHour).clamp(1, 24);
}

class _VisualTimelineBlock {
  final ClassRoutineBlock block;
  final int lane;
  final int order;
  final bool hasOverlap;

  const _VisualTimelineBlock({
    required this.block,
    required this.lane,
    required this.order,
    required this.hasOverlap,
  });
}

@visibleForTesting
class Onboarding4CandidateMappingResult {
  final List<ClassRoutineBlock> blocks;
  final int droppedNoTitle;
  final int droppedInvalidTime;
  final int droppedNoRepeatDays;
  final int droppedNonWork;
  final List<String> droppedExamples;

  const Onboarding4CandidateMappingResult({
    required this.blocks,
    required this.droppedNoTitle,
    required this.droppedInvalidTime,
    required this.droppedNoRepeatDays,
    required this.droppedNonWork,
    this.droppedExamples = const [],
  });

  int get droppedTotal =>
      droppedNoTitle +
      droppedInvalidTime +
      droppedNoRepeatDays +
      droppedNonWork;

  String get filterSummary {
    if (droppedTotal == 0) return 'none';
    return 'noTitle=$droppedNoTitle invalidTime=$droppedInvalidTime '
        'noRepeatDays=$droppedNoRepeatDays nonWork=$droppedNonWork';
  }

  String get droppedExampleText =>
      droppedExamples.isEmpty ? 'none' : droppedExamples.join(' || ');
}

@visibleForTesting
List<Onboarding4UploadTargetSpec> onboarding4UploadTargetsForRole(
  String? role,
) {
  final classesRequired =
      role == LifeRoleDraft.studentKey ||
      role == LifeRoleDraft.studentWorkingKey;
  final workRequired =
      role == LifeRoleDraft.workingKey ||
      role == LifeRoleDraft.studentWorkingKey ||
      role == LifeRoleDraft.businessKey;
  if (classesRequired && workRequired) {
    return const [
      Onboarding4UploadTargetSpec(
        source: RoutineImportReviewSource.classes,
        purpose: UploadedAssetPurpose.classTimetable,
        thumbnailLabel: 'Class',
        title: 'Class timetable',
      ),
      Onboarding4UploadTargetSpec(
        source: RoutineImportReviewSource.work,
        purpose: UploadedAssetPurpose.workSchedule,
        thumbnailLabel: 'Work',
        title: 'Work schedule',
      ),
    ];
  }
  if (classesRequired) {
    return const [
      Onboarding4UploadTargetSpec(
        source: RoutineImportReviewSource.classes,
        purpose: UploadedAssetPurpose.classTimetable,
        thumbnailLabel: 'Class',
        title: 'Class timetable',
      ),
    ];
  }
  if (role == LifeRoleDraft.businessKey) {
    return const [
      Onboarding4UploadTargetSpec(
        source: RoutineImportReviewSource.work,
        purpose: UploadedAssetPurpose.workSchedule,
        thumbnailLabel: 'Business',
        title: 'Work/Business schedule',
      ),
    ];
  }
  return const [
    Onboarding4UploadTargetSpec(
      source: RoutineImportReviewSource.work,
      purpose: UploadedAssetPurpose.workSchedule,
      thumbnailLabel: 'Work',
      title: 'Work schedule',
    ),
  ];
}

@visibleForTesting
List<int> normalizeOnboarding4AiRepeatDays(List<int> days) {
  return days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
}

@visibleForTesting
List<int> repeatDaysForOnboarding4Candidate(
  RoutineImportCandidateBlock candidate,
) {
  final explicitDays = normalizeOnboarding4AiRepeatDays(candidate.repeatDays);
  if (explicitDays.isNotEmpty) return explicitDays;

  final derived = <int>{};
  for (final text in [
    candidate.sourceColumnLabel,
    candidate.sourceRowLabel,
    candidate.sourceTextSnippet,
  ]) {
    if (text == null || text.trim().isEmpty) continue;
    derived.addAll(_dayNumbersFromText(text));
  }
  return derived.toList()..sort();
}

@visibleForTesting
bool isDisallowedOnboarding4WorkCandidate(
  RoutineImportCandidateBlock candidate,
) {
  final normalized = _normalizedWorkCandidateText(candidate.title);
  if (_hasDisallowedWorkText(normalized)) {
    return true;
  }
  if (_hasAllowedWorkText(normalized)) return false;
  final snippet = candidate.sourceTextSnippet;
  if (snippet == null || snippet.isEmpty) return false;
  final normalizedSnippet = _normalizedWorkCandidateText(snippet);
  if (_hasDisallowedWorkPhrase(normalizedSnippet)) return true;
  return _hasDisallowedWorkToken(normalizedSnippet);
}

String _normalizedWorkCandidateText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _hasDisallowedWorkText(String normalized) {
  if (normalized.isEmpty) return false;
  return _hasDisallowedWorkPhrase(normalized) ||
      _hasDisallowedWorkToken(normalized);
}

bool _hasDisallowedWorkPhrase(String normalized) {
  return normalized.contains('rest day') ||
      normalized.contains('no work') ||
      normalized.contains('online course') ||
      normalized.contains('personal habit');
}

bool _hasDisallowedWorkToken(String normalized) {
  final tokens = normalized.split(' ').toSet();
  return tokens.contains('gym') ||
      tokens.contains('exercise') ||
      tokens.contains('workout') ||
      tokens.contains('study') ||
      tokens.contains('reading');
}

bool _hasAllowedWorkText(String normalized) {
  if (normalized.isEmpty) return false;
  return normalized.contains('office work') ||
      normalized == 'work' ||
      normalized.contains(' work') ||
      normalized.contains('work ') ||
      normalized.contains('shift') ||
      normalized.contains('client call') ||
      normalized.contains('meeting') ||
      normalized.contains('team sync') ||
      normalized.contains('team review') ||
      normalized.contains('weekly review') ||
      normalized.contains('project work') ||
      normalized.contains('training') ||
      normalized.contains('freelance') ||
      normalized.contains('business hours') ||
      normalized.contains('commute') ||
      normalized.contains('lunch break') ||
      normalized == 'break';
}

List<int> _dayNumbersFromText(String text) {
  final lower = text
      .toLowerCase()
      .replaceAll(RegExp(r'[–—]'), '-')
      .replaceAll(RegExp(r'[\(\)\[\]\{\},.:;_/]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final found = <int>{};
  if (RegExp(r'(^|[^a-z])weekdays?($|[^a-z])').hasMatch(lower)) {
    found.addAll(const [1, 2, 3, 4, 5]);
  }
  final aliases = <String, int>{
    'mon': 1,
    'monday': 1,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'wed': 3,
    'wednesday': 3,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'thursday': 4,
    'fri': 5,
    'friday': 5,
    'sat': 6,
    'saturday': 6,
    'sun': 7,
    'sunday': 7,
  };
  const dayToken =
      r'monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thur|thu|friday|fri|saturday|sat|sunday|sun';
  final rangePattern = RegExp(
    r'(^|[^a-z])(' +
        dayToken +
        r')\s*(?:-|to|through|thru)\s*(' +
        dayToken +
        r')(?=$|[^a-z])',
  );
  for (final match in rangePattern.allMatches(lower)) {
    final start = aliases[match.group(2)];
    final end = aliases[match.group(3)];
    if (start == null || end == null || end < start) continue;
    for (var day = start; day <= end; day += 1) {
      found.add(day);
    }
  }

  final tokenPattern = RegExp(r'(^|[^a-z])(' + dayToken + r')(?=$|[^a-z])');
  final matches = tokenPattern.allMatches(lower).toList(growable: false);
  for (final match in matches) {
    final day = aliases[match.group(2)];
    if (day != null) found.add(day);
  }

  return found.toList()..sort();
}

@visibleForTesting
Onboarding4CandidateMappingResult mapOnboarding4Candidates({
  required List<RoutineImportCandidateBlock> candidates,
  required ScheduleSetupConfig config,
}) {
  final blocks = <ClassRoutineBlock>[];
  var droppedNoTitle = 0;
  var droppedInvalidTime = 0;
  var droppedNoRepeatDays = 0;
  var droppedNonWork = 0;
  final droppedExamples = <String>[];

  void addExample(String reason, RoutineImportCandidateBlock candidate) {
    if (droppedExamples.length >= 5) return;
    droppedExamples.add('$reason ${candidateDayDebugLabel(candidate)}');
  }

  for (final candidate in candidates) {
    final title = candidate.title.trim();
    if (title.isEmpty) {
      droppedNoTitle++;
      addExample('droppedNoTitle', candidate);
      continue;
    }
    if (config.source == RoutineImportReviewSource.work &&
        isDisallowedOnboarding4WorkCandidate(candidate)) {
      droppedNonWork++;
      addExample('droppedNonWork', candidate);
      continue;
    }
    if (candidate.startMinute >= candidate.endMinute) {
      droppedInvalidTime++;
      addExample('droppedInvalidTime', candidate);
      continue;
    }
    final repeatDays = repeatDaysForOnboarding4Candidate(candidate);
    if (repeatDays.isEmpty) {
      droppedNoRepeatDays++;
      addExample('droppedNoRepeatDays', candidate);
      continue;
    }

    blocks.add(
      ClassRoutineBlock(
        id: candidate.id,
        subject: title,
        room: candidate.location?.trim() ?? '',
        startMinute: candidate.startMinute.clamp(0, 24 * 60 - 1),
        endMinute: candidate.endMinute.clamp(1, 24 * 60),
        repeatDays: repeatDays,
        icon: config.icon,
        color: config.colorCycle[blocks.length % config.colorCycle.length],
        hasTopTape: true,
        hasBottomTape: true,
      ),
    );
  }

  return Onboarding4CandidateMappingResult(
    blocks: blocks,
    droppedNoTitle: droppedNoTitle,
    droppedInvalidTime: droppedInvalidTime,
    droppedNoRepeatDays: droppedNoRepeatDays,
    droppedNonWork: droppedNonWork,
    droppedExamples: droppedExamples,
  );
}

@visibleForTesting
String candidateDayDebugLabel(RoutineImportCandidateBlock candidate) {
  final title = candidate.title.trim().isEmpty
      ? 'untitled'
      : candidate.title.trim();
  final row = candidate.sourceRowLabel?.trim();
  final column = candidate.sourceColumnLabel?.trim();
  final snippet = candidate.sourceTextSnippet?.trim();
  final shortSnippet = snippet == null || snippet.isEmpty
      ? 'none'
      : (snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet);
  return 'title=$title startMinute=${candidate.startMinute} '
      'endMinute=${candidate.endMinute} repeatDays=${candidate.repeatDays} '
      'row=${row?.isEmpty ?? true ? 'none' : row} '
      'column=${column?.isEmpty ?? true ? 'none' : column} '
      'snippet=$shortSnippet category=${candidate.category} '
      'blockType=${candidate.blockType} hasFixedTime=${candidate.hasFixedTime}';
}

@visibleForTesting
String? onboarding4PartialFailureMessage({
  required bool needsBothPhotos,
  required Set<RoutineImportReviewSource> successfulSources,
  required Set<RoutineImportReviewSource> failedSources,
}) {
  if (!needsBothPhotos || successfulSources.isEmpty) return null;
  if (failedSources.contains(RoutineImportReviewSource.work)) {
    return 'Work schedule could not be read clearly. Check the Work photo or upload a clearer image.';
  }
  if (failedSources.contains(RoutineImportReviewSource.classes)) {
    return 'Class timetable could not be read clearly. Check the Class photo or upload a clearer image.';
  }
  return null;
}

@visibleForTesting
String onboarding4TimelineErrorForFailures({
  required bool needsBothPhotos,
  required String? role,
  required Set<RoutineImportReviewSource> failures,
}) {
  final classFailed = failures.contains(RoutineImportReviewSource.classes);
  final workFailed = failures.contains(RoutineImportReviewSource.work);
  if (needsBothPhotos && classFailed && workFailed) {
    return 'AI could not detect class or work schedule blocks clearly.';
  }
  if (classFailed) {
    return 'Class timetable could not be read clearly. Check the Class photo or upload a clearer image.';
  }
  if (workFailed && role == LifeRoleDraft.businessKey) {
    return 'Work/business schedule could not be read clearly. Check the photo or upload a clearer image.';
  }
  if (workFailed) {
    return 'Work schedule could not be read clearly. Check the Work photo or upload a clearer image.';
  }
  return 'AI could not detect timetable blocks clearly.';
}

// ---------------------------------------------------------------------------
//  OnboardingStep4Unified — the single-screen Classes & Job widget
// ---------------------------------------------------------------------------
class OnboardingStep4Unified extends ConsumerStatefulWidget {
  const OnboardingStep4Unified({super.key});

  @override
  ConsumerState<OnboardingStep4Unified> createState() =>
      _OnboardingStep4UnifiedState();
}

class _OnboardingStep4UnifiedState
    extends ConsumerState<OnboardingStep4Unified> {
  static const _kHourHeight = 84.0;
  static const _kPixelsPerMinute = _kHourHeight / 60.0;
  static const _kLeftOffset = 64.0;
  static const _kMinTimelineAreaHeight = 320.0;
  static const _kTimelineBottomPadding = 280.0;
  static const _kOverlapMinLabelWidth = 58.0;
  static const _kOverlapMaxLabelWidth = 96.0;
  static const _kOverlapMinFrontWidth = 152.0;
  static const _kMaxOverlapLane = 2;
  final List<_PhotoSlot> _photos = [];
  bool _isUploading = false;
  bool _isGenerating = false;
  String? _generationError;
  String? _timelineError;
  int _day = 0; // 0=Mon … 6=Sun
  bool _didInitFromDraft = false;
  String? _frontBlockId;

  // ---- Role helpers ----
  String? get _role => ref.read(mockOnboardingProvider).draft.lifeRole.lifeRole;

  bool get _classesRequired =>
      _role == LifeRoleDraft.studentKey ||
      _role == LifeRoleDraft.studentWorkingKey;

  bool get _workRequired =>
      _role == LifeRoleDraft.workingKey ||
      _role == LifeRoleDraft.studentWorkingKey ||
      _role == LifeRoleDraft.businessKey;

  bool get _needsBothPhotos => _classesRequired && _workRequired;
  List<_UploadTarget> get _uploadTargets {
    return onboarding4UploadTargetsForRole(
      _role,
    ).map(_UploadTarget.fromSpec).toList(growable: false);
  }

  int get _maxPhotos => _uploadTargets.length;
  bool get _hasAnyPhoto => _photos.isNotEmpty;
  bool get _hasAllPhotos =>
      _uploadTargets.every((target) => _photoForSource(target.source) != null);

  bool get _canTapGenerate => _hasAnyPhoto && !_isUploading && !_isGenerating;

  // ---- Upload text config ----
  String get _uploadTitle {
    if (_needsBothPhotos) return 'Upload your class and work timetable';
    if (_classesRequired) return 'Upload your class timetable';
    if (_role == LifeRoleDraft.businessKey) {
      return 'Upload your work/business schedule';
    }
    return 'Upload your work schedule';
  }

  String get _uploadSubtitle {
    if (_needsBothPhotos) {
      return 'Add both photos, then generate your timeline.';
    }
    if (_classesRequired) {
      return 'Add your weekly class timetable photo.';
    }
    if (_role == LifeRoleDraft.businessKey) {
      return 'Add your work, shift, or business schedule photo.';
    }
    return 'Add your weekly work schedule photo.';
  }

  String get _loadingTitle {
    if (_needsBothPhotos) {
      return 'AI is reading your class and work schedules...';
    }
    if (_classesRequired) return 'AI is reading your class timetable...';
    if (_role == LifeRoleDraft.businessKey) {
      return 'AI is reading your work/business schedule...';
    }
    return 'AI is reading your work schedule...';
  }

  String get _emptyTimelineHint {
    if (_needsBothPhotos) {
      return 'Upload your class and work schedule photos and tap the arrow '
          'to generate your weekly schedule.';
    }
    if (_classesRequired) {
      return 'Upload your class timetable photo and tap the arrow '
          'to generate your weekly schedule.';
    }
    if (_role == LifeRoleDraft.businessKey) {
      return 'Upload your work/business schedule photo and tap the arrow '
          'to generate your weekly schedule.';
    }
    return 'Upload your work schedule photo and tap the arrow '
        'to generate your weekly schedule.';
  }

  // ---- Accent for the combined view (class-primary) ----
  Color get _accent => OptivusColors.aquaAccent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initFromDraft();
    });
  }

  // ---- Init from draft ----
  void _initFromDraft() {
    if (_didInitFromDraft) return;
    _didInitFromDraft = true;

    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;

    // Restore confirmed class blocks
    if (_classesRequired) {
      final classBlocks = base.confirmedBlocksForSection('classes');
      if (classBlocks.isNotEmpty) {
        ref
            .read(onboardingClassTimelineProvider.notifier)
            .state = _classBlocksFromTimelineDrafts(
          classBlocks,
          ScheduleSetupConfig.classSetup,
        );
      }
    }

    // Restore confirmed work blocks
    if (_workRequired) {
      final workBlocks = base.confirmedBlocksForSection('job_work_business');
      if (workBlocks.isNotEmpty) {
        ref
            .read(onboardingWorkTimelineProvider.notifier)
            .state = _classBlocksFromTimelineDrafts(
          workBlocks,
          ScheduleSetupConfig.workSetup,
        );
      }
    }
  }

  // ---- Helpers ----
  List<ClassRoutineBlock> _classBlocksFromTimelineDrafts(
    List<TimelineBlockDraft> blocks,
    ScheduleSetupConfig config,
  ) {
    return blocks
        .asMap()
        .entries
        .map(
          (entry) => ClassRoutineBlock(
            id: entry.value.id,
            subject: entry.value.title,
            room: entry.value.location ?? '',
            startMinute: entry.value.startMinute.clamp(0, 24 * 60 - 1),
            endMinute: entry.value.endMinute.clamp(1, 24 * 60),
            repeatDays: _safeRepeatDays(entry.value.repeatDays),
            icon: config.icon,
            color: config.colorCycle[entry.key % config.colorCycle.length],
            hasTopTape: true,
            hasBottomTape: true,
          ),
        )
        .where((b) => b.subject.trim().isNotEmpty)
        .where((b) => b.startMinute < b.endMinute)
        .toList(growable: false)
      ..sort((a, b) {
        final dayCompare = (a.weekday ?? 1).compareTo(b.weekday ?? 1);
        return dayCompare != 0
            ? dayCompare
            : a.startMinute.compareTo(b.startMinute);
      });
  }

  List<int> _safeRepeatDays(List<int> days) {
    final safe = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
    return safe.isEmpty ? const [1] : safe;
  }

  _PhotoSlot? _photoForSource(RoutineImportReviewSource source) {
    for (final photo in _photos) {
      if (photo.source == source) return photo;
    }
    return null;
  }

  _TimelineRange _rangeFor(List<ClassRoutineBlock> blocks) {
    var startHour = 6;
    var endHour = 23;
    if (blocks.isNotEmpty) {
      final minStart = blocks
          .map((b) => b.startMinute)
          .reduce((a, b) => a < b ? a : b);
      final maxEnd = blocks
          .map((b) => b.endMinute)
          .reduce((a, b) => a > b ? a : b);
      if (minStart < 6 * 60) {
        startHour = (minStart ~/ 60).clamp(0, 23);
      }
      if (maxEnd > 23 * 60) {
        endHour = ((maxEnd + 59) ~/ 60).clamp(startHour + 1, 24);
      }
    }
    return _TimelineRange(startHour: startHour, endHour: endHour);
  }

  double _timelineY({
    required int minuteOfDay,
    required int visibleStartMinute,
    required double topPadding,
  }) {
    return topPadding + (minuteOfDay - visibleStartMinute) * _kPixelsPerMinute;
  }

  int _compareBlocksByTime(ClassRoutineBlock a, ClassRoutineBlock b) {
    final startCompare = a.startMinute.compareTo(b.startMinute);
    if (startCompare != 0) return startCompare;
    final endCompare = a.endMinute.compareTo(b.endMinute);
    if (endCompare != 0) return endCompare;
    return a.subject.compareTo(b.subject);
  }

  bool _blocksOverlap(ClassRoutineBlock a, ClassRoutineBlock b) {
    return a.startMinute < b.endMinute && a.endMinute > b.startMinute;
  }

  double _blockDurationHeight(ClassRoutineBlock item) {
    final durationMinutes = (item.endMinute - item.startMinute)
        .clamp(1, 24 * 60)
        .toInt();
    return durationMinutes * _kPixelsPerMinute;
  }

  double _blockVisualHeight(ClassRoutineBlock item) {
    return _blockDurationHeight(item);
  }

  List<_VisualTimelineBlock> _visualBlocksFor(
    List<ClassRoutineBlock> dayItems,
  ) {
    final sorted = [...dayItems]..sort(_compareBlocksByTime);
    final active = <_VisualTimelineBlock>[];
    final visualBlocks = <_VisualTimelineBlock>[];

    for (final block in sorted) {
      active.removeWhere((entry) => !_blocksOverlap(block, entry.block));

      final usedLanes = active.map((entry) => entry.lane).toSet();
      var lane = 0;
      while (usedLanes.contains(lane) && lane < _kMaxOverlapLane) {
        lane++;
      }
      if (usedLanes.contains(lane)) {
        lane = _kMaxOverlapLane;
      }

      final visual = _VisualTimelineBlock(
        block: block,
        lane: lane,
        order: visualBlocks.length,
        hasOverlap: dayItems.any(
          (other) => other.id != block.id && _blocksOverlap(block, other),
        ),
      );
      active.add(visual);
      visualBlocks.add(visual);
    }

    return visualBlocks;
  }

  bool _visualsOverlap(_VisualTimelineBlock a, _VisualTimelineBlock b) {
    return a.block.id != b.block.id && _blocksOverlap(a.block, b.block);
  }

  bool _groupHasFocusedBlock(
    _VisualTimelineBlock visual,
    List<_VisualTimelineBlock> blocks,
  ) {
    final frontId = _frontBlockId;
    if (frontId == null) return false;
    return _overlapGroupFor(
      visual,
      blocks,
    ).any((candidate) => candidate.block.id == frontId);
  }

  bool _isFrontVisual(
    _VisualTimelineBlock visual,
    List<_VisualTimelineBlock> blocks,
  ) {
    if (!visual.hasOverlap) return true;
    if (_groupHasFocusedBlock(visual, blocks)) {
      return visual.block.id == _frontBlockId;
    }
    return _isDefaultFrontVisual(visual, blocks);
  }

  List<_VisualTimelineBlock> _overlapGroupFor(
    _VisualTimelineBlock visual,
    List<_VisualTimelineBlock> blocks,
  ) {
    final group = <_VisualTimelineBlock>[];
    final visited = <String>{};
    final queue = <_VisualTimelineBlock>[visual];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.block.id)) continue;
      group.add(current);
      for (final candidate in blocks) {
        if (visited.contains(candidate.block.id)) continue;
        if (_visualsOverlap(current, candidate)) {
          queue.add(candidate);
        }
      }
    }

    return group;
  }

  bool _isDefaultFrontVisual(
    _VisualTimelineBlock visual,
    List<_VisualTimelineBlock> blocks,
  ) {
    for (final candidate in blocks) {
      if (!_visualsOverlap(candidate, visual)) continue;
      if (_compareDefaultFrontPriority(candidate, visual) < 0) {
        return false;
      }
    }
    return true;
  }

  int _compareDefaultFrontPriority(
    _VisualTimelineBlock a,
    _VisualTimelineBlock b,
  ) {
    final durationCompare = a.block.durationMinutes.compareTo(
      b.block.durationMinutes,
    );
    if (durationCompare != 0) return durationCompare;

    final sectionCompare = _sectionPriorityForBlock(
      a.block,
    ).compareTo(_sectionPriorityForBlock(b.block));
    if (sectionCompare != 0) return sectionCompare;

    final startCompare = a.block.startMinute.compareTo(b.block.startMinute);
    if (startCompare != 0) return startCompare;
    return a.order.compareTo(b.order);
  }

  int _sectionPriorityForBlock(ClassRoutineBlock block) {
    final classBlocks = ref.read(onboardingClassTimelineProvider);
    if (classBlocks.any((item) => item.id == block.id)) return 0;
    return 1;
  }

  List<_VisualTimelineBlock> _paintOrderedBlocks(
    List<_VisualTimelineBlock> blocks,
  ) {
    return [...blocks]..sort((a, b) {
      final aFront = _isFrontVisual(a, blocks);
      final bFront = _isFrontVisual(b, blocks);
      if (aFront != bFront) {
        return aFront ? 1 : -1;
      }
      if (!aFront && a.hasOverlap && b.hasOverlap) {
        final laneCompare = b.lane.compareTo(a.lane);
        if (laneCompare != 0) return laneCompare;
      }
      final laneCompare = a.lane.compareTo(b.lane);
      if (laneCompare != 0) return laneCompare;
      return a.order.compareTo(b.order);
    });
  }

  double _leftForVisual(
    _VisualTimelineBlock visual,
    List<_VisualTimelineBlock> blocks,
    double exposedLabelWidth,
  ) {
    if (!visual.hasOverlap) return _kLeftOffset;
    if (_isFrontVisual(visual, blocks)) {
      return _kLeftOffset + exposedLabelWidth;
    }
    return _kLeftOffset;
  }

  double _rightForVisual(
    _VisualTimelineBlock visual,
    List<_VisualTimelineBlock> blocks,
  ) {
    if (!visual.hasOverlap) return 16.0;
    if (_isFrontVisual(visual, blocks)) return 16.0;
    return switch (visual.lane.clamp(0, _kMaxOverlapLane)) {
      0 => 8.0,
      1 => 12.0,
      _ => 16.0,
    };
  }

  double _overlapExposedLabelWidth(double timelineWidth) {
    final available = timelineWidth - _kLeftOffset - 16.0;
    if (!available.isFinite || available <= 0) {
      return _kOverlapMaxLabelWidth;
    }
    if (available >= _kOverlapMinFrontWidth + _kOverlapMaxLabelWidth) {
      return _kOverlapMaxLabelWidth;
    }
    return (available - _kOverlapMinFrontWidth)
        .clamp(_kOverlapMinLabelWidth, _kOverlapMaxLabelWidth)
        .toDouble();
  }

  double _backLabelInsetForVisual(_VisualTimelineBlock visual) {
    return visual.lane.clamp(0, _kMaxOverlapLane).toDouble() * 7.0;
  }

  // ---- Upload ----
  Future<void> _pickAndUpload(_UploadTarget target) async {
    if (_isUploading || _isGenerating) return;
    if (_photoForSource(target.source) != null ||
        _photos.length >= _maxPhotos ||
        _hasAllPhotos) {
      setState(() => _generationError = _photoLimitMessage());
      return;
    }

    setState(() {
      _isUploading = true;
      _generationError = null;
      _timelineError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;

    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: target.purpose,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );

    if (!mounted) return;
    final uploadState = ref.read(uploadControllerProvider);
    setState(() => _isUploading = false);

    if (asset == null) {
      if (uploadState.status == UploadFlowStatus.failed) {
        setState(() {
          _generationError =
              uploadState.errorMessage ?? 'Photo upload failed. Try again.';
        });
      }
      return;
    }

    setState(() {
      _photos.add(
        _PhotoSlot(
          asset: asset,
          label: target.thumbnailLabel,
          source: target.source,
          purpose: target.purpose,
        ),
      );
      _photos.sort(_comparePhotoSlots);
      _generationError = null;
      _timelineError = null;
    });
    _markClassJobDirty();
  }

  void _removePhotoForSource(RoutineImportReviewSource source) {
    if (_isUploading || _isGenerating) return;
    final index = _photos.indexWhere((photo) => photo.source == source);
    if (index < 0) return;
    final removed = _photos[index];
    setState(() {
      _photos.removeAt(index);
      _generationError = null;
      _timelineError = null;
    });

    // Clear generated blocks for the removed section
    if (removed.source == RoutineImportReviewSource.classes) {
      ref.read(onboardingClassTimelineProvider.notifier).state = const [];
    } else {
      ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
    }
    _markClassJobDirty();
  }

  int _comparePhotoSlots(_PhotoSlot a, _PhotoSlot b) {
    int rank(_PhotoSlot photo) =>
        photo.source == RoutineImportReviewSource.classes ? 0 : 1;
    return rank(a).compareTo(rank(b));
  }

  String _photoLimitMessage() {
    if (_needsBothPhotos) {
      return 'Only class and work timetable photos are needed.';
    }
    if (_classesRequired) return 'Only one class timetable photo is allowed.';
    if (_role == LifeRoleDraft.businessKey) {
      return 'Only one work/business schedule photo is allowed.';
    }
    return 'Only one work schedule photo is allowed.';
  }

  bool get _canSwapClassWorkPhotos {
    return _needsBothPhotos &&
        !_isUploading &&
        !_isGenerating &&
        _photoForSource(RoutineImportReviewSource.classes) != null &&
        _photoForSource(RoutineImportReviewSource.work) != null;
  }

  void _swapClassWorkPhotos() {
    if (!_canSwapClassWorkPhotos) return;
    final classIndex = _photos.indexWhere(
      (photo) => photo.source == RoutineImportReviewSource.classes,
    );
    final workIndex = _photos.indexWhere(
      (photo) => photo.source == RoutineImportReviewSource.work,
    );
    if (classIndex < 0 || workIndex < 0) return;

    final classPhoto = _photos[classIndex];
    final workPhoto = _photos[workIndex];
    setState(() {
      _photos[classIndex] = classPhoto.copyWith(asset: workPhoto.asset);
      _photos[workIndex] = workPhoto.copyWith(asset: classPhoto.asset);
      _photos.sort(_comparePhotoSlots);
      _generationError = null;
      _timelineError = null;
    });
    ref.read(onboardingClassTimelineProvider.notifier).state = const [];
    ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
    _markClassJobDirty();
  }

  void _markClassJobDirty() {
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepDirty(onboardingClassJobStepIndex, true);
  }

  ScheduleSetupConfig _configForSource(RoutineImportReviewSource source) {
    return source == RoutineImportReviewSource.classes
        ? ScheduleSetupConfig.classSetup
        : ScheduleSetupConfig.workSetup;
  }

  Onboarding4CandidateMappingResult _blocksFromCandidates(
    List<RoutineImportCandidateBlock> candidates,
    ScheduleSetupConfig config,
  ) {
    return mapOnboarding4Candidates(candidates: candidates, config: config);
  }

  void _debugLogAiMode() {
    if (!kDebugMode) return;
    debugPrint(
      '[Onboarding4] aiMode=${OptivusRoutineImportAiConfig.mode.name} '
      'workerUrlConfigured=${OptivusRoutineImportAiConfig.hasWorkerUrl}',
    );
  }

  void _debugAssertTargetRouting(_PhotoSlot photo) {
    if (!kDebugMode) return;
    final expectedPurpose = switch (photo.source) {
      RoutineImportReviewSource.classes => UploadedAssetPurpose.classTimetable,
      RoutineImportReviewSource.work => UploadedAssetPurpose.workSchedule,
      RoutineImportReviewSource.eating => photo.purpose,
      RoutineImportReviewSource.skinCare => photo.purpose,
    };
    final sourceOk =
        photo.source == RoutineImportReviewSource.classes ||
        photo.source == RoutineImportReviewSource.work;
    final purposeOk = photo.purpose == expectedPurpose;
    if (!sourceOk || !purposeOk) {
      debugPrint(
        '[Onboarding4] ROUTING_MISMATCH source=${photo.source.name} '
        'purpose=${photo.purpose.name} expectedPurpose=${expectedPurpose.name}',
      );
    }
  }

  void _debugLogExtractionStart(_PhotoSlot photo) {
    if (!kDebugMode) return;
    _debugAssertTargetRouting(photo);
    debugPrint(
      '[Onboarding4] START source=${photo.source.name} '
      'purpose=${photo.purpose.name} '
      'assetId=${photo.asset.assetId.trim().isEmpty ? 'missing' : photo.asset.assetId} '
      'r2Key=${photo.asset.r2Key.trim().isEmpty ? 'missing' : 'exists'} '
      'contentType=${photo.asset.contentType.trim().isEmpty ? 'missing' : photo.asset.contentType}',
    );
  }

  void _debugLogExtractionResult({
    required _PhotoSlot photo,
    required RoutineImportExtractionResult? result,
    required RoutineImportAiState controllerState,
    required List<String> warnings,
  }) {
    if (!kDebugMode) return;
    final warningText = warnings.isEmpty ? 'none' : warnings.join(' | ');
    debugPrint(
      '[Onboarding4] RESULT source=${photo.source.name} '
      'controllerStatus=${controllerState.status.name} '
      'resultNull=${result == null} warnings=$warningText',
    );
    if (result != null) {
      debugPrint(
        '[Onboarding4] RAW source=${photo.source.name} '
        'rawCandidates=${result.candidates.length}',
      );
      if (result.candidates.isEmpty &&
          (photo.source == RoutineImportReviewSource.classes ||
              photo.source == RoutineImportReviewSource.work)) {
        debugPrint(
          '[Onboarding4] Worker returned 0 candidates. Check deployed worker prompt/model/image size.',
        );
      }
    }
  }

  void _debugLogExtractionMapped({
    required _PhotoSlot photo,
    required Onboarding4CandidateMappingResult mapping,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[Onboarding4] MAPPED source=${photo.source.name} '
      'mappedBlocks=${mapping.blocks.length} '
      'droppedNoTitle=${mapping.droppedNoTitle} '
      'droppedInvalidTime=${mapping.droppedInvalidTime} '
      'droppedNoRepeatDays=${mapping.droppedNoRepeatDays} '
      'droppedNonWork=${mapping.droppedNonWork}',
    );
    if (mapping.droppedExamples.isNotEmpty) {
      debugPrint(
        '[Onboarding4] DROPPED source=${photo.source.name} '
        'examples=${mapping.droppedExampleText}',
      );
    }
    if (mapping.blocks.isEmpty) {
      debugPrint(
        '[Onboarding4] zero mapped blocks source=${photo.source.name} '
        'purpose=${photo.purpose.name} '
        'workerMode=${OptivusRoutineImportAiConfig.mode.name} '
        'uploadedAssetIdExists=${photo.asset.assetId.trim().isNotEmpty} '
        'uploadedAssetR2KeyExists=${photo.asset.r2Key.trim().isNotEmpty} '
        'filtered=${mapping.filterSummary} '
        'examples=${mapping.droppedExampleText}',
      );
    }
  }

  void _debugLogRoleSummary() {
    if (!kDebugMode) return;
    final classCount = _visibleClassBlocks(
      ref.read(onboardingClassTimelineProvider),
    ).length;
    final workCount = _visibleWorkBlocks(
      ref.read(onboardingWorkTimelineProvider),
    ).length;
    debugPrint(
      '[Onboarding4] role=${_role ?? 'unknown'} classBlocks=$classCount '
      'workBlocks=$workCount allVisible=${classCount + workCount}',
    );
  }

  String? _partialFailureMessage({
    required Set<RoutineImportReviewSource> successfulSources,
    required Set<RoutineImportReviewSource> failedSources,
  }) {
    return onboarding4PartialFailureMessage(
      needsBothPhotos: _needsBothPhotos,
      successfulSources: successfulSources,
      failedSources: failedSources,
    );
  }

  String _timelineErrorForFailures(Set<RoutineImportReviewSource> failures) {
    return onboarding4TimelineErrorForFailures(
      needsBothPhotos: _needsBothPhotos,
      role: _role,
      failures: failures,
    );
  }

  List<ClassRoutineBlock> _visibleClassBlocks(List<ClassRoutineBlock> blocks) {
    return _classesRequired ? blocks : const <ClassRoutineBlock>[];
  }

  List<ClassRoutineBlock> _visibleWorkBlocks(List<ClassRoutineBlock> blocks) {
    return _workRequired ? blocks : const <ClassRoutineBlock>[];
  }

  bool _hasConfirmedScheduleForRole(BaseTimelineDraft base) {
    final hasClasses = base.confirmedBlocksForSection('classes').isNotEmpty;
    final hasWork = base
        .confirmedBlocksForSection('job_work_business')
        .isNotEmpty;
    if (_classesRequired && _workRequired) return hasClasses && hasWork;
    if (_classesRequired) return hasClasses;
    if (_workRequired) return hasWork;
    return false;
  }

  Set<String> get _replaceScheduleSections {
    return {
      if (_classesRequired) 'classes',
      if (_workRequired) 'job_work_business',
    };
  }

  Set<String> get _replacePendingImportSections {
    return {
      if (_classesRequired) onboardingSectionClasses,
      if (_workRequired) onboardingSectionWork,
    };
  }

  Future<void> _confirmReplaceSchedule() async {
    if (_isUploading || _isGenerating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Replace saved schedule?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          content: const Text(
            'This will clear the saved class/work blocks for this setup and let you upload again.',
            style: TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace schedule'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    _replaceSavedSchedule();
  }

  void _replaceSavedSchedule() {
    final sections = _replaceScheduleSections;
    final pendingSections = _replacePendingImportSections;
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              classJobSetupStep: 0,
              blocks: draft.baseTimeline.blocks
                  .where((block) => !sections.contains(block.section))
                  .toList(growable: false),
              pendingFutureImports: draft.baseTimeline.pendingFutureImports
                  .where((entry) => !pendingSections.contains(entry.section))
                  .toList(growable: false),
            ),
            clearFinalPreview: true,
          ),
        );
    if (_classesRequired) {
      ref.read(onboardingClassTimelineProvider.notifier).state = const [];
    }
    if (_workRequired) {
      ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
    }
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepCompleted(onboardingClassJobStepIndex, false);
    _markClassJobDirty();
    setState(() {
      _photos.clear();
      _generationError = null;
      _timelineError = null;
      _frontBlockId = null;
    });
  }

  void _clearIrrelevantProvidersForRole() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_classesRequired &&
          ref.read(onboardingClassTimelineProvider).isNotEmpty) {
        ref.read(onboardingClassTimelineProvider.notifier).state = const [];
      }
      if (!_workRequired &&
          ref.read(onboardingWorkTimelineProvider).isNotEmpty) {
        ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
      }
    });
  }

  // ---- Generation ----
  Future<void> _runGeneration() async {
    if (!_canTapGenerate) return;
    if (_needsBothPhotos && !_hasAllPhotos) {
      setState(() {
        _generationError =
            'Missing one timetable photo.\nPlease upload both class and work schedules.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _timelineError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingClassJobStepIndex, true);

    final draft = ref.read(mockOnboardingProvider).draft;
    final aiController = ref.read(routineImportAiControllerProvider.notifier);
    final successfulSources = <RoutineImportReviewSource>{};
    final failedSources = <RoutineImportReviewSource>{};
    final photosToProcess = [..._photos]..sort(_comparePhotoSlots);
    _debugLogAiMode();

    try {
      for (final photo in photosToProcess) {
        if (!mounted) return;
        if (photo.source == RoutineImportReviewSource.classes) {
          ref.read(onboardingClassTimelineProvider.notifier).state = const [];
        } else {
          ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
        }
        _debugLogExtractionStart(photo);

        final now = DateTime.now();
        final reviewDraft = RoutineImportReviewDraft(
          id: 'onboarding_${photo.source.name}_import_review',
          uid: draft.uid,
          source: photo.source,
          status: RoutineImportReviewStatus.needsReview,
          sourceLabel: photo.label,
          uploadedAssetId: photo.asset.assetId,
          uploadedAssetR2Key: photo.asset.r2Key,
          uploadedAssetStatus: 'uploaded',
          createdAt: now,
          updatedAt: now,
        );

        final result = await aiController.runExtraction(reviewDraft);
        if (!mounted) return;

        final controllerState = ref.read(routineImportAiControllerProvider);
        final warnings =
            result?.warnings ??
            [controllerState.errorMessage ?? 'No extraction result returned.'];
        _debugLogExtractionResult(
          photo: photo,
          result: result,
          controllerState: controllerState,
          warnings: warnings,
        );
        final config = _configForSource(photo.source);
        final mapping = result == null
            ? const Onboarding4CandidateMappingResult(
                blocks: <ClassRoutineBlock>[],
                droppedNoTitle: 0,
                droppedInvalidTime: 0,
                droppedNoRepeatDays: 0,
                droppedNonWork: 0,
              )
            : _blocksFromCandidates(result.candidates, config);

        _debugLogExtractionMapped(photo: photo, mapping: mapping);

        if (mapping.blocks.isNotEmpty) {
          successfulSources.add(photo.source);
          if (photo.source == RoutineImportReviewSource.classes) {
            ref.read(onboardingClassTimelineProvider.notifier).state =
                mapping.blocks;
          } else {
            ref.read(onboardingWorkTimelineProvider.notifier).state =
                mapping.blocks;
          }
        } else {
          failedSources.add(photo.source);
        }
      }
    } finally {
      if (mounted) {
        ref
            .read(mockOnboardingProvider.notifier)
            .setStepLoading(onboardingClassJobStepIndex, false);
      }
    }

    if (!mounted) return;
    _debugLogRoleSummary();
    final anySuccess = successfulSources.isNotEmpty;
    final partialMessage = _partialFailureMessage(
      successfulSources: successfulSources,
      failedSources: failedSources,
    );
    setState(() {
      _isGenerating = false;
      _generationError = partialMessage;
      if (!anySuccess) {
        _timelineError = _timelineErrorForFailures(failedSources);
      }
    });
    if (anySuccess) _markClassJobDirty();
  }

  // ---- Sync local blocks back to provider (for edits) ----
  List<ClassRoutineBlock> _currentBlocks(ScheduleSetupConfig config) {
    return config.source == RoutineImportReviewSource.classes
        ? ref.read(onboardingClassTimelineProvider)
        : ref.read(onboardingWorkTimelineProvider);
  }

  AutoDisposeStateProvider<List<ClassRoutineBlock>> _providerFor(
    ScheduleSetupConfig config,
  ) {
    return config.source == RoutineImportReviewSource.classes
        ? onboardingClassTimelineProvider
        : onboardingWorkTimelineProvider;
  }

  ScheduleSetupConfig _configForBlock(ClassRoutineBlock block) {
    final classBlocks = ref.read(onboardingClassTimelineProvider);
    if (classBlocks.any(
      (item) => identical(item, block) || item.id == block.id,
    )) {
      return ScheduleSetupConfig.classSetup;
    }
    final workBlocks = ref.read(onboardingWorkTimelineProvider);
    if (workBlocks.any(
      (item) => identical(item, block) || item.id == block.id,
    )) {
      return ScheduleSetupConfig.workSetup;
    }
    if (_workRequired && !_classesRequired) {
      return ScheduleSetupConfig.workSetup;
    }
    return ScheduleSetupConfig.classSetup;
  }

  // ---- Edit sheet ----
  Future<void> _showEditDialog(ClassRoutineBlock item) async {
    final config = _configForBlock(item);
    final subjectCtrl = TextEditingController(text: item.subject);
    final startTimeCtrl = TextEditingController(text: item.displayStartTime);
    final endTimeCtrl = TextEditingController(text: item.displayEndTime);
    final roomCtrl = TextEditingController(text: item.room);
    final selectedDays = <int>{
      ..._safeRepeatDays(
        item.repeatDays.isEmpty ? <int>[_day + 1] : item.repeatDays,
      ),
    };
    final formKey = GlobalKey<FormState>();
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.editTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F111A),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (sheetError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: OptivusColors.danger.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: OptivusColors.danger.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  sheetError!,
                                  style: const TextStyle(
                                    color: OptivusColors.danger,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            // Day chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final dayName = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ][index];
                                  final day = index + 1;
                                  final isSelected = selectedDays.contains(day);
                                  return GestureDetector(
                                    onTap: () => setSheetState(() {
                                      if (selectedDays.contains(day)) {
                                        selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
                                      }
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? config.accent
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? config.accent
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        dayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: subjectCtrl,
                              decoration: InputDecoration(
                                labelText: config.subjectLabel,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: startTimeCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Start (e.g. 9:00 AM)',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: endTimeCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'End (e.g. 10:00 AM)',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: roomCtrl,
                              decoration: InputDecoration(
                                labelText: 'Location / Room (Optional)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Spacer(),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: config.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final subject = subjectCtrl.text.trim();
                                    final parsedStart = _parseClockMinute(
                                      startTimeCtrl.text,
                                    );
                                    final parsedEnd = _parseClockMinute(
                                      endTimeCtrl.text,
                                    );
                                    String? error;
                                    if (subject.isEmpty) {
                                      error = config.subjectRequiredText;
                                    } else if (parsedStart == null) {
                                      error =
                                          'Use a valid start time like 9:00 AM.';
                                    } else if (parsedEnd == null) {
                                      error =
                                          'Use a valid end time like 10:00 AM.';
                                    } else if (parsedEnd <= parsedStart) {
                                      error = config.endAfterStartText;
                                    } else if (parsedEnd - parsedStart >
                                        8 * 60) {
                                      error = config.durationTooLongText;
                                    } else if (selectedDays.isEmpty) {
                                      error = 'Select at least one repeat day.';
                                    }

                                    if (error != null) {
                                      setSheetState(() => sheetError = error);
                                      return;
                                    }

                                    final repeatDays = selectedDays.toList()
                                      ..sort();
                                    final updated = item.copyWith(
                                      subject: subject,
                                      room: roomCtrl.text.trim(),
                                      startMinute: parsedStart,
                                      endMinute: parsedEnd,
                                      repeatDays: repeatDays,
                                    );

                                    final provider = _providerFor(config);
                                    ref.read(provider.notifier).state = [
                                      for (final block in _currentBlocks(
                                        config,
                                      ))
                                        if (block.id == item.id)
                                          updated
                                        else
                                          block,
                                    ];
                                    _markClassJobDirty();

                                    Navigator.pop(ctx);
                                  },
                                  child: const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteBlock(ClassRoutineBlock item) {
    final config = _configForBlock(item);
    final provider = _providerFor(config);
    ref.read(provider.notifier).state = _currentBlocks(
      config,
    ).where((block) => block.id != item.id).toList(growable: false);
    if (_frontBlockId == item.id) {
      setState(() => _frontBlockId = null);
    }
    _markClassJobDirty();
  }

  Widget _buildBlockMenuButton(
    ClassRoutineBlock item, {
    required Color color,
    required double size,
  }) {
    final extent = size <= 10 ? 12.0 : size + 18;
    return PopupMenuButton<String>(
      key: ValueKey('onboarding-step4-menu-${item.id}'),
      tooltip: 'Block actions',
      padding: EdgeInsets.zero,
      iconSize: size,
      splashRadius: size <= 10 ? 10 : 18,
      child: SizedBox(
        width: extent,
        height: extent,
        child: Center(
          child: Icon(Icons.more_vert_rounded, color: color, size: size),
        ),
      ),
      onSelected: (value) {
        setState(() => _frontBlockId = item.id);
        if (value == 'edit') {
          _showEditDialog(item);
        } else if (value == 'delete') {
          _deleteBlock(item);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
        PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  // ---- Parse clock time (same as existing) ----
  static int? _parseClockMinute(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\s*$',
    ).firstMatch(value);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0');
    final period = match.group(3)?.toUpperCase();
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }

    var h = hour;
    if (period != null) {
      if (h < 1 || h > 12) return null;
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
    } else if (h < 0 || h > 23) {
      return null;
    }

    return h * 60 + minute;
  }

  static String _formatRange(int startMinute, int endMinute) {
    return '${TimelineUtils.formatMinute(startMinute)} - '
        '${TimelineUtils.formatMinute(endMinute)}';
  }

  // ======================================================================
  //  BUILD
  // ======================================================================
  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    // Watch providers so we re-build when blocks change
    final classBlocks = ref.watch(onboardingClassTimelineProvider);
    final workBlocks = ref.watch(onboardingWorkTimelineProvider);
    final visibleClassBlocks = _visibleClassBlocks(classBlocks);
    final visibleWorkBlocks = _visibleWorkBlocks(workBlocks);
    final allBlocks = [...visibleClassBlocks, ...visibleWorkBlocks];
    final hasBlocks = allBlocks.isNotEmpty;
    final hasConfirmedSchedule = _hasConfirmedScheduleForRole(
      draft.baseTimeline,
    );
    _clearIrrelevantProvidersForRole();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Upload card ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: hasConfirmedSchedule
              ? _buildSavedScheduleCard()
              : _buildUploadCard(),
        ),

        const SizedBox(height: 10),

        // ── Schedule header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Set Your Weekly Schedule',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _accent,
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // ── Day chips ──
        _buildDayChips(),

        // ── Timeline ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height =
                  constraints.maxHeight.isFinite && constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : _kMinTimelineAreaHeight;
              return SizedBox(
                height: height,
                child: _buildTimelineArea(allBlocks, hasBlocks),
              );
            },
          ),
        ),
      ],
    );
  }

  // ======================================================================
  //  Upload Card
  // ======================================================================
  Widget _buildUploadCard() {
    return KeyedSubtree(
      key: const ValueKey('onboarding-step4-upload-card'),
      child: OnboardingGlassCard(
        tint: _accent.withValues(alpha: 0.07),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(Icons.document_scanner_rounded, color: _accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _uploadTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _uploadSubtitle,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),

            const SizedBox(height: 8),

            _buildUploadTargetsRow(),

            if (_canSwapClassWorkPhotos) ...[
              const SizedBox(height: 6),
              _buildSwapControl(),
            ],

            // Generation error
            if (_generationError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: OptivusColors.warning,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _generationError!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTargetsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackTargets = _needsBothPhotos && constraints.maxWidth < 210;
        final pairTileWidth = constraints.maxWidth < 236 ? 72.0 : 80.0;
        final targets = _needsBothPhotos
            ? KeyedSubtree(
                key: const ValueKey('onboarding-step4-upload-targets-pair'),
                child: stackTargets
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < _uploadTargets.length;
                            index++
                          )
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == 0 ? 6 : 0,
                              ),
                              child: _buildUploadTarget(_uploadTargets[index]),
                            ),
                        ],
                      )
                    : Row(
                        key: const ValueKey(
                          'onboarding-step4-upload-targets-horizontal',
                        ),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (
                            var index = 0;
                            index < _uploadTargets.length;
                            index++
                          )
                            SizedBox(
                              width: pairTileWidth,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == 0 ? 8 : 0,
                                ),
                                child: _buildUploadTarget(
                                  _uploadTargets[index],
                                ),
                              ),
                            ),
                        ],
                      ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: _buildUploadTarget(_uploadTargets.first),
              );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: targets),
            ),
            if (_isUploading) ...[
              const SizedBox(width: 7),
              _buildUploadingIndicator(),
            ],
            const SizedBox(width: 8),
            _buildArrowButton(),
          ],
        );
      },
    );
  }

  Widget _buildSavedScheduleCard() {
    return OnboardingGlassCard(
      tint: _accent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: _accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Schedule generated',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Your fixed responsibilities are ready. Use each block menu to edit or remove it.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _confirmReplaceSchedule,
            icon: Icon(Icons.refresh_rounded, size: 16, color: _accent),
            label: const Text(
              'Replace schedule',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapControl() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _swapClassWorkPhotos,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 1.1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, color: _accent, size: 15),
                  const SizedBox(width: 6),
                  const Text(
                    'Swap Class / Work',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadTarget(_UploadTarget target) {
    final photo = _photoForSource(target.source);
    final width = _needsBothPhotos ? 72.0 : 102.0;
    return SizedBox(
      key: ValueKey('onboarding-step4-upload-target-${target.source.name}'),
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            target.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 9,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          photo == null
              ? _buildEmptyUploadTarget(target)
              : _buildPhotoThumbnail(photo, target),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(_PhotoSlot photo, _UploadTarget target) {
    final previewPath = photo.asset.localPreviewPath;
    final hasPreview = previewPath != null && File(previewPath).existsSync();

    return SizedBox(
      width: 56,
      height: 59,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasPreview
                  ? Image.file(File(previewPath), fit: BoxFit.cover)
                  : Container(
                      color: _accent.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.image_rounded,
                        color: _accent,
                        size: 24,
                      ),
                    ),
            ),
          ),
          // Label
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  target.thumbnailLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // X close button
          if (!_isUploading && !_isGenerating)
            Positioned(
              top: -5,
              right: -3,
              width: 22,
              height: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _removePhotoForSource(target.source),
                child: Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyUploadTarget(_UploadTarget target) {
    final disabled = _isUploading || _isGenerating;
    return SizedBox(
      width: 54,
      height: 50,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : () => _pickAndUpload(target),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: Colors.white.withValues(alpha: 0.5),
              border: Border.all(
                color: _accent.withValues(alpha: 0.3),
                width: 1.3,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(target.icon, color: _accent, size: 18),
                const SizedBox(height: 1),
                Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Container(
      width: 44,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: Colors.white.withValues(alpha: 0.5),
        border: Border.all(color: _accent.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
        ),
      ),
    );
  }

  Widget _buildArrowButton() {
    final bool spinning = _isGenerating;
    final bool enabled = _canTapGenerate;
    final bool active = enabled || spinning;

    return SizedBox(
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !spinning ? _runGeneration : null,
        child: Opacity(
          opacity: active ? 1 : 0.48,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? _accent.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.36),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.64),
                width: 1.4,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.62),
                        blurRadius: 8,
                        offset: const Offset(-3, -3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 5,
                      left: 12,
                      right: 12,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                    ),
                    if (spinning)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: active ? Colors.white : OptivusColors.textMuted,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  Day Chips
  // ======================================================================
  Widget _buildDayChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final dayName = [
              'MON',
              'TUE',
              'WED',
              'THU',
              'FRI',
              'SAT',
              'SUN',
            ][index];
            final isSelected = _day == index;
            return SizedBox(
              width: 52,
              height: 46,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _day = index),
                child: _buildDayChip(dayName, isSelected),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, bool selected) {
    final size = selected ? 42.0 : 36.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (selected ? _accent : Colors.black).withValues(
                  alpha: selected ? 0.07 : 0.035,
                ),
                blurRadius: selected ? 5 : 7,
                spreadRadius: 0,
                offset: Offset(0, selected ? 2 : 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: selected ? 0.60 : 0.70),
                blurRadius: selected ? 6 : 10,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? _accent.withValues(alpha: 0.68)
                      : Colors.white.withValues(alpha: 0.38),
                  border: Border.all(
                    color: selected
                        ? _accent.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.72),
                    width: selected ? 1.8 : 1.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 4,
                      left: 9,
                      right: 9,
                      height: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withValues(alpha: 0.46),
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: selected ? 12 : 10,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Colors.white
                            : OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  Timeline Area
  // ======================================================================
  Widget _buildTimelineArea(List<ClassRoutineBlock> allBlocks, bool hasBlocks) {
    // Generating state: show AI reading message
    if (_isGenerating) {
      return SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: OnboardingGlassCard(
                tint: _accent.withValues(alpha: 0.07),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _loadingTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'AI is generating your timeline.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!hasBlocks && _timelineError != null) {
      return SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: OnboardingGlassCard(
                tint: _accent.withValues(alpha: 0.08),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: _accent.withValues(alpha: 0.85),
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _timelineError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Has blocks: show the timeline
    if (hasBlocks) {
      return _buildTimeline(allBlocks);
    }

    // Empty: show placeholder
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: OnboardingGlassCard(
              tint: Colors.white.withValues(alpha: 0.30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: _accent.withValues(alpha: 0.75),
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _emptyTimelineHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  Timeline Rendering
  // ======================================================================
  Widget _buildTimeline(List<ClassRoutineBlock> allBlocks) {
    final dayItems =
        allBlocks
            .where((b) => b.repeatDays.contains(_day + 1))
            .toList(growable: false)
          ..sort(_compareBlocksByTime);
    final visualBlocks = _visualBlocksFor(dayItems);
    final paintedBlocks = _paintOrderedBlocks(visualBlocks);

    final range = _rangeFor(allBlocks);
    const topPadding = 18.0;
    const bottomPadding = _kTimelineBottomPadding;

    final maxCardBottom = dayItems.fold<double>(0, (maxBottom, item) {
      final top = _timelineY(
        minuteOfDay: item.startMinute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      final bottom = top + _blockVisualHeight(item);
      return bottom > maxBottom ? bottom : maxBottom;
    });

    final timelineHeight = [
      _timelineY(
            minuteOfDay: range.endMinute,
            visibleStartMinute: range.startMinute,
            topPadding: topPadding,
          ) +
          bottomPadding,
      maxCardBottom + bottomPadding,
    ].reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _kTimelineBottomPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final exposedLabelWidth = _overlapExposedLabelWidth(
                constraints.maxWidth,
              );

              return SizedBox(
                height: timelineHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Vertical rail
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 48,
                      width: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.40),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Minute tick indicators
                    ..._buildMinuteIndicators(
                      range: range,
                      dayItems: dayItems,
                      topPadding: topPadding,
                    ),

                    // Hour labels
                    ...List.generate(range.hourCount + 1, (i) {
                      final hour = (range.startHour + i) % 24;
                      final minute = range.startMinute + i * 60;
                      final ampm = hour < 12 ? 'AM' : 'PM';
                      final displayHour = hour == 0
                          ? 12
                          : (hour > 12 ? hour - 12 : hour);
                      final label = '$displayHour $ampm';
                      return Positioned(
                        top:
                            _timelineY(
                              minuteOfDay: minute,
                              visibleStartMinute: range.startMinute,
                              topPadding: topPadding,
                            ) -
                            10,
                        left: 0,
                        width: 56,
                        height: 20,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              width: 42,
                              child: Text(
                                label,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 48,
                              top: 9,
                              width: 4,
                              height: 1.5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (dayItems.isEmpty)
                      Positioned(
                        top: topPadding + 28,
                        left: _kLeftOffset,
                        right: 16,
                        child: OnboardingGlassCard(
                          tint: Colors.white.withValues(alpha: 0.30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: const Text(
                            'No fixed blocks on this day.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ),
                      ),

                    // Block cards
                    ...paintedBlocks.map(
                      (visual) => _buildColoredBlock(
                        visual,
                        visualBlocks: visualBlocks,
                        visibleStartMinute: range.startMinute,
                        topPadding: topPadding,
                        exposedLabelWidth: exposedLabelWidth,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- Minute indicators ----
  List<Widget> _buildMinuteIndicators({
    required _TimelineRange range,
    required List<ClassRoutineBlock> dayItems,
    required double topPadding,
  }) {
    final widgets = <Widget>[];
    final boundaryMinutes =
        (<int>{
            for (final item in dayItems) ...[item.startMinute, item.endMinute],
          }.where((minute) {
            return minute % 60 != 0 &&
                minute > range.startMinute &&
                minute < range.endMinute;
          }).toList())
          ..sort();

    var lastLabelY = double.negativeInfinity;
    for (final minute in boundaryMinutes) {
      final y = _timelineY(
        minuteOfDay: minute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      final showLabel = y - lastLabelY >= 18;
      if (showLabel) lastLabelY = y;
      widgets.addAll([
        if (showLabel)
          Positioned(
            top: y - 8,
            left: 0,
            width: 38,
            height: 16,
            child: Text(
              TimelineUtils.formatMinuteShort(minute),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _accent.withValues(alpha: 0.68),
              ),
            ),
          ),
        Positioned(
          top: y,
          left: _kLeftOffset,
          right: 16,
          height: 1,
          child: DecoratedBox(
            key: ValueKey('onboarding-step4-minute-line-$minute'),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: y,
          left: 44,
          width: 18,
          height: 1.5,
          child: DecoratedBox(
            key: ValueKey('onboarding-step4-minute-tick-$minute'),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ]);
    }

    return widgets;
  }

  // ---- Colored block card ----
  Widget _buildColoredBlock(
    _VisualTimelineBlock visual, {
    required List<_VisualTimelineBlock> visualBlocks,
    required int visibleStartMinute,
    required double topPadding,
    required double exposedLabelWidth,
  }) {
    final item = visual.block;
    final isFront = _isFrontVisual(visual, visualBlocks);
    final isBackOverlap = visual.hasOverlap && !isFront;
    final top = _timelineY(
      minuteOfDay: item.startMinute,
      visibleStartMinute: visibleStartMinute,
      topPadding: topPadding,
    );
    final exactHeight = _blockDurationHeight(item);
    final height = exactHeight;
    final compact = height < 92;
    final tiny = height < 42;
    final showSecondaryChips = !compact && height >= 96;

    final config = _configForBlock(item);
    final baseColor = item.color ?? config.accent;
    final backLabelInset = _backLabelInsetForVisual(visual);

    return Positioned(
      top: top,
      left: _leftForVisual(visual, visualBlocks, exposedLabelWidth),
      right: _rightForVisual(visual, visualBlocks),
      height: height,
      child: GestureDetector(
        key: ValueKey('onboarding-step4-block-${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _frontBlockId = item.id);
        },
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(
                alpha: visual.hasOverlap ? (isFront ? 0.72 : 0.58) : 0.42,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: isFront ? 0.26 : 0.18),
                  baseColor.withValues(alpha: isFront ? 0.08 : 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isFront ? 0.96 : 0.82),
                width: isFront ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: isFront ? 0.18 : 0.09),
                  blurRadius: isFront ? 14 : 10,
                  offset: Offset(0, isFront ? 5 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isBackOverlap
                        ? 8
                        : tiny
                        ? 8
                        : compact
                        ? 12
                        : 14,
                    vertical: isBackOverlap
                        ? 5
                        : tiny
                        ? 1
                        : compact
                        ? 7
                        : 10,
                  ),
                  child: isBackOverlap
                      ? _buildBackOverlapBlockContent(
                          item: item,
                          config: config,
                          baseColor: baseColor,
                          exposedLabelWidth: exposedLabelWidth,
                          labelInset: backLabelInset,
                          tiny: tiny,
                        )
                      : compact
                      ? KeyedSubtree(
                          key: ValueKey(
                            'onboarding-step4-front-content-${item.id}',
                          ),
                          child: _buildCompactBlockContent(
                            item: item,
                            config: config,
                            baseColor: baseColor,
                            showMenu: true,
                            tiny: tiny,
                          ),
                        )
                      : KeyedSubtree(
                          key: ValueKey(
                            'onboarding-step4-front-content-${item.id}',
                          ),
                          child: _buildRegularBlockContent(
                            item: item,
                            config: config,
                            baseColor: baseColor,
                            exactHeight: exactHeight,
                            showSecondaryChips: showSecondaryChips,
                            showMenu: true,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegularBlockContent({
    required ClassRoutineBlock item,
    required ScheduleSetupConfig config,
    required Color baseColor,
    required double exactHeight,
    required bool showSecondaryChips,
    required bool showMenu,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(item.icon ?? config.icon, color: baseColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F111A),
                ),
              ),
            ),
            if (showMenu)
              _buildBlockMenuButton(
                item,
                color: OptivusColors.textSecondary,
                size: 18,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildBlockInfoChip(
              _formatRange(item.startMinute, item.endMinute),
              compact: exactHeight < 84,
            ),
            if (showSecondaryChips && item.room.isNotEmpty)
              _buildBlockInfoChip(item.room),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactBlockContent({
    required ClassRoutineBlock item,
    required ScheduleSetupConfig config,
    required Color baseColor,
    required bool showMenu,
    required bool tiny,
  }) {
    final iconSize = tiny ? 8.0 : 16.0;
    final menuSize = tiny ? 6.0 : 16.0;
    final fontSize = tiny ? 8.0 : 13.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(item.icon ?? config.icon, color: baseColor, size: iconSize),
        SizedBox(width: tiny ? 5 : 7),
        Expanded(
          child: Text(
            item.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F111A),
            ),
          ),
        ),
        if (!tiny) ...[
          const SizedBox(width: 6),
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: _buildBlockInfoChip(
                _formatRange(item.startMinute, item.endMinute),
                compact: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        if (showMenu)
          _buildBlockMenuButton(
            item,
            color: OptivusColors.textSecondary,
            size: menuSize,
          ),
      ],
    );
  }

  Widget _buildBackOverlapBlockContent({
    required ClassRoutineBlock item,
    required ScheduleSetupConfig config,
    required Color baseColor,
    required double exposedLabelWidth,
    required double labelInset,
    required bool tiny,
  }) {
    final labelWidth = (exposedLabelWidth - labelInset - 14)
        .clamp(42.0, 96.0)
        .toDouble();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: labelInset),
        child: SizedBox(
          key: ValueKey('onboarding-step4-back-label-${item.id}'),
          width: labelWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: tiny ? 16 : 18,
                  height: tiny ? 16 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    item.icon ?? config.icon,
                    color: baseColor,
                    size: tiny ? 9 : 11,
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelWidth - 23),
                  child: Text(
                    item.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tiny ? 9 : 11,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockInfoChip(String text, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textBody,
        ),
      ),
    );
  }
}
