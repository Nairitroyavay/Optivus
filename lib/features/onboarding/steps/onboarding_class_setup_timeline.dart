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
  String subject;
  String room;
  String professor;
  double start; // Hours from 6 AM
  double duration; // Hours length
  IconData? icon;
  Color? color;
  bool isAdd;
  bool hasTopTape;
  bool hasBottomTape;
  bool reminderEnabled;
  int? weekday;
  String? suggestionId;

  int get startMinute => ((start + 6) * 60).round();
  int get endMinute => (((start + duration) + 6) * 60).round();

  String get displayStartTime => TimelineUtils.formatMinute(startMinute);
  String get displayEndTime => TimelineUtils.formatMinute(endMinute);

  ClassRoutineBlock({
    required this.id,
    required this.subject,
    this.room = '',
    this.professor = '',
    required this.start,
    this.duration = 1.0,
    this.icon,
    this.color,
    this.isAdd = false,
    this.hasTopTape = false,
    this.hasBottomTape = false,
    this.reminderEnabled = false,
    this.weekday,
    this.suggestionId,
  });

  ClassRoutineBlock clone() {
    return ClassRoutineBlock(
      id: id,
      subject: subject,
      room: room,
      professor: professor,
      start: start,
      duration: duration,
      icon: icon,
      color: color,
      isAdd: isAdd,
      hasTopTape: hasTopTape,
      hasBottomTape: hasBottomTape,
      reminderEnabled: reminderEnabled,
      weekday: weekday,
      suggestionId: suggestionId,
    );
  }
}


double _parseHoursFrom6AM(String timeStr) {
  try {
    timeStr = timeStr.trim().toUpperCase();
    bool isPM = timeStr.contains('PM');
    String cleaned = timeStr.replaceAll('AM', '').replaceAll('PM', '').trim();
    List<String> parts = cleaned.split(':');
    if (parts.isEmpty) return 0.0;
    int h = int.parse(parts[0]);
    int m = parts.length > 1 ? int.parse(parts[1]) : 0;

    if (isPM && h != 12) h += 12;
    if (!isPM && h == 12 && timeStr.contains('AM')) h = 0;

    double hoursFromMidnight = h + (m / 60.0);
    double from6AM = hoursFromMidnight - 6;
    if (from6AM < 0) from6AM += 24;
    return from6AM;
  } catch (e) {
    return 0.0;
  }
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
  int _colorIndex = 0;
  bool _localExtractionTriggered = false;

  @override
  void initState() {
    super.initState();
  }

  void _syncLocalBlocksToPending() {
    final candidates = ref.read(onboardingClassTimelineProvider);
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    if (pending == null) return;

    final blocks = candidates.map((c) => TimelineBlockDraft(
      id: c.id,
      section: 'classes',
      title: c.subject,
      startMinute: c.startMinute,
      endMinute: c.endMinute,
      repeatDays: c.weekday != null ? [c.weekday!] : [1],
      location: c.room.isNotEmpty ? c.room : null,
      blockType: 'hard_block',
      source: 'ai_import',
    )).toList();

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(pending.copyWith(parsedBlocks: blocks)),
    );
  }

  void _checkAndRunExtraction(BuildContext context) async {
    if (_localExtractionTriggered) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    final uploadState = ref.read(uploadControllerProvider);
    final purpose = onboardingUploadPurposeForBaseTimelineSection(onboardingSectionClasses);
    final applies = purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;

    // Wait until upload finishes
    if (applies && uploadState.isBusy) return;

    if (pending != null &&
        pending.hasUploadedAssetReference &&
        pending.parsedBlocks.isEmpty) {
      _localExtractionTriggered = true;

      // Extract
      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final reviewDraft = _extractionService.buildReviewDraft(
        uid: draft.uid,
        source: RoutineImportReviewSource.classes,
        onboardingDraft: draft,
      );

      final result = await aiController.runExtraction(reviewDraft);

      if (!mounted) return;

      if (result != null && result.candidates.isNotEmpty) {
        _populateTimelineFromCandidates(result.candidates);
        _syncLocalBlocksToPending();
      } else {
        // Zero blocks or error
        _updatePendingBlocks([]);
      }
      _localExtractionTriggered = false;
    } else if (pending != null && pending.parsedBlocks.isNotEmpty) {
       // If returning to screen and blocks exist, ensure we populate if empty
       final localBlocks = ref.read(onboardingClassTimelineProvider);
       if (localBlocks.isEmpty && !_localExtractionTriggered) {
          final reviewDraft = _extractionService.buildReviewDraft(
            uid: draft.uid,
            source: RoutineImportReviewSource.classes,
            onboardingDraft: draft,
          );
          _populateTimelineFromCandidates(reviewDraft.candidateBlocks);
       }
    }
  }

  void _updatePendingBlocks(List<RoutineImportCandidateBlock> candidates) {
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    if (pending == null) return;

    final blocks = candidates.map((c) => TimelineBlockDraft(
      id: c.id,
      section: 'classes',
      title: c.title,
      startMinute: c.startMinute,
      endMinute: c.endMinute,
      repeatDays: c.repeatDays,
      blockType: c.blockType,
      source: 'ai_import',
    )).toList();

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(pending.copyWith(parsedBlocks: blocks)),
    );
  }

  void _populateTimelineFromCandidates(List<RoutineImportCandidateBlock> candidates) {
    final Map<int, List<ClassRoutineBlock>> weekly = {
      for (int i = 0; i < 7; i++) i: <ClassRoutineBlock>[],
    };

    for (final candidate in candidates) {
      for (final day in candidate.repeatDays) {
        final dayIndex = (day - 1).clamp(0, 6);
        final startHours = ((candidate.startMinute / 60.0) - 6).clamp(0.0, 18.0).toDouble();
        final endHours = ((candidate.endMinute / 60.0) - 6).clamp(0.0, 18.0).toDouble();
        final duration = (endHours - startHours).clamp(0.5, 18.0).toDouble();

        weekly[dayIndex]!.add(
          ClassRoutineBlock(
            id: 'class_${dayIndex}_${candidate.id}',
            subject: candidate.title,
            room: candidate.location ?? '',
            start: startHours,
            duration: duration,
            icon: Icons.school_rounded,
            color: _cycleColors[_colorIndex % _cycleColors.length],
            hasTopTape: true,
            hasBottomTape: true,
            weekday: day,
          ),
        );
        _colorIndex++;
      }
    }

    final flatList = <ClassRoutineBlock>[];
    for (int i = 0; i < 7; i++) {
      weekly[i]!.sort((a, b) => a.start.compareTo(b.start));
      flatList.addAll(weekly[i]!);
    }

    ref.read(onboardingClassTimelineProvider.notifier).state = flatList;
  }

  Future<void> _startUpload(BuildContext context) async {
    final purpose = onboardingUploadPurposeForBaseTimelineSection(onboardingSectionClasses);
    if (purpose == null) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;
    final now = DateTime.now();
    final existing = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    
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

    final asset = await ref.read(uploadControllerProvider.notifier).startUpload(
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
      uploadedAssetStatus: asset?.status.name ??
          state.asset?.status.name ??
          (state.status == UploadFlowStatus.failed
              ? UploadedAssetStatus.failed.name
              : UploadedAssetStatus.uploaded.name),
      errorMessage: state.status == UploadFlowStatus.failed ? state.errorMessage : null,
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
      _checkAndRunExtraction(context);
    });

    final draft = ref.watch(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    final uploadState = ref.watch(uploadControllerProvider);
    final aiState = ref.watch(routineImportAiControllerProvider);

    final purpose = onboardingUploadPurposeForBaseTimelineSection(onboardingSectionClasses);
    final applies = purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;
    final busy = applies && uploadState.isBusy;
    final extracting = aiState.isExtracting;

    if (busy || extracting) {
      return _buildCenteredState(_buildLoadingState(busy ? 'Uploading photo...' : 'AI is reading your timetable…'));
    }

    if (pending?.hasUploadedAssetReference == true && pending!.parsedBlocks.isNotEmpty) {
       return _buildTimelineState();
    }

    if (pending?.hasUploadedAssetReference == true && pending!.parsedBlocks.isEmpty && !extracting && !busy) {
        return _buildCenteredState(_buildZeroBlocksState());
    }

    return _buildCenteredState(_buildUploadState());
  }

  Widget _buildCenteredState(Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLASSES & JOB',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.brandAccent,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Set the fixed responsibilities Optivus must protect.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
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
                child: CircularProgressIndicator(strokeWidth: 2.5, color: OptivusColors.aquaAccent),
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
              Icon(Icons.document_scanner_rounded, color: OptivusColors.aquaAccent),
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

  Widget _buildTimelineState() {
    final allBlocks = ref.watch(onboardingClassTimelineProvider);
    final dayItems = allBlocks.where((b) => b.weekday == _day + 1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFFEFCE8),
          ),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          children: [
                            const Color(0xFF93C5FD),
                            const Color(0xFF60A5FA),
                            const Color(0xFF3B82F6),
                          ].map((color) => Expanded(
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
                          )).toList(),
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
              ),
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
                final dayName = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][index];
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
                        color: isSelected ? const Color(0xFF378ADD) : Colors.white,
                        border: Border.all(
                          color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.05),
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
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
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
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5)),
            ),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: SizedBox(
                  height: 24 * kHourHeight,
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
                            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
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
                      ...List.generate(24, (i) {
                        final hour = (i + 6) % 24;
                        final ampm = hour < 12 ? 'AM' : 'PM';
                        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                        final label = "$displayHour $ampm";
                        return Positioned(
                          top: i * kHourHeight - 10,
                          left: 0,
                          width: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                              const SizedBox(width: 6),
                              Container(width: 4, height: 1.5, color: const Color(0xFFCBD5E1)),
                            ],
                          ),
                        );
                      }),
                      ...dayItems.map((item) => _buildColoredBlock(item)),
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

  Widget _buildColoredBlock(ClassRoutineBlock item) {
    final top = item.start * kHourHeight;
    final minHeight = 64.0;
    final calculatedHeight = item.duration * kHourHeight;
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_rounded, color: baseColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F111A)),
                          ),
                        ),
                        const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 18),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.displayStartTime} - ${item.displayEndTime}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                          ),
                        ),
                        if (item.room.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.room,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
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
  }

  Future<void> _showEditDialog(ClassRoutineBlock item) async {
    TextEditingController subjectCtrl = TextEditingController(text: item.subject);
    TextEditingController startTimeCtrl = TextEditingController(text: item.displayStartTime);
    TextEditingController endTimeCtrl = TextEditingController(text: item.displayEndTime);
    TextEditingController roomCtrl = TextEditingController(text: item.room);
    int selectedDay = item.weekday ?? _day + 1;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Edit Class', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F111A))),
                          const SizedBox(height: 20),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(7, (index) {
                                final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
                                final isSelected = selectedDay == index + 1;
                                return GestureDetector(
                                  onTap: () => setSheetState(() => selectedDay = index + 1),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? OptivusColors.aquaAccent : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? OptivusColors.aquaAccent : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      dayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : const Color(0xFF475569),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  ),
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
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  ),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  final currentList = ref.read(onboardingClassTimelineProvider);
                                  ref.read(onboardingClassTimelineProvider.notifier).state = currentList.where((b) => b.id != item.id).toList();
                                  _syncLocalBlocksToPending();
                                  Navigator.pop(ctx);
                                },
                                icon: const Icon(Icons.delete_outline_rounded, color: OptivusColors.danger, size: 20),
                                label: const Text('Delete', style: TextStyle(color: OptivusColors.danger, fontWeight: FontWeight.w800, fontSize: 15)),
                              ),
                              const Spacer(),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: OptivusColors.aquaAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;
                                  item.subject = subjectCtrl.text.trim();
                                  item.room = roomCtrl.text.trim();
                                  item.weekday = selectedDay;
                                  
                                  double parsedStart = _parseHoursFrom6AM(startTimeCtrl.text);
                                  double parsedEnd = _parseHoursFrom6AM(endTimeCtrl.text);
                                  if (parsedEnd <= parsedStart && parsedEnd != 0.0) parsedEnd += 24;
                                  item.start = parsedStart;
                                  item.duration = parsedEnd - parsedStart > 0.5 ? parsedEnd - parsedStart : 0.5;

                                  final currentList = ref.read(onboardingClassTimelineProvider);
                                  ref.read(onboardingClassTimelineProvider.notifier).state = [...currentList];
                                  _syncLocalBlocksToPending();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }
}
