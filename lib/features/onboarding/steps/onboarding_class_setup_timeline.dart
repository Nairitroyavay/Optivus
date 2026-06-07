import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_step.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

final onboardingClassTimelineProvider =
    StateProvider.autoDispose<List<ClassRoutineBlock>>((ref) => []);

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

  const OnboardingClassSetupWidget({super.key, required this.stepIndex});

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

  final List<Color> _cycleColors = [
    const Color(0xFF378ADD), // Blue
    const Color(0xFFF59E0B), // Orange/Gold
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF43F5E), // Rose
  ];
  String? _activeExtractionKey;
  final Set<String> _extractionAttemptedKeys = <String>{};

  @override
  void initState() {
    super.initState();
  }

  TimelineBlockDraft _timelineDraftFromClassBlock(ClassRoutineBlock block) {
    return TimelineBlockDraft(
      id: block.id,
      section: 'classes',
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
      icon: Icons.school_rounded,
      color: _cycleColors[index % _cycleColors.length],
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

  TimelineBlockDraft _timelineDraftFromCandidate(
    RoutineImportCandidateBlock candidate,
  ) {
    return TimelineBlockDraft(
      id: candidate.id,
      section: 'classes',
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
    final assetKey = pending.uploadedAssetR2Key?.trim().isNotEmpty == true
        ? pending.uploadedAssetR2Key!.trim()
        : pending.uploadedAssetId?.trim();
    return '${pending.id}:${assetKey ?? pending.updatedAt.toIso8601String()}';
  }

  bool _hasAttemptedExtraction(PendingFutureImportDraft pending) {
    final key = _pendingExtractionKey(pending);
    return _activeExtractionKey == key ||
        _extractionAttemptedKeys.contains(key);
  }

  void _scheduleClassSetupStateWork({
    required PendingFutureImportDraft? pending,
    required bool uploadBusy,
    required bool extracting,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLocalTimelineFromPendingParsedBlocks();
      _triggerExtractionFromPendingIfNeeded(
        pending: pending,
        uploadBusy: uploadBusy,
        extracting: extracting,
      );
    });
  }

  void _syncLocalTimelineFromPendingParsedBlocks() {
    final localBlocks = ref.read(onboardingClassTimelineProvider);
    final pending = ref
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .latestImportForSection(onboardingSectionClasses);
    if (localBlocks.isNotEmpty ||
        pending == null ||
        pending.parsedBlocks.isEmpty) {
      return;
    }

    final blocks = _classBlocksFromTimelineDrafts(pending.parsedBlocks);

    if (blocks.isNotEmpty) {
      ref.read(onboardingClassTimelineProvider.notifier).state = blocks;
    }
  }

  void _syncLocalBlocksToPending() {
    final candidates = ref.read(onboardingClassTimelineProvider);
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(
      onboardingSectionClasses,
    );
    if (pending == null) return;

    final blocks = candidates.map(_timelineDraftFromClassBlock).toList();

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
          userEdited: true,
          clearErrorMessage: blocks.isNotEmpty,
        ),
      ),
    );
  }

  void _triggerExtractionFromPendingIfNeeded({
    required PendingFutureImportDraft? pending,
    required bool uploadBusy,
    required bool extracting,
  }) {
    if (pending == null ||
        uploadBusy ||
        extracting ||
        !pending.hasUploadedAssetReference ||
        pending.parsedBlocks.isNotEmpty) {
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
      source: RoutineImportReviewSource.classes,
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
      _updatePendingParsedBlocks(parsedBlocks);
      ref.read(onboardingClassTimelineProvider.notifier).state = parsedBlocks
          .asMap()
          .entries
          .map((entry) => _classBlockFromTimelineDraft(entry.value, entry.key))
          .toList(growable: false);
    } else {
      _updatePendingParsedBlocks(
        const [],
        errorMessage: 'We couldn’t detect classes clearly.',
      );
    }

    if (!mounted) return;
    setState(() => _activeExtractionKey = null);
  }

  void _updatePendingParsedBlocks(
    List<TimelineBlockDraft> blocks, {
    String? errorMessage,
  }) {
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(
      onboardingSectionClasses,
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
  }

  Future<void> _startUpload(BuildContext context) async {
    final purpose = onboardingUploadPurposeForBaseTimelineSection(
      onboardingSectionClasses,
    );
    if (purpose == null) return;

    setState(() => _activeExtractionKey = null);
    ref.read(onboardingClassTimelineProvider.notifier).state = const [];

    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;
    final now = DateTime.now();
    final existing = draft.baseTimeline.latestImportForSection(
      onboardingSectionClasses,
    );

    final seed = PendingFutureImportDraft(
      id: onboardingImportId(onboardingSectionClasses, 'photo_upload'),
      section: onboardingSectionClasses,
      mode: 'Photo Upload',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: existing?.uploadedAssetId,
      uploadedAssetR2Key: existing?.uploadedAssetR2Key,
      uploadedAssetStatus: existing?.uploadedAssetStatus,
      parsedBlocks: const [], // Clear parsed blocks for new upload
    );

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(seed),
    );

    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: purpose,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );

    if (!mounted) return;
    final state = ref.read(uploadControllerProvider);
    final next = seed.copyWith(
      updatedAt: DateTime.now(),
      status: asset == null && state.status == UploadFlowStatus.failed
          ? PendingFutureImportDraft.errorStatus
          : PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: asset?.assetId ?? state.asset?.assetId,
      uploadedAssetR2Key: asset?.r2Key ?? state.asset?.r2Key,
      uploadedAssetStatus:
          asset?.status.name ??
          state.asset?.status.name ??
          (state.status == UploadFlowStatus.failed
              ? UploadedAssetStatus.failed.name
              : UploadedAssetStatus.uploaded.name),
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
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(uploadControllerProvider, (previous, next) {
      final draft = ref.read(mockOnboardingProvider).draft;
      final pending = draft.baseTimeline.latestImportForSection(
        onboardingSectionClasses,
      );
      _triggerExtractionFromPendingIfNeeded(
        pending: pending,
        uploadBusy: next.isBusy,
        extracting: ref.read(routineImportAiControllerProvider).isExtracting,
      );
    });

    final draft = ref.watch(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(
      onboardingSectionClasses,
    );
    final uploadState = ref.watch(uploadControllerProvider);
    final aiState = ref.watch(routineImportAiControllerProvider);
    final localBlocks = ref.watch(onboardingClassTimelineProvider);

    final purpose = onboardingUploadPurposeForBaseTimelineSection(
      onboardingSectionClasses,
    );
    final applies =
        purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;
    final busy = applies && uploadState.isBusy;
    final extracting = aiState.isExtracting;
    final hasParsedBlocks = pending?.parsedBlocks.isNotEmpty == true;
    final hasUploadedAsset = pending?.hasUploadedAssetReference == true;
    final attemptedExtraction =
        pending != null && _hasAttemptedExtraction(pending);

    _scheduleClassSetupStateWork(
      pending: pending,
      uploadBusy: busy,
      extracting: extracting,
    );

    if (busy || extracting || _activeExtractionKey != null) {
      return _buildCenteredState(
        _buildLoadingState(
          busy ? 'Uploading photo...' : 'AI is reading your timetable…',
        ),
      );
    }

    if (hasParsedBlocks || localBlocks.isNotEmpty) {
      final visibleBlocks = localBlocks.isNotEmpty
          ? localBlocks
          : _classBlocksFromTimelineDrafts(pending?.parsedBlocks ?? const []);
      return _buildTimelineState(visibleBlocks);
    }

    if (hasUploadedAsset && !attemptedExtraction) {
      return _buildCenteredState(
        _buildLoadingState('AI is reading your timetable…'),
      );
    }

    if (hasUploadedAsset && attemptedExtraction) {
      return _buildCenteredState(_buildZeroBlocksState());
    }

    return _buildCenteredState(_buildUploadState());
  }

  Widget _buildCenteredState(Widget child) {
    return Container(
      color: const Color(0xFFFEFCE8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CLASS SETUP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706),
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

  Widget _buildHeaderPill() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children:
                    [
                          const Color(0xFF93C5FD),
                          const Color(0xFF60A5FA),
                          const Color(0xFF3B82F6),
                        ]
                        .map(
                          (color) => Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withValues(alpha: 0.1),
                                    color.withValues(alpha: 0.35),
                                    color.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const Center(
                child: Text(
                  'Set Your Weekly Class Schedule',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return OnboardingGlassCard(
      tint: OptivusColors.aquaAccent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: OptivusColors.aquaAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZeroBlocksState() {
    return OnboardingGlassCard(
      tint: OptivusColors.warning.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: OptivusColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'We couldn’t detect classes clearly.',
                  style: TextStyle(
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
      tint: OptivusColors.aquaAccent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.document_scanner_rounded,
                color: OptivusColors.aquaAccent,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload your class timetable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a clear photo of your weekly class schedule.',
            style: TextStyle(
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
            accent: OptivusColors.aquaAccent,
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
    const bottomPadding = 48.0;
    final maxCardBottom = dayItems.fold<double>(0, (maxBottom, item) {
      final top =
          topPadding +
          ((item.startMinute - range.startMinute) / 60) * kHourHeight;
      final height = ((item.endMinute - item.startMinute) / 60) * kHourHeight;
      final bottom = top + (height < 64 ? 64 : height);
      return bottom > maxBottom ? bottom : maxBottom;
    });
    final timelineHeight = [
      topPadding + range.hourCount * kHourHeight + bottomPadding,
      maxCardBottom + bottomPadding,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: const BoxDecoration(color: Color(0xFFFEFCE8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLASS SETUP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD97706),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildHeaderPill(),
              const SizedBox(height: 24),
              const Text(
                'Your Fixed Classes.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Stay on top of your semester with a clear timetable.',
                style: TextStyle(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFFEFCE8),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Container(
                      width: isSelected ? 44 : 36,
                      height: isSelected ? 44 : 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF378ADD)
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isSelected ? 0.15 : 0.05,
                            ),
                            blurRadius: isSelected ? 8 : 4,
                            offset: Offset(0, isSelected ? 4 : 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: isSelected ? 12 : 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
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
                padding: const EdgeInsets.only(bottom: 120),
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
    );
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

    final baseColor = item.color ?? OptivusColors.aquaAccent;

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
                            Icons.school_rounded,
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
    int selectedDay = item.weekday ?? _day + 1;
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
                            const Text(
                              'Edit Class',
                              style: TextStyle(
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
                                  final isSelected = selectedDay == index + 1;
                                  return GestureDetector(
                                    onTap: () => setSheetState(
                                      () => selectedDay = index + 1,
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? OptivusColors.aquaAccent
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? OptivusColors.aquaAccent
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
                                labelText: 'Subject',
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
                                  onPressed: () {
                                    final currentList = ref.read(
                                      onboardingClassTimelineProvider,
                                    );
                                    ref
                                        .read(
                                          onboardingClassTimelineProvider
                                              .notifier,
                                        )
                                        .state = currentList
                                        .where((b) => b.id != item.id)
                                        .toList(growable: false);
                                    _syncLocalBlocksToPending();
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
                                    backgroundColor: OptivusColors.aquaAccent,
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
                                      error = 'Subject is required.';
                                    } else if (parsedStart == null) {
                                      error =
                                          'Use a valid start time like 9:00 AM.';
                                    } else if (parsedEnd == null) {
                                      error =
                                          'Use a valid end time like 10:00 AM.';
                                    } else if (parsedEnd <= parsedStart) {
                                      error =
                                          'Classes must end after they start on the same day.';
                                    } else if (parsedEnd - parsedStart >
                                        8 * 60) {
                                      error =
                                          'That class duration looks too long. Use a normal class window.';
                                    }

                                    if (error != null) {
                                      setSheetState(() => sheetError = error);
                                      return;
                                    }

                                    final updated = item.copyWith(
                                      subject: subject,
                                      room: roomCtrl.text.trim(),
                                      startMinute: parsedStart,
                                      endMinute: parsedEnd,
                                      repeatDays: [selectedDay],
                                    );
                                    final currentList = ref.read(
                                      onboardingClassTimelineProvider,
                                    );
                                    ref
                                        .read(
                                          onboardingClassTimelineProvider
                                              .notifier,
                                        )
                                        .state = [
                                      for (final block in currentList)
                                        if (block.id == item.id)
                                          updated
                                        else
                                          block,
                                    ];
                                    _syncLocalBlocksToPending();
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
