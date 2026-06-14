// ---------------------------------------------------------------------------
// LEGACY CODE: This file contains the old split UI for class and work
// setup. It has been replaced by onboarding_step4_unified.dart.
// Kept for reference but is currently unused.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_step.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

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

int? _parseClockMinute(String value) {
  final match = RegExp(
    r'^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\s*$',
  ).firstMatch(value);
  if (match == null) return null;

  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0');
  final period = match.group(3)?.toUpperCase();
  if (hour == null || minute == null || minute < 0 || minute > 59) return null;

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

String _formatClassRange(int startMinute, int endMinute) {
  return '${TimelineUtils.formatMinute(startMinute)} - ${TimelineUtils.formatMinute(endMinute)}';
}

List<int> _safeClassRepeatDays(List<int> repeatDays) {
  final days = repeatDays.where((day) => day >= 1 && day <= 7).toSet().toList()
    ..sort();
  return days.isEmpty ? const [1] : days;
}

class _ClassTimelineRange {
  final int startHour;
  final int endHour;

  const _ClassTimelineRange({required this.startHour, required this.endHour});

  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
  int get hourCount => (endHour - startHour).clamp(1, 24);
}

class OnboardingClassSetupWidget extends ConsumerStatefulWidget {
  final int stepIndex;
  final ScheduleSetupConfig config;

  const OnboardingClassSetupWidget({
    super.key,
    required this.stepIndex,
    this.config = ScheduleSetupConfig.classSetup,
  });

  const OnboardingClassSetupWidget.work({super.key, required this.stepIndex})
    : config = ScheduleSetupConfig.workSetup;

  @override
  ConsumerState<OnboardingClassSetupWidget> createState() =>
      _OnboardingClassSetupWidgetState();
}

class _OnboardingClassSetupWidgetState
    extends ConsumerState<OnboardingClassSetupWidget> {
  final RoutineImportExtractionService _extractionService =
      const RoutineImportExtractionService();

  int _day = 0; // 0 for Mon, 6 for Sun
  final double kHourHeight = 84.0;
  final double kLeftOffset = 64.0;

  String? _activeExtractionKey;
  final Set<String> _extractionAttemptedKeys = <String>{};

  ScheduleSetupConfig get _config => widget.config;
  AutoDisposeStateProvider<List<ClassRoutineBlock>> get _provider {
    return _config.source == RoutineImportReviewSource.work
        ? onboardingWorkTimelineProvider
        : onboardingClassTimelineProvider;
  }

  @override
  void initState() {
    super.initState();
  }

  TimelineBlockDraft _timelineDraftFromClassBlock(ClassRoutineBlock block) {
    return TimelineBlockDraft(
      id: block.id,
      section: _config.timelineSection,
      title: block.subject,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      repeatDays: _safeClassRepeatDays(block.repeatDays),
      location: block.room.trim().isEmpty ? null : block.room.trim(),
      blockType: TimelineBlockDraft.hardBlockKey,
      source: 'ai_import',
    );
  }

  ClassRoutineBlock _classBlockFromTimelineDraft(
    TimelineBlockDraft block,
    int index,
  ) {
    return ClassRoutineBlock(
      id: block.id,
      subject: block.title,
      room: block.location ?? '',
      startMinute: block.startMinute.clamp(0, 24 * 60 - 1),
      endMinute: block.endMinute.clamp(1, 24 * 60),
      repeatDays: _safeClassRepeatDays(block.repeatDays),
      icon: _config.icon,
      color: _config.colorCycle[index % _config.colorCycle.length],
      hasTopTape: true,
      hasBottomTape: true,
    );
  }

  List<ClassRoutineBlock> _classBlocksFromTimelineDrafts(
    List<TimelineBlockDraft> blocks,
  ) {
    return blocks
        .asMap()
        .entries
        .map((entry) => _classBlockFromTimelineDraft(entry.value, entry.key))
        .where((block) => block.subject.trim().isNotEmpty)
        .where((block) => block.startMinute < block.endMinute)
        .toList(growable: false)
      ..sort((a, b) {
        final dayCompare = (a.weekday ?? 1).compareTo(b.weekday ?? 1);
        return dayCompare != 0
            ? dayCompare
            : a.startMinute.compareTo(b.startMinute);
      });
  }

  List<TimelineBlockDraft> _confirmedTimelineBlocks(BaseTimelineDraft base) {
    return base.confirmedBlocksForSection(_config.timelineSection);
  }

  bool _pendingStatusBlocksExtraction(PendingFutureImportDraft pending) {
    return pending.status != PendingFutureImportDraft.pendingStatus;
  }

  TimelineBlockDraft _timelineDraftFromCandidate(
    RoutineImportCandidateBlock candidate,
  ) {
    return TimelineBlockDraft(
      id: candidate.id,
      section: _config.timelineSection,
      title: candidate.title,
      startMinute: candidate.startMinute.clamp(0, 24 * 60 - 1),
      endMinute: candidate.endMinute.clamp(1, 24 * 60),
      repeatDays: _safeClassRepeatDays(candidate.repeatDays),
      location: candidate.location,
      blockType: TimelineBlockDraft.hardBlockKey,
      source: 'ai_import',
    );
  }

  String _pendingExtractionKey(PendingFutureImportDraft pending) {
    final assetKey = _uploadedAssetKey(pending);
    return '${pending.id}:${assetKey ?? pending.updatedAt.toIso8601String()}';
  }

  String? _uploadedAssetKey(PendingFutureImportDraft pending) {
    if (pending.uploadedAssetId?.trim().isNotEmpty == true) {
      return 'id:${pending.uploadedAssetId!.trim()}';
    }
    if (pending.uploadedAssetR2Key?.trim().isNotEmpty == true) {
      return 'r2:${pending.uploadedAssetR2Key!.trim()}';
    }
    return null;
  }

  bool _sameUploadedAsset(
    PendingFutureImportDraft first,
    PendingFutureImportDraft second,
  ) {
    final firstAssetId = first.uploadedAssetId?.trim();
    final secondAssetId = second.uploadedAssetId?.trim();
    if (firstAssetId?.isNotEmpty == true && firstAssetId == secondAssetId) {
      return true;
    }
    final firstR2Key = first.uploadedAssetR2Key?.trim();
    final secondR2Key = second.uploadedAssetR2Key?.trim();
    return firstR2Key?.isNotEmpty == true && firstR2Key == secondR2Key;
  }

  bool _uploadedAssetAlreadyHasParsedOutput(
    BaseTimelineDraft base,
    PendingFutureImportDraft pending,
  ) {
    final assetKey = _uploadedAssetKey(pending);
    if (assetKey == null) return false;
    return base.pendingFutureImports.any(
      (entry) =>
          entry.section == _config.sectionLabel &&
          entry.parsedBlocks.isNotEmpty &&
          _sameUploadedAsset(entry, pending),
    );
  }

  bool _hasAttemptedExtraction(PendingFutureImportDraft pending) {
    final key = _pendingExtractionKey(pending);
    return _activeExtractionKey == key ||
        _extractionAttemptedKeys.contains(key);
  }

  void _scheduleClassSetupStateWork({
    required PendingFutureImportDraft? pending,
    required List<TimelineBlockDraft> confirmedBlocks,
    required bool hasLocalBlocks,
    required bool uploadBusy,
    required bool extracting,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLocalTimelineFromPendingParsedBlocks();
      _triggerExtractionFromPendingIfNeeded(
        pending: pending,
        confirmedBlocks: confirmedBlocks,
        hasLocalBlocks: hasLocalBlocks,
        uploadBusy: uploadBusy,
        extracting: extracting,
      );
    });
  }

  void _syncLocalTimelineFromPendingParsedBlocks() {
    final localBlocks = ref.read(_provider);
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final confirmed = _confirmedTimelineBlocks(base);
    final pending = base.latestImportForSection(_config.sectionLabel);

    final sourceBlocks = confirmed.isNotEmpty
        ? confirmed
        : pending?.parsedBlocks ?? const <TimelineBlockDraft>[];
    if (sourceBlocks.isEmpty) return;

    final blocks = _classBlocksFromTimelineDrafts(sourceBlocks);

    if (blocks.isNotEmpty && !_sameClassBlocks(localBlocks, blocks)) {
      ref.read(_provider.notifier).state = blocks;
    }
  }

  bool _sameClassBlocks(
    List<ClassRoutineBlock> first,
    List<ClassRoutineBlock> second,
  ) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];
      if (a.id != b.id ||
          a.subject != b.subject ||
          a.room != b.room ||
          a.startMinute != b.startMinute ||
          a.endMinute != b.endMinute ||
          a.repeatDays.join(',') != b.repeatDays.join(',')) {
        return false;
      }
    }
    return true;
  }

  List<ClassRoutineBlock> _restoredBlocksFromDraft() {
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final confirmed = _confirmedTimelineBlocks(base);
    if (confirmed.isNotEmpty) {
      return _classBlocksFromTimelineDrafts(confirmed);
    }
    final pending = base.latestImportForSection(_config.sectionLabel);
    if (pending?.parsedBlocks.isNotEmpty == true) {
      return _classBlocksFromTimelineDrafts(pending!.parsedBlocks);
    }
    return const [];
  }

  List<ClassRoutineBlock> _currentEditableBlocks() {
    final restored = _restoredBlocksFromDraft();
    if (restored.isNotEmpty) return restored;
    final local = ref.read(_provider);
    return local;
  }

  Future<void> _persistCurrentDraftNow() async {
    final authUser = ref.read(authProvider).user;
    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = authUser?.uid.trim().isNotEmpty == true
        ? authUser!.uid.trim()
        : draft.uid.trim();
    if (uid.isEmpty) return;
    await ref
        .read(onboardingRepositoryProvider)
        .saveDraft(draft.copyWith(uid: uid));
  }

  void _persistCurrentDraftSoon() {
    unawaited(_persistCurrentDraftNow().catchError((_) {}));
  }

  Future<void> _syncLocalBlocksToPending() async {
    final candidates = ref.read(_provider);
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(
      _config.sectionLabel,
    );
    final now = DateTime.now();
    final target =
        pending ??
        PendingFutureImportDraft(
          id: onboardingImportId(_config.sectionLabel, 'photo_upload'),
          section: _config.sectionLabel,
          mode: 'Photo Upload',
          createdAt: now,
          updatedAt: now,
        );

    final blocks = candidates.map(_timelineDraftFromClassBlock).toList();

    updateBaseTimelineDraft(ref, widget.stepIndex, (base) {
      final hasConfirmed = _confirmedTimelineBlocks(base).isNotEmpty;
      final nextBase = hasConfirmed
          ? base.copyWith(
              blocks: [
                ...base.blocks.where(
                  (block) => block.section != _config.timelineSection,
                ),
                ...blocks,
              ],
            )
          : base;
      return nextBase.upsertPendingImport(
        target.copyWith(
          updatedAt: now,
          status: blocks.isEmpty
              ? PendingFutureImportDraft.errorStatus
              : PendingFutureImportDraft.parsedStatus,
          parsedBlocks: blocks,
          userEdited: true,
          clearErrorMessage: blocks.isNotEmpty,
        ),
      );
    });
    await _persistCurrentDraftNow();
  }

  void _triggerExtractionFromPendingIfNeeded({
    required PendingFutureImportDraft? pending,
    required List<TimelineBlockDraft> confirmedBlocks,
    required bool hasLocalBlocks,
    required bool uploadBusy,
    required bool extracting,
  }) {
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    if (pending == null ||
        confirmedBlocks.isNotEmpty ||
        hasLocalBlocks ||
        uploadBusy ||
        extracting ||
        !pending.hasUploadedAssetReference ||
        pending.parsedBlocks.isNotEmpty ||
        _uploadedAssetAlreadyHasParsedOutput(base, pending) ||
        _pendingStatusBlocksExtraction(pending)) {
      return;
    }

    final key = _pendingExtractionKey(pending);
    if (_activeExtractionKey == key || _extractionAttemptedKeys.contains(key)) {
      return;
    }

    _runExtractionForPending(key);
  }

  Future<void> _runExtractionForPending(String extractionKey) async {
    _extractionAttemptedKeys.add(extractionKey);
    setState(() => _activeExtractionKey = extractionKey);

    final draft = ref.read(mockOnboardingProvider).draft;
    final aiController = ref.read(routineImportAiControllerProvider.notifier);
    final reviewDraft = _extractionService.buildReviewDraft(
      uid: draft.uid,
      source: _config.source,
      onboardingDraft: draft,
    );

    final result = await aiController.runExtraction(reviewDraft);
    if (!mounted) return;

    if (result != null && result.candidates.isNotEmpty) {
      final parsedBlocks = result.candidates
          .map(_timelineDraftFromCandidate)
          .where((block) => block.title.trim().isNotEmpty)
          .where((block) => block.startMinute < block.endMinute)
          .toList(growable: false);
      await _updatePendingParsedBlocks(parsedBlocks);
      ref.read(_provider.notifier).state = parsedBlocks
          .asMap()
          .entries
          .map((entry) => _classBlockFromTimelineDraft(entry.value, entry.key))
          .toList(growable: false);
    } else {
      await _updatePendingParsedBlocks(
        const [],
        errorMessage: _config.clearFailureText,
      );
    }

    if (!mounted) return;
    setState(() => _activeExtractionKey = null);
  }

  Future<void> _updatePendingParsedBlocks(
    List<TimelineBlockDraft> blocks, {
    String? errorMessage,
  }) async {
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(
      _config.sectionLabel,
    );
    if (pending == null) return;

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(
        pending.copyWith(
          updatedAt: DateTime.now(),
          status: blocks.isEmpty
              ? PendingFutureImportDraft.errorStatus
              : PendingFutureImportDraft.parsedStatus,
          parsedBlocks: blocks,
          errorMessage: errorMessage,
          clearErrorMessage: errorMessage == null,
        ),
      ),
    );
    await _persistCurrentDraftNow();
  }

  Future<void> _startUpload(BuildContext context) async {
    final purpose = onboardingUploadPurposeForBaseTimelineSection(
      _config.sectionLabel,
    );
    if (purpose == null) return;

    setState(() => _activeExtractionKey = null);
    ref.read(_provider.notifier).state = const [];

    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;
    final now = DateTime.now();
    final existing = draft.baseTimeline.latestImportForSection(
      _config.sectionLabel,
    );

    final seed = PendingFutureImportDraft(
      id: onboardingImportId(_config.sectionLabel, 'photo_upload'),
      section: _config.sectionLabel,
      mode: 'Photo Upload',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: PendingFutureImportDraft.pendingStatus,
      parsedBlocks: const [], // Clear parsed blocks for new upload
    );

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(seed),
    );
    _persistCurrentDraftSoon();

    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: purpose,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );

    if (!mounted) return;
    final state = ref.read(uploadControllerProvider);
    final uploadedAssetId = asset?.assetId ?? state.asset?.assetId;
    final uploadedAssetR2Key = asset?.r2Key ?? state.asset?.r2Key;
    final hasUploadedAsset =
        uploadedAssetId?.trim().isNotEmpty == true ||
        uploadedAssetR2Key?.trim().isNotEmpty == true;
    final next = seed.copyWith(
      updatedAt: DateTime.now(),
      status: asset == null && state.status == UploadFlowStatus.failed
          ? PendingFutureImportDraft.errorStatus
          : PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: uploadedAssetId,
      uploadedAssetR2Key: uploadedAssetR2Key,
      uploadedAssetStatus:
          asset?.status.name ??
          state.asset?.status.name ??
          (state.status == UploadFlowStatus.failed
              ? UploadedAssetStatus.failed.name
              : hasUploadedAsset
              ? UploadedAssetStatus.uploaded.name
              : null),
      errorMessage: state.status == UploadFlowStatus.failed
          ? state.errorMessage
          : null,
      clearErrorMessage: state.status != UploadFlowStatus.failed,
    );

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(next),
    );
    await _persistCurrentDraftNow();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(uploadControllerProvider, (previous, next) {
      final draft = ref.read(mockOnboardingProvider).draft;
      final pending = draft.baseTimeline.latestImportForSection(
        _config.sectionLabel,
      );
      _triggerExtractionFromPendingIfNeeded(
        pending: pending,
        confirmedBlocks: _confirmedTimelineBlocks(draft.baseTimeline),
        hasLocalBlocks: ref.read(_provider).isNotEmpty,
        uploadBusy: next.isBusy,
        extracting: ref.read(routineImportAiControllerProvider).isExtracting,
      );
    });

    final draft = ref.watch(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(
      _config.sectionLabel,
    );
    final confirmedBlocks = _confirmedTimelineBlocks(draft.baseTimeline);
    final uploadState = ref.watch(uploadControllerProvider);
    final aiState = ref.watch(routineImportAiControllerProvider);
    final localBlocks = ref.watch(_provider);

    final purpose = onboardingUploadPurposeForBaseTimelineSection(
      _config.sectionLabel,
    );
    final applies =
        purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;
    final busy = applies && uploadState.isBusy;
    final extracting = aiState.isExtracting;
    final hasParsedBlocks = pending?.parsedBlocks.isNotEmpty == true;
    final hasConfirmedBlocks = confirmedBlocks.isNotEmpty;
    final hasUploadedAsset = pending?.hasUploadedAssetReference == true;
    final attemptedExtraction =
        pending != null && _hasAttemptedExtraction(pending);

    _scheduleClassSetupStateWork(
      pending: pending,
      confirmedBlocks: confirmedBlocks,
      hasLocalBlocks: localBlocks.isNotEmpty,
      uploadBusy: busy,
      extracting: extracting,
    );

    if (hasConfirmedBlocks || hasParsedBlocks || localBlocks.isNotEmpty) {
      final visibleBlocks = hasConfirmedBlocks
          ? _classBlocksFromTimelineDrafts(confirmedBlocks)
          : hasParsedBlocks
          ? _classBlocksFromTimelineDrafts(pending?.parsedBlocks ?? const [])
          : localBlocks;
      return _buildTimelineState(visibleBlocks);
    }

    if (busy || extracting || _activeExtractionKey != null) {
      return _buildCenteredState(
        _buildLoadingState(
          busy ? 'Uploading photo' : 'Processing your timetable',
        ),
      );
    }

    final canAttemptExtraction =
        pending != null &&
        pending.status == PendingFutureImportDraft.pendingStatus &&
        !_pendingStatusBlocksExtraction(pending) &&
        !_uploadedAssetAlreadyHasParsedOutput(draft.baseTimeline, pending);

    if (hasUploadedAsset && canAttemptExtraction && !attemptedExtraction) {
      return _buildCenteredState(
        _buildLoadingState('Processing your timetable'),
      );
    }

    if (hasUploadedAsset) {
      return _buildCenteredState(_buildZeroBlocksState());
    }

    return _buildCenteredState(_buildUploadState());
  }

  Widget _buildCenteredState(Widget child) {
    return _buildSetupBackground(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _config.setupTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _config.titleAccent,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeaderPill(),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupBackground(Widget child) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OptivusColors.onboardingTop,
            _config.accent.withValues(alpha: 0.10),
            OptivusColors.onboardingBottom,
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
      child: child,
    );
  }

  Widget _buildHeaderPill() {
    return OnboardingGlassCard(
      radius: 18,
      padding: EdgeInsets.zero,
      tint: _config.accent.withValues(alpha: 0.08),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.20),
                      _config.accent.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              _config.headerPillTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, bool selected) {
    final size = selected ? 46.0 : 38.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (selected ? _config.accent : Colors.black).withValues(
                alpha: selected ? 0.20 : 0.06,
              ),
              blurRadius: selected ? 14 : 8,
              offset: Offset(0, selected ? 6 : 3),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.70),
              blurRadius: 10,
              offset: const Offset(-3, -3),
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
                    ? _config.accent.withValues(alpha: 0.46)
                    : Colors.white.withValues(alpha: 0.38),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.96 : 0.72),
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
                      color: selected ? Colors.white : const Color(0xFF64748B),
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

  Widget _buildLoadingState(String message) {
    return AiThinkingCard(
      messages: [message],
      accent: _config.accent,
      isActive: true,
    );
  }

  Widget _buildZeroBlocksState() {
    return OnboardingGlassCard(
      tint: OptivusColors.warning.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: OptivusColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _config.clearFailureText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OnboardingActionPill(
            label: 'Upload again',
            icon: Icons.upload_rounded,
            accent: OptivusColors.warning,
            selected: true,
            onTap: () => _startUpload(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadState() {
    return OnboardingGlassCard(
      tint: _config.accent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: _config.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _config.uploadTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _config.uploadSubtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OnboardingActionPill(
            label: 'Upload photo',
            icon: Icons.upload_rounded,
            accent: _config.accent,
            selected: true,
            compact: true,
            onTap: () => _startUpload(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineState(List<ClassRoutineBlock> allBlocks) {
    final dayItems =
        allBlocks
            .where((b) => b.repeatDays.contains(_day + 1))
            .toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final range = _timelineRangeFor(allBlocks);
    const topPadding = 18.0;
    const bottomPadding = 220.0;
    final maxCardBottom = dayItems.fold<double>(0, (maxBottom, item) {
      final top =
          topPadding +
          ((item.startMinute - range.startMinute) / 60) * kHourHeight;
      final height = ((item.endMinute - item.startMinute) / 60) * kHourHeight;
      final bottom = top + (height < 72 ? 72 : height);
      return bottom > maxBottom ? bottom : maxBottom;
    });
    final timelineHeight = [
      topPadding + range.hourCount * kHourHeight + bottomPadding,
      maxCardBottom + bottomPadding,
    ].reduce((a, b) => a > b ? a : b);

    return _buildSetupBackground(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _config.setupTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _config.titleAccent,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeaderPill(),
                const SizedBox(height: 24),
                Text(
                  _config.mainTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _config.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          // Day Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  return GestureDetector(
                    onTap: () => setState(() => _day = index),
                    child: _buildDayChip(dayName, isSelected),
                  );
                }),
              ),
            ),
          ),
          // Timeline View
          Expanded(
            child: Container(
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
                  padding: const EdgeInsets.only(bottom: 220),
                  child: SizedBox(
                    height: timelineHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 48,
                          width: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ..._buildMinuteIndicators(
                          range: range,
                          dayItems: dayItems,
                          topPadding: topPadding,
                        ),
                        ...List.generate(range.hourCount + 1, (i) {
                          final hour = (range.startHour + i) % 24;
                          final ampm = hour < 12 ? 'AM' : 'PM';
                          final displayHour = hour == 0
                              ? 12
                              : (hour > 12 ? hour - 12 : hour);
                          final label = "$displayHour $ampm";
                          return Positioned(
                            top: topPadding + i * kHourHeight - 10,
                            left: 0,
                            width: 44,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 4,
                                  height: 1.5,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                          );
                        }),
                        ...dayItems.map(
                          (item) => _buildColoredBlock(
                            item,
                            rangeStartMinute: range.startMinute,
                            topPadding: topPadding,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMinuteIndicators({
    required _ClassTimelineRange range,
    required List<ClassRoutineBlock> dayItems,
    required double topPadding,
  }) {
    final widgets = <Widget>[];
    final boundaryMinutes = <int>{
      for (final item in dayItems) ...[item.startMinute, item.endMinute],
    }.where((minute) => minute % 60 != 0).toSet();

    for (
      var minute = range.startMinute + 15;
      minute < range.endMinute;
      minute += 15
    ) {
      final minutePart = minute % 60;
      if (minutePart == 0) continue;
      final isHalfHour = minutePart == 30;
      final top =
          topPadding + ((minute - range.startMinute) / 60) * kHourHeight;
      final showLabel = boundaryMinutes.contains(minute);
      widgets.add(
        Positioned(
          top: top,
          left: showLabel ? 2 : 34,
          right: showLabel ? null : 16,
          height: 1,
          child: Row(
            children: [
              if (showLabel)
                SizedBox(
                  width: 34,
                  child: Text(
                    TimelineUtils.formatMinuteShort(minute),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _config.accent.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              if (showLabel) const SizedBox(width: 8),
              Container(
                width: showLabel ? 10 : (isHalfHour ? 12 : 7),
                height: isHalfHour ? 1.4 : 1,
                color: _config.accent.withValues(
                  alpha: showLabel ? 0.34 : (isHalfHour ? 0.20 : 0.13),
                ),
              ),
              if (showLabel)
                Expanded(
                  child: Container(
                    height: 1,
                    color: _config.accent.withValues(alpha: 0.10),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    for (final minute in boundaryMinutes.where((minute) => minute % 15 != 0)) {
      if (minute <= range.startMinute || minute >= range.endMinute) continue;
      final top =
          topPadding + ((minute - range.startMinute) / 60) * kHourHeight;
      widgets.add(
        Positioned(
          top: top,
          left: 2,
          right: 16,
          height: 1,
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  TimelineUtils.formatMinuteShort(minute),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _config.accent.withValues(alpha: 0.58),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 1,
                color: _config.accent.withValues(alpha: 0.30),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: _config.accent.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  _ClassTimelineRange _timelineRangeFor(List<ClassRoutineBlock> blocks) {
    var startHour = 6;
    var endHour = 23;
    if (blocks.isNotEmpty) {
      final minStart = blocks
          .map((block) => block.startMinute)
          .reduce((a, b) => a < b ? a : b);
      final maxEnd = blocks
          .map((block) => block.endMinute)
          .reduce((a, b) => a > b ? a : b);
      if (minStart < 6 * 60) {
        startHour = (minStart ~/ 60).clamp(0, 23);
      }
      if (maxEnd > 23 * 60) {
        endHour = ((maxEnd + 59) ~/ 60).clamp(startHour + 1, 24);
      }
    }
    return _ClassTimelineRange(startHour: startHour, endHour: endHour);
  }

  Widget _buildColoredBlock(
    ClassRoutineBlock item, {
    required int rangeStartMinute,
    required double topPadding,
  }) {
    final top =
        topPadding + ((item.startMinute - rangeStartMinute) / 60) * kHourHeight;
    final minHeight = 72.0;
    final calculatedHeight = (item.durationMinutes / 60) * kHourHeight;
    final height = calculatedHeight < minHeight ? minHeight : calculatedHeight;

    final baseColor = item.color ?? _config.accent;

    return Positioned(
      top: top,
      left: kLeftOffset,
      right: 16,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor.withValues(alpha: 0.3),
                baseColor.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.icon ?? _config.icon,
                            color: baseColor,
                            size: 18,
                          ),
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
                          const Icon(
                            Icons.more_vert_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatClassRange(
                                item.startMinute,
                                item.endMinute,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          if (item.room.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.room,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
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
      ),
    );
  }

  Future<void> _showEditDialog(ClassRoutineBlock item) async {
    TextEditingController subjectCtrl = TextEditingController(
      text: item.subject,
    );
    TextEditingController startTimeCtrl = TextEditingController(
      text: item.displayStartTime,
    );
    TextEditingController endTimeCtrl = TextEditingController(
      text: item.displayEndTime,
    );
    TextEditingController roomCtrl = TextEditingController(text: item.room);
    final selectedDays = <int>{
      ..._safeClassRepeatDays(
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
                              _config.editTitle,
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
                                            ? _config.accent
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? _config.accent
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
                                labelText: _config.subjectLabel,
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
                                TextButton.icon(
                                  onPressed: () async {
                                    final currentList =
                                        _currentEditableBlocks();
                                    ref
                                        .read(_provider.notifier)
                                        .state = currentList
                                        .where((b) => b.id != item.id)
                                        .toList(growable: false);
                                    await _syncLocalBlocksToPending();
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: OptivusColors.danger,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: OptivusColors.danger,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _config.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () async {
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
                                      error = _config.subjectRequiredText;
                                    } else if (parsedStart == null) {
                                      error =
                                          'Use a valid start time like 9:00 AM.';
                                    } else if (parsedEnd == null) {
                                      error =
                                          'Use a valid end time like 10:00 AM.';
                                    } else if (parsedEnd <= parsedStart) {
                                      error = _config.endAfterStartText;
                                    } else if (parsedEnd - parsedStart >
                                        8 * 60) {
                                      error = _config.durationTooLongText;
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
                                    final currentList =
                                        _currentEditableBlocks();
                                    ref.read(_provider.notifier).state = [
                                      for (final block in currentList)
                                        if (block.id == item.id)
                                          updated
                                        else
                                          block,
                                    ];
                                    await _syncLocalBlocksToPending();
                                    if (!ctx.mounted) return;
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
}
