import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/eating_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/eating_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_save_success_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_import_review_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_meal_edit_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_settings_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_source_selection_view.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/state/app_state.dart';

/// Host coordinator screen for Base Timeline Eating setup.
///
/// Refactored to delegate state mutations and transactions to
/// [EatingSetupController], presenting clean subviews for:
/// - Current Setup ([EatingCurrentSetupView])
/// - Source Selection ([EatingSourceSelectionView])
/// - Review & Edit ([EatingReviewView])
/// - AI & Upload Progress ([BaseTimelineAiThinkingView])
/// - Save Confirmation ([BaseTimelineSaveSuccessView])
class EatingBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const EatingBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<EatingBaseSetupScreen> createState() =>
      _EatingBaseSetupScreenState();
}

class _EatingBaseSetupScreenState extends ConsumerState<EatingBaseSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final setup = ref.read(baseTimelineSetupNotifierProvider).valueOrNull;
      if (setup != null) {
        final uid = ref.read(userProfileProvider).uid;
        ref
            .read(eatingSetupControllerProvider.notifier)
            .performStartupCleanup(setup, uid: uid);
        ref.read(eatingSetupControllerProvider.notifier).initDayIfNeeded(setup);
      }
    });
  }

  Future<bool> _confirmDiscard(EatingSetupState state) async {
    final hasUnsavedPhoto =
        (state.workingAssetId != null &&
            state.workingAssetId != state.baseCommittedAssetId) ||
        (state.candidateAssetId != null &&
            state.candidateAssetId != state.baseCommittedAssetId);
    if (!state.isDirty && !hasUnsavedPhoto) {
      return true;
    }
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Any unsaved eating schedule edits will be lost.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _handleEatingBack(
    BaseTimelineSetup? setup,
    EatingSetupState state,
    String uid,
  ) async {
    final controller = ref.read(eatingSetupControllerProvider.notifier);

    if (state.stage == EatingSetupStage.saving ||
        state.stage == EatingSetupStage.saveSuccess) {
      return;
    }

    if (state.stage == EatingSetupStage.uploading ||
        state.stage == EatingSetupStage.extracting ||
        state.stage == EatingSetupStage.generating) {
      await controller.cancelCurrentOperation(setup, uid: uid);
      return;
    }

    if (state.stage == EatingSetupStage.chooseSource) {
      final snapshot = setup?.snapshotFor(BaseTimelineSection.eating);
      if (snapshot != null && snapshot.isConfigured) {
        controller.cancelChooseSource();
      } else {
        widget.onBack();
      }
      return;
    }

    if (state.stage == EatingSetupStage.error) {
      if (state.workingBlocks.isNotEmpty) {
        controller.keepPreviousDraft(setup, uid: uid);
      } else {
        await controller.resetWorkingDraft(setup, uid: uid);
      }
      return;
    }

    if (state.stage == EatingSetupStage.review ||
        state.stage == EatingSetupStage.editingBlock) {
      final canDiscard = await _confirmDiscard(state);
      if (!canDiscard || !mounted) return;
      final snapshot = setup?.snapshotFor(BaseTimelineSection.eating);
      if (snapshot != null && snapshot.isConfigured) {
        await controller.resetWorkingDraft(setup, uid: uid);
      } else {
        await controller.resetWorkingDraft(setup, uid: uid);
        widget.onBack();
      }
      return;
    }

    if (state.stage == EatingSetupStage.currentSetup) {
      widget.onBack();
    }
  }

  void _showPhotoSourceSheet(String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndExtractPhoto(uid: uid, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndExtractPhoto(uid: uid, source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndExtractPhoto({
    required String uid,
    required ImageSource source,
  }) async {
    final controller = ref.read(eatingSetupControllerProvider.notifier);
    final candidates = await controller.pickAndUploadPhoto(
      uid: uid,
      source: source,
    );

    if (!mounted || candidates == null || candidates.isEmpty) return;

    final candidateAssetId = ref
        .read(eatingSetupControllerProvider)
        .candidateAssetId;
    final candidateR2Key = ref
        .read(eatingSetupControllerProvider)
        .candidateR2Key;

    final reviewed = await EatingImportReviewSheet.show(
      context,
      candidates: candidates,
    );

    if (!mounted) return;

    await controller.applyReviewedCandidates(
      uid: uid,
      reviewed: reviewed,
      candidateAssetId: candidateAssetId,
      candidateR2Key: candidateR2Key,
    );
  }

  Future<void> _openPlanSettingsSheet({bool isBuildingNew = false}) async {
    final state = ref.read(eatingSetupControllerProvider);
    final controller = ref.read(eatingSetupControllerProvider.notifier);
    final isNew = isBuildingNew || state.workingBlocks.isEmpty;
    final engine = ref.read(eatingDomainEngineProvider);
    final profile = ref.read(userProfileProvider);
    final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
    final currentSetup =
        setupAsync.value ??
        BaseTimelineSetup(uid: profile.uid, updatedAt: DateTime.now());

    NutritionTargets? calculatedTargets;
    try {
      calculatedTargets = engine.calculateTargets(
        profile: profile,
        setup: currentSetup.copyWith(
          mealPlanningGoal: state.workingGoal,
          mealsPerDay: state.workingMealsPerDay,
          breakfastMinute: state.workingBreakfastMinute,
          lunchMinute: state.workingLunchMinute,
          dinnerMinute: state.workingDinnerMinute,
          snackMinute: state.workingSnackMinute,
          extraSnackMinute: state.workingExtraSnackMinute,
        ),
      );
    } catch (_) {}

    final result = await EatingPlanSettingsSheet.show(
      context,
      title: isNew ? 'Build Balanced Meal Plan' : 'Plan Settings & Preferences',
      regenerateActionLabel: isNew
          ? 'Generate Balanced Plan'
          : 'Regenerate Plan',
      isNew: isNew,
      initialGoal: state.workingGoal,
      initialMealsPerDay: state.workingMealsPerDay,
      initialEatingMode: state.workingEatingMode,
      initialFoodType: state.workingFoodType,
      initialFoodStyleCustomText: state.workingFoodStyleCustomText,
      initialFoodsToAvoid: state.workingFoodsToAvoid,
      initialBreakfastMinute: state.workingBreakfastMinute,
      initialLunchMinute: state.workingLunchMinute,
      initialDinnerMinute: state.workingDinnerMinute,
      initialSnackMinute: state.workingSnackMinute,
      initialExtraSnackMinute: state.workingExtraSnackMinute,
      initialTargetCalories: state.workingTargetCalories,
      initialTargetProtein: state.workingTargetProtein,
      initialTargetCaloriesOverride: state.workingTargetCaloriesOverride,
      initialTargetProteinOverride: state.workingTargetProteinOverride,
      calculatedCalories: calculatedTargets?.targetCalories,
      calculatedProtein: calculatedTargets?.proteinTarget?.round(),
      showRegenerateAction: true,
    );

    if (result == null || !mounted) return;

    controller.updateSettingsParameters(
      goal: result.goal,
      mealsPerDay: result.mealsPerDay,
      eatingMode: result.eatingMode,
      foodType: result.foodType,
      foodStyleCustomText: result.foodStyleCustomText,
      foodsToAvoid: result.foodsToAvoid,
      breakfastMinute: result.breakfastMinute,
      lunchMinute: result.lunchMinute,
      dinnerMinute: result.dinnerMinute,
      snackMinute: result.snackMinute,
      extraSnackMinute: result.extraSnackMinute,
      targetCalories: result.targetCalories,
      targetProtein: result.targetProtein,
      targetCaloriesOverride: result.targetCaloriesOverride,
      targetProteinOverride: result.targetProteinOverride,
    );

    if (result.shouldRegenerate) {
      await _runBalancedPlanGeneration(uid: profile.uid, setup: currentSetup);
    }
  }

  Future<void> _runBalancedPlanGeneration({
    required String uid,
    required BaseTimelineSetup setup,
  }) async {
    final controller = ref.read(eatingSetupControllerProvider.notifier);
    final success = await controller.generateBalancedPlan(
      uid: uid,
      currentSetup: setup,
    );

    if (!success && mounted) {
      final err =
          ref.read(eatingSetupControllerProvider).errorMessage ??
          'Failed to generate meal plan.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          action: SnackBarAction(
            label: 'Retry',
            textColor: OptivusColors.roseAccent,
            onPressed: () => _runBalancedPlanGeneration(uid: uid, setup: setup),
          ),
        ),
      );
    }
  }

  void _addMealBlock() {
    final state = ref.read(eatingSetupControllerProvider);
    final controller = ref.read(eatingSetupControllerProvider.notifier);
    final newBlock = TimelineBlockDraft(
      id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      startMinute: 12 * 60,
      endMinute: 12 * 60 + 30,
      repeatDays: [state.selectedDay],
      section: 'eating',
      blockType: TimelineBlockDraft.softBlockKey,
      dishes: const [],
    );

    EatingMealEditSheet.show(
      context: context,
      block: newBlock,
      onSave: (updated) async {
        controller.addBlock(updated);
        return true;
      },
    );
  }

  void _editMealBlock(TimelineBlockDraft block) {
    final controller = ref.read(eatingSetupControllerProvider.notifier);
    EatingMealEditSheet.show(
      context: context,
      block: block,
      onSave: (updated) async {
        controller.updateBlock(updated);
        return true;
      },
      onDelete: () => controller.deleteBlock(block.id),
    );
  }

  Future<void> _handleRemoveSetup(BaseTimelineSetup setup, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Eating Plan?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will delete your current eating schedule and clear your meal plan setup. This action cannot be undone.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final controller = ref.read(eatingSetupControllerProvider.notifier);
    final success = await controller.removeSetup(uid: uid, currentSetup: setup);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eating plan removed.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPhotoViewer(String r2Key, String? assetId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: r2Key,
                assetId: assetId,
                title: 'Meal Plan Photo',
                height: MediaQuery.sizeOf(context).height * 0.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCancelBar({required VoidCallback onCancel, String? title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(
              Icons.close_rounded,
              color: OptivusColors.textPrimary,
            ),
            onPressed: onCancel,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OptivusRadii.md),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);
    final state = ref.watch(eatingSetupControllerProvider);
    final controller = ref.read(eatingSetupControllerProvider.notifier);
    final uid = ref.watch(userProfileProvider).uid;

    ref.listen<AsyncValue<BaseTimelineSetup>>(
      baseTimelineSetupNotifierProvider,
      (prev, next) {
        final setup = next.valueOrNull;
        if (setup != null) {
          controller.performStartupCleanup(setup, uid: uid);
          controller.initDayIfNeeded(setup);
        }
      },
    );

    if (setupAsync.isLoading && !setupAsync.hasValue) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (setupAsync.hasError && !setupAsync.hasValue) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Failed to load setup',
                style: TextStyle(color: OptivusColors.textPrimary),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(baseTimelineSetupNotifierProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final setup = setupAsync.valueOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleEatingBack(setup, state, uid);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(
          builder: (context) {
            final disableAnimations =
                MediaQuery.maybeDisableAnimationsOf(context) ?? false;
            final isTest = WidgetsBinding.instance.runtimeType
                .toString()
                .contains('Test');
            final transitionDuration = (disableAnimations || isTest)
                ? Duration.zero
                : const Duration(milliseconds: 250);

            return AnimatedSwitcher(
              duration: transitionDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _buildStageContent(context, state, setup, uid),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageContent(
    BuildContext context,
    EatingSetupState state,
    BaseTimelineSetup? setup,
    String uid,
  ) {
    final controller = ref.read(eatingSetupControllerProvider.notifier);

    // AI & Upload progress stages
    if (state.stage == EatingSetupStage.uploading ||
        state.stage == EatingSetupStage.extracting ||
        state.stage == EatingSetupStage.generating) {
      return SafeArea(
        child: BaseTimelineAiThinkingView(
          key: const ValueKey('eating-ai-thinking'),
          initialMessage: state.aiActionTitle,
          progressMessages: state.aiProgressMessages,
          onCancel: () => controller.cancelCurrentOperation(setup, uid: uid),
        ),
      );
    }

    // Save success celebration stage
    if (state.stage == EatingSetupStage.saveSuccess) {
      return BaseTimelineSaveSuccessView(
        key: const ValueKey('eating-save-success'),
        title: 'Eating schedule updated successfully',
        subtitle: state.routineRefreshPending
            ? 'Setup saved. Routine projection update pending.'
            : 'Your meal plan has been saved to your Base Timeline.',
        accent: OptivusColors.roseAccent,
        onComplete: () => controller.reloadFromCanonical(
          setup ?? BaseTimelineSetup(uid: uid, updatedAt: DateTime.now()),
        ),
      );
    }

    // Error stage
    if (state.stage == EatingSetupStage.error) {
      return _buildErrorView(setup, state, uid);
    }

    // Source selection stage
    if (state.stage == EatingSetupStage.chooseSource) {
      return SafeArea(
        key: const ValueKey('eating-choose-source'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopCancelBar(
              onCancel: () => controller.cancelChooseSource(),
              title: 'Change Eating Source',
            ),
            Expanded(
              child: EatingSourceSelectionView(
                errorMessage: state.errorMessage,
                onClearError: () => controller.clearError(),
                onBuildPersonalized: () {
                  if (setup != null) controller.editCurrentMealPlan(setup);
                  _openPlanSettingsSheet(isBuildingNew: true);
                },
                onImportPhoto: () {
                  if (setup != null) controller.editCurrentMealPlan(setup);
                  _showPhotoSourceSheet(uid);
                },
                onCreateManually: () {
                  if (setup != null) {
                    controller.startManualSetup(setup);
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    // Review & editing block stage
    if (state.stage == EatingSetupStage.review ||
        state.stage == EatingSetupStage.editingBlock) {
      final isNew =
          setup == null ||
          !setup.snapshotFor(BaseTimelineSection.eating).isConfigured;
      return EatingReviewView(
        key: const ValueKey('eating-review'),
        workingBlocks: state.workingBlocks,
        workingAssetId: state.workingAssetId,
        workingR2Key: state.workingR2Key,
        workingSetupPath: state.workingSetupPath,
        workingCustomized: state.workingCustomized,
        targetCalories: state.workingTargetCalories,
        targetProtein: state.workingTargetProtein,
        selectedDay: state.selectedDay,
        onDayChanged: (d) => controller.selectDay(d),
        errorMessage: state.errorMessage,
        onClearError: () => controller.clearError(),
        isSaving: state.isSaving,
        onCancel: () => _handleEatingBack(setup, state, uid),
        onAddMeal: _addMealBlock,
        onEditBlock: _editMealBlock,
        onSave: () async {
          final effectiveSetup =
              setup ?? BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
          await controller.saveWorkingSetup(
            uid: uid,
            currentSetup: effectiveSetup,
          );
        },
        onOpenSettings: () => _openPlanSettingsSheet(isBuildingNew: false),
        onChangePhoto: () => _showPhotoSourceSheet(uid),
        frontBlockId: state.frontBlockId,
        onFrontSelected: (id) => controller.setFrontBlockId(id),
        isNew: isNew,
      );
    }

    // Default Current Setup stage
    if (setup == null ||
        !setup.snapshotFor(BaseTimelineSection.eating).isConfigured) {
      // Unconfigured state shows initial Source Selection with Back button
      return SafeArea(
        key: const ValueKey('eating-unconfigured'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: OptivusColors.textPrimary,
                    ),
                    onPressed: widget.onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eating',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Choose how to set up your meal plan',
                          style: TextStyle(
                            fontSize: 12,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EatingSourceSelectionView(
                errorMessage: state.errorMessage,
                onClearError: () => controller.clearError(),
                onBuildPersonalized: () {
                  if (setup != null) controller.editCurrentMealPlan(setup);
                  _openPlanSettingsSheet(isBuildingNew: true);
                },
                onImportPhoto: () {
                  if (setup != null) controller.editCurrentMealPlan(setup);
                  _showPhotoSourceSheet(uid);
                },
                onCreateManually: () {
                  final effectiveSetup =
                      setup ??
                      BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
                  controller.startManualSetup(effectiveSetup);
                },
              ),
            ),
          ],
        ),
      );
    }

    return EatingCurrentSetupView(
      key: const ValueKey('eating-current-setup'),
      setup: setup,
      selectedDay: state.selectedDay,
      onDayChanged: (d) => controller.selectDay(d),
      onBack: widget.onBack,
      onEditSchedule: () => controller.editCurrentMealPlan(setup),
      onChangeSource: () => controller.startChooseSource(),
      onRemoveSetup: () => _handleRemoveSetup(setup, uid),
      onOpenSettings: () {
        controller.editCurrentMealPlan(setup);
        _openPlanSettingsSheet(isBuildingNew: false);
      },
      onRegenerate: () {
        controller.editCurrentMealPlan(setup);
        _openPlanSettingsSheet(isBuildingNew: false);
      },
      onViewPhoto: _showPhotoViewer,
      routineRefreshPending: state.routineRefreshPending,
      routineRefreshMessage: state.routineRefreshMessage,
      onRetryRefresh: () async {
        final result = await ref
            .read(baseTimelineTransactionCoordinatorProvider)
            .retryRoutineRefresh(
              uid: uid,
              targetRevision: state.committedRevision,
            );
        if (mounted && result.isRefreshed) {
          controller.reloadFromCanonical(setup);
        }
      },
    );
  }

  Widget _buildErrorView(
    BaseTimelineSetup? setup,
    EatingSetupState state,
    String uid,
  ) {
    final controller = ref.read(eatingSetupControllerProvider.notifier);

    return SafeArea(
      key: const ValueKey('eating-error-stage'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: OnboardingGlassCard(
              radius: OptivusRadii.surfaceLarge,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: OptivusColors.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        OptivusRadii.controlCompact,
                      ),
                      border: Border.all(
                        color: OptivusColors.danger.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: OptivusColors.danger,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Meal Plan Processing Issue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ??
                        'An error occurred while building your meal plan.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OptivusColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (state.workingBlocks.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: OptivusColors.roseAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              OptivusRadii.controlCompact,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () =>
                            controller.keepPreviousDraft(setup, uid: uid),
                        child: const Text(
                          'Review Current Draft',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OptivusColors.textPrimary,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            OptivusRadii.controlCompact,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _handleEatingBack(setup, state, uid),
                      child: const Text('Back to Setup'),
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
