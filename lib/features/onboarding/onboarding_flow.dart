import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/onboarding_state.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/views/screens/loading_screen.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/services/session_destination_resolver.dart';

import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_steps.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/onboarding_step_readiness.dart';

// ── Main Onboarding Flow Wizard ──────────────────────────────────────────────
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late PageController _pageController;

  double _pageOffset = 0.0;
  int _currentPage = 0;
  bool _initialDraftReady = true;
  bool _initialDraftSyncScheduled = false;
  bool _isSaving = false; // Double-tap prevention for Save
  bool _isNavigating = false; // Double-tap prevention for Next
  bool _isHandlingPopGesture = false;
  final Set<int> _stepsWithRevealedPrimaryCta = <int>{};

  @override
  void initState() {
    super.initState();
    final initialAuthState = ref.read(authProvider);
    _initialDraftReady = !initialAuthState.isLoading;
    final initialStep = _initialDraftReady ? _currentDraftStep() : 0;
    _currentPage = initialStep;
    _pageOffset = initialStep.toDouble();
    _createPageController(initialStep);
  }

  int _currentDraftStep() {
    final onboarding = ref.read(mockOnboardingProvider);
    return durableOnboardingResumeStep(onboarding.draft);
  }

  void _createPageController(int initialStep) {
    _pageController = PageController(initialPage: initialStep);
    _pageController.addListener(_handlePageControllerChanged);
  }

  void _replacePageController(int initialStep) {
    _pageController.removeListener(_handlePageControllerChanged);
    _pageController.dispose();
    _createPageController(initialStep);
  }

  void _handlePageControllerChanged() {
    if (!mounted) return;
    setState(() {
      _pageOffset = _pageController.page ?? _currentPage.toDouble();
    });
  }

  void _scheduleInitialDraftSync() {
    if (_initialDraftSyncScheduled) return;
    _initialDraftSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialDraftSyncScheduled = false;
      if (!mounted) return;
      final restoredStep = _currentDraftStep();
      if (!_pageController.hasClients) {
        _replacePageController(restoredStep);
      }
      setState(() {
        _currentPage = restoredStep;
        _pageOffset = restoredStep.toDouble();
        _initialDraftReady = true;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(restoredStep);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper validation per step
  String? _validateStep(int step) {
    final onboarding = ref.read(mockOnboardingProvider);
    return onboarding.draft.validateStep(step, onboarding.stepCompleted);
  }

  bool _needsEmailVerification(AuthUser? user) {
    return user?.needsEmailVerification ?? false;
  }

  String? _currentPersistenceUid() {
    final authUser = ref.read(authProvider).user;
    if (_needsEmailVerification(authUser)) return null;
    if (!ref.read(fakeDataAllowedProvider) && authUser == null) return null;
    return authUser?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
  }

  bool _stillOwnsDraft(String uid) =>
      _currentPersistenceUid() == uid &&
      ref.read(mockOnboardingProvider).draft.uid == uid;

  Future<void> _persistCurrentDraftAfterNavigation() async {
    final uid = _currentPersistenceUid();
    if (uid == null) return;

    final step = ref.read(mockOnboardingProvider).currentStep;
    final sourceDraft = ref.read(mockOnboardingProvider).draft;
    final submittedRevision = sourceDraft.revision;
    final draft = sourceDraft.copyWith(uid: uid, incrementRevision: false);
    ref.read(mockOnboardingProvider.notifier).markStepSaving(step);

    try {
      await ref.read(onboardingRepositoryProvider).saveDraft(draft);
      await ref.read(onboardingRepositoryProvider).flushPendingDraftSave();
    } catch (_) {
      if (!mounted) return;
      if (!_stillOwnsDraft(uid)) return;
      ref
          .read(mockOnboardingProvider.notifier)
          .markStepSyncFailed(
            step,
            message:
                "Couldn't sync your changes. Your changes are still open here. Retry before leaving this step.",
          );
      return;
    }
    if (!mounted) return;
    if (!_stillOwnsDraft(uid)) return;
    ref
        .read(mockOnboardingProvider.notifier)
        .acknowledgeDraftSync(step: step, submittedRevision: submittedRevision);
  }

  // Core Save step action — with double-tap prevention
  Future<bool> _saveStep(int step) async {
    if (_isSaving) return false; // Prevent double tap
    String? saveOwnerUid;

    final readiness = _readStepReadiness(step);
    if (!readiness.canRevealPrimary) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            readiness.validationMessage ??
                'Complete the required information before continuing.',
          );
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final validationError = _validateStep(step);
      if (validationError != null) {
        ref
            .read(mockOnboardingProvider.notifier)
            .setValidationMessage(validationError);
        return false;
      }

      final uid = _currentPersistenceUid();
      if (uid == null) {
        ref
            .read(mockOnboardingProvider.notifier)
            .setValidationMessage(
              'Please verify your email before saving onboarding.',
            );
        return false;
      }
      saveOwnerUid = uid;

      ref.read(mockOnboardingProvider.notifier).setStepLoading(step, true);
      ref.read(mockOnboardingProvider.notifier).clearValidation();

      final submittedRevision = ref.read(mockOnboardingProvider).draft.revision;
      final savedDraft = _buildStepSaveCandidate(step: step, uid: uid);

      final onboardingRepository = ref.read(onboardingRepositoryProvider);
      await onboardingRepository.saveDraft(savedDraft);
      await onboardingRepository.flushPendingDraftSave();
      if (_currentPersistenceUid() != uid) {
        throw StateError('Authenticated account changed during save.');
      }

      // Completion becomes visible to navigation only after the repository
      // acknowledges the durable write.
      final acknowledged = ref
          .read(mockOnboardingProvider.notifier)
          .acknowledgeStepSave(
            step: step,
            submittedRevision: submittedRevision,
            savedDraft: savedDraft,
          );
      if (!acknowledged) return false;

      // This profile field is only a startup-loader hint. The saved draft's
      // completed-step vector remains the sole progression authority.
      final profile = ref
          .read(mockUserProfileProvider)
          .copyWith(
            onboardingStep: durableOnboardingResumeStep(savedDraft),
            updatedAt: DateTime.now(),
          );
      ref.read(mockUserProfileProvider.notifier).updateProfile(profile);
      if (!ref.read(fakeDataAllowedProvider)) {
        try {
          await ref.read(profileRepositoryProvider).saveUserProfile(profile);
        } catch (_) {
          // The draft is already durably verified. Failure to update this
          // optional hint must not turn a successful step save into failure.
        }
      }

      return true;
    } catch (e) {
      if (saveOwnerUid != null && !_stillOwnsDraft(saveOwnerUid)) {
        return false;
      }
      ref
          .read(mockOnboardingProvider.notifier)
          .markStepSyncFailed(
            step,
            message:
                "Couldn't sync your changes. Your changes are still open here. Retry before leaving this step.",
          );
      return false;
    } finally {
      if (saveOwnerUid == null || _stillOwnsDraft(saveOwnerUid)) {
        ref.read(mockOnboardingProvider.notifier).setStepLoading(step, false);
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  OnboardingDraft _buildStepSaveCandidate({
    required int step,
    required String uid,
  }) {
    final now = DateTime.now();
    var draft = ref.read(mockOnboardingProvider).draft;
    if (step == 0) {
      draft = draft.copyWith(welcomeSaved: true);
    } else if (step == 3) {
      draft = draft.copyWith(bodyBasics: draft.bodyBasics.withEstimates());
    } else if (step == onboardingFixedStepIndex) {
      draft = draft.copyWith(
        baseTimeline: draft.baseTimeline.withRequiredFixedBlocks(),
      );
    } else if (step == OnboardingDraft.lastStepIndex) {
      draft = draft.copyWith(finalPreview: draft.buildFinalPreview());
    }

    final completed = List<bool>.from(draft.stepCompleted)..[step] = true;
    final dirty = List<bool>.from(draft.stepDirty)..[step] = false;
    final loading = List<bool>.from(draft.stepLoading)..[step] = false;
    return draft.copyWith(
      uid: uid,
      currentStep: step,
      stepCompleted: completed,
      stepDirty: dirty,
      stepLoading: loading,
      createdAt: draft.createdAt ?? now,
      updatedAt: now,
    );
  }

  // Next step trigger action — with double-tap prevention
  void _onNextPressed() async {
    if (_isNavigating) return; // Prevent double tap

    final readiness = _readStepReadiness(_currentPage);
    if (_currentPage >= 1 && _currentPage <= 13 && !readiness.canSubmit) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            readiness.validationMessage ??
                'Complete the required information before continuing.',
          );
      return;
    }
    setState(() => _isNavigating = true);

    try {
      if (_currentPage == OnboardingDraft.lastStepIndex) {
        await _completeOnboarding();
        return;
      }

      if (await _handleInternalNextIfNeeded()) {
        return;
      }

      final targetStep = _currentPage;
      final onboardingState = ref.read(mockOnboardingProvider);
      final isDirty = onboardingState.stepDirty[targetStep];
      final isCompleted = onboardingState.stepCompleted[targetStep];

      // If dirty or not completed, force save logic
      if (isDirty || !isCompleted) {
        final saveSuccess = await _saveStep(targetStep);
        if (!mounted) return;
        if (!saveSuccess) {
          return; // Stop if invalid
        }
      }

      // Otherwise slide to the next step
      final latestState = ref.read(mockOnboardingProvider);
      final nextPage = _currentPage + 1;
      if (!canAccessOnboardingStep(
        targetStep: nextPage,
        completedSteps: latestState.stepCompleted,
      )) {
        ref
            .read(mockOnboardingProvider.notifier)
            .setValidationMessage(
              'This step is available after the previous step is saved.',
            );
        return;
      }
      _currentPage = nextPage;
      ref.read(mockOnboardingProvider.notifier).setStep(_currentPage);
      await _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      if (!mounted) return;
      await _persistCurrentDraftAfterNavigation();
    } catch (e) {
      if (!mounted) return;
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Could not continue onboarding safely. Please try again.',
          );
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  Future<void> _completeOnboarding() async {
    final onboarding = ref.read(mockOnboardingProvider);
    for (var step = 0; step <= OnboardingDraft.lastStepIndex; step++) {
      final error = onboarding.draft.validateStep(
        step,
        onboarding.stepCompleted,
      );
      if (error != null) {
        ref.read(mockOnboardingProvider.notifier).setValidationMessage(error);
        return;
      }
    }

    final authUser = ref.read(authProvider).user;
    if (authUser?.needsEmailVerification ?? false) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Please verify your email before finishing onboarding.',
          );
      return;
    }

    final uid = _currentPersistenceUid();
    if (uid == null) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Please verify your email before finishing onboarding.',
          );
      return;
    }

    late final OnboardingDraft finalDraft;
    late final OnboardingCompletionBundle bundle;
    final onboardingRepository = ref.read(onboardingRepositoryProvider);
    if (isDurablyFinalOnboardingDraft(onboarding.draft)) {
      finalDraft = onboarding.draft;
      final storedBundle = await onboardingRepository.fetchCompletionBundle(
        uid,
      );
      if (storedBundle != null) {
        if (!OnboardingCompletionService.bundleMatchesFinalDraft(
          uid: uid,
          draft: finalDraft,
          bundle: storedBundle,
        )) {
          ref
              .read(mockOnboardingProvider.notifier)
              .setValidationMessage(
                'Saved completion state does not match this setup. '
                'Please try again after it finishes syncing.',
              );
          return;
        }
        bundle = storedBundle;
      } else {
        bundle = OnboardingCompletionService.buildBundle(finalDraft);
      }
    } else {
      final saveSuccess = await _saveStep(OnboardingDraft.lastStepIndex);
      if (!saveSuccess) {
        return;
      }

      final savedDraft = ref.read(mockOnboardingProvider).draft;
      final draftForBundle = savedDraft.copyWith(uid: uid);
      final now = DateTime.now();
      finalDraft = draftForBundle.copyWith(
        onboardingCompleted: true,
        currentStep: OnboardingDraft.lastStepIndex,
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
        stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
        finalPreview:
            draftForBundle.finalPreview ?? draftForBundle.buildFinalPreview(),
        createdAt: draftForBundle.createdAt ?? now,
        updatedAt: now,
      );
      bundle = OnboardingCompletionService.buildBundle(finalDraft);
    }
    String? blockingWarning;
    for (final warning in bundle.warnings) {
      if (warning.startsWith('Resolve or accept')) {
        blockingWarning = warning;
        break;
      }
    }
    if (blockingWarning != null) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(blockingWarning);
      return;
    }

    try {
      final job = await ref
          .read(onboardingCompletionJobServiceProvider)
          .runCompletionJob(
            uid: uid,
            finalDraft: finalDraft,
            bundle: bundle,
            reader: ref.read,
          );
      if (job.status != OnboardingJobStatus.completed ||
          job.stage != OnboardingCompletionStage.completed) {
        ref
            .read(mockOnboardingProvider.notifier)
            .setValidationMessage(
              'Setup is still finishing. Please tap Enter Optivus to resume.',
            );
        return;
      }
    } catch (_) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Could not finish and load your Routine setup. '
            'Please check your connection and try again.',
          );
      return;
    }
    ref.read(mockOnboardingProvider.notifier).loadSeedData(finalDraft);

    // Initialize the coach tab with a starter session so it doesn't crash empty
    ref
        .read(mockCoachProvider.notifier)
        .createNewSession(
          'Onboarding Review',
          CoachSessionType.generalChat,
          bundle.coachPreferences.name,
          bundle.coachPreferences.style,
        );

    if (authUser != null) {
      await ref
          .read(authProvider.notifier)
          .acceptCanonicalOnboardingCompletion(authUser);
    }

    if (mounted && authUser == null) {
      context.go('/app?tab=0');
    }
  }

  Future<void> _navigateToIndicatorStep(int index) async {
    if (_isSaving || _isNavigating) return;
    final onboardingState = ref.read(mockOnboardingProvider);
    final boundedIndex = index.clamp(
      0,
      onboardingState.stepCompleted.length - 1,
    );

    if (boundedIndex == _currentPage) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      return;
    }

    final isBackward = boundedIndex < _currentPage;
    final isSavedForwardStep = canAccessOnboardingStep(
      targetStep: boundedIndex,
      completedSteps: onboardingState.stepCompleted,
    );
    final hasUnsavedForwardStep =
        !isBackward &&
        onboardingState.stepDirty
            .sublist(_currentPage, boundedIndex + 1)
            .any((dirty) => dirty);

    if (hasUnsavedForwardStep) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage('Save changed steps before moving forward.');
      return;
    }

    if (!isBackward && !isSavedForwardStep) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Use Next Step to unlock the next onboarding step.',
          );
      return;
    }

    if (!isBackward) {
      for (var i = _currentPage; i < boundedIndex; i++) {
        final error = onboardingState.draft.validateStep(
          i,
          onboardingState.stepCompleted,
        );
        if (error != null) {
          ref
              .read(mockOnboardingProvider.notifier)
              .setValidationMessage(
                'Please complete earlier steps before skipping ahead.',
              );
          return;
        }
      }
    }

    _currentPage = boundedIndex;
    ref.read(mockOnboardingProvider.notifier).setStep(boundedIndex);
    await _pageController.animateToPage(
      boundedIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    await _persistCurrentDraftAfterNavigation();
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Onboarding?'),
        content: const Text(
          'Exit to the main menu? Changes that have not synced may be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Exit',
              style: const TextStyle(color: OptivusColors.danger),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showDiscardDraftDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes on this step. Do you want to save or discard before going back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () async {
              final saved = await _saveStep(_currentPage);
              if (saved && ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: const Text('Save & Go Back'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handlePopGesture() async {
    if (_isHandlingPopGesture) return;
    _isHandlingPopGesture = true;
    try {
      final currentFocus = FocusManager.instance.primaryFocus;
      final focusContext = currentFocus?.context;
      final hasEditableFocus =
          currentFocus != null &&
          currentFocus.hasFocus &&
          focusContext != null &&
          (focusContext.widget is EditableText ||
              focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                  null);
      if (hasEditableFocus) {
        currentFocus.unfocus();
        return;
      }

      if (_handleInternalBackIfNeeded()) {
        return;
      }

      if (_currentPage <= 0) {
        final confirmed = await _showExitConfirmationDialog(context);
        if (confirmed && mounted) {
          context.go('/');
        }
        return;
      }

      final onboardingState = ref.read(mockOnboardingProvider);
      if (onboardingState.stepDirty[_currentPage]) {
        final proceed = await _showDiscardDraftDialog(context);
        if (!proceed) return;
      }

      _goToPreviousStepDirect();
    } finally {
      _isHandlingPopGesture = false;
    }
  }

  void _goToPreviousStepDirect() {
    if (_currentPage <= 0) {
      context.go('/');
      return;
    }

    final target = _currentPage - 1;
    _currentPage = target;
    ref.read(mockOnboardingProvider.notifier).setStep(target);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );

    _persistCurrentDraftAfterNavigation();
  }

  void _goToPreviousStep() {
    _handlePopGesture();
  }

  bool _handleInternalBackIfNeeded() {
    final draft = ref.read(mockOnboardingProvider).draft;
    return switch (_currentPage) {
      onboardingClassJobStepIndex => _backClassesJob(draft),
      onboardingEatingStepIndex => _backEating(draft),
      onboardingFixedStepIndex => _backFixed(draft),
      onboardingSkinCareStepIndex => _backSkinCare(draft),
      _ => false,
    };
  }

  void _onDotTapped(int index) => _navigateToIndicatorStep(index);

  void _onIndicatorDraggedTo(int index) => _navigateToIndicatorStep(index);

  bool _showTopLeftOverlay(OnboardingDraft draft) {
    return onboardingShouldShowTopLeftBackButton(
      currentPage: _currentPage,
      baseTimeline: draft.baseTimeline,
    );
  }

  bool _classJobReviewReady(
    OnboardingDraft draft,
    List<ClassRoutineBlock> classBlocks,
    List<ClassRoutineBlock> workBlocks,
  ) {
    final role = draft.lifeRole.lifeRole;
    final classesRequired =
        role == LifeRoleDraft.studentKey ||
        role == LifeRoleDraft.studentWorkingKey;
    final workRequired =
        role == LifeRoleDraft.workingKey ||
        role == LifeRoleDraft.studentWorkingKey ||
        role == LifeRoleDraft.businessKey;
    final classesReady = _timelineBlocksFromLocalSchedule(
      classBlocks,
      'classes',
    ).isNotEmpty;
    final workReady = _timelineBlocksFromLocalSchedule(
      workBlocks,
      'job_work_business',
    ).isNotEmpty;
    return (!classesRequired || classesReady) && (!workRequired || workReady);
  }

  bool _uploadBusyForStep(int step, UploadState uploadState) {
    if (uploadState.sourceFeature != OnboardingDraft.sourceOnboarding ||
        !uploadState.isBusy) {
      return false;
    }
    return switch (step) {
      onboardingClassJobStepIndex =>
        uploadState.purpose == UploadedAssetPurpose.classTimetable ||
            uploadState.purpose == UploadedAssetPurpose.workSchedule,
      onboardingEatingStepIndex =>
        uploadState.purpose == UploadedAssetPurpose.eatingMenu,
      onboardingSkinCareStepIndex =>
        uploadState.purpose == UploadedAssetPurpose.skinCare,
      _ => false,
    };
  }

  OnboardingStepReadiness _evaluateReadiness({
    required int step,
    required OnboardingState onboardingState,
    required RoutineImportAiState aiState,
    required UploadState uploadState,
    required List<ClassRoutineBlock> classBlocks,
    required List<ClassRoutineBlock> workBlocks,
  }) {
    final aiBusy =
        (step == onboardingClassJobStepIndex ||
            step == onboardingEatingStepIndex) &&
        aiState.isExtracting;
    final asyncIdle =
        !onboardingState.stepLoading[step] &&
        !aiBusy &&
        !_uploadBusyForStep(step, uploadState);
    final classJobReviewReady =
        step == onboardingClassJobStepIndex && onboardingState.stepDirty[step]
        ? _classJobReviewReady(onboardingState.draft, classBlocks, workBlocks)
        : null;

    return evaluateOnboardingStepReadiness(
      draft: onboardingState.draft,
      step: step,
      completedSteps: onboardingState.stepCompleted,
      dirtySteps: onboardingState.stepDirty,
      runtime: OnboardingStepRuntimeState(
        asyncIdle: asyncIdle,
        saveIdle: !_isSaving && !_isNavigating,
        classJobReviewReady: classJobReviewReady,
      ),
    );
  }

  OnboardingStepReadiness _readStepReadiness(int step) {
    final onboardingState = ref.read(mockOnboardingProvider);
    return _evaluateReadiness(
      step: step,
      onboardingState: onboardingState,
      aiState: ref.read(routineImportAiControllerProvider),
      uploadState: ref.read(uploadControllerProvider),
      classBlocks: step == onboardingClassJobStepIndex
          ? ref.read(onboardingClassTimelineProvider)
          : const <ClassRoutineBlock>[],
      workBlocks: step == onboardingClassJobStepIndex
          ? ref.read(onboardingWorkTimelineProvider)
          : const <ClassRoutineBlock>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final onboardingState = ref.watch(mockOnboardingProvider);
    if (authState.isLoading) {
      return const LoadingScreen(message: 'Restoring your setup...');
    }
    if (!_initialDraftReady) {
      _scheduleInitialDraftSync();
      return const LoadingScreen(message: 'Restoring your setup...');
    }

    final bool isSaved =
        onboardingState.stepSaveStatus[_currentPage] == SaveSyncStatus.synced;
    final bool showSave = false; // Globally hidden for onboarding.
    final aiState = ref.watch(routineImportAiControllerProvider);
    final uploadState = ref.watch(uploadControllerProvider);
    final classBlocks = _currentPage == onboardingClassJobStepIndex
        ? ref.watch(onboardingClassTimelineProvider)
        : const <ClassRoutineBlock>[];
    final workBlocks = _currentPage == onboardingClassJobStepIndex
        ? ref.watch(onboardingWorkTimelineProvider)
        : const <ClassRoutineBlock>[];
    final readiness = _evaluateReadiness(
      step: _currentPage,
      onboardingState: onboardingState,
      aiState: aiState,
      uploadState: uploadState,
      classBlocks: classBlocks,
      workBlocks: workBlocks,
    );

    String ctaLabel = 'Next Step';
    bool ctaEnabled =
        !_isNavigating &&
        !_isSaving &&
        !onboardingState.stepLoading[_currentPage];
    if (_currentPage == 0) {
      ctaLabel = 'Get Started';
    } else if (_currentPage == OnboardingDraft.lastStepIndex) {
      ctaLabel = 'Enter Optivus';
      ctaEnabled = !_isNavigating && !_isSaving;
    }
    ctaEnabled = ctaEnabled && readiness.canSubmit;
    if (_currentPage >= 1 && _currentPage <= 13 && readiness.canRevealPrimary) {
      _stepsWithRevealedPrimaryCta.add(_currentPage);
    }
    final showPrimaryCta = shouldShowOnboardingPrimaryCta(
      step: _currentPage,
      readiness: readiness,
      revealedDuringInteraction: _stepsWithRevealedPrimaryCta.contains(
        _currentPage,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePopGesture();
      },
      child: OnboardingStepShell(
        currentPage: _currentPage,
        pageOffset: _pageOffset,
        completedSteps: onboardingState.stepCompleted,
        validationMessage: onboardingState.validationMessage,
        onRetry:
            onboardingState.stepSaveStatus[_currentPage] ==
                    SaveSyncStatus.failed ||
                (onboardingState.stepSaveStatus[_currentPage] ==
                        SaveSyncStatus.dirty &&
                    (onboardingState.validationMessage?.startsWith(
                              'Your latest changes still need to sync.',
                            ) ==
                            true ||
                        onboardingState.validationMessage?.startsWith(
                              "Couldn't sync your changes.",
                            ) ==
                            true))
            ? () => _saveStep(_currentPage)
            : null,
        onDotTap: _onDotTapped,
        onIndicatorDraggedTo: _onIndicatorDraggedTo,
        onNext: _onNextPressed,
        onSave: null,
        showSave: showSave,
        isSaving: onboardingState.stepLoading[_currentPage] || _isSaving,
        isSaved: isSaved,
        saveEnabled: !_isSaving && !onboardingState.stepLoading[_currentPage],
        ctaLabel: ctaLabel,
        showPrimaryCta: showPrimaryCta,
        ctaEnabled: ctaEnabled,
        ctaLoading: _isNavigating,
        topLeftOverlay: _showTopLeftOverlay(onboardingState.draft)
            ? OnboardingStageBackButton(
                key: Key('onboarding-step$_currentPage-back'),
                onTap: _goToPreviousStep,
              )
            : null,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const OnboardingStep0(),
            const OnboardingStep1(),
            const OnboardingStep2(),
            const OnboardingStep3(),
            const OnboardingStep4(),
            const OnboardingStep5(),
            const OnboardingStep6(),
            const OnboardingStep7(),
            const OnboardingStep8(),
            const OnboardingStep9(),
            const OnboardingStep10(),
            const OnboardingStep11(),
            const OnboardingStep12(),
            const OnboardingStep13(),
            OnboardingStep14(onJumpToStep: _onDotTapped),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleInternalNextIfNeeded() async {
    final draft = ref.read(mockOnboardingProvider).draft;
    return switch (_currentPage) {
      onboardingClassJobStepIndex => _nextClassesJob(draft),
      onboardingEatingStepIndex => _nextEating(draft),
      onboardingFixedStepIndex => _nextFixed(draft),
      onboardingSkinCareStepIndex => _nextSkinCare(draft),
      _ => Future.value(false),
    };
  }

  bool _backClassesJob(OnboardingDraft draft) {
    // Simplified: no internal stages, always go back to previous step.
    return false;
  }

  bool _backEating(OnboardingDraft draft) {
    final base = draft.baseTimeline;
    if (base.eatingSetupStep <= 0) return false;
    _updateBaseTimelineStage(
      onboardingEatingStepIndex,
      (base) => base.copyWith(eatingSetupStep: 0),
    );
    return true;
  }

  bool _backFixed(OnboardingDraft draft) => false;

  bool _backSkinCare(OnboardingDraft draft) {
    final base = draft.baseTimeline;

    if (base.skinCareSetupStep <= 0) {
      return false;
    }

    _updateBaseTimelineStage(
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        skinCareSetupStep: 0,
        // keep saved answers/blocks unless user explicitly clears them
      ),
    );

    return true;
  }

  List<TimelineBlockDraft> _timelineBlocksFromLocalSchedule(
    List<ClassRoutineBlock> localBlocks,
    String section,
  ) {
    return localBlocks
        .where((block) => block.subject.trim().isNotEmpty)
        .where((block) => block.startMinute < block.endMinute)
        .expand<TimelineBlockDraft>((block) {
          final repeatDays = _repeatDaysForClassJobSave(block.repeatDays);
          if (repeatDays.isEmpty) return const <TimelineBlockDraft>[];
          return [
            TimelineBlockDraft(
              id: block.id,
              section: section,
              title: block.subject.trim(),
              startMinute: block.startMinute,
              endMinute: block.endMinute,
              repeatDays: repeatDays,
              location: block.room.trim().isEmpty ? null : block.room.trim(),
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
            ),
          ];
        })
        .toList(growable: false);
  }

  List<int> _repeatDaysForClassJobSave(List<int> days) {
    return days.where((day) => day >= 1 && day <= 7).toSet().toList()..sort();
  }

  bool _classJobActionBusy(OnboardingDraft _, {required bool watch}) {
    final aiState = watch
        ? ref.watch(routineImportAiControllerProvider)
        : ref.read(routineImportAiControllerProvider);
    final uploadState = watch
        ? ref.watch(uploadControllerProvider)
        : ref.read(uploadControllerProvider);
    final uploadApplies =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.isBusy;
    return aiState.isExtracting || uploadApplies;
  }

  Future<bool> _nextClassesJob(OnboardingDraft draft) async {
    final role = draft.lifeRole.lifeRole;
    final classesRequired =
        role == LifeRoleDraft.studentKey ||
        role == LifeRoleDraft.studentWorkingKey;
    final workRequired =
        role == LifeRoleDraft.workingKey ||
        role == LifeRoleDraft.studentWorkingKey ||
        role == LifeRoleDraft.businessKey;
    if (!classesRequired && !workRequired) return false;

    if (_classJobActionBusy(draft, watch: false)) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      return true;
    }

    // Read generated blocks from unified step 4 providers
    final localClassBlocks = ref.read(onboardingClassTimelineProvider);
    final localWorkBlocks = ref.read(onboardingWorkTimelineProvider);
    final visibleClassBlocks = _timelineBlocksFromLocalSchedule(
      localClassBlocks,
      'classes',
    );
    final visibleWorkBlocks = _timelineBlocksFromLocalSchedule(
      localWorkBlocks,
      'job_work_business',
    );
    final hasClassBlocks = visibleClassBlocks.isNotEmpty;
    final hasWorkBlocks = visibleWorkBlocks.isNotEmpty;

    // Validate
    if (classesRequired &&
        workRequired &&
        (!hasClassBlocks || !hasWorkBlocks)) {
      _setInternalValidation('Generate both class and work schedules first.');
      return true;
    }
    if (classesRequired && !hasClassBlocks) {
      _setInternalValidation('Generate your class timeline first.');
      return true;
    }
    if (workRequired && !hasWorkBlocks) {
      _setInternalValidation(
        role == LifeRoleDraft.businessKey
            ? 'Generate your work/business timeline first.'
            : 'Generate your work timeline first.',
      );
      return true;
    }

    // Build all blocks to save
    final allNewBlocks = <TimelineBlockDraft>[];
    if (classesRequired) {
      allNewBlocks.addAll(visibleClassBlocks);
    }
    if (workRequired) {
      allNewBlocks.addAll(visibleWorkBlocks);
    }

    ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
      final base = draft.baseTimeline;
      final nextBlocks =
          base.blocks
              .where(
                (b) =>
                    b.section != 'classes' && b.section != 'job_work_business',
              )
              .toList()
            ..addAll(allNewBlocks);
      final nextPending = base.pendingFutureImports
          .where(
            (entry) =>
                entry.section != onboardingSectionClasses &&
                entry.section != onboardingSectionWork,
          )
          .toList(growable: false);
      return draft.copyWith(
        baseTimeline: base.copyWith(
          classJobSetupStep: 5,
          blocks: nextBlocks,
          pendingFutureImports: nextPending,
        ),
        clearFinalPreview: true,
      );
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepDirty(onboardingClassJobStepIndex, true);

    // The outer flow now performs the only durable save/verification and may
    // advance only after that succeeds.
    return false;
  }

  Future<bool> _nextEating(OnboardingDraft draft) async {
    final base = draft.baseTimeline;
    final stage = base.eatingSetupStep;
    final path = base.eatingSetupPath;
    if (stage == 0) {
      if (path == null) {
        _setInternalValidation('Choose how to set up eating.');
        return true;
      }
      _updateBaseTimelineStage(
        onboardingEatingStepIndex,
        (base) => base.copyWith(eatingSetupStep: 1),
      );
      return true;
    }

    if (path == onboardingEatingPathHasRoutine ||
        path == onboardingEatingPathCreate ||
        path == 'no_routine') {
      if (!base.hasConfirmedSection('eating')) {
        _setInternalValidation('Generate your meal routine first.');
        return true;
      }
      return false;
    }

    _setInternalValidation('Choose how to set up eating.');
    return true;
  }

  Future<bool> _nextFixed(OnboardingDraft draft) async => false;

  Future<bool> _nextSkinCare(OnboardingDraft draft) async {
    final base = draft.baseTimeline;
    if (base.skinCareSkipped) return false;

    if (base.skinCareSetupPath == null) {
      _setInternalValidation('Choose skin care setup or skip.');
      return true;
    }

    final blocks = base.confirmedBlocksForSection('skin_care');
    if (base.skinCareSetupPath == 'has_products') {
      final desired = onboarding7NormalizeDesiredApplications(
        base.skinCareDesiredApplicationsPerDay,
      );
      final missingMessage = onboarding7MissingRoutineMessage(blocks, desired);
      if (missingMessage == null) return false;
      _setInternalValidation(missingMessage);
      return true;
    }
    if (blocks.isNotEmpty) return false;

    _setInternalValidation(
      'Generate a routine before moving to the next step.',
    );
    return true;
  }

  void _setInternalValidation(String message) {
    ref.read(mockOnboardingProvider.notifier).setValidationMessage(message);
  }

  void _updateBaseTimelineStage(
    int stepIndex,
    BaseTimelineDraft Function(BaseTimelineDraft base) update,
  ) {
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: update(draft.baseTimeline),
            clearFinalPreview: true,
          ),
        );
    ref.read(mockOnboardingProvider.notifier).setStepDirty(stepIndex, true);
  }
}

@visibleForTesting
bool onboardingShouldShowTopLeftBackButton({
  required int currentPage,
  required BaseTimelineDraft baseTimeline,
}) {
  if (currentPage == onboardingEatingStepIndex) {
    return baseTimeline.eatingSetupStep > 0;
  }
  // Skin Care has both page-level and internal navigation. On its choice
  // screen this returns to Fixed Schedule; inside a path it returns to choice.
  if (currentPage == onboardingSkinCareStepIndex) return true;
  return false;
}
