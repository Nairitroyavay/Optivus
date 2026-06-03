import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineImportExtractionService {
  const RoutineImportExtractionService();

  static const String noAiExtractionWarning =
      'Photo is attached from onboarding. Run AI extraction or review manually before saving.';

  RoutineImportReviewDraft buildReviewDraft({
    required String uid,
    required RoutineImportReviewSource source,
    required OnboardingDraft onboardingDraft,
  }) {
    final now = DateTime.now();
    final sourceLabel = sourceSectionLabel(source);
    final sectionKey = timelineSectionKey(source);
    final pendingImport = _pendingImportForSource(onboardingDraft, source);
    final pendingParsedBlocks = pendingImport?.parsedBlocks ?? const [];
    final candidates = <RoutineImportCandidateBlock>[
      ...onboardingDraft.baseTimeline.blocks
          .where((block) => block.section == sectionKey)
          .map(
            (block) => _candidateFromTimelineBlock(
              block,
              source: source,
              idPrefix: 'block',
              needsManualReview: block.needsTimeConfirmation,
              sourceAssetId: pendingImport?.uploadedAssetId,
              sourceR2Key: pendingImport?.uploadedAssetR2Key,
              confidenceLabel: block.needsTimeConfirmation ? 'low' : 'medium',
              notes: block.needsTimeConfirmation
                  ? 'Starter from onboarding; confirm timing manually.'
                  : block.source,
            ),
          ),
      ...pendingParsedBlocks.map(
        (block) => _candidateFromTimelineBlock(
          block,
          source: source,
          idPrefix: 'pending',
          needsManualReview: true,
          sourceAssetId: pendingImport?.uploadedAssetId,
          sourceR2Key: pendingImport?.uploadedAssetR2Key,
          sourceTextSnippet: pendingImport?.pastedText,
          confidenceLabel: 'low',
          notes: 'Starter from onboarding import text; review manually.',
        ),
      ),
    ];
    final warnings = <String>[];
    final pendingHasAsset = _hasUploadedAssetReference(pendingImport);

    if (pendingHasAsset) {
      warnings.add(noAiExtractionWarning);
    }

    if (pendingHasAsset && candidates.isEmpty) {
      candidates.addAll(_photoOnlyCandidates(source, pendingImport!));
    }

    if (!pendingHasAsset && candidates.isEmpty) {
      candidates.add(_manualStarterCandidate(source));
      warnings.add(
        'No onboarding blocks were found for $sourceLabel. Add or edit details manually before saving.',
      );
    }

    final needsReview = candidates.any((block) => block.needsManualReview);
    return RoutineImportReviewDraft(
      id: reviewIdForSource(source),
      uid: uid,
      source: source,
      status: needsReview
          ? RoutineImportReviewStatus.needsReview
          : RoutineImportReviewStatus.draft,
      sourceLabel: sourceLabel,
      onboardingPendingImportId: pendingImport?.id,
      uploadedAssetId: pendingImport?.uploadedAssetId,
      uploadedAssetR2Key: pendingImport?.uploadedAssetR2Key,
      uploadedAssetStatus: pendingImport?.uploadedAssetStatus,
      candidateBlocks: candidates,
      warnings: warnings,
      createdAt: now,
      updatedAt: now,
    );
  }

  RoutineImportReviewDraft buildReviewDraftFromCompletionBundle({
    required String uid,
    required RoutineImportReviewSource source,
    required OnboardingCompletionBundle bundle,
  }) {
    final now = DateTime.now();
    final sourceLabel = sourceSectionLabel(source);
    final sectionKey = timelineSectionKey(source);
    final assetReference = _assetReferenceForSource(bundle, source);
    final candidates = bundle.baseTimelineBlocks
        .where((block) => block.section == sectionKey)
        .map(
          (block) => _candidateFromTimelineBlock(
            block,
            source: source,
            idPrefix: 'bundle',
            needsManualReview: true,
            sourceAssetId: assetReference?.uploadedAssetId,
            sourceR2Key: assetReference?.uploadedAssetR2Key,
            confidenceLabel: 'low',
            notes:
                'Attached from completed onboarding. Confirm details manually before saving.',
          ),
        )
        .toList(growable: false);
    final warnings = <String>[];
    if (_hasUploadedAssetReference(assetReference)) {
      warnings.add(noAiExtractionWarning);
    }

    final candidateBlocks = candidates.isNotEmpty
        ? candidates
        : _hasUploadedAssetReference(assetReference)
        ? _photoOnlyCandidates(
            source,
            _pendingImportFromBundleAsset(source, assetReference!),
          )
        : [_manualStarterCandidate(source)];

    if (!_hasUploadedAssetReference(assetReference) && candidates.isEmpty) {
      warnings.add(
        'No completed onboarding source was found for $sourceLabel. Add or edit details manually before saving.',
      );
    }

    return RoutineImportReviewDraft(
      id: reviewIdForSource(source),
      uid: uid,
      source: source,
      status: RoutineImportReviewStatus.needsReview,
      sourceLabel: sourceLabel,
      onboardingPendingImportId: assetReference?.id,
      uploadedAssetId: assetReference?.uploadedAssetId,
      uploadedAssetR2Key: assetReference?.uploadedAssetR2Key,
      uploadedAssetStatus: assetReference?.uploadedAssetStatus,
      candidateBlocks: candidateBlocks,
      warnings: warnings,
      createdAt: now,
      updatedAt: now,
    );
  }

  String reviewIdForSource(RoutineImportReviewSource source) {
    return 'onboarding_${source.name}_import_review';
  }

  String sourceSectionLabel(RoutineImportReviewSource source) {
    return switch (source) {
      RoutineImportReviewSource.classes => 'Classes',
      RoutineImportReviewSource.work => 'Job / Work / Business',
      RoutineImportReviewSource.eating => 'Eating',
      RoutineImportReviewSource.skinCare => 'Skin Care',
    };
  }

  String timelineSectionKey(RoutineImportReviewSource source) {
    return switch (source) {
      RoutineImportReviewSource.classes => 'classes',
      RoutineImportReviewSource.work => 'job_work_business',
      RoutineImportReviewSource.eating => 'eating',
      RoutineImportReviewSource.skinCare => 'skin_care',
    };
  }

  String? uploadedAssetPurposeKey(RoutineImportReviewSource source) {
    return switch (source) {
      RoutineImportReviewSource.classes => 'class_timetable',
      RoutineImportReviewSource.work => 'work_schedule',
      RoutineImportReviewSource.eating => 'eating_menu',
      RoutineImportReviewSource.skinCare => 'skin_care',
    };
  }

  PendingFutureImportDraft? _pendingImportForSource(
    OnboardingDraft draft,
    RoutineImportReviewSource source,
  ) {
    final section = sourceSectionLabel(source);
    final matches = draft.baseTimeline.pendingFutureImports
        .where((entry) => entry.section == section)
        .toList(growable: false);
    if (matches.isEmpty) return null;

    final withAsset = matches.reversed.where(_hasUploadedAssetReference);
    if (withAsset.isNotEmpty) return withAsset.first;

    final withParsedBlocks = matches.reversed.where(
      (entry) => entry.parsedBlocks.isNotEmpty,
    );
    if (withParsedBlocks.isNotEmpty) return withParsedBlocks.first;

    return matches.last;
  }

  bool _hasUploadedAssetReference(Object? entry) {
    if (entry is PendingFutureImportDraft) {
      return entry.uploadedAssetId?.trim().isNotEmpty == true ||
          entry.uploadedAssetR2Key?.trim().isNotEmpty == true ||
          entry.uploadedAssetStatus?.trim().isNotEmpty == true;
    }
    if (entry is OnboardingUploadedAssetReference) {
      return entry.uploadedAssetId?.trim().isNotEmpty == true ||
          entry.uploadedAssetR2Key?.trim().isNotEmpty == true ||
          entry.uploadedAssetStatus?.trim().isNotEmpty == true;
    }
    return false;
  }

  OnboardingUploadedAssetReference? _assetReferenceForSource(
    OnboardingCompletionBundle bundle,
    RoutineImportReviewSource source,
  ) {
    final sourceLabel = sourceSectionLabel(source);
    final purposeKey = uploadedAssetPurposeKey(source);
    final matches = bundle.uploadedAssetReferences
        .where((entry) {
          final sectionMatches = entry.section == sourceLabel;
          final keyMatches =
              purposeKey != null &&
              (entry.uploadedAssetR2Key?.contains('/$purposeKey/') ?? false);
          return sectionMatches || keyMatches;
        })
        .toList(growable: false);
    if (matches.isEmpty) return null;

    final withAsset = matches.reversed.where(_hasUploadedAssetReference);
    if (withAsset.isNotEmpty) return withAsset.first;
    return matches.last;
  }

  PendingFutureImportDraft _pendingImportFromBundleAsset(
    RoutineImportReviewSource source,
    OnboardingUploadedAssetReference assetReference,
  ) {
    return PendingFutureImportDraft(
      id: assetReference.id.trim().isEmpty
          ? '${source.name}_completion_bundle_photo'
          : assetReference.id,
      section: sourceSectionLabel(source),
      mode: assetReference.mode.trim().isEmpty
          ? 'Photo Upload'
          : assetReference.mode,
      createdAt: assetReference.createdAt,
      updatedAt: assetReference.updatedAt,
      uploadedAssetId: assetReference.uploadedAssetId,
      uploadedAssetR2Key: assetReference.uploadedAssetR2Key,
      uploadedAssetStatus: assetReference.uploadedAssetStatus,
    );
  }

  RoutineImportCandidateBlock _candidateFromTimelineBlock(
    TimelineBlockDraft block, {
    required RoutineImportReviewSource source,
    required String idPrefix,
    required bool needsManualReview,
    String? sourceAssetId,
    String? sourceR2Key,
    String? sourceTextSnippet,
    String? confidenceLabel,
    String? notes,
  }) {
    return RoutineImportCandidateBlock(
      id: '${idPrefix}_${block.id}',
      title: block.title.trim().isEmpty
          ? '${sourceSectionLabel(source)} block'
          : block.title.trim(),
      startMinute: block.startMinute.clamp(0, 1439),
      endMinute: block.endMinute.clamp(1, 1440),
      repeatDays: _safeRepeatDays(block.repeatDays),
      blockType: block.blockType,
      category: _routineCategoryName(source),
      hardBlock: block.blockType == TimelineBlockDraft.hardBlockKey,
      selected: true,
      needsManualReview: needsManualReview,
      candidateType: block.blockType == TimelineBlockDraft.flexibleTaskKey
          ? RoutineImportCandidateType.flexibleTask
          : RoutineImportCandidateType.block,
      confidenceLabel: confidenceLabel,
      sourceAssetId: sourceAssetId,
      sourceR2Key: sourceR2Key,
      sourceTextSnippet: sourceTextSnippet,
      extractionEngine: 'manualSeed',
      extractionVersion: 'phase2c',
      location: block.location,
      notes: notes,
      mealCategory: block.mealCategory,
      steps: block.skincareProducts,
    );
  }

  List<RoutineImportCandidateBlock> _photoOnlyCandidates(
    RoutineImportReviewSource source,
    PendingFutureImportDraft pendingImport,
  ) {
    final idBase = pendingImport.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_');
    final sourceAssetId = pendingImport.uploadedAssetId;
    final sourceR2Key = pendingImport.uploadedAssetR2Key;
    return switch (source) {
      RoutineImportReviewSource.classes => [
        RoutineImportCandidateBlock(
          id: 'photo_${idBase}_class',
          title: 'Class block from uploaded timetable',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
          category: RoutineCategory.classBlock.name,
          hardBlock: true,
          candidateType: RoutineImportCandidateType.block,
          confidenceLabel: 'low',
          sourceAssetId: sourceAssetId,
          sourceR2Key: sourceR2Key,
          sourceTextSnippet: null,
          extractionEngine: 'manualSeed',
          extractionVersion: 'phase2c',
          needsManualReview: true,
          notes:
              'Photo attached; edit class time, days, and location manually.',
        ),
      ],
      RoutineImportReviewSource.work => [
        RoutineImportCandidateBlock(
          id: 'photo_${idBase}_work',
          title: 'Work block from uploaded schedule',
          startMinute: 9 * 60,
          endMinute: 17 * 60,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
          category: RoutineCategory.job.name,
          hardBlock: true,
          candidateType: RoutineImportCandidateType.block,
          confidenceLabel: 'low',
          sourceAssetId: sourceAssetId,
          sourceR2Key: sourceR2Key,
          extractionEngine: 'manualSeed',
          extractionVersion: 'phase2c',
          needsManualReview: true,
          notes: 'Photo attached; edit work hours and repeat days manually.',
        ),
      ],
      RoutineImportReviewSource.eating => [
        RoutineImportCandidateBlock(
          id: 'photo_${idBase}_lunch',
          title: 'Meal window from uploaded menu',
          startMinute: 13 * 60,
          endMinute: 13 * 60 + 30,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          category: RoutineCategory.eating.name,
          hardBlock: false,
          candidateType: RoutineImportCandidateType.block,
          confidenceLabel: 'low',
          sourceAssetId: sourceAssetId,
          sourceR2Key: sourceR2Key,
          extractionEngine: 'manualSeed',
          extractionVersion: 'phase2c',
          needsManualReview: true,
          mealCategory: 'Lunch',
          notes: 'Photo attached; edit meal window and dishes manually.',
        ),
        RoutineImportCandidateBlock(
          id: 'photo_${idBase}_dinner',
          title: 'Meal window from uploaded menu',
          startMinute: 20 * 60,
          endMinute: 20 * 60 + 30,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          category: RoutineCategory.eating.name,
          hardBlock: false,
          candidateType: RoutineImportCandidateType.block,
          confidenceLabel: 'low',
          sourceAssetId: sourceAssetId,
          sourceR2Key: sourceR2Key,
          extractionEngine: 'manualSeed',
          extractionVersion: 'phase2c',
          needsManualReview: true,
          mealCategory: 'Dinner',
          notes: 'Photo attached; edit meal window and dishes manually.',
        ),
      ],
      RoutineImportReviewSource.skinCare => [
        RoutineImportCandidateBlock(
          id: 'photo_${idBase}_skin_care',
          title: 'Skin care routine from uploaded photo',
          startMinute: 7 * 60 + 30,
          endMinute: 7 * 60 + 45,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          category: RoutineCategory.skinCare.name,
          hardBlock: false,
          candidateType: RoutineImportCandidateType.block,
          confidenceLabel: 'low',
          sourceAssetId: sourceAssetId,
          sourceR2Key: sourceR2Key,
          extractionEngine: 'manualSeed',
          extractionVersion: 'phase2c',
          needsManualReview: true,
          notes: 'Photo attached; edit products and steps manually.',
          steps: const ['Review products manually'],
        ),
      ],
    };
  }

  RoutineImportCandidateBlock _manualStarterCandidate(
    RoutineImportReviewSource source,
  ) {
    return RoutineImportCandidateBlock(
      id: 'manual_${source.name}_${DateTime.now().millisecondsSinceEpoch}',
      title: switch (source) {
        RoutineImportReviewSource.classes => 'Class block to review',
        RoutineImportReviewSource.work => 'Work block to review',
        RoutineImportReviewSource.eating => 'Meal window to review',
        RoutineImportReviewSource.skinCare => 'Skin care routine to review',
      },
      startMinute: switch (source) {
        RoutineImportReviewSource.classes => 9 * 60,
        RoutineImportReviewSource.work => 9 * 60,
        RoutineImportReviewSource.eating => 13 * 60,
        RoutineImportReviewSource.skinCare => 7 * 60 + 30,
      },
      endMinute: switch (source) {
        RoutineImportReviewSource.classes => 10 * 60,
        RoutineImportReviewSource.work => 17 * 60,
        RoutineImportReviewSource.eating => 13 * 60 + 30,
        RoutineImportReviewSource.skinCare => 7 * 60 + 45,
      },
      repeatDays:
          source == RoutineImportReviewSource.skinCare ||
              source == RoutineImportReviewSource.eating
          ? const [1, 2, 3, 4, 5, 6, 7]
          : const [1, 2, 3, 4, 5],
      blockType:
          source == RoutineImportReviewSource.classes ||
              source == RoutineImportReviewSource.work
          ? TimelineBlockDraft.hardBlockKey
          : TimelineBlockDraft.softBlockKey,
      category: _routineCategoryName(source),
      hardBlock:
          source == RoutineImportReviewSource.classes ||
          source == RoutineImportReviewSource.work,
      selected: false,
      candidateType: RoutineImportCandidateType.block,
      confidenceLabel: 'low',
      extractionEngine: 'manualSeed',
      extractionVersion: 'phase2c',
      needsManualReview: true,
      notes: 'Add details manually before saving.',
    );
  }

  String _routineCategoryName(RoutineImportReviewSource source) {
    return switch (source) {
      RoutineImportReviewSource.classes => RoutineCategory.classBlock.name,
      RoutineImportReviewSource.work => RoutineCategory.job.name,
      RoutineImportReviewSource.eating => RoutineCategory.eating.name,
      RoutineImportReviewSource.skinCare => RoutineCategory.skinCare.name,
    };
  }

  List<int> _safeRepeatDays(List<int> repeatDays) {
    final days =
        repeatDays
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList(growable: false)
          ..sort();
    return days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days;
  }
}
