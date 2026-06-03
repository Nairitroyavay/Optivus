import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/services/routine_import_conversion_service.dart';
import 'package:optivus/services/routine_import_ai_review_update_service.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';
import 'package:optivus/services/routine_import_timeline_edit_service.dart';
import 'package:optivus/services/routine_import_validation_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/auth_state.dart';

class RoutineImportReviewScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final RoutineImportSource source;

  const RoutineImportReviewScreen({
    super.key,
    required this.onBack,
    required this.source,
  });

  @override
  ConsumerState<RoutineImportReviewScreen> createState() =>
      _RoutineImportReviewScreenState();
}

class _RoutineImportReviewScreenState
    extends ConsumerState<RoutineImportReviewScreen> {
  static const double _pixelsPerMinute = 0.56;

  final RoutineImportExtractionService _extractionService =
      const RoutineImportExtractionService();
  final RoutineImportConversionService _conversionService =
      const RoutineImportConversionService();
  final RoutineImportValidationService _validationService =
      const RoutineImportValidationService();
  final RoutineImportAiReviewUpdateService _aiReviewUpdateService =
      const RoutineImportAiReviewUpdateService();

  RoutineImportReviewDraft? _review;
  bool _loading = true;
  bool _saving = false;
  bool _hadDeletedCandidate = false;
  final Set<String> _deletedCandidateIds = {};
  int _initialCandidateCount = 0;
  int _activeDay = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadReview);
  }

  @override
  void didUpdateWidget(covariant RoutineImportReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      Future.microtask(_loadReview);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final existing = ref.watch(routineNotifierProvider).items;
    final validation = review == null
        ? const RoutineImportValidationResult(candidateResults: [])
        : _validationService.validateCandidates(
            candidates: review.candidateBlocks,
            existingRoutineItems: existing,
          );
    final selected =
        review?.candidateBlocks
            .where((candidate) => candidate.selected)
            .toList(growable: false) ??
        const <RoutineImportCandidateBlock>[];
    final selectedHasBlockingIssues = selected.any(
      (candidate) => validation.hasBlockingIssuesFor(candidate.id),
    );
    final alreadyApplied = _alreadyApplied(review);
    final aiState = ref.watch(routineImportAiControllerProvider);
    final authUser = ref.watch(authProvider).user;

    return LiquidDetailScaffold(
      eyebrow: 'Routine import',
      title: '${review?.sourceLabel ?? _sourceLabel(widget.source)} Review',
      subtitle: 'Review before saving to Routine',
      accentColor: OptivusColors.routineAccent,
      onBack: widget.onBack,
      trailing: _HeaderSaveButton(
        enabled: !_loading && review != null && !_saving && !alreadyApplied,
        saving: _saving,
        blocked: selectedHasBlockingIssues,
        onTap: () => _saveAction(validation),
      ),
      children: [
        if (_loading)
          const LiquidDetailSection(
            title: 'Preparing review',
            children: [
              Text(
                'Loading onboarding import references...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          )
        else if (_errorMessage != null)
          _errorSection()
        else if (review != null) ...[
          _daySelector(),
          _sourceEvidenceSection(
            review: review,
            aiState: aiState,
            canRunAi: _canRunAiExtraction(
              review: review,
              emailVerified: authUser?.emailVerified,
            ),
            onRunAi: () => _runAiExtraction(review),
          ),
          if (alreadyApplied) _alreadyAppliedSection(review),
          _warningSummarySection(review, validation),
          _unplacedTray(review, validation),
          _timelineSection(review, validation),
          _footerActions(
            review: review,
            validation: validation,
            selectedCount: selected.length,
            selectedHasBlockingIssues: selectedHasBlockingIssues,
            alreadyApplied: alreadyApplied,
          ),
        ],
      ],
    );
  }

  Widget _errorSection() {
    return LiquidDetailSection(
      title: 'Import review error',
      tint: OptivusColors.danger.withValues(alpha: 0.08),
      children: [
        Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: OptivusColors.danger,
          ),
        ),
        const SizedBox(height: 12),
        _GlassTextButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          color: OptivusColors.routineAccent,
          onTap: _loadReview,
        ),
      ],
    );
  }

  Widget _daySelector() {
    return LiquidDetailSection(
      title: 'Day review',
      padding: const EdgeInsets.all(12),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(7, (index) {
              final day = index + 1;
              return Padding(
                padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
                child: _DayChip(
                  label: TimelineUtils.getShortDayName(day),
                  selected: _activeDay == day,
                  onTap: () => setState(() => _activeDay = day),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _sourceEvidenceSection({
    required RoutineImportReviewDraft review,
    required RoutineImportAiState aiState,
    required bool canRunAi,
    required VoidCallback onRunAi,
  }) {
    return LiquidDetailSection(
      title: 'Source evidence',
      children: [
        _SourceEvidenceCard(
          review: review,
          aiState: aiState,
          canRunAi: canRunAi,
          disabledReason: _aiDisabledReason(
            review: review,
            emailVerified: ref.read(authProvider).user?.emailVerified,
          ),
          onRunAi: onRunAi,
        ),
      ],
    );
  }

  Widget _alreadyAppliedSection(RoutineImportReviewDraft review) {
    return LiquidDetailSection(
      title: 'Already applied',
      tint: OptivusColors.success.withValues(alpha: 0.08),
      children: [
        const Text(
          'This review has already been applied to the Base Timeline. Normal save is disabled to avoid duplicate routine blocks.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w800,
            color: OptivusColors.success,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: review.appliedRoutineItemIds
              .map((id) => LiquidPill(label: id, color: OptivusColors.success))
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _warningSummarySection(
    RoutineImportReviewDraft review,
    RoutineImportValidationResult validation,
  ) {
    final messages = <String>[
      ...review.warnings,
      for (final candidate in review.candidateBlocks)
        ...validation
            .messagesFor(candidate.id)
            .map(
              (message) =>
                  '${candidate.title.trim().isEmpty ? 'Untitled' : candidate.title}: $message',
            ),
    ];
    if (messages.isEmpty) return const SizedBox.shrink();

    return LiquidDetailSection(
      title: 'Validation and confidence',
      tint: OptivusColors.warning.withValues(alpha: 0.08),
      children: [
        ...messages
            .take(6)
            .map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.warning,
                  ),
                ),
              ),
            ),
        if (messages.length > 6)
          Text(
            '+${messages.length - 6} more warnings',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _unplacedTray(
    RoutineImportReviewDraft review,
    RoutineImportValidationResult validation,
  ) {
    final unplaced = review.candidateBlocks
        .where((candidate) => _isUnplaced(candidate))
        .toList(growable: false);
    if (unplaced.isEmpty) return const SizedBox.shrink();

    return LiquidDetailSection(
      title: 'Unplaced / Flexible Tasks',
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: unplaced
              .map(
                (candidate) => _UnplacedCandidateChip(
                  candidate: candidate,
                  messages: validation.messagesFor(candidate.id),
                  onTap: () => _openCandidateEditor(candidate),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _timelineSection(
    RoutineImportReviewDraft review,
    RoutineImportValidationResult validation,
  ) {
    final dayCandidates =
        review.candidateBlocks
            .where(
              (candidate) =>
                  !_isUnplaced(candidate) &&
                  candidate.repeatDays.contains(_activeDay),
            )
            .toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return LiquidDetailSection(
      title: '${TimelineUtils.getShortDayName(_activeDay)} timeline',
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      children: [
        _VisualTimeline(
          candidates: dayCandidates,
          validation: validation,
          pixelsPerMinute: _pixelsPerMinute,
          onOpen: _openCandidateEditor,
          onMoveDelta: (candidate, delta) => _applyCandidateTimelineEdit(
            RoutineImportTimelineEditService.moveCandidate(
              candidate: candidate,
              deltaMinutes: delta,
            ),
          ),
          onResizeStartDelta: (candidate, delta) => _applyCandidateTimelineEdit(
            RoutineImportTimelineEditService.resizeCandidateStart(
              candidate: candidate,
              deltaMinutes: delta,
            ),
          ),
          onResizeEndDelta: (candidate, delta) => _applyCandidateTimelineEdit(
            RoutineImportTimelineEditService.resizeCandidateEnd(
              candidate: candidate,
              deltaMinutes: delta,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footerActions({
    required RoutineImportReviewDraft review,
    required RoutineImportValidationResult validation,
    required int selectedCount,
    required bool selectedHasBlockingIssues,
    required bool alreadyApplied,
  }) {
    return Row(
      children: [
        Expanded(
          child: _RoutineButton(
            label: 'Add block',
            color: OptivusColors.textSecondary,
            onTap: _saving || alreadyApplied ? null : _addCandidate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoutineButton(
            label: alreadyApplied
                ? 'Already applied'
                : _saving
                ? 'Saving...'
                : selectedHasBlockingIssues
                ? 'Fix issues'
                : selectedCount == 0
                ? 'Save review'
                : 'Save to Base Timeline',
            color:
                alreadyApplied ||
                    selectedHasBlockingIssues ||
                    selectedCount == 0
                ? OptivusColors.textSecondary
                : OptivusColors.routineAccent,
            onTap: _saving || alreadyApplied
                ? null
                : () => _saveAction(validation),
          ),
        ),
      ],
    );
  }

  Future<void> _loadReview() async {
    setState(() {
      _loading = true;
      _saving = false;
      _errorMessage = null;
      _review = null;
      _hadDeletedCandidate = false;
      _deletedCandidateIds.clear();
      _initialCandidateCount = 0;
    });

    try {
      final uid = _currentUid();
      final source = _reviewSourceFor(widget.source);
      final onboardingRepository = ref.read(onboardingRepositoryProvider);
      var onboardingDraft = ref
          .read(mockOnboardingProvider)
          .draft
          .copyWith(uid: uid);

      if (!_hasRelevantDraftSource(onboardingDraft, source) &&
          uid.trim().isNotEmpty) {
        final fetched = await onboardingRepository.fetchDraft(uid);
        if (fetched != null) {
          onboardingDraft = fetched.copyWith(
            uid: uid,
            stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
          );
          ref
              .read(mockOnboardingProvider.notifier)
              .loadSeedData(onboardingDraft);
        }
      }

      RoutineImportReviewDraft builtReview;
      if (_hasRelevantDraftSource(onboardingDraft, source)) {
        builtReview = _extractionService.buildReviewDraft(
          uid: uid,
          source: source,
          onboardingDraft: onboardingDraft,
        );
      } else {
        final bundle = await onboardingRepository.fetchCompletionBundle(uid);
        builtReview = bundle != null && _hasRelevantBundleSource(bundle, source)
            ? _extractionService.buildReviewDraftFromCompletionBundle(
                uid: uid,
                source: source,
                bundle: bundle,
              )
            : _extractionService.buildReviewDraft(
                uid: uid,
                source: source,
                onboardingDraft: onboardingDraft,
              );
      }

      final repository = ref.read(routineImportReviewRepositoryProvider);
      final savedReview = await repository.fetchReview(
        uid: uid,
        reviewId: builtReview.id,
      );
      final review = savedReview ?? builtReview;
      if (savedReview == null) {
        await repository.saveReview(review);
      }

      if (!mounted) return;
      setState(() {
        _review = review;
        _initialCandidateCount = review.candidateBlocks.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  bool _hasRelevantDraftSource(
    OnboardingDraft draft,
    RoutineImportReviewSource source,
  ) {
    final sectionLabel = _extractionService.sourceSectionLabel(source);
    final sectionKey = _extractionService.timelineSectionKey(source);
    return draft.baseTimeline.pendingFutureImports.any(
          (entry) => entry.section == sectionLabel,
        ) ||
        draft.baseTimeline.blocks.any((block) => block.section == sectionKey);
  }

  bool _hasRelevantBundleSource(
    OnboardingCompletionBundle bundle,
    RoutineImportReviewSource source,
  ) {
    final sectionLabel = _extractionService.sourceSectionLabel(source);
    final sectionKey = _extractionService.timelineSectionKey(source);
    final purposeKey = _extractionService.uploadedAssetPurposeKey(source);
    return bundle.baseTimelineBlocks.any(
          (block) => block.section == sectionKey,
        ) ||
        bundle.uploadedAssetReferences.any((entry) {
          final sectionMatches = entry.section == sectionLabel;
          final keyMatches =
              purposeKey != null &&
              (entry.uploadedAssetR2Key?.contains('/$purposeKey/') ?? false);
          return sectionMatches || keyMatches;
        });
  }

  String _currentUid() {
    final authUid = ref.read(authProvider).user?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid;
    final profileUid = ref.read(mockUserProfileProvider).uid;
    if (profileUid.trim().isNotEmpty) return profileUid;
    final draftUid = ref.read(mockOnboardingProvider).draft.uid;
    if (draftUid.trim().isNotEmpty) return draftUid;
    return 'local-routine-import-review';
  }

  bool _alreadyApplied(RoutineImportReviewDraft? review) {
    return review?.blocksDuplicateApply ?? false;
  }

  bool _canRunAiExtraction({
    required RoutineImportReviewDraft review,
    required bool? emailVerified,
  }) {
    return _aiDisabledReason(review: review, emailVerified: emailVerified) ==
        null;
  }

  String? _aiDisabledReason({
    required RoutineImportReviewDraft review,
    required bool? emailVerified,
  }) {
    if (OptivusRoutineImportAiConfig.mode ==
        OptivusRoutineImportAiMode.disabled) {
      return 'AI disabled';
    }
    if (_alreadyApplied(review)) return 'Already applied';
    if (review.uploadedAssetR2Key?.trim().isEmpty ?? true) {
      return 'Upload photo first';
    }
    if (emailVerified != true) return 'Verify email first';
    if (ref.read(routineImportAiControllerProvider).isExtracting) {
      return 'Extracting...';
    }
    return null;
  }

  bool _isUnplaced(RoutineImportCandidateBlock candidate) {
    return candidate.isUnplaced;
  }

  Future<void> _replaceCandidates(
    List<RoutineImportCandidateBlock> candidates,
  ) async {
    final review = _review;
    if (review == null) return;
    final validation = _validationService.validateCandidates(
      candidates: candidates,
      existingRoutineItems: ref.read(routineNotifierProvider).items,
    );
    final nextCandidates = _candidatesWithValidation(candidates, validation);
    final next = review.copyWith(
      candidateBlocks: nextCandidates,
      status: nextCandidates.any((candidate) => candidate.needsManualReview)
          ? RoutineImportReviewStatus.needsReview
          : RoutineImportReviewStatus.draft,
      updatedAt: DateTime.now(),
    );
    setState(() => _review = next);
    await _persistReview(next);
  }

  Future<void> _persistReview(RoutineImportReviewDraft review) async {
    try {
      await ref.read(routineImportReviewRepositoryProvider).saveReview(review);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _applyCandidateTimelineEdit(
    RoutineImportCandidateBlock candidate,
  ) async {
    final review = _review;
    if (review == null || _alreadyApplied(review)) return;
    await _replaceCandidates([
      for (final item in review.candidateBlocks)
        if (item.id == candidate.id) candidate else item,
    ]);
  }

  Future<void> _deleteCandidate(RoutineImportCandidateBlock candidate) async {
    final review = _review;
    if (review == null || _alreadyApplied(review)) return;
    _hadDeletedCandidate = true;
    _deletedCandidateIds.add(candidate.id);
    await _replaceCandidates(
      review.candidateBlocks
          .where((item) => item.id != candidate.id)
          .toList(growable: false),
    );
  }

  Future<void> _addCandidate() async {
    final review = _review;
    if (review == null || _alreadyApplied(review)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final blockType = _defaultBlockTypeForSource(review.source);
    final candidate = RoutineImportCandidateBlock(
      id: 'added_${review.source.name}_$now',
      title: _defaultTitleForSource(review.source),
      startMinute: 15 * 60,
      endMinute: 15 * 60 + 45,
      hasFixedTime: true,
      repeatDays: [_activeDay],
      blockType: blockType,
      category: _categoryNameForReviewSource(review.source),
      hardBlock: blockType == TimelineBlockDraft.hardBlockKey,
      selected: true,
      candidateType: RoutineImportCandidateType.block,
      confidenceLabel: 'manual',
      extractionEngine: 'manualSeed',
      extractionVersion: 'phase2c',
      notes: 'Added during import review.',
    );
    await _replaceCandidates([...review.candidateBlocks, candidate]);
  }

  Future<void> _runAiExtraction(RoutineImportReviewDraft review) async {
    if (_alreadyApplied(review)) return;
    setState(() => _errorMessage = null);

    if (_shouldConfirmAiReplacement(review)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Replace starter candidates?'),
            content: const Text(
              'AI extraction will replace starter candidates. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    final result = await ref
        .read(routineImportAiControllerProvider.notifier)
        .runExtraction(review);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _errorMessage = ref
            .read(routineImportAiControllerProvider)
            .errorMessage;
      });
      return;
    }
    if (result.candidates.isEmpty) {
      await _persistExtractionWarning(review, result);
      if (!mounted) return;
      setState(() {
        _errorMessage = result.warnings.isEmpty
            ? 'AI extraction did not return candidates.'
            : result.warnings.join('\n');
      });
      return;
    }
    await _applyExtractionResult(review: review, result: result);
  }

  bool _shouldConfirmAiReplacement(RoutineImportReviewDraft review) {
    return review.candidateBlocks.isNotEmpty &&
        (review.extractionAttemptCount > 0 ||
            review.candidateBlocks.any((candidate) => candidate.selected));
  }

  Future<void> _persistExtractionWarning(
    RoutineImportReviewDraft review,
    RoutineImportExtractionResult result,
  ) async {
    final next = _aiReviewUpdateService.recordExtractionWarning(
      review: review,
      result: result,
    );
    setState(() => _review = next);
    await _persistReview(next);
  }

  Future<void> _applyExtractionResult({
    required RoutineImportReviewDraft review,
    required RoutineImportExtractionResult result,
  }) async {
    final next = _aiReviewUpdateService.applySuccessfulExtraction(
      review: review,
      result: result,
      existingRoutineItems: ref.read(routineNotifierProvider).items,
    );
    setState(() {
      _review = next;
      _initialCandidateCount = next.candidateBlocks.length;
    });
    await _persistReview(next);
  }

  Future<void> _saveAction(RoutineImportValidationResult validation) async {
    final review = _review;
    if (review == null || _saving) return;
    if (_alreadyApplied(review)) {
      setState(() {
        _errorMessage =
            'This review was already applied. Reopen Base Timeline to edit the saved routine items.';
      });
      return;
    }

    final selectedCount = review.candidateBlocks
        .where((candidate) => candidate.selected)
        .length;
    if (selectedCount == 0) {
      final savedReview = review.copyWith(updatedAt: DateTime.now());
      setState(() => _review = savedReview);
      await _persistReview(savedReview);
      return;
    }

    await _saveAcceptedReview(validation);
  }

  Future<void> _saveAcceptedReview(
    RoutineImportValidationResult validation,
  ) async {
    final review = _review;
    if (review == null || _saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final candidatesWithValidation = _candidatesWithValidation(
        review.candidateBlocks,
        validation,
      );
      final selectedBlockingIssues = candidatesWithValidation
          .where((candidate) => candidate.selected)
          .where((candidate) => validation.hasBlockingIssuesFor(candidate.id))
          .toList(growable: false);
      if (selectedBlockingIssues.isNotEmpty) {
        final blockedReview = review.copyWith(
          candidateBlocks: candidatesWithValidation,
          updatedAt: DateTime.now(),
        );
        await _persistReview(blockedReview);
        if (!mounted) return;
        setState(() {
          _review = blockedReview;
          _saving = false;
          _errorMessage = 'Fix invalid selected candidates before saving.';
        });
        return;
      }

      final routineItems = _conversionService.convertAcceptedCandidates(
        reviewId: review.id,
        candidates: candidatesWithValidation,
      );
      if (routineItems.isEmpty) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorMessage =
              'Assign a valid time to selected candidates before saving.';
        });
        return;
      }

      final routineController = ref.read(routineNotifierProvider.notifier);
      final existingIds = ref
          .read(routineNotifierProvider)
          .items
          .map((item) => item.id)
          .toSet();
      final appliedRoutineItemIds = <String>[];
      for (final item in routineItems) {
        if (existingIds.contains(item.id)) continue;
        final itemWithUser = item.copyWith(userId: review.uid);
        appliedRoutineItemIds.add(itemWithUser.id);
        await routineController.addItem(itemWithUser);
      }

      final selected = candidatesWithValidation
          .where((candidate) => candidate.selected)
          .toList(growable: false);
      final acceptedCandidateIds = selected
          .map((candidate) => candidate.id)
          .toList(growable: false);
      final rejectedCandidateIds = {
        ..._deletedCandidateIds,
        for (final candidate in candidatesWithValidation)
          if (!candidate.selected) candidate.id,
      }.toList(growable: false);
      final now = DateTime.now();
      final status = acceptedCandidateIds.isEmpty
          ? RoutineImportReviewStatus.rejected
          : _isPartialAcceptance(
              review.copyWith(candidateBlocks: candidatesWithValidation),
            )
          ? RoutineImportReviewStatus.partiallyAccepted
          : RoutineImportReviewStatus.accepted;
      final acceptedReview = review.copyWith(
        candidateBlocks: candidatesWithValidation,
        status: status,
        acceptedCandidateIds: acceptedCandidateIds,
        rejectedCandidateIds: rejectedCandidateIds,
        appliedRoutineItemIds: appliedRoutineItemIds,
        appliedAt: acceptedCandidateIds.isEmpty ? null : now,
        updatedAt: now,
      );
      await ref
          .read(routineImportReviewRepositoryProvider)
          .saveReview(acceptedReview);
      if (status == RoutineImportReviewStatus.accepted) {
        await ref
            .read(routineImportReviewRepositoryProvider)
            .markAccepted(uid: review.uid, reviewId: review.id);
      }
      if (acceptedCandidateIds.isNotEmpty) {
        await _markOnboardingPendingImportApplied(acceptedReview);
      }

      if (!mounted) return;
      setState(() {
        _review = acceptedReview;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = error.toString();
      });
    }
  }

  List<RoutineImportCandidateBlock> _candidatesWithValidation(
    List<RoutineImportCandidateBlock> candidates,
    RoutineImportValidationResult validation,
  ) {
    return [
      for (final candidate in candidates)
        candidate.copyWith(
          validationIssues: validation.messagesFor(candidate.id),
        ),
    ];
  }

  bool _isPartialAcceptance(RoutineImportReviewDraft review) {
    if (_hadDeletedCandidate) return true;
    if (_initialCandidateCount > review.candidateBlocks.length) return true;
    return review.candidateBlocks.any((candidate) => !candidate.selected);
  }

  Future<void> _markOnboardingPendingImportApplied(
    RoutineImportReviewDraft review,
  ) async {
    final importId = review.onboardingPendingImportId;
    if (importId == null || importId.trim().isEmpty) return;
    final repository = ref.read(onboardingRepositoryProvider);
    var draft = ref.read(mockOnboardingProvider).draft;
    if (!draft.baseTimeline.pendingFutureImports.any(
      (entry) => entry.id == importId,
    )) {
      final fetched = await repository.fetchDraft(review.uid);
      if (fetched == null) return;
      draft = fetched;
    }

    var changed = false;
    final now = DateTime.now();
    final nextImports = [
      for (final entry in draft.baseTimeline.pendingFutureImports)
        if (entry.id == importId)
          entry.copyWith(
            status: PendingFutureImportDraft.appliedStatus,
            updatedAt: now,
            userVerified: true,
            userEdited: true,
          )
        else
          entry,
    ];
    changed = nextImports.any((entry) {
      final current = draft.baseTimeline.pendingFutureImports.firstWhere(
        (candidate) => candidate.id == entry.id,
      );
      return current.status != entry.status ||
          current.updatedAt != entry.updatedAt ||
          current.userVerified != entry.userVerified ||
          current.userEdited != entry.userEdited;
    });
    if (!changed) return;

    final nextDraft = draft.copyWith(
      uid: review.uid,
      updatedAt: now,
      baseTimeline: draft.baseTimeline.copyWith(
        pendingFutureImports: nextImports,
      ),
      clearFinalPreview: true,
    );
    ref.read(mockOnboardingProvider.notifier).loadSeedData(nextDraft);
    await repository.saveDraft(nextDraft);
  }

  Future<void> _openCandidateEditor(
    RoutineImportCandidateBlock candidate,
  ) async {
    final review = _review;
    if (review == null || _alreadyApplied(review)) return;

    final titleController = TextEditingController(text: candidate.title);
    final locationController = TextEditingController(
      text: candidate.location ?? '',
    );
    final notesController = TextEditingController(text: candidate.notes ?? '');
    final mealController = TextEditingController(
      text: candidate.mealCategory ?? '',
    );
    final stepsController = TextEditingController(
      text: candidate.steps.join(', '),
    );
    var startMinute = candidate.startMinute.clamp(0, 1430);
    var endMinute = candidate.endMinute.clamp(startMinute + 10, 1440);
    var repeatDays = candidate.repeatDays.toSet();
    var blockType = candidate.blockType;
    var candidateType = candidate.candidateType;
    var category = candidate.category;
    var selected = candidate.selected;
    var needsManualReview = candidate.needsManualReview;
    var hasFixedTime = candidate.hasFixedTime;

    final updated = await showModalBottomSheet<RoutineImportCandidateBlock>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Material(
                    color: OptivusColors.routineBgTop,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SheetHeader(
                            title: 'Candidate details',
                            onClose: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 14),
                          _SheetSection(
                            title: 'Main',
                            children: [
                              _SheetTextField(
                                controller: titleController,
                                label: 'Title',
                              ),
                              const SizedBox(height: 10),
                              _SheetSwitchRow(
                                label: selected ? 'Selected' : 'Skipped',
                                value: selected,
                                onChanged: (value) =>
                                    setSheetState(() => selected = value),
                              ),
                            ],
                          ),
                          _SheetSection(
                            title: 'Time & Days',
                            children: [
                              _SheetSwitchRow(
                                label: hasFixedTime
                                    ? 'Fixed time'
                                    : 'Unplaced / flexible',
                                value: hasFixedTime,
                                onChanged: (value) =>
                                    setSheetState(() => hasFixedTime = value),
                              ),
                              if (hasFixedTime) ...[
                                const SizedBox(height: 8),
                                _TimeSlider(
                                  label: 'Start',
                                  value: startMinute,
                                  max: 1430,
                                  onChanged: (value) => setSheetState(() {
                                    startMinute = value;
                                    if (endMinute < startMinute + 10) {
                                      endMinute = (startMinute + 10).clamp(
                                        10,
                                        1440,
                                      );
                                    }
                                  }),
                                ),
                                _TimeSlider(
                                  label: 'End',
                                  value: endMinute,
                                  min: 10,
                                  max: 1440,
                                  onChanged: (value) => setSheetState(() {
                                    endMinute = math.max(
                                      value,
                                      startMinute + 10,
                                    );
                                  }),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(7, (index) {
                                  final day = index + 1;
                                  return _SelectablePill(
                                    label: TimelineUtils.getShortDayName(day),
                                    selected: repeatDays.contains(day),
                                    color: OptivusColors.routineAccent,
                                    onTap: () => setSheetState(() {
                                      if (repeatDays.contains(day)) {
                                        repeatDays = {...repeatDays}
                                          ..remove(day);
                                      } else {
                                        repeatDays = {...repeatDays, day};
                                      }
                                    }),
                                  );
                                }),
                              ),
                            ],
                          ),
                          _SheetSection(
                            title: 'Category',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _blockTypeOptions
                                    .map(
                                      (option) => _SelectablePill(
                                        label: _blockTypeLabel(option),
                                        selected: blockType == option,
                                        color: _blockTypeColor(option),
                                        onTap: () => setSheetState(() {
                                          blockType = option;
                                          if (option ==
                                              TimelineBlockDraft
                                                  .flexibleTaskKey) {
                                            candidateType =
                                                RoutineImportCandidateType
                                                    .flexibleTask;
                                          }
                                        }),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: RoutineImportCandidateType.values
                                    .where(
                                      (type) =>
                                          type !=
                                          RoutineImportCandidateType.unknown,
                                    )
                                    .map(
                                      (type) => _SelectablePill(
                                        label: _candidateTypeLabel(type),
                                        selected: candidateType == type,
                                        color: OptivusColors.aquaAccent,
                                        onTap: () => setSheetState(
                                          () => candidateType = type,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categoryOptions
                                    .map(
                                      (option) => _SelectablePill(
                                        label: _categoryLabel(option),
                                        selected: category == option,
                                        color: OptivusColors.routineAccent,
                                        onTap: () => setSheetState(
                                          () => category = option,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                              _SheetTextField(
                                controller: locationController,
                                label: 'Location',
                              ),
                            ],
                          ),
                          _SheetSection(
                            title: 'Notes / Steps',
                            children: [
                              _SheetTextField(
                                controller: mealController,
                                label: 'Meal category',
                              ),
                              const SizedBox(height: 10),
                              _SheetTextField(
                                controller: notesController,
                                label: 'Notes',
                                minLines: 3,
                              ),
                              const SizedBox(height: 10),
                              _SheetTextField(
                                controller: stepsController,
                                label: 'Steps / checklist',
                                minLines: 2,
                              ),
                            ],
                          ),
                          _SheetSection(
                            title: 'Review Status',
                            children: [
                              _SheetSwitchRow(
                                label: needsManualReview
                                    ? 'Needs manual review'
                                    : 'Reviewed manually',
                                value: needsManualReview,
                                onChanged: (value) => setSheetState(
                                  () => needsManualReview = value,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  LiquidPill(
                                    label: _confidenceLabel(candidate),
                                    color: _confidenceColor(candidate),
                                  ),
                                  LiquidPill(
                                    label: _sourceBadgeLabel(candidate),
                                    color: OptivusColors.aquaAccent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _RoutineButton(
                                  label: 'Delete',
                                  color: OptivusColors.danger,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _deleteCandidate(candidate);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _RoutineButton(
                                  label: 'Save details',
                                  color: OptivusColors.routineAccent,
                                  onTap: () {
                                    final nextBlockType = blockType;
                                    final next = candidate.copyWith(
                                      title: titleController.text.trim(),
                                      startMinute: startMinute,
                                      endMinute: endMinute,
                                      hasFixedTime: hasFixedTime,
                                      suggestedStartMinute: hasFixedTime
                                          ? null
                                          : startMinute,
                                      suggestedEndMinute: hasFixedTime
                                          ? null
                                          : endMinute,
                                      repeatDays: repeatDays.toList(
                                        growable: false,
                                      )..sort(),
                                      blockType: nextBlockType,
                                      candidateType: candidateType,
                                      category: category,
                                      hardBlock:
                                          nextBlockType ==
                                          TimelineBlockDraft.hardBlockKey,
                                      selected: selected,
                                      needsManualReview: needsManualReview,
                                      confidenceLabel: needsManualReview
                                          ? candidate.confidenceLabel
                                          : 'manual',
                                      location: _emptyToNull(
                                        locationController.text,
                                      ),
                                      notes: _emptyToNull(notesController.text),
                                      mealCategory: _emptyToNull(
                                        mealController.text,
                                      ),
                                      steps: _parseSteps(stepsController.text),
                                      clearSuggestedStartMinute: hasFixedTime,
                                      clearSuggestedEndMinute: hasFixedTime,
                                      clearLocation: locationController.text
                                          .trim()
                                          .isEmpty,
                                      clearNotes: notesController.text
                                          .trim()
                                          .isEmpty,
                                      clearMealCategory: mealController.text
                                          .trim()
                                          .isEmpty,
                                    );
                                    Navigator.of(context).pop(next);
                                  },
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
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();
    notesController.dispose();
    mealController.dispose();
    stepsController.dispose();

    if (updated != null) {
      await _applyCandidateTimelineEdit(updated);
    }
  }
}

class _VisualTimeline extends StatelessWidget {
  final List<RoutineImportCandidateBlock> candidates;
  final RoutineImportValidationResult validation;
  final double pixelsPerMinute;
  final ValueChanged<RoutineImportCandidateBlock> onOpen;
  final void Function(RoutineImportCandidateBlock candidate, int deltaMinutes)
  onMoveDelta;
  final void Function(RoutineImportCandidateBlock candidate, int deltaMinutes)
  onResizeStartDelta;
  final void Function(RoutineImportCandidateBlock candidate, int deltaMinutes)
  onResizeEndDelta;

  const _VisualTimeline({
    required this.candidates,
    required this.validation,
    required this.pixelsPerMinute,
    required this.onOpen,
    required this.onMoveDelta,
    required this.onResizeStartDelta,
    required this.onResizeEndDelta,
  });

  @override
  Widget build(BuildContext context) {
    final height = 24 * 60 * pixelsPerMinute;
    return Container(
      constraints: const BoxConstraints(minHeight: 480),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                left: 52,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border(
                      left: BorderSide(
                        color: OptivusColors.routineAccent.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ...List.generate(25, (hour) {
                final top = hour * 60 * pixelsPerMinute;
                return Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 46,
                        child: Text(
                          TimelineUtils.formatMinute(hour * 60),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (candidates.isEmpty)
                const Positioned(
                  top: 220,
                  left: 70,
                  right: 20,
                  child: Text(
                    'No fixed-time candidates for this day.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ),
              ...candidates.map(
                (candidate) => _DraggableTimelineBlock(
                  candidate: candidate,
                  messages: validation.messagesFor(candidate.id),
                  hasBlockingIssue: validation.hasBlockingIssuesFor(
                    candidate.id,
                  ),
                  pixelsPerMinute: pixelsPerMinute,
                  onOpen: () => onOpen(candidate),
                  onMoveDelta: (delta) => onMoveDelta(candidate, delta),
                  onResizeStartDelta: (delta) =>
                      onResizeStartDelta(candidate, delta),
                  onResizeEndDelta: (delta) =>
                      onResizeEndDelta(candidate, delta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableTimelineBlock extends StatefulWidget {
  final RoutineImportCandidateBlock candidate;
  final List<String> messages;
  final bool hasBlockingIssue;
  final double pixelsPerMinute;
  final VoidCallback onOpen;
  final ValueChanged<int> onMoveDelta;
  final ValueChanged<int> onResizeStartDelta;
  final ValueChanged<int> onResizeEndDelta;

  const _DraggableTimelineBlock({
    required this.candidate,
    required this.messages,
    required this.hasBlockingIssue,
    required this.pixelsPerMinute,
    required this.onOpen,
    required this.onMoveDelta,
    required this.onResizeStartDelta,
    required this.onResizeEndDelta,
  });

  @override
  State<_DraggableTimelineBlock> createState() =>
      _DraggableTimelineBlockState();
}

class _DraggableTimelineBlockState extends State<_DraggableTimelineBlock> {
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final top = candidate.startMinute * widget.pixelsPerMinute;
    final duration = (candidate.endMinute - candidate.startMinute).clamp(
      10,
      1440,
    );
    final height = math.max(duration * widget.pixelsPerMinute, 64.0);
    final color = _categoryColor(candidate.category);

    return Positioned(
      top: top,
      left: 64,
      right: 10,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen,
              onVerticalDragStart: (_) => _dragDelta = 0,
              onVerticalDragUpdate: (details) => _dragDelta += details.delta.dy,
              onVerticalDragEnd: (_) => _finishDrag(widget.onMoveDelta),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: candidate.selected ? 0.22 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.hasBlockingIssue
                        ? OptivusColors.danger.withValues(alpha: 0.55)
                        : widget.messages.isNotEmpty
                        ? OptivusColors.warning.withValues(alpha: 0.55)
                        : color.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _categoryIcon(candidate.category),
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            candidate.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                        ),
                        if (widget.messages.isNotEmpty)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.hasBlockingIssue
                                  ? OptivusColors.danger
                                  : OptivusColors.warning,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      TimelineUtils.formatTimeRange(
                        candidate.startMinute,
                        candidate.endMinute,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        LiquidPill(
                          label: _confidenceLabel(candidate),
                          color: _confidenceColor(candidate),
                        ),
                        if (candidate.needsManualReview)
                          const LiquidPill(
                            label: 'Needs review',
                            color: OptivusColors.warning,
                          ),
                        LiquidPill(
                          label: _sourceBadgeLabel(candidate),
                          color: OptivusColors.aquaAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 18,
            right: 18,
            height: 14,
            child: _DragHandle(
              onVerticalDragStart: () => _dragDelta = 0,
              onVerticalDragUpdate: (delta) => _dragDelta += delta,
              onVerticalDragEnd: () => _finishDrag(widget.onResizeStartDelta),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 18,
            right: 18,
            height: 14,
            child: _DragHandle(
              onVerticalDragStart: () => _dragDelta = 0,
              onVerticalDragUpdate: (delta) => _dragDelta += delta,
              onVerticalDragEnd: () => _finishDrag(widget.onResizeEndDelta),
            ),
          ),
        ],
      ),
    );
  }

  void _finishDrag(ValueChanged<int> callback) {
    final delta = RoutineImportTimelineEditService.snappedDeltaMinutes(
      verticalDelta: _dragDelta,
      pixelsPerMinute: widget.pixelsPerMinute,
      snapMinutes: 5,
    );
    _dragDelta = 0;
    if (delta != 0) callback(delta);
  }
}

class _DragHandle extends StatelessWidget {
  final VoidCallback onVerticalDragStart;
  final ValueChanged<double> onVerticalDragUpdate;
  final VoidCallback onVerticalDragEnd;

  const _DragHandle({
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => onVerticalDragStart(),
      onVerticalDragUpdate: (details) => onVerticalDragUpdate(details.delta.dy),
      onVerticalDragEnd: (_) => onVerticalDragEnd(),
      child: Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: OptivusColors.textMuted.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _SourceEvidenceCard extends StatelessWidget {
  final RoutineImportReviewDraft review;
  final RoutineImportAiState aiState;
  final bool canRunAi;
  final String? disabledReason;
  final VoidCallback onRunAi;

  const _SourceEvidenceCard({
    required this.review,
    required this.aiState,
    required this.canRunAi,
    required this.disabledReason,
    required this.onRunAi,
  });

  @override
  Widget build(BuildContext context) {
    final hasEvidence =
        review.uploadedAssetId != null || review.uploadedAssetStatus != null;
    final sourceType = hasEvidence
        ? review.warnings.contains(
                RoutineImportExtractionService.noAiExtractionWarning,
              )
              ? 'From onboarding photo'
              : 'From uploaded photo'
        : 'Manual starter';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasEvidence
                    ? Icons.image_outlined
                    : Icons.edit_calendar_rounded,
                color: hasEvidence
                    ? OptivusColors.aquaAccent
                    : OptivusColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  sourceType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              LiquidPill(
                label: _statusLabel(review.status),
                color: _statusColor(review.status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LiquidPill(
                label: review.sourceLabel,
                color: OptivusColors.routineAccent,
                filled: true,
              ),
              if (review.uploadedAssetStatus != null)
                LiquidPill(
                  label: 'Asset ${review.uploadedAssetStatus}',
                  color: OptivusColors.aquaAccent,
                ),
              if (review.uploadedAssetId != null)
                LiquidPill(
                  label: 'Photo attached',
                  color: OptivusColors.success,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'AI extraction creates draft candidates only. Review manually before saving.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w900,
              color: OptivusColors.warning,
            ),
          ),
          const SizedBox(height: 12),
          _AiExtractionButton(
            state: aiState,
            enabled: canRunAi,
            disabledReason: disabledReason,
            onTap: onRunAi,
          ),
        ],
      ),
    );
  }
}

class _AiExtractionButton extends StatelessWidget {
  final RoutineImportAiState state;
  final bool enabled;
  final String? disabledReason;
  final VoidCallback onTap;

  const _AiExtractionButton({
    required this.state,
    required this.enabled,
    required this.disabledReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extracting = state.status == RoutineImportAiStatus.extracting;
    final extracted = state.status == RoutineImportAiStatus.extracted;
    final failed = state.status == RoutineImportAiStatus.failed;
    final label = extracting
        ? 'Extracting...'
        : extracted
        ? 'AI draft ready - review below'
        : disabledReason ?? 'Run AI extraction';
    final color = failed
        ? OptivusColors.danger
        : extracted
        ? OptivusColors.success
        : OptivusColors.routineAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: enabled && !extracting ? onTap : null,
          child: Opacity(
            opacity: enabled && !extracting ? 1 : 0.58,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withValues(alpha: 0.26)),
              ),
              child: Row(
                children: [
                  Icon(
                    extracting
                        ? Icons.hourglass_top_rounded
                        : extracted
                        ? Icons.check_circle_outline_rounded
                        : Icons.auto_fix_high_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (failed && state.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            state.errorMessage!,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: OptivusColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}

class _UnplacedCandidateChip extends StatelessWidget {
  final RoutineImportCandidateBlock candidate;
  final List<String> messages;
  final VoidCallback onTap;

  const _UnplacedCandidateChip({
    required this.candidate,
    required this.messages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(candidate.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: messages.isEmpty
                ? color.withValues(alpha: 0.28)
                : OptivusColors.warning.withValues(alpha: 0.48),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(candidate.category), size: 16, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    candidate.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                LiquidPill(
                  label: _candidateTypeLabel(candidate.candidateType),
                  color: OptivusColors.blockFlex,
                ),
                if (messages.isNotEmpty)
                  const LiquidPill(
                    label: 'Warning',
                    color: OptivusColors.warning,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSaveButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final bool blocked;
  final VoidCallback onTap;

  const _HeaderSaveButton({
    required this.enabled,
    required this.saving,
    required this.blocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = blocked ? OptivusColors.warning : OptivusColors.routineAccent;
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: Icon(
            saving
                ? Icons.more_horiz_rounded
                : blocked
                ? Icons.error_outline_rounded
                : Icons.check_rounded,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? OptivusColors.routineAccent
              : Colors.white.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? OptivusColors.routineAccent
                : Colors.white.withValues(alpha: 0.72),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : OptivusColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _GlassTextButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassTextButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _RoutineButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.56,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _SheetHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          color: OptivusColors.textSecondary,
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SheetSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;

  const _SheetTextField({
    required this.controller,
    required this.label,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 5,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
      ),
    );
  }
}

class _SheetSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SheetSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: OptivusColors.textPrimary,
        ),
      ),
      value: value,
      activeThumbColor: OptivusColors.routineAccent,
      onChanged: onChanged,
    );
  }
}

class _TimeSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _TimeSlider({
    required this.label,
    required this.value,
    this.min = 0,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
            Text(
              TimelineUtils.formatMinute(safeValue),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        Slider(
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: ((max - min) / 5).round(),
          value: safeValue.toDouble(),
          activeColor: OptivusColors.routineAccent,
          onChanged: (next) => onChanged((next / 5).round() * 5),
        ),
      ],
    );
  }
}

class _SelectablePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SelectablePill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

RoutineImportReviewSource _reviewSourceFor(RoutineImportSource source) {
  return switch (source) {
    RoutineImportSource.classes => RoutineImportReviewSource.classes,
    RoutineImportSource.work => RoutineImportReviewSource.work,
    RoutineImportSource.eating => RoutineImportReviewSource.eating,
    RoutineImportSource.skinCare => RoutineImportReviewSource.skinCare,
  };
}

String _sourceLabel(RoutineImportSource source) {
  return switch (source) {
    RoutineImportSource.classes => 'Classes',
    RoutineImportSource.work => 'Work',
    RoutineImportSource.eating => 'Eating',
    RoutineImportSource.skinCare => 'Skin Care',
  };
}

String _statusLabel(RoutineImportReviewStatus status) {
  return switch (status) {
    RoutineImportReviewStatus.draft => 'Draft',
    RoutineImportReviewStatus.needsReview => 'Needs review',
    RoutineImportReviewStatus.accepted => 'Accepted',
    RoutineImportReviewStatus.partiallyAccepted => 'Partially accepted',
    RoutineImportReviewStatus.rejected => 'Rejected',
  };
}

Color _statusColor(RoutineImportReviewStatus status) {
  return switch (status) {
    RoutineImportReviewStatus.accepted => OptivusColors.success,
    RoutineImportReviewStatus.partiallyAccepted ||
    RoutineImportReviewStatus.needsReview => OptivusColors.warning,
    RoutineImportReviewStatus.rejected => OptivusColors.danger,
    RoutineImportReviewStatus.draft => OptivusColors.routineAccent,
  };
}

String _defaultBlockTypeForSource(RoutineImportReviewSource source) {
  return source == RoutineImportReviewSource.classes ||
          source == RoutineImportReviewSource.work
      ? TimelineBlockDraft.hardBlockKey
      : TimelineBlockDraft.softBlockKey;
}

String _defaultTitleForSource(RoutineImportReviewSource source) {
  return switch (source) {
    RoutineImportReviewSource.classes => 'Class block',
    RoutineImportReviewSource.work => 'Work block',
    RoutineImportReviewSource.eating => 'Meal window',
    RoutineImportReviewSource.skinCare => 'Skin care routine',
  };
}

String _categoryNameForReviewSource(RoutineImportReviewSource source) {
  return switch (source) {
    RoutineImportReviewSource.classes => RoutineCategory.classBlock.name,
    RoutineImportReviewSource.work => RoutineCategory.job.name,
    RoutineImportReviewSource.eating => RoutineCategory.eating.name,
    RoutineImportReviewSource.skinCare => RoutineCategory.skinCare.name,
  };
}

const _blockTypeOptions = [
  TimelineBlockDraft.hardBlockKey,
  TimelineBlockDraft.softBlockKey,
  TimelineBlockDraft.flexibleTaskKey,
];

const _categoryOptions = [
  'classBlock',
  'job',
  'eating',
  'skinCare',
  'fixed',
  'habit',
  'health',
];

String _blockTypeLabel(String blockType) {
  return switch (blockType) {
    TimelineBlockDraft.hardBlockKey || 'hardBlock' => 'Hard',
    TimelineBlockDraft.flexibleTaskKey || 'flexibleTask' => 'Flexible',
    _ => 'Soft',
  };
}

Color _blockTypeColor(String blockType) {
  return switch (blockType) {
    TimelineBlockDraft.hardBlockKey || 'hardBlock' => OptivusColors.blockHard,
    TimelineBlockDraft.flexibleTaskKey ||
    'flexibleTask' => OptivusColors.blockFlex,
    _ => OptivusColors.blockSoft,
  };
}

String _candidateTypeLabel(RoutineImportCandidateType type) {
  return switch (type) {
    RoutineImportCandidateType.block => 'Block',
    RoutineImportCandidateType.flexibleTask => 'Flexible task',
    RoutineImportCandidateType.checklistStep => 'Checklist step',
    RoutineImportCandidateType.note => 'Note',
    RoutineImportCandidateType.unknown => 'Unknown',
  };
}

String _categoryLabel(String category) {
  return switch (category) {
    'classBlock' || 'class_block' || 'classes' => 'Classes',
    'job' || 'job_work_business' || 'work' => 'Work',
    'eating' => 'Eating',
    'skinCare' || 'skin_care' => 'Skin Care',
    'habit' => 'Habit',
    'health' => 'Health',
    _ => 'Fixed',
  };
}

Color _categoryColor(String category) {
  return switch (category) {
    'classBlock' || 'class_block' || 'classes' => OptivusColors.aquaAccent,
    'job' || 'job_work_business' || 'work' => OptivusColors.brandAccent,
    'eating' => OptivusColors.warning,
    'skinCare' || 'skin_care' => const Color(0xFFFF88C9),
    'habit' => OptivusColors.blockFlex,
    'health' => OptivusColors.success,
    _ => OptivusColors.routineAccent,
  };
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'classBlock' || 'class_block' || 'classes' => Icons.school_rounded,
    'job' || 'job_work_business' || 'work' => Icons.work_rounded,
    'eating' => Icons.restaurant_rounded,
    'skinCare' || 'skin_care' => Icons.face_retouching_natural_rounded,
    'habit' => Icons.task_alt_rounded,
    'health' => Icons.favorite_rounded,
    _ => Icons.schedule_rounded,
  };
}

String _confidenceLabel(RoutineImportCandidateBlock candidate) {
  return switch (candidate.confidenceLabel) {
    'high' => 'High',
    'medium' => 'Medium',
    'low' => 'Low',
    'manual' => 'Manual',
    _ => candidate.extractionEngine == 'manualSeed' ? 'Manual' : 'Medium',
  };
}

Color _confidenceColor(RoutineImportCandidateBlock candidate) {
  return switch (candidate.confidenceLabel) {
    'high' => OptivusColors.success,
    'medium' => OptivusColors.routineAccent,
    'low' => OptivusColors.warning,
    _ => OptivusColors.textSecondary,
  };
}

String _sourceBadgeLabel(RoutineImportCandidateBlock candidate) {
  if (candidate.extractionEngine.toLowerCase().contains('ai')) {
    return 'Future AI';
  }
  if (candidate.sourceAssetId != null || candidate.sourceR2Key != null) {
    return 'Photo';
  }
  return 'Manual';
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _parseSteps(String value) {
  return value
      .split(RegExp(r'[\n,]+'))
      .map((step) => step.trim())
      .where((step) => step.isNotEmpty)
      .toList(growable: false);
}
