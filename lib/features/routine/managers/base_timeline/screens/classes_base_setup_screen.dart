import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_load_error.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_skeleton.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_processing_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_save_success_view.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';

/// Host coordinator screen for Base Timeline Classes setup.
class ClassesBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ClassesBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<ClassesBaseSetupScreen> createState() =>
      _ClassesBaseSetupScreenState();
}

class _ClassesBaseSetupScreenState
    extends ConsumerState<ClassesBaseSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final setup = ref.read(baseTimelineSetupNotifierProvider).valueOrNull;
      if (setup != null) {
        final uid = ref.read(userProfileProvider).uid;
        ref
            .read(classesSetupControllerProvider.notifier)
            .performStartupCleanup(setup, uid: uid);
        ref
            .read(classesSetupControllerProvider.notifier)
            .initDayIfNeeded(setup);
      }
    });
  }

  Future<bool> _confirmDiscard(ClassesSetupState state) async {
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
        content: const Text(
          "Your current Classes setup won't be affected.",
          style: TextStyle(color: OptivusColors.textSecondary),
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

  Future<void> _handleClassesBack(
    BaseTimelineSetup? setup,
    ClassesSetupState state,
    String uid,
  ) async {
    final controller = ref.read(classesSetupControllerProvider.notifier);

    if (state.stage == ClassesSetupStage.saving ||
        state.stage == ClassesSetupStage.saveSuccess) {
      return;
    }

    if (state.stage == ClassesSetupStage.uploading ||
        state.stage == ClassesSetupStage.extracting) {
      await controller.cancelCurrentExtraction(setup, uid: uid);
      return;
    }

    if (state.stage == ClassesSetupStage.chooseSource) {
      controller.cancelChooseSource();
      return;
    }

    if (state.stage == ClassesSetupStage.error) {
      if (state.workingBlocks.isNotEmpty) {
        controller.keepPreviousDraft(setup, uid: uid);
      } else {
        await controller.resetWorkingDraft(setup, uid: uid);
      }
      return;
    }

    if (state.stage == ClassesSetupStage.review ||
        state.stage == ClassesSetupStage.editingBlock) {
      final canDiscard = await _confirmDiscard(state);
      if (!canDiscard || !mounted) return;
      await controller.resetWorkingDraft(setup, uid: uid);
      return;
    }

    if (state.stage == ClassesSetupStage.currentSetup) {
      widget.onBack();
    }
  }

  Future<void> _addNewBlock(int selectedDay) async {
    final controller = ref.read(classesSetupControllerProvider.notifier);
    final newBlock = ClassRoutineBlock(
      id: 'cls_${DateTime.now().millisecondsSinceEpoch}',
      subject: '',
      room: '',
      professor: '',
      courseCode: '',
      classType: '',
      section: '',
      notes: '',
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      repeatDays: [selectedDay],
    );

    controller.startEditingBlock();
    await ClassTimelineAdapter.showClassEditSheet(
      context: context,
      block: newBlock,
      accent: OptivusColors.blueAccent,
      isNew: true,
      saveLabel: 'Save',
      onSave: (updated) async {
        controller.addBlock(updated);
        return true;
      },
    );
    if (mounted) {
      controller.stopEditingBlock();
    }
  }

  Future<void> _editBlock(ClassRoutineBlock block) async {
    final controller = ref.read(classesSetupControllerProvider.notifier);
    controller.startEditingBlock();
    await ClassTimelineAdapter.showClassEditSheet(
      context: context,
      block: block,
      accent: OptivusColors.blueAccent,
      isNew: false,
      saveLabel: 'Save',
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

  Future<void> _editBlockFromCurrentSetup(
    BaseTimelineSetup setup,
    ClassRoutineBlock block,
    String uid,
  ) async {
    final controller = ref.read(classesSetupControllerProvider.notifier);
    controller.editCurrentTimetable(setup);
    controller.startEditingBlock();
    var didSave = false;
    try {
      await ClassTimelineAdapter.showClassEditSheet(
        context: context,
        block: block,
        accent: OptivusColors.blueAccent,
        isNew: false,
        saveLabel: 'Save',
        onSave: (updated) async {
          controller.updateBlock(updated);
          didSave = true;
          return true;
        },
        onDelete: (toDelete) async {
          controller.deleteBlock(toDelete.id);
          didSave = true;
          return true;
        },
      );
    } finally {
      if (mounted) {
        controller.stopEditingBlock();
        if (!didSave && !ref.read(classesSetupControllerProvider).isDirty) {
          await controller.resetWorkingDraft(setup, uid: uid);
        }
      }
    }
  }

  void _showScanAgainSheet(String uid) {
    final controller = ref.read(classesSetupControllerProvider.notifier);
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
              const Text(
                'Scan Timetable Photo',
                style: TextStyle(
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
                  color: OptivusColors.aquaAccent,
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

  Future<void> _handleRemoveSetup(BaseTimelineSetup setup, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Classes setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will remove all scheduled classes from your Base Timeline. This action cannot be undone.',
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

    final controller = ref.read(classesSetupControllerProvider.notifier);
    await controller.removeSetup(uid: uid, setup: setup);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classes setup removed.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);
    final state = ref.watch(classesSetupControllerProvider);
    final controller = ref.read(classesSetupControllerProvider.notifier);
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

    if (state.stage == ClassesSetupStage.currentSetup) {
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
        _handleClassesBack(setup, state, uid);
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
    ClassesSetupState state,
    String uid,
  ) {
    final controller = ref.read(classesSetupControllerProvider.notifier);

    switch (state.stage) {
      case ClassesSetupStage.uploading:
        return BaseTimelineProcessingScaffold(
          title: 'Updating timetable',
          onCancel: () => _handleClassesBack(setup, state, uid),
          child: BaseTimelineUploadView(
            localPreviewPath: state.workingLocalPreviewPath,
          ),
        );

      case ClassesSetupStage.extracting:
        return BaseTimelineProcessingScaffold(
          title: 'Reading timetable',
          onCancel: () => _handleClassesBack(setup, state, uid),
          child: BaseTimelineAiThinkingView(
            initialMessage: 'Reading your timetable',
            progressMessages: const [
              'Finding subjects',
              'Reading rooms and faculty',
              'Matching weekdays',
              'Checking exact times',
              'Building your new timetable',
            ],
            localPreviewPath: state.workingLocalPreviewPath,
            assetId: state.candidateAssetId,
            r2Key: state.candidateR2Key,
          ),
        );

      case ClassesSetupStage.chooseSource:
        if (setup == null) {
          return _buildCanonicalUnavailableView(
            onBack: controller.cancelChooseSource,
          );
        }
        return ClassesSourceSelectionView(
          setup: setup,
          onCancel: () => _handleClassesBack(setup, state, uid),
          onPickPhoto: (source) => controller.pickAndUploadPhoto(
            uid: uid,
            source: source,
            setup: setup,
          ),
          onManualSetup: () => controller.startManualSetup(setup),
          onEditCurrent: () => controller.editCurrentTimetable(setup),
          onRemoveSetup: () => _handleRemoveSetup(setup, uid),
        );

      case ClassesSetupStage.error:
        return _buildErrorView(setup, state, uid);

      case ClassesSetupStage.saveSuccess:
        return BaseTimelineSaveSuccessView(
          title: 'Classes updated',
          subtitle: 'Your new timetable is now active.',
          accent: OptivusColors.blueAccent,
          onComplete: () {
            if (!mounted) return;
            controller.dismissSuccess();
          },
        );

      case ClassesSetupStage.review:
      case ClassesSetupStage.editingBlock:
      case ClassesSetupStage.saving:
        return ClassesReviewView(
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
          onCancel: () => _handleClassesBack(setup, state, uid),
          onScanAgain: () => _showScanAgainSheet(uid),
          onAddClass: () => _addNewBlock(state.selectedDay),
          onEditBlock: _editBlock,
          onSave: () => controller.save(uid: uid),
          frontBlockId: state.frontBlockId,
          onFrontSelected: (id) => controller.selectFrontBlock(id),
          isConcurrencyConflict: state.isConcurrencyConflict,
          onReloadLatestSetup: setup == null
              ? null
              : () => controller.reloadFromCanonical(setup),
          isEditing:
              setup != null &&
              setup.snapshotFor(BaseTimelineSection.classes).isConfigured,
        );

      case ClassesSetupStage.currentSetup:
        if (setup == null) {
          return _buildCanonicalUnavailableView(onBack: widget.onBack);
        }
        final routineBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
          setup.classBlocks,
        );

        return ClassesCurrentSetupView(
          setup: setup,
          routineBlocks: routineBlocks,
          selectedDay: state.selectedDay,
          onDayChanged: (d) => controller.selectDay(d),
          onBack: () => _handleClassesBack(setup, state, uid),
          onEditSchedule: () => controller.editCurrentTimetable(setup),
          onEditBlock: (block) => _editBlockFromCurrentSetup(setup, block, uid),
          onChangeSource: () => controller.chooseSource(setup, uid: uid),
          onChangeSetup: () => controller.chooseSource(setup, uid: uid),
          onRemoveSetup: () => _handleRemoveSetup(setup, uid),
          routineRefreshPending: state.routineRefreshPending,
          routineRefreshMessage: state.routineRefreshMessage,
          onRetryRefresh: () => controller.retryRoutineRefresh(uid: uid),
        );
    }
  }

  Widget _buildCurrentSetupSkeletonView() {
    return BaseTimelineCurrentSetupSkeleton(
      title: 'Classes',
      loadingMessage: 'Loading timetable...',
      accent: OptivusColors.blueAccent,
      onBack: widget.onBack,
    );
  }

  Widget _buildCurrentSetupLoadErrorView(Object? error) {
    return BaseTimelineCurrentSetupLoadError(
      title: 'Failed to load Classes timetable',
      errorMessage: ClassSetupErrorMapper.mapLoadError(error),
      onBack: widget.onBack,
      onRetry: () => ref.read(baseTimelineSetupNotifierProvider.notifier).load(),
    );
  }

  Widget _buildCanonicalUnavailableView({required VoidCallback onBack}) {
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
                  const Text(
                    'Classes setup temporarily unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                        backgroundColor: OptivusColors.blueAccent,
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
    ClassesSetupState state,
    String uid,
  ) {
    final controller = ref.read(classesSetupControllerProvider.notifier);

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
                  const Text(
                    'Timetable Processing Issue',
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
                              backgroundColor: OptivusColors.blueAccent,
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
                              backgroundColor: OptivusColors.blueAccent,
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
                    onPressed: () => _handleClassesBack(setup, state, uid),
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
