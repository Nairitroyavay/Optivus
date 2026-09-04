import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_timeline_preview.dart';
import 'package:optivus/features/onboarding/timeline/onboarding_timeline.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

const String onboardingEatingPathHasRoutine = 'has_routine';
const String onboardingEatingPathCreate = 'create';
const String onboardingEatingGeneratedSource = 'ai_generated_meal_setup';
const String onboardingEatingAiImportSource = 'ai_import';

class OnboardingStep5 extends ConsumerStatefulWidget {
  const OnboardingStep5({super.key});

  @override
  ConsumerState<OnboardingStep5> createState() => _OnboardingStep5State();
}

class _OnboardingStep5State extends ConsumerState<OnboardingStep5> {
  int _selectedDay = 1;
  String? _uploadError;
  String? _generationError;
  String? _createError;
  late final AiGenerationController _createLifecycle;
  bool _editingGeneratedRoutine = false;

  @override
  void initState() {
    super.initState();
    _createLifecycle = AiGenerationController()
      ..addListener(_onCreateLifecycleChanged);
  }

  void _onCreateLifecycleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _createLifecycle
      ..removeListener(_onCreateLifecycleChanged)
      ..dispose();
    super.dispose();
  }

  bool _isCurrentSession(String uid, int authGeneration) {
    final currentUid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    return mounted &&
        currentUid == uid &&
        ref.read(authGenerationProvider) == authGeneration;
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final path = base.eatingSetupPath;
    final eatingBlocks = base.confirmedBlocksForSection('eating');
    final isChoice = base.eatingSetupStep == 0;
    final uploadRuntime = ref.watch(
      onboardingUploadInteractionProvider.select(
        (slots) => slots[onboardingEatingUploadSlot]!,
      ),
    );
    final effectiveAsset = uploadRuntime.durableAsset;

    if (isChoice) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 38),
          child: const _EatingChoiceScreen(),
        ),
      );
    }

    final generatedBlocks = eatingBlocks
        .where((block) => block.source == onboardingEatingGeneratedSource)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: path == onboardingEatingPathHasRoutine
          ? _EatingUploadTimelineScreen(
              asset: effectiveAsset,
              previewPath: uploadRuntime.usablePreviewPath,
              uploadRuntime: uploadRuntime,
              uploadError: _uploadError,
              generationError: _generationError,
              selectedDay: _selectedDay,
              blocks: eatingBlocks,
              onUpload: _startUpload,
              onChangePhoto: () => _startUpload(selectNewFile: true),
              onRemove: _removeUploadedRoutine,
              onGenerate: _runAiExtraction,
              onDayChanged: (day) => setState(() => _selectedDay = day),
            )
          : _EatingCreateTimelineScreen(
              base: base,
              selectedDay: _selectedDay,
              blocks: generatedBlocks,
              error: _createError,
              lifecycle: _createLifecycle.state,
              editing: _editingGeneratedRoutine,
              onGenerate: _generateCreatedRoutine,
              onEdit: () {
                setState(() => _editingGeneratedRoutine = true);
              },
              onDayChanged: (day) => setState(() => _selectedDay = day),
            ),
    );
  }

  Future<void> _startUpload({bool selectNewFile = false}) async {
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final authGeneration = ref.read(authGenerationProvider);
    final previousAssetId = ref
        .read(onboardingUploadInteractionProvider)[onboardingEatingUploadSlot]
        ?.durableAsset
        ?.assetId;
    final controller = ref.read(onboardingUploadInteractionProvider.notifier);
    final before = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingEatingUploadSlot]!;
    final asset =
        !selectNewFile &&
            before.phase == UploadInteractionPhase.failed &&
            before.transientFile != null
        ? await controller.retry(
            onboardingEatingUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : await controller.chooseFromGallery(
            onboardingEatingUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          );
    if (!_isCurrentSession(uid, authGeneration)) return;

    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingEatingUploadSlot]!;
    setState(() {
      _uploadError = uploadState.phase == UploadInteractionPhase.failed
          ? _friendlyUploadMessage(uploadState.attemptError)
          : null;
    });
    if (asset != null && asset.assetId != previousAssetId) {
      _replaceEatingBlocks(const []);
    }
  }

  Future<void> _removeUploadedRoutine() async {
    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final asset = ref
        .read(onboardingUploadInteractionProvider)[onboardingEatingUploadSlot]
        ?.durableAsset;
    if (asset != null) {
      final removed = await ref
          .read(onboardingUploadInteractionProvider.notifier)
          .remove(onboardingEatingUploadSlot, uid: uid);
      if (!mounted) return;
      if (!removed) {
        setState(() {
          _uploadError = "Couldn't remove the photo. Try again.";
        });
        return;
      }
    }
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    _replaceEatingBlocks(const []);
  }

  Future<void> _runAiExtraction() async {
    if (kDebugMode) {
      debugPrint(
        '[Onboarding5] AI mode: ${OptivusAiWorkersConfig.mode.name.toUpperCase()}',
      );
    }
    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final authGeneration = ref.read(authGenerationProvider);
    final asset = ref
        .read(onboardingUploadInteractionProvider)[onboardingEatingUploadSlot]
        ?.durableAsset;
    setState(() => _generationError = null);
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    if (asset == null ||
        !uploadedAssetIsDurablyUploadedForSlot(
          asset: asset,
          uid: uid,
          purpose: UploadedAssetPurpose.eatingMenu,
        )) {
      setState(
        () => _generationError = 'Upload your routine/menu photo first.',
      );
      return;
    }
    if (!_isSupportedImageContentType(asset.contentType)) {
      setState(
        () => _generationError =
            'This photo format is not supported. Please upload JPEG, PNG, or WEBP.',
      );
      return;
    }
    if (asset.r2Key.trim().isEmpty) {
      setState(
        () => _generationError = 'Upload incomplete. Please upload again.',
      );
      return;
    }

    debugPrint(
      '[Onboarding5] START source=eating purpose=eatingMenu '
      'assetIdPresent=${asset.assetId.trim().isNotEmpty} '
      'r2KeyPresent=${asset.r2Key.trim().isNotEmpty} '
      'contentTypePresent=${asset.contentType.trim().isNotEmpty}',
    );

    final capturedAssetId = asset.assetId;
    final capturedR2Key = asset.r2Key;
    bool sourceIsCurrent() {
      final current = ref
          .read(onboardingUploadInteractionProvider)[onboardingEatingUploadSlot]
          ?.durableAsset;
      return _isCurrentSession(uid, authGeneration) &&
          current?.assetId == capturedAssetId &&
          current?.r2Key == capturedR2Key;
    }

    final now = DateTime.now();
    final review = RoutineImportReviewDraft(
      id: onboardingImportId(onboardingSectionEating, 'photo_ai'),
      uid: uid,
      source: RoutineImportReviewSource.eating,
      status: RoutineImportReviewStatus.needsReview,
      sourceLabel: onboardingSectionEating,
      onboardingPendingImportId: onboardingImportId(
        onboardingSectionEating,
        'photo_ai',
      ),
      uploadedAssetId: asset.assetId,
      uploadedAssetR2Key: asset.r2Key,
      uploadedAssetStatus: asset.status.wireName,
      createdAt: now,
      updatedAt: now,
    );

    final result = await ref
        .read(routineImportAiControllerProvider.notifier)
        .runExtraction(review);
    if (!sourceIsCurrent()) return;

    final aiState = ref.read(routineImportAiControllerProvider);
    debugPrint(
      '[Onboarding5] RESULT source=eating resultNull=${result == null} '
      'controllerStatus=${aiState.status.name} '
      'warningCount=${result?.warnings.length ?? 0}',
    );
    if (result == null) {
      setState(
        () => _generationError = onboarding5FriendlyAiMessage(
          aiState.errorMessage,
          const [],
        ),
      );
      return;
    }

    debugPrint(
      '[Onboarding5] RAW source=eating rawCandidates=${result.candidates.length}',
    );
    final mapped = mapOnboarding5MealCandidates(
      result.candidates,
      now: DateTime.now(),
      baseTimeline: ref.read(mockOnboardingProvider).draft.baseTimeline,
    );
    final blocks = mapped.blocks;
    debugPrint(
      '[Onboarding5] MAPPED source=eating mappedBlocks=${mapped.blocks.length} '
      'droppedNoTitle=${mapped.droppedNoTitle} '
      'droppedInvalidTime=${mapped.droppedInvalidTime} '
      'droppedNoMealTime=${mapped.droppedNoMealTime}',
    );
    if (blocks.isEmpty) {
      setState(
        () => _generationError = mapped.droppedNoDishes > 0
            ? 'AI did not return specific dishes. Please upload a clearer photo.'
            : onboarding5FriendlyAiMessage(
                aiState.errorMessage,
                result.warnings,
              ),
      );
      return;
    }

    if (!sourceIsCurrent()) return;
    final blocksWithProvenance = blocks
        .map(
          (b) => b.copyWith(
            provenanceSourceIds: [
              if (asset.assetId.trim().isNotEmpty) asset.assetId.trim(),
              if (asset.r2Key.trim().isNotEmpty) asset.r2Key.trim(),
            ],
          ),
        )
        .toList();
    _replaceEatingBlocks(blocksWithProvenance, sourceAsset: asset);
    setState(() => _generationError = null);
  }

  Future<void> _generateCreatedRoutine() async {
    if (_createLifecycle.state.isActive) return;
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final draft = ref.read(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final bodyContext = onboarding5MealBodyContextFromDraft(draft);
    if (!bodyContext.hasBodyBasics) {
      setState(() {
        _createError =
            'Complete Body Basics with your height and weight before generating a meal routine.';
      });
      return;
    }
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;
    final authGeneration = ref.read(authGenerationProvider);
    final isRetry = _createLifecycle.state.phase == AiGenerationPhase.error;
    setState(() => _createError = null);
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingEatingStepIndex, true);

    final run = await _createLifecycle.run<List<TimelineBlockDraft>>(
      operationType: 'nutrition-routine',
      timeoutPolicy: AiOperationTimeouts.nutrition,
      retry: isRetry,
      preparingMessage: 'Getting your meal preferences ready…',
      isSessionCurrent: () => _isCurrentSession(uid, authGeneration),
      mapError: (error) => AiGenerationError(
        category: error is _Onboarding5ResponseException
            ? AiGenerationErrorCategory.responseInvalid
            : AiGenerationErrorCategory.serviceUnavailable,
        message: error is _Onboarding5ResponseException
            ? error.message
            : 'AI is temporarily unavailable. Try again.',
        canRetry: true,
      ),
      operation: (scope) async {
        debugPrint(
          '[Onboarding5] GENERATE source=create '
          'hasBodyBasics=${bodyContext.hasBodyBasics}',
        );
        final idToken =
            await ref.read(authRepositoryProvider).currentIdToken() ?? '';
        if (!scope.isCurrent) throw const _Onboarding5StaleOperation();
        scope.transition(
          AiGenerationPhase.generating,
          message: 'Building your eating plan…',
        );
        final nutritionClient = ref.read(nutritionAiClientProvider);
        final result = await nutritionClient.generateEatingRoutine(
          uid: uid,
          idToken: idToken,
          params: {
            'bodyGoal': bodyContext.bodyGoal,
            'eatingMode': base.eatingMode,
            'foodType': base.foodType,
            'foodStyleCustomText': base.foodStyleCustomText,
            'mealsPerDay': base.mealsPerDay,
            'targetCalories': bodyContext.targetCalories,
            'proteinTarget': bodyContext.proteinTarget,
            'estimatedBmr': bodyContext.estimatedBmr,
            'breakfastMinute': base.breakfastMinute,
            'lunchMinute': base.lunchMinute,
            'dinnerMinute': base.dinnerMinute,
            'snackMinute': base.snackMinute,
            'extraSnackMinute': base.extraSnackMinute,
            'mealTimes': bodyContext.mealTimes,
            'heightCm': bodyContext.heightCm,
            'weightKg': bodyContext.currentWeightKg,
            'age': bodyContext.age,
            'gender': bodyContext.gender,
            'bmi': bodyContext.bmi,
            'estimatedMaintenanceCalories':
                bodyContext.estimatedMaintenanceCalories,
            'targetMode': bodyContext.targetMode,
            'lifestyle': bodyContext.lifestyle,
            'country': bodyContext.country,
          },
        );

        if (result.id.trim().isEmpty ||
            result.uid != uid ||
            result.candidates.isEmpty) {
          throw _Onboarding5ResponseException(
            onboarding5FriendlyAiMessage(
              null,
              result.warnings.isNotEmpty
                  ? result.warnings
                  : ['no_blocks_generated'],
            ),
          );
        }

        final mapped = mapOnboarding5MealCandidates(
          result.candidates,
          now: DateTime.now(),
          source: onboardingEatingGeneratedSource,
          baseTimeline: draft.baseTimeline,
        );
        final blocks = mapped.blocks;

        if (blocks.isEmpty) {
          throw _Onboarding5ResponseException(
            mapped.droppedNoDishes > 0
                ? 'AI did not return specific dishes. Please try again.'
                : 'Generated routine was invalid. Please try again.',
          );
        }
        return blocks;
      },
    );
    if (!mounted) return;
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingEatingStepIndex, false);
    if (run.isSuccess) {
      _replaceEatingBlocks(run.value!);
      setState(() => _editingGeneratedRoutine = false);
    } else if (run.error != null) {
      setState(() => _createError = run.error!.message);
    }
  }

  void _replaceEatingBlocks(
    List<TimelineBlockDraft> eatingBlocks, {
    UploadedAsset? sourceAsset,
  }) {
    updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
      final nextBlocks =
          base.blocks
              .where((block) => block.section != 'eating')
              .toList(growable: true)
            ..addAll(eatingBlocks);
      final nextPending = base.pendingFutureImports
          .where((entry) => entry.section != onboardingSectionEating)
          .toList(growable: true);

      if (sourceAsset != null) {
        final now = DateTime.now();
        nextPending.add(
          PendingFutureImportDraft(
            id: onboardingImportId(onboardingSectionEating, 'photo_ai'),
            section: onboardingSectionEating,
            mode: 'Photo AI',
            createdAt: now,
            updatedAt: now,
            status: PendingFutureImportDraft.appliedStatus,
            uploadedAssetId: sourceAsset.assetId,
            uploadedAssetR2Key: sourceAsset.r2Key,
            uploadedAssetStatus: sourceAsset.status.wireName,
            parsedBlocks: eatingBlocks,
          ),
        );
      }

      return base.copyWith(
        eatingSetupPath: base.eatingSetupPath ?? onboardingEatingPathCreate,
        blocks: nextBlocks,
        pendingFutureImports: nextPending,
        eatingSetupStep: 1,
      );
    });
  }
}

class _EatingChoiceScreen extends ConsumerWidget {
  const _EatingChoiceScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    void select(String value) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
        final switchedPath = base.eatingSetupPath != value;
        final createPath = value == onboardingEatingPathCreate;
        return _clearEatingBlocks(
          base.copyWith(
            eatingSetupPath: value,
            eatingSetupStep: 1,
            eatingMode: createPath
                ? (base.eatingMode ?? 'india')
                : base.eatingMode,
            mealPlanningGoal: createPath
                ? (base.mealPlanningGoal ??
                      onboarding5DefaultBodyGoalForDraft(draft))
                : base.mealPlanningGoal,
            foodType: createPath ? (base.foodType ?? 'mixed') : base.foodType,
            mealsPerDay: createPath
                ? (base.mealsPerDay ?? 4)
                : base.mealsPerDay,
            breakfastMinute: createPath
                ? (base.breakfastMinute ?? 8 * 60)
                : base.breakfastMinute,
            lunchMinute: createPath
                ? (base.lunchMinute ?? 13 * 60)
                : base.lunchMinute,
            snackMinute: createPath
                ? (base.snackMinute ?? 17 * 60)
                : base.snackMinute,
            dinnerMinute: createPath
                ? (base.dinnerMinute ?? 20 * 60 + 30)
                : base.dinnerMinute,
            extraSnackMinute: createPath
                ? (base.extraSnackMinute ?? 11 * 60)
                : base.extraSnackMinute,
            clearMealPlanning: value == onboardingEatingPathHasRoutine,
          ),
          clear: switchedPath,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EatingChoiceHeader(),
        const SizedBox(height: 18),
        _EatingPathCard(
          title: 'Yes, I have a routine/menu',
          subtitle: 'Upload a meal timetable or weekly menu.',
          icon: Icons.document_scanner_rounded,
          accent: OptivusColors.success,
          onTap: () => select(onboardingEatingPathHasRoutine),
        ),
        const SizedBox(height: 12),
        _EatingPathCard(
          title: 'No, help me create one',
          subtitle: 'Generate a simple meal routine with dishes.',
          icon: Icons.auto_awesome_rounded,
          accent: OptivusColors.roseAccent,
          onTap: () => select(onboardingEatingPathCreate),
        ),
      ],
    );
  }
}

class _EatingChoiceHeader extends StatelessWidget {
  const _EatingChoiceHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eating Setup',
          style: TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Build your weekly meal routine in a simple way.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EatingPathCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _EatingPathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        padding: const EdgeInsets.all(14),
        radius: 22,
        tint: Colors.white.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.48),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
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
      ),
    );
  }
}

class _EatingUploadTimelineScreen extends ConsumerWidget {
  final UploadedAsset? asset;
  final String? previewPath;
  final UploadSlotRuntimeState uploadRuntime;
  final String? uploadError;
  final String? generationError;
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final VoidCallback onUpload;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemove;
  final VoidCallback onGenerate;
  final ValueChanged<int> onDayChanged;

  const _EatingUploadTimelineScreen({
    required this.asset,
    required this.previewPath,
    required this.uploadRuntime,
    required this.uploadError,
    required this.generationError,
    required this.selectedDay,
    required this.blocks,
    required this.onUpload,
    required this.onChangePhoto,
    required this.onRemove,
    required this.onGenerate,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(routineImportAiControllerProvider);
    final uploadBusy = uploadRuntime.isBusy;
    final generating = aiState.isExtracting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EatingUploadCard(
          asset: asset,
          previewPath: previewPath,
          busy: uploadBusy || generating,
          failed: uploadRuntime.phase == UploadInteractionPhase.failed,
          onUpload: onUpload,
          onChangePhoto: onChangePhoto,
          onRemove: onRemove,
          onGenerate: asset == null || uploadBusy || generating
              ? null
              : onGenerate,
        ),

        if (generating ||
            aiState.lifecycle.phase == AiGenerationPhase.error) ...[
          const SizedBox(height: 14),
          AiThinkingCard(
            state: aiState.lifecycle,
            title: 'AI is reading your meal photo',
            detail: 'Looking for dishes, portions, and meal timing',
            accent: OptivusColors.roseAccent,
            onRetry: onGenerate,
          ),
        ],

        if (uploadError != null ||
            (generationError != null &&
                aiState.lifecycle.phase != AiGenerationPhase.error)) ...[
          const SizedBox(height: 8),
          _EatingInlineMessage(message: uploadError ?? generationError!),
        ],
        const SizedBox(height: 14),
        _EatingTimelineSection(
          selectedDay: selectedDay,
          blocks: blocks,
          onDayChanged: onDayChanged,
          emptyLabel: 'Generate your weekly meal routine first.',
        ),
      ],
    );
  }
}

class _EatingCreateTimelineScreen extends ConsumerWidget {
  final BaseTimelineDraft base;
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final String? error;
  final AiGenerationState lifecycle;
  final bool editing;
  final VoidCallback onGenerate;
  final VoidCallback onEdit;
  final ValueChanged<int> onDayChanged;

  const _EatingCreateTimelineScreen({
    required this.base,
    required this.selectedDay,
    required this.blocks,
    required this.error,
    required this.lifecycle,
    required this.editing,
    required this.onGenerate,
    required this.onEdit,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final bodyContext = onboarding5MealBodyContextFromDraft(draft);
    final bodyGoal = onboarding5BodyGoalForBase(base, draft);
    final mealsPerDay = _normalizedMealsPerDay(base.mealsPerDay);
    final generated = blocks.isNotEmpty && !editing;
    final isGenerating = lifecycle.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (generated)
          _EatingGeneratedSummaryRow(
            bodyGoal: bodyGoal,
            style: base.eatingMode ?? 'india',
            eatingType: base.foodType ?? 'mixed',
            mealsPerDay: mealsPerDay,
            targetCalories: bodyContext.targetCalories,
            onEdit: onEdit,
          )
        else
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: OnboardingGlassCard(
                tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
                padding: const EdgeInsets.all(12),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create your meal intelligence',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Optivus will build a weekly meal timeline using your body goal, calorie need, food culture, and usual meal times.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _EatingBodyContextLine(
                      hasBodyBasics: bodyContext.hasBodyBasics,
                    ),
                    const SizedBox(height: 9),
                    _EatingChipGroup(
                      label: 'Goal',
                      children: [
                        for (final option in const [
                          _EatingModeOption('gain', 'Gain'),
                          _EatingModeOption('lose', 'Lose'),
                          _EatingModeOption('maintain', 'Maintain'),
                        ])
                          _EatingPreferenceChip(
                            label: option.label,
                            selected: bodyGoal == option.key,
                            accent: OptivusColors.roseAccent,
                            onTap: () => _updateCreateDraft(
                              ref,
                              (base) =>
                                  base.copyWith(mealPlanningGoal: option.key),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _EatingChipGroup(
                      label: 'Meals',
                      children: [
                        for (final count in const [3, 4, 5])
                          _EatingPreferenceChip(
                            label: '$count',
                            selected: mealsPerDay == count,
                            accent: OptivusColors.roseAccent,
                            onTap: () => _updateCreateDraft(
                              ref,
                              (base) => base.copyWith(mealsPerDay: count),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _EatingChipGroup(
                      label: 'Style',
                      children: [
                        for (final option in const [
                          _EatingModeOption('india', 'India'),
                          _EatingModeOption('us', 'US'),
                          _EatingModeOption('germany', 'Germany'),
                          _EatingModeOption('mixed', 'Mixed'),
                          _EatingModeOption('custom', 'Custom'),
                        ])
                          _EatingPreferenceChip(
                            label: option.label,
                            selected:
                                (base.eatingMode ?? 'india') == option.key,
                            accent: OptivusColors.roseAccent,
                            onTap: () => _updateCreateDraft(
                              ref,
                              (base) => base.copyWith(eatingMode: option.key),
                            ),
                          ),
                      ],
                    ),
                    if ((base.eatingMode ?? 'india') == 'custom') ...[
                      const SizedBox(height: 7),
                      _EatingCustomStyleField(base: base),
                    ],
                    const SizedBox(height: 7),
                    _EatingChipGroup(
                      label: 'Type',
                      children: [
                        for (final option in const [
                          _EatingModeOption('veg', 'Veg'),
                          _EatingModeOption('non_veg', 'Non-veg'),
                          _EatingModeOption('mixed', 'Mixed'),
                        ])
                          _EatingPreferenceChip(
                            label: option.label,
                            selected: (base.foodType ?? 'mixed') == option.key,
                            accent: OptivusColors.roseAccent,
                            onTap: () => _updateCreateDraft(
                              ref,
                              (base) => base.copyWith(foodType: option.key),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _CompactMealTimeRows(base: base, mealsPerDay: mealsPerDay),
                    const SizedBox(height: 9),
                    _EatingGenerateRoutineButton(
                      isGenerating: isGenerating,
                      onTap: onGenerate,
                    ),
                    if (isGenerating ||
                        lifecycle.phase == AiGenerationPhase.error) ...[
                      const SizedBox(height: 14),
                      AiThinkingCard(
                        state: lifecycle,
                        title: 'AI is creating your weekly meal plan',
                        detail: 'Planning meals around your daily routine',
                        accent: OptivusColors.roseAccent,
                        onRetry: onGenerate,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (error != null && lifecycle.phase != AiGenerationPhase.error) ...[
          const SizedBox(height: 8),
          _EatingInlineMessage(message: error!),
        ],
        if (generated) ...[
          const SizedBox(height: 10),
          _EatingTimelineSection(
            selectedDay: selectedDay,
            blocks: blocks,
            onDayChanged: onDayChanged,
            emptyLabel: 'Generate your meal routine to preview the week.',
          ),
        ],
      ],
    );
  }
}

class _EatingUploadCard extends StatelessWidget {
  final UploadedAsset? asset;
  final String? previewPath;
  final bool busy;
  final bool failed;
  final VoidCallback onUpload;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemove;
  final VoidCallback? onGenerate;

  const _EatingUploadCard({
    required this.asset,
    required this.previewPath,
    required this.busy,
    required this.failed,
    required this.onUpload,
    required this.onChangePhoto,
    required this.onRemove,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(12),
      radius: 21,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload your routine/menu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          const Text(
            'Add your weekly meal timetable photo.',
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: busy ? null : onUpload,
                  child: _EatingPhotoTarget(
                    asset: asset,
                    previewPath: previewPath,
                    onRemove: onRemove,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _EatingGenerateButton(onTap: onGenerate, busy: busy),
            ],
          ),
          if (failed && !busy) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  key: const Key('onboarding-step5-retry-upload'),
                  onPressed: onUpload,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Retry'),
                ),
                TextButton.icon(
                  key: const Key('onboarding-step5-change-photo'),
                  onPressed: onChangePhoto,
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Change photo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EatingBodyContextLine extends StatelessWidget {
  final bool hasBodyBasics;

  const _EatingBodyContextLine({required this.hasBodyBasics});

  @override
  Widget build(BuildContext context) {
    return Text(
      hasBodyBasics
          ? 'Using your body basics to guide the meal routine.'
          : 'Body basics missing. Using a simple balanced routine.',
      style: const TextStyle(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: OptivusColors.textSecondary,
      ),
    );
  }
}

class _EatingGeneratedSummaryRow extends StatelessWidget {
  final String bodyGoal;
  final String style;
  final String eatingType;
  final int mealsPerDay;
  final int? targetCalories;
  final VoidCallback onEdit;

  const _EatingGeneratedSummaryRow({
    required this.bodyGoal,
    required this.style,
    required this.eatingType,
    required this.mealsPerDay,
    required this.targetCalories,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final summary =
        '${_goalLabel(bodyGoal)} · ${_styleLabel(style)} · ${_typeLabel(eatingType)} · $mealsPerDay meals · ${targetCalories == null ? 'calorie target unavailable' : '~$targetCalories kcal'}';
    return OnboardingGlassCard(
      tint: Colors.white.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 18,
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: OptivusColors.roseAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.roseAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingPhotoTarget extends ConsumerWidget {
  final UploadedAsset? asset;
  final String? previewPath;
  final VoidCallback onRemove;

  const _EatingPhotoTarget({
    required this.asset,
    required this.previewPath,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = previewPath;
    final restored = ref
        .watch(restoredUploadsProvider)
        .forPurpose(UploadedAssetPurpose.eatingMenu);
    final remotePreview = restored?.asset.assetId == asset?.assetId
        ? restored?.previewUri
        : null;
    final previewStatus = restored?.asset.assetId == asset?.assetId
        ? restored?.previewStatus
        : UploadedAssetPreviewStatus.unavailable;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: preview != null
                  ? Image.file(
                      File(preview),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(previewStatus),
                    )
                  : remotePreview != null
                  ? Image.network(
                      remotePreview.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _fallback(UploadedAssetPreviewStatus.unavailable),
                    )
                  : _fallback(previewStatus),
            ),
          ),
          if (asset != null)
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(UploadedAssetPreviewStatus? status) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          asset == null
              ? Icons.add_photo_alternate_rounded
              : Icons.check_circle_rounded,
          color: OptivusColors.roseAccent,
          size: 24,
        ),
        const SizedBox(height: 3),
        Text(
          asset == null ? 'Add photo' : 'Photo uploaded',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
        if (asset != null)
          Text(
            status == UploadedAssetPreviewStatus.loading
                ? 'Loading preview…'
                : 'Preview unavailable',
            style: const TextStyle(fontSize: 9),
          ),
      ],
    );
  }
}

class _EatingGenerateButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;

  const _EatingGenerateButton({required this.onTap, required this.busy});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.45,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? OptivusColors.roseAccent : Colors.white,
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: enabled ? Colors.white : OptivusColors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _EatingChipGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _EatingChipGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 43,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _EatingPreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _EatingPreferenceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.36)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.42),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : OptivusColors.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EatingCustomStyleField extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;

  const _EatingCustomStyleField({required this.base});

  @override
  ConsumerState<_EatingCustomStyleField> createState() =>
      __EatingCustomStyleFieldState();
}

class __EatingCustomStyleFieldState
    extends ConsumerState<_EatingCustomStyleField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && context.mounted) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      focusNode: _focusNode,
      initialValue: widget.base.foodStyleCustomText ?? '',
      minLines: 1,
      maxLines: 1,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Example: Bengali hostel food, high protein',
        hintStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.24),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OptivusColors.roseAccent),
        ),
      ),
      onChanged: (value) => _updateCreateDraft(
        ref,
        (base) => base.copyWith(foodStyleCustomText: value),
      ),
    );
  }
}

class _CompactMealTimeRows extends ConsumerWidget {
  final BaseTimelineDraft base;
  final int mealsPerDay;

  const _CompactMealTimeRows({required this.base, required this.mealsPerDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs = <_MealTimeControl>[
      _MealTimeControl('Breakfast', base.breakfastMinute ?? 8 * 60, (value) {
        _updateCreateDraft(
          ref,
          (base) => base.copyWith(breakfastMinute: value),
        );
      }),
      if (mealsPerDay == 5)
        _MealTimeControl('Extra snack', base.extraSnackMinute ?? 11 * 60, (
          value,
        ) {
          _updateCreateDraft(
            ref,
            (base) => base.copyWith(extraSnackMinute: value),
          );
        }),
      _MealTimeControl('Lunch', base.lunchMinute ?? 13 * 60, (value) {
        _updateCreateDraft(ref, (base) => base.copyWith(lunchMinute: value));
      }),
      if (mealsPerDay >= 4)
        _MealTimeControl('Snack', base.snackMinute ?? 17 * 60, (value) {
          _updateCreateDraft(ref, (base) => base.copyWith(snackMinute: value));
        }),
      _MealTimeControl('Dinner', base.dinnerMinute ?? 20 * 60 + 30, (value) {
        _updateCreateDraft(ref, (base) => base.copyWith(dinnerMinute: value));
      }),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = math.max(120.0, (constraints.maxWidth - 8) / 2);
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final spec in specs)
              SizedBox(
                width: itemWidth,
                child: _CompactMealTimeRow(spec: spec),
              ),
          ],
        );
      },
    );
  }
}

class _CompactMealTimeRow extends StatelessWidget {
  final _MealTimeControl spec;

  const _CompactMealTimeRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: onboardingTimeFromMinute(spec.minute),
        );
        if (picked == null) return;
        spec.onChanged(onboardingMinuteFromTime(picked));
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                spec.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
              ),
              child: Text(
                onboardingTimeLabel(spec.minute),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.roseAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EatingGenerateRoutineButton extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onTap;

  const _EatingGenerateRoutineButton({
    required this.isGenerating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isGenerating ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: OptivusColors.roseAccent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.roseAccent.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'Generate meal routine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Onboarding5ResponseException implements Exception {
  final String message;
  const _Onboarding5ResponseException(this.message);
}

class _Onboarding5StaleOperation implements Exception {
  const _Onboarding5StaleOperation();
}

class _EatingTimelineSection extends ConsumerWidget {
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final ValueChanged<int> onDayChanged;
  final String emptyLabel;

  const _EatingTimelineSection({
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const adapter = MealTimelineAdapter();
    final entries = [for (final block in blocks) ...adapter.toEntries(block)];

    Future<void> openMealEditor(TimelineBlockDraft block) {
      return MealTimelineAdapter.showMealEditSheet(
        context: context,
        block: block,
        onSave: (updated) async {
          updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
            return base.copyWith(
              blocks: [
                for (final item in base.blocks)
                  if (item.id == block.id) updated else item,
              ],
            );
          });
          return true;
        },
      );
    }

    return Expanded(
      child: FullScreenTimelineScaffold(
        key: const ValueKey('onboarding-step5-full-screen-timeline'),
        entries: entries,
        selectedDay: selectedDay,
        onDayChanged: onDayChanged,
        title: 'Set Your Weekly Meal',
        emptyDayMessage: emptyLabel,
        accent: OptivusColors.roseAccent,
        styleBuilder: adapter.styleForEntry,
        blockBuilder: (context, positioned) {
          final block = blocks
              .where((candidate) => candidate.id == positioned.entry.sourceId)
              .first;
          return _EatingTimelineBlock(
            block: block,
            onEditRequested: () => openMealEditor(block),
          );
        },
        onEntryTapped: (entry) {
          final block = blocks
              .where((candidate) => candidate.id == entry.sourceId)
              .firstOrNull;
          if (block == null) return;
          openMealEditor(block);
        },
      ),
    );
  }
}

void _showEatingBlockDetails(BuildContext context, TimelineBlockDraft block) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _mealIcon(block.mealCategory),
                    color: OptivusColors.roseAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _mealTitleForDisplay(block),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.ink.withValues(alpha: 0.6),
                ),
              ),
              if (block.dishes.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Menu / Dishes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.roseAccent,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final dish in block.dishes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: OptivusColors.roseAccent.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dish,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

// ignore: unused_element
class _EatingTimelineBlock extends StatelessWidget {
  final TimelineBlockDraft block;
  final VoidCallback onEditRequested;

  const _EatingTimelineBlock({
    required this.block,
    required this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final allDishes = block.dishes
        .map((dish) => dish.trim())
        .where((dish) => dish.isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: () => _showEatingBlockDetails(context, block),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.44),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              OptivusColors.roseAccent.withValues(alpha: 0.22),
              OptivusColors.roseAccent.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.88),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.roseAccent.withValues(alpha: 0.14),
              blurRadius: 13,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _mealIcon(block.mealCategory),
                    color: OptivusColors.roseAccent,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _mealTitleForDisplay(block),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.ink,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                key: ValueKey(
                                  'onboarding-step5-edit-${block.id}',
                                ),
                                tooltip: 'Edit meal',
                                padding: EdgeInsets.zero,
                                onPressed: onEditRequested,
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  size: 19,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textScaler = MediaQuery.textScalerOf(
                                context,
                              );
                              final textDirection = Directionality.of(context);
                              final wrapWidth = constraints.maxWidth;
                              final availableHeight = constraints.maxHeight;

                              final List<String> labels = [
                                '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
                                ...allDishes,
                              ];

                              List<Widget> children = [];
                              double currentX = 0.0;
                              double currentY = 0.0;
                              double rowHeight = 0.0;
                              int visibleCount = 0;
                              bool overflowed = false;

                              for (int i = 0; i < labels.length; i++) {
                                final label = labels[i];
                                final textPainter =
                                    TextPainter(
                                      text: TextSpan(
                                        text: label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      textDirection: textDirection,
                                      textScaler: textScaler,
                                    )..layout(
                                      maxWidth: math.max(
                                        10.0,
                                        wrapWidth - 16.0,
                                      ),
                                    );

                                final chipWidth = textPainter.width + 16.0;
                                final chipHeight = textPainter.height + 8.0;

                                double nextX;
                                double nextY;
                                double nextRowHeight;

                                if (currentX == 0) {
                                  nextX = chipWidth;
                                  nextY = currentY;
                                  nextRowHeight = chipHeight;
                                } else {
                                  if (currentX + 6.0 + chipWidth <= wrapWidth) {
                                    nextX = currentX + 6.0 + chipWidth;
                                    nextY = currentY;
                                    nextRowHeight = math.max(
                                      rowHeight,
                                      chipHeight,
                                    );
                                  } else {
                                    nextY = currentY + rowHeight + 5.0;
                                    nextX = chipWidth;
                                    nextRowHeight = chipHeight;
                                  }
                                }

                                if (nextY + nextRowHeight > availableHeight) {
                                  overflowed = true;
                                  break;
                                }

                                currentX = nextX;
                                currentY = nextY;
                                rowHeight = nextRowHeight;
                                visibleCount++;
                              }

                              if (overflowed && visibleCount < labels.length) {
                                final int toShow = math.max(
                                  1,
                                  visibleCount - 1,
                                );
                                for (int i = 0; i < toShow; i++) {
                                  children.add(OnboardingInfoChip(labels[i]));
                                }
                                final remaining = labels.length - toShow;
                                children.add(
                                  GestureDetector(
                                    onTap: () =>
                                        _showEatingBlockDetails(context, block),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: OptivusColors.roseAccent
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: OptivusColors.roseAccent
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        '+$remaining more',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: OptivusColors.roseAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                for (final label in labels) {
                                  children.add(OnboardingInfoChip(label));
                                }
                              }

                              return Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                children: children,
                              );
                            },
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
}

class _EatingInlineMessage extends StatelessWidget {
  final String message;

  const _EatingInlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.warning.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(11),
      radius: 17,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: OptivusColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.32,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingModeOption {
  final String key;
  final String label;

  const _EatingModeOption(this.key, this.label);
}

class _MealTimeControl {
  final String title;
  final int minute;
  final ValueChanged<int> onChanged;

  const _MealTimeControl(this.title, this.minute, this.onChanged);
}

@visibleForTesting
class Onboarding5MealBodyContext {
  final String bodyGoal;
  final String targetMode;
  final double? currentWeightKg;
  final double? heightCm;
  final int? age;
  final String? gender;
  final double? bmi;
  final int? estimatedBmr;
  final int? estimatedMaintenanceCalories;
  final int? targetCalories;
  final double? proteinTarget;
  final int mealsPerDay;
  final String eatingType;
  final String foodStyle;
  final String? customFoodStyle;
  final Map<String, int> mealTimes;
  final String? lifestyle;
  final String? country;
  final bool hasBodyBasics;

  const Onboarding5MealBodyContext({
    required this.bodyGoal,
    required this.targetMode,
    required this.currentWeightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
    required this.bmi,
    required this.estimatedBmr,
    required this.estimatedMaintenanceCalories,
    required this.targetCalories,
    required this.proteinTarget,
    required this.mealsPerDay,
    required this.eatingType,
    required this.foodStyle,
    required this.customFoodStyle,
    required this.mealTimes,
    required this.lifestyle,
    required this.country,
    required this.hasBodyBasics,
  });
}

@visibleForTesting
class Onboarding5MealCandidateMappingResult {
  final List<TimelineBlockDraft> blocks;
  final int droppedNoTitle;
  final int droppedInvalidTime;
  final int droppedNoMealTime;

  final int droppedNoDishes;

  const Onboarding5MealCandidateMappingResult({
    required this.blocks,
    required this.droppedNoTitle,
    required this.droppedInvalidTime,
    required this.droppedNoMealTime,
    required this.droppedNoDishes,
  });
}

@visibleForTesting
String onboarding5DefaultBodyGoalForDraft(OnboardingDraft draft) {
  final baseGoal = draft.baseTimeline.mealPlanningGoal;
  final normalizedBase = _normalizedBodyGoal(baseGoal);
  if (normalizedBase != null) return normalizedBase;
  final goalKeys = draft.identityGoals
      .expand((goal) => [goal.goalKey, ...goal.systemKeys])
      .map((value) => value.toLowerCase())
      .join(' ');
  if (goalKeys.contains('strong_body') ||
      goalKeys.contains('muscle') ||
      goalKeys.contains('workout') ||
      goalKeys.contains('protein')) {
    return 'gain';
  }
  return 'maintain';
}

@visibleForTesting
String onboarding5BodyGoalForBase(
  BaseTimelineDraft base,
  OnboardingDraft draft,
) {
  return _normalizedBodyGoal(base.mealPlanningGoal) ??
      onboarding5DefaultBodyGoalForDraft(draft);
}

@visibleForTesting
Onboarding5MealBodyContext onboarding5MealBodyContextFromDraft(
  OnboardingDraft draft,
) {
  final base = draft.baseTimeline;
  final body = draft.bodyBasics.withEstimates();
  final bodyGoal = onboarding5BodyGoalForBase(base, draft);
  final weight = body.weightKg;
  final height = body.heightCm;
  final age = _ageFromRange(body.ageRange);
  final hasBodyBasics =
      weight != null &&
      weight > 0 &&
      height != null &&
      height > 0 &&
      age != null &&
      body.gender != null;
  final bmr = hasBodyBasics
      ? _estimateBmr(
          weightKg: weight,
          heightCm: height,
          age: age,
          gender: body.gender,
        )
      : null;
  final maintenance = !hasBodyBasics
      ? null
      : body.calorieEstimate != null && body.calorieEstimate! > 0
      ? body.calorieEstimate!.round()
      : (bmr! * _activityFactorForLifeRole(draft.lifeRole)).round();
  final target = maintenance == null
      ? null
      : _targetCalories(
          maintenanceCalories: maintenance,
          bodyGoal: bodyGoal,
          gender: body.gender,
        );
  final mealsPerDay = _normalizedMealsPerDay(base.mealsPerDay);

  return Onboarding5MealBodyContext(
    bodyGoal: bodyGoal,
    targetMode: switch (bodyGoal) {
      'gain' => 'mild_surplus',
      'lose' => 'mild_deficit',
      _ => 'maintenance',
    },
    currentWeightKg: weight,
    heightCm: height,
    age: age,
    gender: body.gender,
    bmi: body.bmiEstimate,
    estimatedBmr: bmr,
    estimatedMaintenanceCalories: maintenance,
    targetCalories: target,
    proteinTarget: body.proteinEstimate,
    mealsPerDay: mealsPerDay,
    eatingType: _normalizedEatingType(base.foodType),
    foodStyle: _normalizedFoodStyle(base.eatingMode, base.foodStyleCustomText),
    customFoodStyle: base.foodStyleCustomText?.trim().isEmpty == true
        ? null
        : base.foodStyleCustomText?.trim(),
    mealTimes: _mealTimesForBase(base, mealsPerDay),
    lifestyle: draft.lifeRole.lifeRole,
    country: null, // Country is not captured in the current onboarding draft
    hasBodyBasics: hasBodyBasics,
  );
}

List<TimelineBlockDraft> onboarding5MealBlocksFromCandidates(
  List<RoutineImportCandidateBlock> candidates, {
  DateTime? now,
}) {
  return mapOnboarding5MealCandidates(
    candidates,
    now: now,
    baseTimeline: null,
  ).blocks;
}

@visibleForTesting
Onboarding5MealCandidateMappingResult mapOnboarding5MealCandidates(
  List<RoutineImportCandidateBlock> candidates, {
  DateTime? now,
  String source = onboardingEatingAiImportSource,
  BaseTimelineDraft? baseTimeline,
}) {
  final timestamp = now ?? DateTime.now();
  final blocks = <TimelineBlockDraft>[];
  var droppedNoTitle = 0;
  var droppedInvalidTime = 0;
  var droppedNoMealTime = 0;
  var droppedNoDishes = 0;

  for (final candidate in candidates) {
    final mealCategory = _inferMealCategoryForCandidate(candidate);
    final title = _mealCandidateTitle(candidate, mealCategory);
    if (title.isEmpty) {
      droppedNoTitle++;
      continue;
    }

    final defaultTime = _defaultMealTimeForCategory(mealCategory);

    int? overrideStart;
    int? overrideEnd;
    if (baseTimeline != null) {
      if (mealCategory == 'breakfast' && baseTimeline.breakfastMinute != null) {
        overrideStart = baseTimeline.breakfastMinute;
        overrideEnd = overrideStart! + 30;
      } else if (mealCategory == 'lunch' && baseTimeline.lunchMinute != null) {
        overrideStart = baseTimeline.lunchMinute;
        overrideEnd = overrideStart! + 45;
      } else if (mealCategory == 'snack' && baseTimeline.snackMinute != null) {
        overrideStart = baseTimeline.snackMinute;
        overrideEnd = overrideStart! + 20;
      } else if (mealCategory == 'extra-snack' &&
          baseTimeline.extraSnackMinute != null) {
        overrideStart = baseTimeline.extraSnackMinute;
        overrideEnd = overrideStart! + 20;
      } else if (mealCategory == 'dinner' &&
          baseTimeline.dinnerMinute != null) {
        overrideStart = baseTimeline.dinnerMinute;
        overrideEnd = overrideStart! + 45;
      }
    }

    final hasCandidateTime =
        candidate.hasFixedTime && candidate.startMinute < candidate.endMinute;
    final startMinute = hasCandidateTime
        ? candidate.startMinute
        : (overrideStart ?? defaultTime?.$1);
    final endMinute = hasCandidateTime
        ? candidate.endMinute
        : (overrideEnd ?? defaultTime?.$2);
    if (startMinute == null || endMinute == null) {
      droppedNoMealTime++;
      continue;
    }
    if (startMinute < 0 || endMinute > 24 * 60 || startMinute >= endMinute) {
      droppedInvalidTime++;
      continue;
    }

    final repeatDays = _repeatDaysForEatingCandidate(candidate);
    final dishes = _dishesForEatingCandidate(candidate);

    if (dishes.isEmpty) {
      droppedNoDishes++;
      continue;
    }

    blocks.add(
      TimelineBlockDraft(
        id: 'eating-ai-${candidate.id}-${timestamp.millisecondsSinceEpoch}',
        section: 'eating',
        title: title,
        startMinute: startMinute,
        endMinute: endMinute,
        repeatDays: repeatDays.isEmpty ? onboardingEveryDay() : repeatDays,
        location: candidate.location,
        blockType: TimelineBlockDraft.hardBlockKey,
        source: source,
        mealCategory: mealCategory,
        dishes: dishes,
      ),
    );
  }
  blocks.sort((a, b) {
    final aDay = a.repeatDays.isEmpty ? 1 : a.repeatDays.first;
    final bDay = b.repeatDays.isEmpty ? 1 : b.repeatDays.first;
    final day = aDay.compareTo(bDay);
    if (day != 0) return day;
    return a.startMinute.compareTo(b.startMinute);
  });

  final mergedBlocks = mergeOverlappingEatingBlocks(blocks);

  return Onboarding5MealCandidateMappingResult(
    blocks: mergedBlocks,
    droppedNoTitle: droppedNoTitle,
    droppedInvalidTime: droppedInvalidTime,
    droppedNoMealTime: droppedNoMealTime,
    droppedNoDishes: droppedNoDishes,
  );
}

String? _normalizedBodyGoal(String? value) {
  final lower = value?.trim().toLowerCase();
  return switch (lower) {
    'gain' || 'gain_weight' || 'build_muscle' || 'muscle_gain' => 'gain',
    'lose' || 'lose_fat' || 'fat_loss' || 'weight_loss' => 'lose',
    'maintain' || 'maintenance' || 'eat_healthier' || 'balanced' => 'maintain',
    _ => null,
  };
}

int? _ageFromRange(String? ageRange) {
  return switch (ageRange?.trim()) {
    '<18' => 17,
    '18-24' => 21,
    '25-34' => 30,
    '35-44' => 40,
    '45+' => 50,
    _ => null,
  };
}

int _estimateBmr({
  required double weightKg,
  required double heightCm,
  required int age,
  required String? gender,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  final adjustment = switch (gender) {
    'male' => 5.0,
    'female' => -161.0,
    _ => -78.0,
  };
  return (base + adjustment).round().clamp(1100, 2600);
}

double _activityFactorForLifeRole(LifeRoleDraft lifeRole) {
  return switch (lifeRole.exerciseLevel) {
    'high' || 'active' => 1.45,
    'medium' || 'moderate' => 1.35,
    'low' || 'sedentary' => 1.25,
    _ => 1.30,
  };
}

int _targetCalories({
  required int maintenanceCalories,
  required String bodyGoal,
  required String? gender,
}) {
  final safeMaintenance = maintenanceCalories.clamp(1500, 4200);
  if (bodyGoal == 'gain') {
    return (safeMaintenance + 300).clamp(
      safeMaintenance,
      safeMaintenance + 500,
    );
  }
  if (bodyGoal == 'lose') {
    final floor = gender == 'female' ? 1200 : 1400;
    return (safeMaintenance - 350).clamp(
      math.max(floor, (safeMaintenance * 0.75).round()),
      safeMaintenance,
    );
  }
  return safeMaintenance;
}

Map<String, int> _mealTimesForBase(BaseTimelineDraft base, int mealsPerDay) {
  return {
    'breakfast': base.breakfastMinute ?? 8 * 60,
    if (mealsPerDay == 5) 'extra-snack': base.extraSnackMinute ?? 11 * 60,
    'lunch': base.lunchMinute ?? 13 * 60,
    if (mealsPerDay >= 4) 'snack': base.snackMinute ?? 17 * 60,
    'dinner': base.dinnerMinute ?? 20 * 60 + 30,
  };
}

String _inferMealCategoryForCandidate(RoutineImportCandidateBlock candidate) {
  for (final value in [
    candidate.mealCategory,
    candidate.sourceColumnLabel,
    candidate.title,
    candidate.category,
    candidate.sourceTextSnippet,
  ]) {
    final category = _inferMealCategory(value ?? '');
    if (category != 'meal') return category;
  }
  return 'meal';
}

String _mealCandidateTitle(
  RoutineImportCandidateBlock candidate,
  String mealCategory,
) {
  final title = candidate.title.trim();
  if (title.isNotEmpty && !_looksLikeRawMealLabel(title)) return title;
  if (mealCategory != 'meal') return _goalLabel(mealCategory);
  return title;
}

bool _looksLikeRawMealLabel(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'extra_snack' ||
      normalized == 'extra-snack' ||
      normalized == 'snacks';
}

(int, int)? _defaultMealTimeForCategory(String mealCategory) {
  return switch (mealCategory) {
    'breakfast' => (7 * 60 + 30, 10 * 60),
    'lunch' => (13 * 60, 15 * 60),
    'snack' || 'extra-snack' => (18 * 60, 19 * 60),
    'dinner' => (20 * 60, 22 * 60),
    _ => null,
  };
}

List<int> _repeatDaysForEatingCandidate(RoutineImportCandidateBlock candidate) {
  final days = <int>{};
  days.addAll(candidate.repeatDays.where((day) => day >= 1 && day <= 7));
  for (final value in [
    candidate.sourceRowLabel,
    candidate.sourceColumnLabel,
    candidate.sourceTextSnippet,
  ]) {
    if (value == null || value.trim().isEmpty) continue;
    days.addAll(_dayNumbersFromText(value));
  }
  return days.toList()..sort();
}

List<String> _dishesForEatingCandidate(RoutineImportCandidateBlock candidate) {
  final dishes = <String>{};

  void addDish(String text) {
    final dish = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (dish.length < 2 || _looksLikeNonDishMealToken(dish)) return;
    dishes.add(dish);
  }

  for (final step in candidate.steps) {
    addDish(step);
  }

  void extractFromRawText(String? text, {bool stripMealWords = true}) {
    if (text == null || text.trim().isEmpty) return;
    final cleaned = text
        .replaceAll(RegExp(r'[–—]'), '-')
        .replaceAll(
          stripMealWords
              ? RegExp(
                  r'\b(Breakfast|Lunch|Brunch|Supper|Snacks?|Dinner)\b',
                  caseSensitive: false,
                )
              : RegExp(r'(?!)'),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(Mon|Tue|Tues|Wed|Thu|Thur|Fri|Sat|Sun)(day)?\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\d{1,2}[:.]\d{2}\s*(AM|PM)?', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\d{1,2}\s*(AM|PM)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+-\s+'), ' ');
    final items = cleaned
        .split(RegExp(r'[,;\n|•·]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2);
    for (final item in items) {
      addDish(item);
    }
  }

  extractFromRawText(candidate.sourceTextSnippet);
  extractFromRawText(candidate.notes);
  extractFromRawText(candidate.sourceColumnLabel);
  if (_candidateTitleCanBeDishHint(candidate.title)) {
    extractFromRawText(candidate.title, stripMealWords: false);
  }

  return dishes.toList();
}

bool _candidateTitleCanBeDishHint(String title) {
  final value = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length < 2) return false;
  if (_looksLikeNonDishMealToken(value)) return false;
  final withoutMealWords = value
      .replaceAll(
        RegExp(
          r'\b(Breakfast|Lunch|Brunch|Supper|Snacks?|Dinner|Meal)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (withoutMealWords.isEmpty) return false;
  return !_looksLikeNonDishMealToken(withoutMealWords);
}

bool _looksLikeNonDishMealToken(String value) {
  final lower = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s/-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (lower.isEmpty || !RegExp(r'[a-z]').hasMatch(lower)) return true;
  if (RegExp(r'\bpart\s*\d+\b').hasMatch(lower)) return true;
  const generic = {
    'breakfast',
    'lunch',
    'brunch',
    'supper',
    'snack',
    'snacks',
    'dinner',
    'extra snack',
    'extra-snack',
    'meal',
    'meals',
    'menu',
    'mess menu',
    'mess item',
    'food',
    'item',
    'items',
    'routine',
  };
  return generic.contains(lower);
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
    for (var day = start; day <= end; day++) {
      found.add(day);
    }
  }
  final tokenPattern = RegExp(r'(^|[^a-z])(' + dayToken + r')(?=$|[^a-z])');
  for (final match in tokenPattern.allMatches(lower)) {
    final day = aliases[match.group(2)];
    if (day != null) found.add(day);
  }
  return found.toList()..sort();
}

String onboarding5FriendlyAiMessage(String? error, List<String> warnings) {
  final messages = [
    if (error?.trim().isNotEmpty == true) error!.trim(),
    ...warnings
        .map((warning) => warning.trim())
        .where((warning) => warning.isNotEmpty),
  ];
  final text = messages.join(' ').toLowerCase();

  if (text.contains('worker is not configured') ||
      text.contains('worker url') ||
      text.contains('missing_worker_url')) {
    return 'Real AI is not configured. Missing nutrition worker URL.';
  }
  if (text.contains('network_unavailable') ||
      text.contains('provider_unavailable') ||
      text.contains('provider_timeout')) {
    return 'AI service is unavailable. Try again after a moment.';
  }
  if (text.contains('provider_model_not_found')) {
    return 'AI model is not available. Check worker model config.';
  }
  if (text.contains('provider_request_failed')) {
    return 'AI is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_high_demand')) {
    return 'AI model is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_quota_exceeded') ||
      text.contains('quota') ||
      text.contains('rate limit') ||
      text.contains('rate_limit')) {
    return 'AI quota/rate limit reached. Try again later.';
  }
  if (text.contains('unsupported_content_type') ||
      text.contains('content type') ||
      text.contains('format')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  if (text.contains('provider_empty_candidates') ||
      text.contains('no_blocks_generated')) {
    return 'AI could not read meals clearly. Try a clearer photo.';
  }
  if (text.contains('too large') || text.contains('image too large')) {
    return 'Meal photo is too large. Upload a smaller, clearer photo.';
  }
  if (text.contains('not found') || text.contains('r2_image_missing')) {
    return 'Uploaded meal photo could not be found. Please upload again.';
  }
  if (text.contains('unauthorized') ||
      text.contains('invalid key') ||
      text.contains('invalid_api_key')) {
    return 'AI key is invalid or unauthorized.';
  }
  if (text.contains('invalid structured') ||
      text.contains('could not be read safely') ||
      text.contains('provider_invalid_json')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (messages.isNotEmpty &&
      !messages.first.startsWith('provider_') &&
      !messages.first.toLowerCase().contains('exception') &&
      !messages.first.toLowerCase().contains('raw_') &&
      !messages.first.toLowerCase().contains('secret') &&
      !messages.first.contains('{') &&
      !messages.first.contains('}')) {
    return messages.first;
  }
  return 'AI could not read this meal routine/menu image. Please upload a clearer image and try again.';
}

BaseTimelineDraft _clearEatingBlocks(
  BaseTimelineDraft base, {
  bool clear = true,
}) {
  if (!clear) return base;
  return base.copyWith(
    blocks: base.blocks
        .where((block) => block.section != 'eating')
        .toList(growable: false),
    pendingFutureImports: base.pendingFutureImports
        .where((entry) => entry.section != onboardingSectionEating)
        .toList(growable: false),
  );
}

void _updateCreateDraft(
  WidgetRef ref,
  BaseTimelineDraft Function(BaseTimelineDraft base) update,
) {
  ref.read(mockOnboardingProvider.notifier).clearValidation();
  updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
    final updated = update(base);
    return updated.copyWith(
      blocks: updated.blocks
          .where(
            (block) =>
                block.section != 'eating' ||
                block.source != onboardingEatingGeneratedSource,
          )
          .toList(growable: false),
    );
  });
}

int _normalizedMealsPerDay(int? value) {
  final count = value ?? 4;
  if (count <= 3) return 3;
  if (count >= 5) return 5;
  return 4;
}

bool _isSupportedImageContentType(String contentType) {
  final normalized = contentType.trim().toLowerCase();
  return normalized == 'image/jpeg' ||
      normalized == 'image/jpg' ||
      normalized == 'image/png' ||
      normalized == 'image/webp';
}

String _friendlyUploadMessage(String? message) {
  final value = message?.trim();
  if (value == null || value.isEmpty) return 'Photo upload failed. Try again.';
  final lower = value.toLowerCase();
  if (lower.contains('heic') ||
      lower.contains('heif') ||
      lower.contains('format') ||
      lower.contains('content type')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  if (lower.contains('raw_') ||
      lower.contains('secret') ||
      lower.contains('exception') ||
      lower.contains('token') ||
      lower.contains('{') ||
      lower.contains('}')) {
    return 'Photo upload failed. Please try again.';
  }
  return 'Photo upload failed. Please try again.';
}

String _inferMealCategory(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('breakfast')) return 'breakfast';
  if (lower.contains('lunch')) return 'lunch';
  if (lower.contains('dinner')) return 'dinner';
  if (lower.contains('extra snack') ||
      lower.contains('extra_snack') ||
      lower.contains('extra-snack')) {
    return 'extra-snack';
  }
  if (lower.contains('snack') || lower.contains('tiffin')) return 'snack';
  return 'meal';
}

String _normalizedFoodStyle(String? value, String? customText) {
  final style = value?.trim().toLowerCase();
  if (style == 'custom' && customText?.trim().isNotEmpty == true) {
    return 'custom';
  }
  return switch (style) {
    'us' => 'us',
    'germany' => 'germany',
    'mixed' => 'mixed',
    'custom' => 'mixed',
    _ => 'india',
  };
}

String _normalizedEatingType(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'veg' => 'veg',
    'non_veg' => 'non_veg',
    _ => 'mixed',
  };
}

String _goalLabel(String value) {
  return switch (value) {
    'gain' => 'Gain',
    'lose' => 'Lose',
    'maintain' => 'Maintain',
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'snack' => 'Snack',
    'extra-snack' => 'Extra snack',
    'dinner' => 'Dinner',
    _ =>
      value
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
  };
}

String _styleLabel(String value) {
  return switch (value) {
    'us' => 'US',
    'germany' => 'Germany',
    'mixed' => 'Mixed',
    'custom' => 'Custom',
    _ => 'India',
  };
}

String _typeLabel(String value) {
  return switch (value) {
    'veg' => 'Veg',
    'non_veg' => 'Non-veg',
    _ => 'Mixed',
  };
}

String _mealTitleForDisplay(TimelineBlockDraft block) {
  final category = block.mealCategory;
  final title = block.title.trim();
  if (category != null && _looksLikeRawMealLabel(title)) {
    return _goalLabel(category);
  }
  return title.isEmpty ? _goalLabel(category ?? 'Meal') : title;
}

IconData _mealIcon(String? category) {
  return switch (category) {
    'breakfast' => Icons.wb_sunny_rounded,
    'lunch' => Icons.restaurant_rounded,
    'snack' || 'extra-snack' => Icons.local_cafe_rounded,
    'dinner' => Icons.nightlight_round,
    _ => Icons.restaurant_menu_rounded,
  };
}
