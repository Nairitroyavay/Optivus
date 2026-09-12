import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
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
      final setup = ref.read(baseTimelineSetupNotifierProvider).value;
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

  Future<bool> _confirmDiscard(
    BaseTimelineSetup setup,
    ClassesSetupState state,
  ) async {
    final hasUnsavedPhoto =
        (state.workingAssetId != null &&
            state.workingAssetId != setup.classLogicalAssetId) ||
        (state.candidateAssetId != null &&
            state.candidateAssetId != setup.classLogicalAssetId);
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
    BaseTimelineSetup setup,
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
      final canDiscard = await _confirmDiscard(setup, state);
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

  void _showScanAgainSheet(BaseTimelineSetup setup, String uid) {
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
                    setup: setup,
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
                    setup: setup,
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
        final setup = next.value;
        if (setup != null) {
          controller.performStartupCleanup(setup, uid: uid);
          controller.initDayIfNeeded(setup);
        }
      },
    );

    if (state.stage == ClassesSetupStage.currentSetup &&
        setupAsync.isLoading &&
        !setupAsync.hasValue) {
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

    final setup =
        setupAsync.value ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleClassesBack(setup, state, uid);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildStageContent(setup, state, uid),
      ),
    );
  }

  Widget _buildStageContent(
    BaseTimelineSetup setup,
    ClassesSetupState state,
    String uid,
  ) {
    final controller = ref.read(classesSetupControllerProvider.notifier);

    switch (state.stage) {
      case ClassesSetupStage.uploading:
        return SafeArea(
          child: Column(
            children: [
              _buildTopCancelBar(() => _handleClassesBack(setup, state, uid)),
              const Expanded(
                child: BaseTimelineAiThinkingView(
                  initialMessage: 'Uploading timetable photo...',
                  progressMessages: [
                    'Encrypting and uploading to private storage...',
                    'Preparing document for analysis...',
                  ],
                ),
              ),
            ],
          ),
        );

      case ClassesSetupStage.extracting:
        return SafeArea(
          child: Column(
            children: [
              _buildTopCancelBar(() => _handleClassesBack(setup, state, uid)),
              const Expanded(
                child: BaseTimelineAiThinkingView(
                  initialMessage: 'Reading your timetable',
                  progressMessages: [
                    'Finding subjects',
                    'Reading rooms and faculty',
                    'Matching weekdays',
                    'Checking exact times',
                    'Building your new timetable',
                  ],
                ),
              ),
            ],
          ),
        );

      case ClassesSetupStage.chooseSource:
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
        );

      case ClassesSetupStage.error:
        return _buildErrorView(setup, state, uid);

      case ClassesSetupStage.saveSuccess:
        return _ClassesSaveSuccessView(
          onComplete: () {
            if (!mounted) return;
            controller.dismissSuccess();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Classes updated. Your new timetable is now active.',
                ),
                duration: Duration(seconds: 3),
                backgroundColor: OptivusColors.routineAccent,
              ),
            );
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
          onScanAgain: () => _showScanAgainSheet(setup, uid),
          onAddClass: () => _addNewBlock(state.selectedDay),
          onEditBlock: _editBlock,
          onSave: () => controller.save(uid: uid, setup: setup),
          frontBlockId: state.frontBlockId,
          onFrontSelected: (id) => controller.selectFrontBlock(id),
        );

      case ClassesSetupStage.currentSetup:
        final routineBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
          setup.classBlocks,
        );

        return ClassesCurrentSetupView(
          setup: setup,
          routineBlocks: routineBlocks,
          selectedDay: state.selectedDay,
          onDayChanged: (d) => controller.selectDay(d),
          onBack: () => _handleClassesBack(setup, state, uid),
          onChangeSetup: () => controller.chooseSource(setup, uid: uid),
          onRemoveSetup: () => _handleRemoveSetup(setup, uid),
        );
    }
  }

  Widget _buildTopCancelBar(VoidCallback onCancel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: OptivusColors.textPrimary,
            ),
            onPressed: onCancel,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSetupSkeletonView() {
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Loading timetable...',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    height: 110,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: OptivusColors.blueAccent.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(
    BaseTimelineSetup setup,
    ClassesSetupState state,
    String uid,
  ) {
    final controller = ref.read(classesSetupControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
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
                    Icons.warning_amber_rounded,
                    color: OptivusColors.danger,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Timetable Processing Issue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
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
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (state.candidateAssetId != null &&
                    state.candidateR2Key != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OptivusColors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => controller.retryCandidateExtraction(
                            uid: uid,
                            setup: setup,
                          ),
                          child: const Text('Retry AI'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () =>
                              controller.chooseSource(setup, uid: uid),
                          child: const Text('Choose another photo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => controller.startManualSetup(setup),
                      child: const Text('Add Manually'),
                    ),
                  ),
                ] else ...[
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
                          onPressed: () =>
                              controller.chooseSource(setup, uid: uid),
                          child: const Text('Try Again'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OptivusColors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => controller.startManualSetup(setup),
                          child: const Text('Add Manually'),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () =>
                          controller.keepPreviousDraft(setup, uid: uid),
                      child: const Text('Keep previous draft'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _handleClassesBack(setup, state, uid),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: OptivusColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassesSaveSuccessView extends StatefulWidget {
  final VoidCallback onComplete;

  const _ClassesSaveSuccessView({required this.onComplete});

  @override
  State<_ClassesSaveSuccessView> createState() =>
      _ClassesSaveSuccessViewState();
}

class _ClassesSaveSuccessViewState extends State<_ClassesSaveSuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
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
                      color: OptivusColors.routineAccent.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: OptivusColors.routineAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Classes updated',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your new timetable is now active.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: OptivusColors.textSecondary,
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
