import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/services/routine_import_conversion_service.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';
import 'package:optivus/services/routine_import_validation_service.dart';
import 'package:optivus/state/app_state.dart';
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
  final RoutineImportExtractionService _extractionService =
      const RoutineImportExtractionService();
  final RoutineImportConversionService _conversionService =
      const RoutineImportConversionService();
  final RoutineImportValidationService _validationService =
      const RoutineImportValidationService();

  RoutineImportReviewDraft? _review;
  bool _loading = true;
  bool _saving = false;
  bool _hadDeletedCandidate = false;
  final Set<String> _deletedCandidateIds = {};
  int _initialCandidateCount = 0;
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
    final selectedCount =
        review?.candidateBlocks
            .where((candidate) => candidate.selected)
            .length ??
        0;
    final selectedHasBlockingIssues =
        review?.candidateBlocks
            .where((candidate) => candidate.selected)
            .any(
              (candidate) => validation.hasBlockingIssuesFor(candidate.id),
            ) ??
        false;

    return LiquidDetailScaffold(
      eyebrow: 'Routine import',
      title: '${review?.sourceLabel ?? _sourceLabel(widget.source)} Review',
      subtitle:
          'Review starter blocks from onboarding/manual input and attached source evidence. No AI/OCR extraction runs in this phase.',
      accentColor: OptivusColors.routineAccent,
      onBack: widget.onBack,
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
          LiquidDetailSection(
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
              _TextButton(
                label: 'Retry',
                color: OptivusColors.routineAccent,
                onTap: _loadReview,
              ),
            ],
          )
        else if (review != null) ...[
          _sourceSummarySection(review),
          _reviewWarningSection(review),
          LiquidDetailSection(
            title: 'Candidate blocks',
            children: [
              if (review.candidateBlocks.isEmpty)
                const Text(
                  'No candidate blocks are left in this review. Add one manually or cancel.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                )
              else
                ..._groupCandidatesByDay(review.candidateBlocks).entries.expand(
                  (entry) => [
                    _DayGroupHeader(label: entry.key),
                    ...entry.value.map(
                      (candidate) => _ImportBlockTile(
                        candidate: candidate,
                        messages: validation.messagesFor(candidate.id),
                        hasBlockingIssue: validation.hasBlockingIssuesFor(
                          candidate.id,
                        ),
                        onEdit: () => _shiftCandidate(candidate),
                        onDelete: () => _deleteCandidate(candidate),
                        onToggleFlexible: () => _toggleFlexible(candidate),
                        onToggleSelected: () => _toggleSelected(candidate),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              _TextButton(
                label: 'Add block',
                color: OptivusColors.routineAccent,
                onTap: _addCandidate,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _RoutineButton(
                  label: 'Cancel',
                  color: OptivusColors.textSecondary,
                  onTap: _saving ? null : widget.onBack,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RoutineButton(
                  label: _saving
                      ? 'Saving...'
                      : selectedHasBlockingIssues
                      ? 'Fix issues'
                      : selectedCount == 0
                      ? 'Save review'
                      : 'Save to Base Timeline',
                  color: selectedHasBlockingIssues || selectedCount == 0
                      ? OptivusColors.textSecondary
                      : OptivusColors.routineAccent,
                  onTap: _saving ? null : () => _saveAcceptedReview(validation),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sourceSummarySection(RoutineImportReviewDraft review) {
    return LiquidDetailSection(
      title: 'Import source summary',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            LiquidPill(
              label: review.sourceLabel,
              color: OptivusColors.routineAccent,
              filled: true,
            ),
            LiquidPill(
              label: _statusLabel(review.status),
              color: _statusColor(review.status),
            ),
            if (review.uploadedAssetStatus != null)
              LiquidPill(
                label: 'Asset ${review.uploadedAssetStatus}',
                color: OptivusColors.aquaAccent,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _EvidenceCard(review: review),
      ],
    );
  }

  Widget _reviewWarningSection(RoutineImportReviewDraft review) {
    return LiquidDetailSection(
      title: 'Review warning',
      tint: OptivusColors.warning.withValues(alpha: 0.08),
      children: [
        const Text(
          'AI extraction is not connected yet. Review these starter blocks manually.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w900,
            color: OptivusColors.warning,
          ),
        ),
        if (review.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...review.warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                warning,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
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
      var onboardingDraft = ref.read(mockOnboardingProvider).draft;
      if (uid.trim().isNotEmpty &&
          _shouldFetchPersistedDraft(onboardingDraft, widget.source)) {
        final fetched = await ref
            .read(onboardingRepositoryProvider)
            .fetchDraft(uid);
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

      final source = _reviewSourceFor(widget.source);
      final builtReview = _extractionService.buildReviewDraft(
        uid: uid,
        source: source,
        onboardingDraft: onboardingDraft.copyWith(uid: uid),
      );
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

  bool _shouldFetchPersistedDraft(
    OnboardingDraft draft,
    RoutineImportSource source,
  ) {
    final reviewSource = _reviewSourceFor(source);
    final sectionLabel = _extractionService.sourceSectionLabel(reviewSource);
    final sectionKey = _extractionService.timelineSectionKey(reviewSource);
    final hasRelevantImport = draft.baseTimeline.pendingFutureImports.any(
      (entry) => entry.section == sectionLabel,
    );
    final hasRelevantBlocks = draft.baseTimeline.blocks.any(
      (block) => block.section == sectionKey,
    );
    return !hasRelevantImport && !hasRelevantBlocks;
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

  Future<void> _replaceCandidates(
    List<RoutineImportCandidateBlock> candidates,
  ) async {
    final review = _review;
    if (review == null) return;
    final next = review.copyWith(
      candidateBlocks: candidates,
      status: candidates.any((candidate) => candidate.needsManualReview)
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

  Future<void> _shiftCandidate(RoutineImportCandidateBlock candidate) async {
    final review = _review;
    if (review == null) return;
    final duration = (candidate.endMinute - candidate.startMinute).clamp(
      5,
      24 * 60,
    );
    final nextStart = (candidate.startMinute + 15).clamp(0, 1439);
    final nextEnd = (nextStart + duration).clamp(1, 1440);
    await _replaceCandidates([
      for (final item in review.candidateBlocks)
        if (item.id == candidate.id)
          item.copyWith(startMinute: nextStart, endMinute: nextEnd)
        else
          item,
    ]);
  }

  Future<void> _deleteCandidate(RoutineImportCandidateBlock candidate) async {
    final review = _review;
    if (review == null) return;
    _hadDeletedCandidate = true;
    _deletedCandidateIds.add(candidate.id);
    await _replaceCandidates(
      review.candidateBlocks
          .where((item) => item.id != candidate.id)
          .toList(growable: false),
    );
  }

  Future<void> _toggleSelected(RoutineImportCandidateBlock candidate) async {
    final review = _review;
    if (review == null) return;
    await _replaceCandidates([
      for (final item in review.candidateBlocks)
        if (item.id == candidate.id)
          item.copyWith(selected: !item.selected)
        else
          item,
    ]);
  }

  Future<void> _toggleFlexible(RoutineImportCandidateBlock candidate) async {
    final review = _review;
    if (review == null) return;
    final isFlexible =
        candidate.blockType == TimelineBlockDraft.flexibleTaskKey;
    final restoredType = _defaultBlockTypeForSource(review.source);
    final nextType = isFlexible
        ? restoredType
        : TimelineBlockDraft.flexibleTaskKey;
    final nextCandidateType = nextType == TimelineBlockDraft.flexibleTaskKey
        ? RoutineImportCandidateType.flexibleTask
        : RoutineImportCandidateType.block;
    await _replaceCandidates([
      for (final item in review.candidateBlocks)
        if (item.id == candidate.id)
          item.copyWith(
            blockType: nextType,
            candidateType: nextCandidateType,
            hardBlock: nextType == TimelineBlockDraft.hardBlockKey,
          )
        else
          item,
    ]);
  }

  Future<void> _addCandidate() async {
    final review = _review;
    if (review == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final blockType = _defaultBlockTypeForSource(review.source);
    final candidate = RoutineImportCandidateBlock(
      id: 'added_${review.source.name}_$now',
      title: 'Added review block',
      startMinute: 15 * 60,
      endMinute: 15 * 60 + 45,
      repeatDays: const [1, 2, 3, 4, 5],
      blockType: blockType,
      category: _categoryNameForReviewSource(review.source),
      hardBlock: blockType == TimelineBlockDraft.hardBlockKey,
      selected: true,
      candidateType: RoutineImportCandidateType.block,
      confidenceLabel: 'low',
      extractionEngine: 'manualSeed',
      extractionVersion: 'phase2c',
      needsManualReview: true,
      notes: 'Added during import review.',
    );
    await _replaceCandidates([...review.candidateBlocks, candidate]);
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

      final selected = candidatesWithValidation
          .where((candidate) => candidate.selected)
          .toList(growable: false);
      final now = DateTime.now();
      final candidatesForConversion = [
        for (var i = 0; i < selected.length; i++)
          selected[i].copyWith(
            id: 'import-${review.source.name}-${selected[i].id}-${now.microsecondsSinceEpoch}-$i',
          ),
      ];
      final routineItems = _conversionService.convertAcceptedCandidates(
        candidates: candidatesForConversion,
      );
      final routineController = ref.read(routineNotifierProvider.notifier);
      final appliedRoutineItemIds = <String>[];
      for (final item in routineItems) {
        final itemWithUser = item.copyWith(userId: review.uid);
        appliedRoutineItemIds.add(itemWithUser.id);
        await routineController.addItem(itemWithUser);
      }

      final acceptedCandidateIds = selected
          .map((candidate) => candidate.id)
          .toList(growable: false);
      final rejectedCandidateIds = {
        ..._deletedCandidateIds,
        for (final candidate in candidatesWithValidation)
          if (!candidate.selected) candidate.id,
      }.toList(growable: false);
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
      widget.onBack();
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
}

class _EvidenceCard extends StatelessWidget {
  final RoutineImportReviewDraft review;

  const _EvidenceCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final hasEvidence =
        review.uploadedAssetId != null || review.uploadedAssetR2Key != null;
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
                hasEvidence ? Icons.image_outlined : Icons.info_outline_rounded,
                color: hasEvidence
                    ? OptivusColors.aquaAccent
                    : OptivusColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  hasEvidence
                      ? 'Attached source evidence'
                      : 'No uploaded source evidence attached',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _EvidenceRow(
            label: 'Pending import',
            value: review.onboardingPendingImportId,
          ),
          _EvidenceRow(label: 'Asset ID', value: review.uploadedAssetId),
          _EvidenceRow(label: 'R2 key', value: review.uploadedAssetR2Key),
          _EvidenceRow(
            label: 'Asset status',
            value: review.uploadedAssetStatus,
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final String label;
  final String? value;

  const _EvidenceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value!.trim().isEmpty ? 'Not attached' : value!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayGroupHeader extends StatelessWidget {
  final String label;

  const _DayGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: OptivusColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ImportBlockTile extends StatelessWidget {
  final RoutineImportCandidateBlock candidate;
  final List<String> messages;
  final bool hasBlockingIssue;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFlexible;
  final VoidCallback onToggleSelected;

  const _ImportBlockTile({
    required this.candidate,
    required this.messages,
    required this.hasBlockingIssue,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFlexible,
    required this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isFlexible =
        candidate.blockType == TimelineBlockDraft.flexibleTaskKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: candidate.selected
            ? Colors.white.withValues(alpha: 0.56)
            : Colors.white.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasBlockingIssue
              ? OptivusColors.danger.withValues(alpha: 0.48)
              : messages.isNotEmpty
              ? OptivusColors.warning.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.78),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  candidate.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: candidate.selected
                        ? OptivusColors.textPrimary
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
              LiquidPill(
                label: candidate.selected ? 'Selected' : 'Skipped',
                color: candidate.selected
                    ? OptivusColors.success
                    : OptivusColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LiquidPill(
                label: isFlexible
                    ? 'Flexible'
                    : candidate.hardBlock
                    ? 'Hard block'
                    : 'Soft block',
                color: isFlexible
                    ? OptivusColors.blockFlex
                    : candidate.hardBlock
                    ? OptivusColors.blockHard
                    : OptivusColors.blockSoft,
              ),
              if (candidate.needsManualReview)
                LiquidPill(label: 'Needs review', color: OptivusColors.warning),
              if (candidate.confidenceLabel != null)
                LiquidPill(
                  label: '${candidate.confidenceLabel} confidence',
                  color: candidate.confidenceLabel == 'low'
                      ? OptivusColors.warning
                      : OptivusColors.routineAccent,
                ),
              if (messages.isNotEmpty)
                LiquidPill(
                  label: hasBlockingIssue ? 'Fix issue' : 'Warnings',
                  color: hasBlockingIssue
                      ? OptivusColors.danger
                      : OptivusColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            TimelineUtils.formatTimeRange(
              candidate.startMinute,
              candidate.endMinute,
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
          if (candidate.location != null && candidate.location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              candidate.location!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textMuted,
              ),
            ),
          ],
          if (candidate.steps.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              candidate.steps.join(' • '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textMuted,
              ),
            ),
          ],
          if (candidate.notes != null && candidate.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              candidate.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: hasBlockingIssue
                        ? OptivusColors.danger
                        : OptivusColors.warning,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TextButton(
                label: 'Edit +15m',
                color: OptivusColors.routineAccent,
                onTap: onEdit,
              ),
              _TextButton(
                label: isFlexible ? 'Restore type' : 'Mark flexible',
                color: OptivusColors.blockFlex,
                onTap: onToggleFlexible,
              ),
              _TextButton(
                label: candidate.selected ? 'Unselect' : 'Select',
                color: candidate.selected
                    ? OptivusColors.textSecondary
                    : OptivusColors.success,
                onTap: onToggleSelected,
              ),
              _TextButton(
                label: 'Delete',
                color: OptivusColors.danger,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
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
        opacity: enabled ? 1 : 0.62,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
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

Map<String, List<RoutineImportCandidateBlock>> _groupCandidatesByDay(
  List<RoutineImportCandidateBlock> candidates,
) {
  final grouped = <String, List<RoutineImportCandidateBlock>>{};
  for (final candidate in candidates) {
    final days = candidate.repeatDays.toSet();
    if (days.length == 7) {
      grouped.putIfAbsent('Every day', () => []).add(candidate);
      continue;
    }
    if (days.isEmpty) {
      grouped.putIfAbsent('No repeat days', () => []).add(candidate);
      continue;
    }
    final sortedDays = days.toList(growable: false)..sort();
    for (final day in sortedDays) {
      grouped.putIfAbsent(_dayName(day), () => []).add(candidate);
    }
  }
  return grouped;
}

String _dayName(int day) {
  return switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'No repeat days',
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

String _categoryNameForReviewSource(RoutineImportReviewSource source) {
  return switch (source) {
    RoutineImportReviewSource.classes => RoutineCategory.classBlock.name,
    RoutineImportReviewSource.work => RoutineCategory.job.name,
    RoutineImportReviewSource.eating => RoutineCategory.eating.name,
    RoutineImportReviewSource.skinCare => RoutineCategory.skinCare.name,
  };
}
