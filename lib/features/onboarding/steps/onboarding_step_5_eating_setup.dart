import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
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
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  String? _generationError;
  String? _createError;
  bool _creatingRoutine = false;
  bool _editingGeneratedRoutine = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final path = base.eatingSetupPath;
    final eatingBlocks = base.confirmedBlocksForSection('eating');
    final isChoice = base.eatingSetupStep == 0;

    if (isChoice) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          10,
          24,
          0,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: OnboardingStepShell.bottomCtaHeight + 38),
          child: const _EatingChoiceScreen(),
        ),
      );
    }

    final generatedBlocks = eatingBlocks
        .where((block) => block.source == onboardingEatingGeneratedSource)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        10,
        24,
        0,
      ),
      child: path == onboardingEatingPathHasRoutine
          ? _EatingUploadTimelineScreen(
              asset: _uploadedAsset,
              uploadError: _uploadError,
              generationError: _generationError,
              selectedDay: _selectedDay,
              blocks: eatingBlocks,
              onUpload: _startUpload,
              onRemove: _removeUploadedRoutine,
              onGenerate: _runAiExtraction,
              onDayChanged: (day) => setState(() => _selectedDay = day),
            )
          : _EatingCreateTimelineScreen(
              base: base,
              selectedDay: _selectedDay,
              blocks: generatedBlocks,
              error: _createError,
              isGenerating: _creatingRoutine,
              editing: _editingGeneratedRoutine,
              onGenerate: _generateCreatedRoutine,
              onEdit: () {
                setState(() => _editingGeneratedRoutine = true);
              },
              onDayChanged: (day) => setState(() => _selectedDay = day),
            ),
    );
  }

  Future<void> _startUpload() async {
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: UploadedAssetPurpose.eatingMenu,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );
    if (!mounted) return;

    final uploadState = ref.read(uploadControllerProvider);
    setState(() {
      _uploadedAsset = asset ?? uploadState.asset;
      _uploadError = uploadState.status == UploadFlowStatus.failed
          ? _friendlyUploadMessage(uploadState.errorMessage)
          : null;
    });
  }

  void _removeUploadedRoutine() {
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    _replaceEatingBlocks(const []);
  }

  Future<void> _runAiExtraction() async {
    if (kDebugMode) {
      debugPrint('[Onboarding5] AI mode: ${OptivusAiWorkersConfig.mode.name.toUpperCase()}');
    }
    final asset = _uploadedAsset;
    setState(() => _generationError = null);
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    if (asset == null) {
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
      'assetId=${asset.assetId} r2Key=${asset.r2Key.trim().isEmpty ? 'missing' : 'exists'} '
      'contentType=${asset.contentType}',
    );

    final now = DateTime.now();
    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
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
    if (!mounted) return;

    final aiState = ref.read(routineImportAiControllerProvider);
    debugPrint(
      '[Onboarding5] RESULT source=eating resultNull=${result == null} '
      'warnings=${result?.warnings.join('|') ?? aiState.errorMessage ?? 'none'}',
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

    _replaceEatingBlocks(blocks);
    setState(() => _generationError = null);
  }

  Future<void> _generateCreatedRoutine() async {
    if (_creatingRoutine) return;
    setState(() {
      _creatingRoutine = true;
      _createError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final bodyContext = onboarding5MealBodyContextFromDraft(draft);
    debugPrint(
      '[Onboarding5] GENERATE source=create bodyGoal=${bodyContext.bodyGoal} '
      'hasBodyBasics=${bodyContext.hasBodyBasics} heightCm=${bodyContext.heightCm ?? "missing"} '
      'weightKg=${bodyContext.currentWeightKg ?? "missing"} age=${bodyContext.age ?? "missing"} '
      'bmr=${bodyContext.estimatedBmr} maintenance=${bodyContext.estimatedMaintenanceCalories} '
      'targetCalories=${bodyContext.targetCalories}',
    );
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;
    final idToken = await ref.read(authRepositoryProvider).currentIdToken() ?? '';
    final nutritionClient = ref.read(nutritionAiClientProvider);

    try {
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
          'estimatedMaintenanceCalories': bodyContext.estimatedMaintenanceCalories,
          'targetMode': bodyContext.targetMode,
          'lifestyle': bodyContext.lifestyle,
          'country': bodyContext.country,
        },
      );

      if (!mounted) return;

      if (result.id.trim().isEmpty || result.uid != uid || result.candidates.isEmpty) {
        setState(() {
          _creatingRoutine = false;
          _createError = onboarding5FriendlyAiMessage(
            null,
            result.warnings.isNotEmpty ? result.warnings : ['no_blocks_generated'],
          );
        });
        return;
      }

      final mapped = mapOnboarding5MealCandidates(
        result.candidates,
        now: DateTime.now(),
        source: onboardingEatingGeneratedSource,
        baseTimeline: draft.baseTimeline,
      );
      final blocks = mapped.blocks;

      if (blocks.isEmpty) {
        setState(() {
          _creatingRoutine = false;
          _createError = mapped.droppedNoDishes > 0
              ? 'AI did not return specific dishes. Please try again.'
              : 'Generated routine was invalid. Please try again.';
        });
        return;
      }

      _replaceEatingBlocks(blocks);
      setState(() {
        _creatingRoutine = false;
        _editingGeneratedRoutine = false;
      });
    } on MissingConfigException catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingRoutine = false;
        _createError = onboarding5FriendlyAiMessage(e.message, const []);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingRoutine = false;
        _createError = onboarding5FriendlyAiMessage(null, ['provider_unavailable']);
      });
    }
  }

  void _replaceEatingBlocks(List<TimelineBlockDraft> eatingBlocks) {
    updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
      final nextBlocks =
          base.blocks
              .where((block) => block.section != 'eating')
              .toList(growable: true)
            ..addAll(eatingBlocks);
      final nextPending = base.pendingFutureImports
          .where((entry) => entry.section != onboardingSectionEating)
          .toList(growable: false);
      return base.copyWith(
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
  final String? uploadError;
  final String? generationError;
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final VoidCallback onGenerate;
  final ValueChanged<int> onDayChanged;

  const _EatingUploadTimelineScreen({
    required this.asset,
    required this.uploadError,
    required this.generationError,
    required this.selectedDay,
    required this.blocks,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadControllerProvider);
    final aiState = ref.watch(routineImportAiControllerProvider);
    final uploadBusy =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.eatingMenu &&
        uploadState.isBusy;
    final generating = aiState.isExtracting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EatingUploadCard(
          asset: asset,
          busy: uploadBusy || generating,
          onUpload: onUpload,
          onRemove: onRemove,
          onGenerate: asset == null || uploadBusy || generating
              ? null
              : onGenerate,
        ),

        if (generating) ...[
          const SizedBox(height: 14),
          AiThinkingCard(
            title: 'AI is reading your meal photo',
            detail: 'Looking for dishes, portions, and meal timing',
            accent: OptivusColors.roseAccent,
            isActive: generating,
          ),
        ],

        if (uploadError != null || generationError != null) ...[
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
  final bool isGenerating;
  final bool editing;
  final VoidCallback onGenerate;
  final VoidCallback onEdit;
  final ValueChanged<int> onDayChanged;

  const _EatingCreateTimelineScreen({
    required this.base,
    required this.selectedDay,
    required this.blocks,
    required this.error,
    required this.isGenerating,
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
              physics: const BouncingScrollPhysics(),
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
                                      (base) => base.copyWith(
                                        mealPlanningGoal: option.key,
                                      ),
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
                                      (base) =>
                                          base.copyWith(mealsPerDay: count),
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
                                        (base.eatingMode ?? 'india') ==
                                        option.key,
                                    accent: OptivusColors.roseAccent,
                                    onTap: () => _updateCreateDraft(
                                      ref,
                                      (base) =>
                                          base.copyWith(eatingMode: option.key),
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
                                    selected:
                                        (base.foodType ?? 'mixed') ==
                                        option.key,
                                    accent: OptivusColors.roseAccent,
                                    onTap: () => _updateCreateDraft(
                                      ref,
                                      (base) =>
                                          base.copyWith(foodType: option.key),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _CompactMealTimeRows(
                              base: base,
                              mealsPerDay: mealsPerDay,
                            ),
                            const SizedBox(height: 9),
                            _EatingGenerateRoutineButton(
                              isGenerating: isGenerating,
                              onTap: onGenerate,
                            ),
                            if (isGenerating) ...[
                              const SizedBox(height: 14),
                              AiThinkingCard(
                                title: 'AI is creating your weekly meal plan',
                                detail: 'Planning meals around your daily routine',
                                accent: OptivusColors.roseAccent,
                                isActive: isGenerating,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
        if (error != null) ...[
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
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final VoidCallback? onGenerate;

  const _EatingUploadCard({
    required this.asset,
    required this.busy,
    required this.onUpload,
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
                  child: _EatingPhotoTarget(asset: asset, onRemove: onRemove),
                ),
              ),
              const SizedBox(width: 10),
              _EatingGenerateButton(onTap: onGenerate, busy: busy),
            ],
          ),
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
  final int targetCalories;
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
        '${_goalLabel(bodyGoal)} · ${_styleLabel(style)} · ${_typeLabel(eatingType)} · $mealsPerDay meals · ~$targetCalories kcal';
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

class _EatingPhotoTarget extends StatelessWidget {
  final UploadedAsset? asset;
  final VoidCallback onRemove;

  const _EatingPhotoTarget({required this.asset, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final preview = asset?.localPreviewPath;
    final showFile = preview != null && File(preview).existsSync();

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
              child: showFile
                  ? Image.file(File(preview), fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          asset == null
                              ? Icons.add_photo_alternate_rounded
                              : Icons.image_rounded,
                          color: OptivusColors.roseAccent,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          asset == null ? 'Add photo' : 'Photo uploaded',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
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

class _EatingCustomStyleField extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _EatingCustomStyleField({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      initialValue: base.foodStyleCustomText ?? '',
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
            if (isGenerating)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
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

class _EatingTimelineSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dayBlocks =
        blocks
            .where((block) => block.repeatDays.contains(selectedDay))
            .toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Your Weekly Meal',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          _EatingDayChips(selectedDay: selectedDay, onChanged: onDayChanged),
          const SizedBox(height: 8),
          Expanded(
            child: dayBlocks.isEmpty
                ? _EatingTimelineEmptyCard(label: emptyLabel)
                : _EatingVerticalTimeline(blocks: dayBlocks),
          ),
        ],
      ),
    );
  }
}

class StretchedSegment {
  final int startMinute;
  final int endMinute;
  final double extraStretch;

  const StretchedSegment({
    required this.startMinute,
    required this.endMinute,
    required this.extraStretch,
  });
}

class EatingTimelineLayout {
  final int startMinute;
  final int endMinute;
  final double pxPerMinute;
  final double topPadding;
  final List<StretchedSegment> mergedSegments;
  final double totalExtraStretch;

  EatingTimelineLayout({
    required this.startMinute,
    required int rangeMinutes,
    required this.pxPerMinute,
    required this.topPadding,
    required List<StretchedSegment> segments,
  })  : endMinute = startMinute + rangeMinutes,
        mergedSegments = _mergeSegments(segments),
        totalExtraStretch = _calculateTotalStretch(segments);

  static List<StretchedSegment> _mergeSegments(List<StretchedSegment> segments) {
    if (segments.isEmpty) return [];
    final sorted = List<StretchedSegment>.from(segments)
      ..sort((a, b) {
        final cmp = a.startMinute.compareTo(b.startMinute);
        if (cmp != 0) return cmp;
        return a.endMinute.compareTo(b.endMinute);
      });

    final List<StretchedSegment> merged = [];
    var current = sorted[0];

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (next.startMinute <= current.endMinute) {
        final newStart = current.startMinute;
        final newEnd = math.max(current.endMinute, next.endMinute);
        final newExtraStretch = current.extraStretch + next.extraStretch;
        current = StretchedSegment(
          startMinute: newStart,
          endMinute: newEnd,
          extraStretch: newExtraStretch,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  static double _calculateTotalStretch(List<StretchedSegment> segments) {
    final merged = _mergeSegments(segments);
    return merged.fold<double>(0.0, (sum, seg) => sum + seg.extraStretch);
  }

  double yFor(num minute) {
    final double m = minute.toDouble();
    final double baseClamped = m.clamp(startMinute.toDouble(), endMinute.toDouble());
    final double normalY = topPadding + (baseClamped - startMinute) * pxPerMinute;
    
    double stretch = 0.0;
    for (final seg in mergedSegments) {
      if (m <= seg.startMinute) {
        continue;
      } else if (m >= seg.endMinute) {
        stretch += seg.extraStretch;
      } else {
        final double fraction = (m - seg.startMinute) / (seg.endMinute - seg.startMinute);
        stretch += fraction * seg.extraStretch;
      }
    }
    return normalY + stretch;
  }
}

double calculateRequiredBlockHeight({
  required BuildContext context,
  required String title,
  required List<String> dishes,
  required String timeLabel,
  required double blockWidth,
}) {
  final allDishes = dishes.map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  const double titleRowHeight = 22.0;
  const double spacingBeforeWrap = 5.0;
  const double verticalPadding = 20.0; // SafeArea padding inside block

  final List<String> labels = [timeLabel, ...allDishes];
  // Match actual layout:
  // block width - padding(12*2) - icon(17) - sizedBox(8) = blockWidth - 49.0
  final double wrapWidth = math.max(50.0, blockWidth - 49.0);
  final double wrapHeight = _calculateWrapHeight(context, labels, wrapWidth, 6.0, 5.0);
  
  // Padding(8*2) + title(22 approx) + spacing(5) + buffer(10)
  final double estimatedHeight = verticalPadding + titleRowHeight + spacingBeforeWrap + wrapHeight + 10.0;
  // Increase cap to 450 to ensure 6-dish tests pass without overflow
  return math.min(450.0, math.max(74.0, estimatedHeight));
}

double _calculateWrapHeight(
  BuildContext context,
  List<String> labels,
  double wrapWidth,
  double spacing,
  double runSpacing,
) {
  if (labels.isEmpty) return 0.0;
  final TextScaler textScaler = MediaQuery.textScalerOf(context);
  final TextDirection textDirection = Directionality.of(context);
  double currentX = 0.0;
  double currentY = 0.0;
  double rowHeight = 0.0;

  for (int i = 0; i < labels.length; i++) {
    final label = labels[i];
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: math.max(10.0, wrapWidth - 16.0));
    
    final double chipWidth = textPainter.width + 16.0;
    final double chipHeight = textPainter.height + 8.0;

    if (currentX == 0) {
      currentX = chipWidth;
      rowHeight = chipHeight;
    } else {
      if (currentX + spacing + chipWidth <= wrapWidth) {
        currentX += spacing + chipWidth;
        rowHeight = math.max(rowHeight, chipHeight);
      } else {
        currentY += rowHeight + runSpacing;
        currentX = chipWidth;
        rowHeight = chipHeight;
      }
    }
  }
  return currentY + rowHeight;
}

class _EatingVerticalTimeline extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _EatingVerticalTimeline({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final minStart = blocks.map((block) => block.startMinute).reduce(math.min);
    final maxEnd = blocks.map((block) => block.endMinute).reduce(math.max);
    final startMinute = math.max(5 * 60, ((minStart - 45) ~/ 60) * 60);
    final endMinute = math.min(24 * 60, (((maxEnd + 75) / 60).ceil()) * 60);
    final rangeMinutes = math.max(180, endMinute - startMinute);
    const topPadding = 18.0;
    const bottomPadding = OnboardingStepShell.bottomCtaHeight + 40;
    const pxPerMinute = 0.82;

    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = constraints.maxWidth - 64 - 16;

        final List<StretchedSegment> segments = [];
        for (final block in blocks) {
          final normalHeight = (block.endMinute - block.startMinute) * pxPerMinute;
          final requiredHeight = calculateRequiredBlockHeight(
            context: context,
            title: _mealTitleForDisplay(block),
            dishes: block.dishes,
            timeLabel: '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
            blockWidth: blockWidth,
          );
          if (requiredHeight > normalHeight) {
            segments.add(StretchedSegment(
              startMinute: block.startMinute,
              endMinute: block.endMinute,
              extraStretch: requiredHeight - normalHeight,
            ));
          }
        }

        final layout = EatingTimelineLayout(
          startMinute: startMinute,
          rangeMinutes: rangeMinutes,
          pxPerMinute: pxPerMinute,
          topPadding: topPadding,
          segments: segments,
        );

        final timelineHeight = rangeMinutes * pxPerMinute + topPadding + bottomPadding + layout.totalExtraStretch;

        return Container(
          key: const ValueKey('onboarding-step5-timeline'),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.40),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.80),
                width: 1.5,
              ),
            ),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.045, 0.95, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              key: const ValueKey('onboarding-step5-timeline-scroll'),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: bottomPadding),
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
                          color: OptivusColors.roseAccent.withValues(alpha: 0.17),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: OptivusColors.roseAccent.withValues(alpha: 0.36),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: OptivusColors.roseAccent.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final minute in _mealBoundaryMinutes(
                      blocks,
                      startMinute,
                      endMinute,
                    ))
                      _EatingMinuteIndicator(minute: minute, top: layout.yFor(minute)),
                    for (
                      var minute = startMinute;
                      minute <= endMinute;
                      minute += 60
                    )
                      _EatingTimelineTick(minute: minute, top: layout.yFor(minute)),
                    for (final block in blocks)
                      _EatingTimelineBlock(
                        block: block,
                        top: layout.yFor(block.startMinute),
                        height: layout.yFor(block.endMinute) - layout.yFor(block.startMinute),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EatingTimelineTick extends StatelessWidget {
  final int minute;
  final double top;

  const _EatingTimelineTick({required this.minute, required this.top});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top - 10,
      left: 0,
      width: 56,
      height: 20,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            width: 42,
            child: Text(
              _shortTimeLabel(minute),
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
                color: OptivusColors.roseAccent.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingMinuteIndicator extends StatelessWidget {
  final int minute;
  final double top;

  const _EatingMinuteIndicator({required this.minute, required this.top});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: top - 8,
          left: 0,
          width: 38,
          height: 16,
          child: Text(
            _compactMinuteLabel(minute),
            textAlign: TextAlign.right,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: OptivusColors.roseAccent.withValues(alpha: 0.68),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: 64,
          right: 16,
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OptivusColors.roseAccent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: top,
          left: 44,
          width: 18,
          height: 1.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OptivusColors.roseAccent.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
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
                Icon(_mealIcon(block.mealCategory), color: OptivusColors.roseAccent),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: OptivusColors.roseAccent.withValues(alpha: 0.1),
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

class _EatingTimelineBlock extends StatelessWidget {
  final TimelineBlockDraft block;
  final double top;
  final double height;

  const _EatingTimelineBlock({
    required this.block,
    required this.top,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final allDishes = block.dishes
        .map((dish) => dish.trim())
        .where((dish) => dish.isNotEmpty)
        .toList();

    return Positioned(
      top: top,
      left: 64,
      right: 16,
      height: height,
      child: GestureDetector(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                          Text(
                            _mealTitleForDisplay(block),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final textScaler = MediaQuery.textScalerOf(context);
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
                                  final textPainter = TextPainter(
                                    text: TextSpan(
                                      text: label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    textDirection: textDirection,
                                    textScaler: textScaler,
                                  )..layout(maxWidth: math.max(10.0, wrapWidth - 16.0));

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
                                      nextRowHeight = math.max(rowHeight, chipHeight);
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
                                  final int toShow = math.max(1, visibleCount - 1);
                                  for (int i = 0; i < toShow; i++) {
                                    children.add(_EatingInfoChip(labels[i]));
                                  }
                                  final remaining = labels.length - toShow;
                                  children.add(
                                    GestureDetector(
                                      onTap: () => _showEatingBlockDetails(context, block),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: OptivusColors.roseAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: OptivusColors.roseAccent.withValues(alpha: 0.5)),
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
                                    children.add(_EatingInfoChip(label));
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
      ),
    );
  }
}

class _EatingInfoChip extends StatelessWidget {
  final String label;

  const _EatingInfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textBody,
        ),
      ),
    );
  }
}

class _EatingDayChips extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onChanged;

  const _EatingDayChips({required this.selectedDay, required this.onChanged});

  static const _labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < _labels.length; index++)
              SizedBox(
                width: 50,
                height: 42,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(index + 1),
                  child: _EatingDayChip(
                    label: _labels[index],
                    selected: selectedDay == index + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EatingDayChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _EatingDayChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final size = selected ? 40.0 : 35.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (selected ? OptivusColors.roseAccent : Colors.black)
                  .withValues(alpha: selected ? 0.07 : 0.035),
              blurRadius: selected ? 5 : 7,
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
                    ? OptivusColors.roseAccent.withValues(alpha: 0.68)
                    : Colors.white.withValues(alpha: 0.38),
                border: Border.all(
                  color: selected
                      ? OptivusColors.roseAccent.withValues(alpha: 0.42)
                      : Colors.white.withValues(alpha: 0.72),
                  width: selected ? 1.8 : 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: selected ? 12 : 10,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? Colors.white
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EatingTimelineEmptyCard extends StatelessWidget {
  final String label;

  const _EatingTimelineEmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 110),
          child: OnboardingGlassCard(
            tint: Colors.white.withValues(alpha: 0.30),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            radius: 20,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
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
  final int estimatedBmr;
  final int estimatedMaintenanceCalories;
  final int targetCalories;
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
  final safeWeight = weight != null && weight > 0 ? weight : 70.0;
  final safeHeight = height != null && height > 0 ? height : 170.0;
  final safeAge = age ?? 25;
  final bmr = _estimateBmr(
    weightKg: safeWeight,
    heightCm: safeHeight,
    age: safeAge,
    gender: body.gender,
  );
  final maintenance = body.calorieEstimate != null && body.calorieEstimate! > 0
      ? body.calorieEstimate!.round()
      : (bmr * _activityFactorForLifeRole(draft.lifeRole)).round();
  final target = _targetCalories(
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
  return mapOnboarding5MealCandidates(candidates, now: now, baseTimeline: null).blocks;
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
      } else if (mealCategory == 'extra-snack' && baseTimeline.extraSnackMinute != null) {
        overrideStart = baseTimeline.extraSnackMinute;
        overrideEnd = overrideStart! + 20;
      } else if (mealCategory == 'dinner' && baseTimeline.dinnerMinute != null) {
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
  return Onboarding5MealCandidateMappingResult(
    blocks: blocks,
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
  dishes.addAll(
    candidate.steps.map((s) => s.trim()).where((s) => s.isNotEmpty),
  );

  void extractFromRawText(String? text) {
    if (text == null || text.trim().isEmpty) return;
    final withoutMealWords = text
        .replaceAll(
          RegExp(r'\b(Breakfast|Lunch|Brunch|Supper|Snacks?|Dinner)\b', caseSensitive: false),
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
        .replaceAll(RegExp(r'\d{1,2}\s*(AM|PM)', caseSensitive: false), ' ');
    final items = withoutMealWords
        .split(RegExp(r'[,;\n|•·]+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2);
    dishes.addAll(items);
  }

  extractFromRawText(candidate.sourceTextSnippet);
  extractFromRawText(candidate.notes);
  extractFromRawText(candidate.sourceColumnLabel);
  extractFromRawText(candidate.title);

  return dishes.toList();
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
  
  if (text.contains('worker is not configured') || text.contains('worker url') || text.contains('missing_worker_url')) {
    return 'Real AI is not configured. Missing nutrition worker URL.';
  }
  if (text.contains('network_unavailable') || text.contains('provider_unavailable') || text.contains('provider_timeout')) {
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
  if (text.contains('provider_empty_candidates') || text.contains('no_blocks_generated')) {
    return 'AI could not read meals clearly. Try a clearer photo.';
  }
  if (text.contains('too large') || text.contains('image too large')) {
    return 'Meal photo is too large. Upload a smaller, clearer photo.';
  }
  if (text.contains('not found') || text.contains('r2_image_missing')) {
    return 'Uploaded meal photo could not be found. Please upload again.';
  }
  if (text.contains('unauthorized') || text.contains('invalid key') || text.contains('invalid_api_key')) {
    return 'AI key is invalid or unauthorized.';
  }
  if (text.contains('invalid structured') ||
      text.contains('could not be read safely') || text.contains('provider_invalid_json')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (messages.isNotEmpty && !messages.first.startsWith('provider_')) {
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
  return value;
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

String _shortTimeLabel(int minute) {
  final hour = (minute ~/ 60) % 24;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$display $suffix';
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

List<int> _mealBoundaryMinutes(
  List<TimelineBlockDraft> blocks,
  int startMinute,
  int endMinute,
) {
  final minutes =
      <int>{
          for (final block in blocks) ...[block.startMinute, block.endMinute],
        }.where((minute) {
          return minute % 60 != 0 && minute > startMinute && minute < endMinute;
        }).toList()
        ..sort();
  return minutes;
}

String _compactMinuteLabel(int minute) {
  final safe = minute.clamp(0, 24 * 60).toInt();
  final hour = safe ~/ 60;
  final m = safe % 60;
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final suffix = hour >= 12 ? 'p' : 'a';
  return '$displayHour:${m.toString().padLeft(2, '0')}$suffix';
}


