import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/work_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';

/// Host coordinator screen for Base Timeline Work / Business setup.
class WorkBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const WorkBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<WorkBaseSetupScreen> createState() =>
      _WorkBaseSetupScreenState();
}

class _WorkBaseSetupScreenState extends ConsumerState<WorkBaseSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final setup = ref.read(baseTimelineSetupNotifierProvider).valueOrNull;
      if (setup != null) {
        final uid = ref.read(userProfileProvider).uid;
        ref
            .read(workSetupControllerProvider.notifier)
            .performStartupCleanup(setup, uid: uid);
        ref.read(workSetupControllerProvider.notifier).initDayIfNeeded(setup);
      }
    });
  }

  Future<bool> _confirmDiscard(WorkSetupState state) async {
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
          'Discard this setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          WorkPresentationUtils.discardDialogContent(
            ref.read(userProfileProvider).lifeRole,
          ),
          style: const TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
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

  Future<void> _handleWorkBack(
    BaseTimelineSetup? setup,
    WorkSetupState state,
    String uid,
  ) async {
    final controller = ref.read(workSetupControllerProvider.notifier);

    if (state.stage == WorkSetupStage.saving ||
        state.stage == WorkSetupStage.saveSuccess) {
      return;
    }

    if (state.stage == WorkSetupStage.uploading ||
        state.stage == WorkSetupStage.extracting) {
      await controller.cancelCurrentExtraction(setup, uid: uid);
      return;
    }

    if (state.stage == WorkSetupStage.chooseSource) {
      controller.cancelChooseSource();
      return;
    }

    if (state.stage == WorkSetupStage.error) {
      if (state.workingBlocks.isNotEmpty) {
        controller.keepPreviousDraft(setup, uid: uid);
      } else {
        await controller.resetWorkingDraft(setup, uid: uid);
      }
      return;
    }

    if (state.stage == WorkSetupStage.review ||
        state.stage == WorkSetupStage.editingBlock) {
      final canDiscard = await _confirmDiscard(state);
      if (!canDiscard || !mounted) return;
      await controller.resetWorkingDraft(setup, uid: uid);
      return;
    }

    if (state.stage == WorkSetupStage.currentSetup) {
      widget.onBack();
    }
  }

  Future<void> _addNewBlock(int selectedDay) async {
    final controller = ref.read(workSetupControllerProvider.notifier);
    final profile = ref.read(userProfileProvider);
    final lifeRole = profile.lifeRole;
    final defaultContext = WorkPresentationUtils.defaultContextForProfile(
      lifeRole,
    );
    final defaultMode = WorkPresentationUtils.defaultModeForProfile(
      profile.workingExtra,
    );
    final defaultKind = WorkPresentationUtils.defaultBlockKindForProfile(
      profile.workingExtra,
    );

    final newBlock = TimelineBlockDraft(
      id: 'work_${DateTime.now().millisecondsSinceEpoch}',
      section: 'work',
      title: '',
      startMinute: 9 * 60,
      endMinute: 17 * 60,
      repeatDays: [selectedDay],
      blockType: TimelineBlockDraft.hardBlockKey,
      workContextType: defaultContext,
      workMode: defaultMode,
      workBlockKind: defaultKind,
    );

    controller.startEditingBlock();
    await BaseTimelineWorkAdapter.showEditSheet(
      context: context,
      block: newBlock,
      accent: OptivusColors.warning,
      lifeRole: lifeRole,
      isNew: true,
      onSave: (updated) async {
        controller.addBlock(updated);
        return true;
      },
    );
    if (mounted) {
      controller.stopEditingBlock();
    }
  }

  Future<void> _editBlock(TimelineBlockDraft block) async {
    final controller = ref.read(workSetupControllerProvider.notifier);
    final profile = ref.read(userProfileProvider);
    controller.startEditingBlock();
    await BaseTimelineWorkAdapter.showEditSheet(
      context: context,
      block: block,
      accent: OptivusColors.warning,
      lifeRole: profile.lifeRole,
      isNew: false,
      onSave: (updated) async {
        controller.updateBlock(updated);
        return true;
      },
      onDelete: (toDelete) async {
        controller.deleteBlock(toDelete.id);
        return true;
      },
    );
    if (mounted) {
      controller.stopEditingBlock();
    }
  }

  void _showScanAgainSheet(String uid) {
    final controller = ref.read(workSetupControllerProvider.notifier);
    final lifeRole = ref.read(userProfileProvider).lifeRole;
    final sheetTitle = WorkPresentationUtils.scanSheetTitle(lifeRole);
    showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sheetTitle,
                style: const TextStyle(
                  color: OptivusColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: OptivusColors.aquaAccent,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.pickAndUploadPhoto(
                    uid: uid,
                    source: ImageSource.gallery,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: OptivusColors.warning,
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.pickAndUploadPhoto(
                    uid: uid,
                    source: ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRemoveWorkSetup(
    BaseTimelineSetup setup,
    String uid,
  ) async {
    final lifeRole = ref.read(userProfileProvider).lifeRole;
    final dialogTitle = WorkPresentationUtils.removeSetupConfirmTitle(lifeRole);
    final dialogContent = WorkPresentationUtils.removeSetupConfirmContent(
      lifeRole,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          dialogTitle,
          style: const TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          dialogContent,
          style: const TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('work-confirm-remove-button'),
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

    final controller = ref.read(workSetupControllerProvider.notifier);
    final outcome = await controller.removeSetup(uid: uid, setup: setup);

    if (mounted) {
      if (outcome.isSuccessful) {
        final successMsg = WorkPresentationUtils.removeSuccessMessage(
          refreshPending:
              outcome.status == WorkRemoveOutcomeStatus.refreshPending,
          lifeRole: lifeRole,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.message ??
                  WorkPresentationUtils.removeFailureMessage(lifeRole),
            ),
            backgroundColor: OptivusColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);
    final state = ref.watch(workSetupControllerProvider);
    final controller = ref.read(workSetupControllerProvider.notifier);
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

    if (state.stage == WorkSetupStage.currentSetup) {
      if (setupAsync.isLoading && !setupAsync.hasValue) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            widget.onBack();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildCurrentSetupSkeletonView(),
          ),
        );
      }

      if (setupAsync.hasError && !setupAsync.hasValue) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            widget.onBack();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildCurrentSetupLoadErrorView(setupAsync.error),
          ),
        );
      }
    }

    final setup = setupAsync.valueOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleWorkBack(setup, state, uid);
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
              child: KeyedSubtree(
                key: ValueKey(state.stage),
                child: _buildStageContent(setup, state, uid),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageContent(
    BaseTimelineSetup? setup,
    WorkSetupState state,
    String uid,
  ) {
    final controller = ref.read(workSetupControllerProvider.notifier);
    final profile = ref.watch(userProfileProvider);
    final lifeRole = profile.lifeRole;

    switch (state.stage) {
      case WorkSetupStage.uploading:
        return SafeArea(
          child: Column(
            children: [
              _buildTopCancelBar(
                onCancel: () => _handleWorkBack(setup, state, uid),
                title: WorkPresentationUtils.uploadingTitle(lifeRole),
              ),
              Expanded(
                child: BaseTimelineUploadView(
                  localPreviewPath: state.workingLocalPreviewPath,
                ),
              ),
            ],
          ),
        );

      case WorkSetupStage.extracting:
        return SafeArea(
          child: Column(
            children: [
              _buildTopCancelBar(
                onCancel: () => _handleWorkBack(setup, state, uid),
                title: WorkPresentationUtils.extractionTitle(lifeRole),
              ),
              Expanded(
                child: BaseTimelineAiThinkingView(
                  initialMessage:
                      WorkPresentationUtils.extractionInitialMessage(lifeRole),
                  progressMessages:
                      WorkPresentationUtils.extractionProgressMessages(
                        lifeRole,
                      ),
                  localPreviewPath: state.workingLocalPreviewPath,
                  assetId: state.candidateAssetId,
                  r2Key: state.candidateR2Key,
                ),
              ),
            ],
          ),
        );

      case WorkSetupStage.chooseSource:
        if (setup == null) {
          return _buildCanonicalUnavailableView(
            onBack: controller.cancelChooseSource,
          );
        }
        return WorkSourceSelectionView(
          setup: setup,
          onCancel: () => _handleWorkBack(setup, state, uid),
          onPickPhoto: (source) => controller.pickAndUploadPhoto(
            uid: uid,
            source: source,
            setup: setup,
          ),
          onManualSetup: () => controller.startManualSetup(setup),
          onEditCurrent: () => controller.editCurrentWorkSchedule(setup),
          onRemoveSetup: () => _handleRemoveWorkSetup(setup, uid),
          lifeRole: lifeRole,
          businessMode: profile.businessMode,
        );

      case WorkSetupStage.error:
        return _buildErrorView(setup, state, uid);

      case WorkSetupStage.saveSuccess:
        return _WorkSaveSuccessView(
          lifeRole: lifeRole,
          onComplete: () {
            if (!mounted) return;
            controller.dismissSuccess();
          },
        );

      case WorkSetupStage.review:
      case WorkSetupStage.editingBlock:
      case WorkSetupStage.saving:
        return WorkReviewView(
          workingBlocks: state.workingBlocks,
          workingAssetId: state.workingAssetId,
          workingR2Key: state.workingR2Key,
          workingLocalPreviewPath: state.workingLocalPreviewPath,
          selectedDay: state.selectedDay,
          onDayChanged: (d) => controller.selectDay(d),
          droppedCount: state.droppedCount,
          droppedExamples: state.droppedExamples,
          errorMessage: state.errorMessage,
          onClearError: () => controller.clearError(),
          isSaving: state.isSaving,
          onCancel: () => _handleWorkBack(setup, state, uid),
          onScanAgain: () => _showScanAgainSheet(uid),
          onAddBlock: () => _addNewBlock(state.selectedDay),
          onEditBlock: _editBlock,
          onSave: () => controller.save(uid: uid),
          frontBlockId: state.frontBlockId,
          onFrontSelected: (id) => controller.selectFrontBlock(id),
          isConcurrencyConflict: state.isConcurrencyConflict,
          onReloadLatestSetup: setup == null
              ? null
              : () => controller.reloadFromCanonical(setup),
          lifeRole: lifeRole,
        );

      case WorkSetupStage.currentSetup:
        if (setup == null) {
          return _buildCanonicalUnavailableView(onBack: widget.onBack);
        }

        return WorkCurrentSetupView(
          setup: setup,
          routineBlocks: setup.workBlocks,
          selectedDay: state.selectedDay,
          onDayChanged: (d) => controller.selectDay(d),
          onBack: () => _handleWorkBack(setup, state, uid),
          onChangeSetup: () => controller.chooseSource(setup, uid: uid),
          onRemoveSetup: () => _handleRemoveWorkSetup(setup, uid),
          routineRefreshPending: state.routineRefreshPending,
          routineRefreshMessage: state.routineRefreshMessage,
          onRetryRefresh: () => controller.retryRoutineRefresh(uid: uid),
          lifeRole: ref.watch(userProfileProvider).lifeRole,
        );
    }
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

  Widget _buildCurrentSetupSkeletonView() {
    final lifeRole = ref.watch(userProfileProvider).lifeRole;
    final headerTitle = WorkPresentationUtils.currentSetupHeaderTitle(lifeRole);
    final loadingMsg = WorkPresentationUtils.loadingScheduleMessage(lifeRole);

    return SafeArea(
      bottom: false,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loadingMsg,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 120,
                  height: 36,
                  decoration: BoxDecoration(
                    color: OptivusColors.warning.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    height: 140,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, index) => Container(
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSetupLoadErrorView(Object? error) {
    final lifeRole = ref.watch(userProfileProvider).lifeRole;
    final errorTitle = WorkPresentationUtils.failedToLoadTitle(lifeRole);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: OptivusColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: OptivusColors.danger,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  errorTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  WorkSetupErrorMapper.mapLoadError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OptivusColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: widget.onBack,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: OptivusColors.warning,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          ref
                              .read(baseTimelineSetupNotifierProvider.notifier)
                              .load();
                        },
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanonicalUnavailableView({required VoidCallback onBack}) {
    final lifeRole = ref.watch(userProfileProvider).lifeRole;
    final title = WorkPresentationUtils.temporarilyUnavailableTitle(lifeRole);

    return SafeArea(
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
                      color: OptivusColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        OptivusRadii.controlCompact,
                      ),
                      border: Border.all(
                        color: OptivusColors.warning.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: OptivusColors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: OptivusColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reload your setup to continue. Your local changes have been kept.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: OptivusColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OptivusColors.warning,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            OptivusRadii.controlCompact,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => ref
                          .read(baseTimelineSetupNotifierProvider.notifier)
                          .load(),
                      child: const Text(
                        'Reload setup',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onBack,
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: OptivusColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildErrorView(
    BaseTimelineSetup? setup,
    WorkSetupState state,
    String uid,
  ) {
    final controller = ref.read(workSetupControllerProvider.notifier);

    final lifeRole = ref.watch(userProfileProvider).lifeRole;
    final errorTitle = WorkPresentationUtils.errorTitle(
      errorKindString: state.errorKind?.name,
      lifeRole: lifeRole,
    );

    return SafeArea(
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
                  Text(
                    errorTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ??
                        'An error occurred while processing the photo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OptivusColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (state.candidateAssetId != null &&
                      state.candidateR2Key != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.warning,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  OptivusRadii.controlCompact,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () =>
                                controller.retryCandidateExtraction(uid: uid),
                            child: const Text(
                              'Retry AI',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
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
                            onPressed: () =>
                                controller.chooseSource(setup, uid: uid),
                            child: const Text(
                              'Choose another photo',
                              style: TextStyle(
                                color: OptivusColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
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
                        onPressed: setup == null
                            ? null
                            : () => controller.startManualSetup(setup),
                        child: const Text(
                          'Add Manually',
                          style: TextStyle(
                            color: OptivusColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
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
                            onPressed: () =>
                                controller.chooseSource(setup, uid: uid),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                color: OptivusColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.warning,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  OptivusRadii.controlCompact,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: setup == null
                                ? null
                                : () => controller.startManualSetup(setup),
                            child: const Text(
                              'Add Manually',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (state.workingBlocks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
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
                        onPressed: () =>
                            controller.keepPreviousDraft(setup, uid: uid),
                        child: const Text(
                          'Keep previous draft',
                          style: TextStyle(
                            color: OptivusColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _handleWorkBack(setup, state, uid),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: OptivusColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
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

class _WorkSaveSuccessView extends StatefulWidget {
  final VoidCallback onComplete;
  final String? lifeRole;

  const _WorkSaveSuccessView({required this.onComplete, this.lifeRole});

  @override
  State<_WorkSaveSuccessView> createState() => _WorkSaveSuccessViewState();
}

class _WorkSaveSuccessViewState extends State<_WorkSaveSuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  bool _didCompleteImmediately = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations && !_didCompleteImmediately) {
      _didCompleteImmediately = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(OptivusRadii.surfaceLarge),
        border: Border.all(
          color: OptivusColors.warning.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: OptivusColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: OptivusColors.warning.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: OptivusColors.warning,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            WorkPresentationUtils.saveSuccessTitle(widget.lifeRole),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your Base Timeline has been updated.',
            style: TextStyle(fontSize: 13, color: OptivusColors.textSecondary),
          ),
        ],
      ),
    );

    if (disableAnimations) {
      return SafeArea(child: Center(child: content));
    }

    return SafeArea(
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(scale: _scaleAnimation, child: content),
        ),
      ),
    );
  }
}
