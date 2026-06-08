import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus/config/backend_config.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/views/screens/loading_screen.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_steps.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';

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
    return ref
        .read(mockOnboardingProvider)
        .draft
        .currentStep
        .clamp(0, OnboardingDraft.lastStepIndex);
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
    return user != null && user.providerId == 'password' && !user.emailVerified;
  }

  String? _currentPersistenceUid() {
    final authUser = ref.read(authProvider).user;
    if (_needsEmailVerification(authUser)) return null;
    if (OptivusBackendConfig.useFirebase && authUser == null) return null;
    return authUser?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
  }

  Future<void> _persistCurrentDraftAfterNavigation() async {
    final uid = _currentPersistenceUid();
    if (uid == null) return;

    final draft = ref.read(mockOnboardingProvider).draft.copyWith(uid: uid);

    try {
      await ref.read(onboardingRepositoryProvider).saveDraft(draft);
    } catch (_) {
      if (!mounted) return;
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            OptivusBackendConfig.useFirebase
                ? 'Your progress is saved locally, but cloud sync failed. Please check your connection.'
                : null,
          );
    }
  }

  // Core Save step action — with double-tap prevention
  Future<bool> _saveStep(int step) async {
    if (_isSaving) return false; // Prevent double tap
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

      ref.read(mockOnboardingProvider.notifier).setStepLoading(step, true);
      ref.read(mockOnboardingProvider.notifier).clearValidation();

      // Simulate offline-first save database delay
      await Future.delayed(const Duration(milliseconds: 600));

      final onboardingNotifier = ref.read(mockOnboardingProvider.notifier);
      onboardingNotifier.saveStep(
        step,
        uid: uid,
        transform: (draft) {
          if (step == 0) {
            return draft.copyWith(welcomeSaved: true);
          }
          if (step == 3) {
            return draft.copyWith(bodyBasics: draft.bodyBasics.withEstimates());
          }
          if (step == OnboardingDraft.lastStepIndex) {
            return draft.copyWith(finalPreview: draft.buildFinalPreview());
          }
          return draft;
        },
      );

      final savedDraft = ref.read(mockOnboardingProvider).draft;
      await ref.read(onboardingRepositoryProvider).saveDraft(savedDraft);

      return true;
    } catch (e) {
      ref.read(mockOnboardingProvider.notifier).setStepDirty(step, true);
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            OptivusBackendConfig.useFirebase
                ? 'Could not save this step. Please check your connection and try again.'
                : e.toString(),
          );
      return false;
    } finally {
      ref.read(mockOnboardingProvider.notifier).setStepLoading(step, false);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Next step trigger action — with double-tap prevention
  void _onNextPressed() async {
    if (_isNavigating) return; // Prevent double tap
    setState(() => _isNavigating = true);

    try {
      final onboardingState = ref.read(mockOnboardingProvider);
      if (_currentPage == OnboardingDraft.lastStepIndex) {
        await _completeOnboarding();
        return;
      }

      if (await _handleInternalNextIfNeeded()) {
        return;
      }

      final isDirty = onboardingState.stepDirty[_currentPage];
      final isCompleted = onboardingState.stepCompleted[_currentPage];

      // If dirty or not completed, force save logic
      if (isDirty || !isCompleted) {
        final saveSuccess = await _saveStep(_currentPage);
        if (!saveSuccess) {
          return; // Stop if invalid
        }
      }

      // Otherwise slide to the next step
      _currentPage++;
      ref.read(mockOnboardingProvider.notifier).setStep(_currentPage);
      await _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      await _persistCurrentDraftAfterNavigation();
    } catch (e) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(e.toString());
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

    final saveSuccess = await _saveStep(OnboardingDraft.lastStepIndex);
    if (!saveSuccess) {
      return;
    }

    final savedDraft = ref.read(mockOnboardingProvider).draft;
    final uid = _currentPersistenceUid();
    if (uid == null) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Please verify your email before finishing onboarding.',
          );
      return;
    }

    final draftForBundle = savedDraft.copyWith(uid: uid);
    final bundle = OnboardingCompletionService.buildBundle(draftForBundle);
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

    final now = DateTime.now();
    final finalDraft = draftForBundle.copyWith(
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

    try {
      await ref
          .read(onboardingRepositoryProvider)
          .completeOnboarding(finalDraft: finalDraft, bundle: bundle);
    } catch (_) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(
            'Could not finish setup. Please check your connection and try again.',
          );
      return;
    }

    await const OnboardingFrontendHydrationService().hydrate(
      read: ref.read,
      bundle: bundle,
    );
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

    final authUser = ref.read(authProvider).user;
    if (authUser != null) {
      await ref.read(authProvider.notifier).markOnboardingComplete(authUser);
    }

    if (mounted) {
      context.go('/app?tab=0');
    }
  }

  int _lastCompletedStep(List<bool> completedSteps) {
    var lastCompleted = 0;

    for (var i = 0; i < completedSteps.length; i++) {
      if (!completedSteps[i]) {
        break;
      }
      lastCompleted = i;
    }

    return lastCompleted;
  }

  Future<void> _navigateToIndicatorStep(int index) async {
    final onboardingState = ref.read(mockOnboardingProvider);
    final boundedIndex = index.clamp(
      0,
      onboardingState.stepCompleted.length - 1,
    );

    if (boundedIndex == _currentPage) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      return;
    }

    final lastCompleted = _lastCompletedStep(onboardingState.stepCompleted);
    final isBackward = boundedIndex < _currentPage;
    final isSavedForwardStep = boundedIndex <= lastCompleted;
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

    _currentPage = boundedIndex;
    ref.read(mockOnboardingProvider.notifier).setStep(boundedIndex);
    await _pageController.animateToPage(
      boundedIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    await _persistCurrentDraftAfterNavigation();
  }

  void _goToPreviousStep() {
    if (_handleInternalBackIfNeeded()) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final onboardingState = ref.watch(mockOnboardingProvider);
    if (authState.isLoading) {
      return const LoadingScreen(message: 'Restoring your setup...');
    }
    if (authState.backendRestoreFailed) {
      return const LoadingScreen();
    }

    if (!_initialDraftReady) {
      _scheduleInitialDraftSync();
      return const LoadingScreen(message: 'Restoring your setup...');
    }

    final bool isSaved =
        onboardingState.stepCompleted[_currentPage] &&
        !onboardingState.stepDirty[_currentPage];
    final bool showSave = false; // Globally hidden for onboarding.

    String ctaLabel = 'Next Step';
    bool ctaEnabled =
        !_isNavigating &&
        !_isSaving &&
        !onboardingState.stepLoading[_currentPage];
    final classJobActionBusy =
        _currentPage == onboardingClassJobStepIndex &&
        _classJobActionBusy(onboardingState.draft, watch: true);

    if (_currentPage == 0) {
      ctaLabel = 'Get Started';
    } else if (_currentPage == OnboardingDraft.lastStepIndex) {
      ctaLabel = 'Enter Optivus';
      ctaEnabled = !_isNavigating && !_isSaving;
    }
    if (classJobActionBusy) {
      ctaEnabled = false;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goToPreviousStep();
      },
      child: OnboardingStepShell(
        currentPage: _currentPage,
        pageOffset: _pageOffset,
        completedSteps: onboardingState.stepCompleted,
        validationMessage: onboardingState.validationMessage,
        onDotTap: _onDotTapped,
        onIndicatorDraggedTo: _onIndicatorDraggedTo,
        onNext: _onNextPressed,
        onSave: null,
        showSave: showSave,
        isSaving: onboardingState.stepLoading[_currentPage] || _isSaving,
        isSaved: isSaved,
        saveEnabled: !_isSaving && !onboardingState.stepLoading[_currentPage],
        ctaLabel: ctaLabel,
        ctaEnabled: ctaEnabled,
        ctaLoading: _isNavigating,
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
    final path = base.eatingSetupPath;
    final stages = path == 'has_routine'
        ? const [0, 1, 2, 3]
        : const [0, 1, 2, 3, 4, 5];
    final previous = _previousInternalStage(base.eatingSetupStep, stages);
    if (previous == null) return false;
    _updateBaseTimelineStage(
      onboardingEatingStepIndex,
      (base) => base.copyWith(eatingSetupStep: previous),
    );
    return true;
  }

  bool _backFixed(OnboardingDraft draft) {
    final previous = _previousInternalStage(
      draft.baseTimeline.fixedScheduleSetupStep,
      const [0, 1, 2, 3, 4, 5],
    );
    if (previous == null) return false;
    _updateBaseTimelineStage(
      onboardingFixedStepIndex,
      (base) => base.copyWith(fixedScheduleSetupStep: previous),
    );
    return true;
  }

  bool _backSkinCare(OnboardingDraft draft) {
    final base = draft.baseTimeline;
    if (base.skinCareSkipped) {
      _updateBaseTimelineStage(
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(skinCareSkipped: false, skinCareSetupStep: 0),
      );
      return true;
    }
    final stages = base.skinCareSetupPath == 'has_products'
        ? const [0, 1, 2, 3]
        : const [0, 1, 2, 3, 4, 5, 6, 7];
    final previous = _previousInternalStage(base.skinCareSetupStep, stages);
    if (previous == null) return false;
    _updateBaseTimelineStage(
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(skinCareSetupStep: previous),
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
        .map((block) {
          return TimelineBlockDraft(
            id: block.id,
            section: section,
            title: block.subject.trim(),
            startMinute: block.startMinute,
            endMinute: block.endMinute,
            repeatDays: block.repeatDays,
            location: block.room.trim().isEmpty ? null : block.room.trim(),
            blockType: TimelineBlockDraft.hardBlockKey,
            source: 'ai_import',
          );
        })
        .toList(growable: false);
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
      _setInternalValidation('Generate your work timeline first.');
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

    // Save all blocks to baseTimeline at once
    _updateBaseTimelineStage(onboardingClassJobStepIndex, (base) {
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
      return base.copyWith(
        classJobSetupStep: 5,
        blocks: nextBlocks,
        pendingFutureImports: nextPending,
      );
    });
    await _persistCurrentDraftAfterNavigation();

    // Return false to let outer flow advance to step 5
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

    if (path == 'has_routine') {
      if (stage == 1 &&
          !_sectionHasUploadOrBlocks(base, onboardingSectionEating)) {
        _setInternalValidation('Upload your eating routine or menu.');
        return true;
      }
      if (stage == 2 && !base.hasConfirmedSection('eating')) {
        _setInternalValidation(
          base.sectionNeedsImportReview(onboardingSectionEating)
              ? 'Review AI draft to continue.'
              : 'Upload your eating routine or menu.',
        );
        return true;
      }
      final next = _nextInternalStage(stage, const [1, 2, 3]);
      if (next == null) return false;
      _updateBaseTimelineStage(
        onboardingEatingStepIndex,
        (base) => base.copyWith(eatingSetupStep: next),
      );
      return true;
    }

    if (stage == 1 && base.mealPlanningGoal == null) {
      _setInternalValidation('Choose an eating goal.');
      return true;
    }
    if (stage == 2 && base.eatingMode == null) {
      _setInternalValidation('Choose your eating situation.');
      return true;
    }
    if (stage == 3) {
      final detailError = _eatingDetailError(base);
      if (detailError != null) {
        _setInternalValidation(detailError);
        return true;
      }
      _updateBaseTimelineStage(
        onboardingEatingStepIndex,
        (base) => upsertGeneratedEatingImport(
          base.copyWith(eatingSetupStep: 4),
          draft.bodyBasics,
        ),
      );
      if (!mounted) return true;
      await openOnboardingImportReview(
        context,
        source: onboardingImportSourceForSection(onboardingSectionEating),
        autoRunAiOnLoad: false,
      );
      return true;
    }
    if (stage == 4 && !base.hasConfirmedSection('eating')) {
      _setInternalValidation('Review AI draft to continue.');
      return true;
    }
    final next = _nextInternalStage(stage, const [1, 2, 3, 4, 5]);
    if (next == null) return false;
    _updateBaseTimelineStage(
      onboardingEatingStepIndex,
      (base) => base.copyWith(eatingSetupStep: next),
    );
    return true;
  }

  Future<bool> _nextFixed(OnboardingDraft draft) async {
    final stage = draft.baseTimeline.fixedScheduleSetupStep;
    final next = _nextInternalStage(stage, const [0, 1, 2, 3, 4, 5]);
    if (next == null) return false;
    _updateBaseTimelineStage(
      onboardingFixedStepIndex,
      (base) =>
          base.withRequiredFixedBlocks().copyWith(fixedScheduleSetupStep: next),
    );
    return true;
  }

  Future<bool> _nextSkinCare(OnboardingDraft draft) async {
    final base = draft.baseTimeline;
    if (base.skinCareSkipped) return false;
    final stage = base.skinCareSetupStep;
    final path = base.skinCareSetupPath;
    if (stage == 0) {
      if (path == null) {
        _setInternalValidation('Choose skincare setup or skip.');
        return true;
      }
      _updateBaseTimelineStage(
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(skinCareSetupStep: 1),
      );
      return true;
    }

    if (path == 'has_products') {
      if (stage == 1) {
        if (_skinProductNames(base).isNotEmpty) {
          _updateBaseTimelineStage(
            onboardingSkinCareStepIndex,
            (base) => upsertGeneratedSkinCareImport(
              base.copyWith(skinCareSetupStep: 2),
            ),
          );
          if (!mounted) return true;
          await openOnboardingImportReview(
            context,
            source: onboardingImportSourceForSection(onboardingSectionSkinCare),
            autoRunAiOnLoad: false,
          );
          return true;
        }
        if (!_sectionHasUploadOrBlocks(base, onboardingSectionSkinCare)) {
          _setInternalValidation(
            'Add product photo or product names, or skip.',
          );
          return true;
        }
      }
      if (stage == 2 && !base.hasConfirmedSection('skin_care')) {
        _setInternalValidation('Review AI draft to continue.');
        return true;
      }
      final next = _nextInternalStage(stage, const [1, 2, 3]);
      if (next == null) return false;
      _updateBaseTimelineStage(
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(skinCareSetupStep: next),
      );
      return true;
    }

    if (stage == 1 &&
        !base.skinCareFacePhotoSkipped &&
        !_sectionHasUploadOrBlocks(base, onboardingSectionSkinCare)) {
      _setInternalValidation('Upload face photo or skip photo.');
      return true;
    }
    if (stage == 2 && base.skinCareSkinType == null) {
      _setInternalValidation('Choose your skin type.');
      return true;
    }
    if (stage == 3 && base.skinCareProblems.isEmpty) {
      _setInternalValidation('Choose skin problems or None.');
      return true;
    }
    if (stage == 4 && base.skinCareBudget == null) {
      _setInternalValidation('Choose skin care budget.');
      return true;
    }
    if (stage == 5) {
      if (base.skinCarePreference == null) {
        _setInternalValidation('Choose simple, minimal, or advanced.');
        return true;
      }
      _updateBaseTimelineStage(
        onboardingSkinCareStepIndex,
        (base) =>
            upsertGeneratedSkinCareImport(base.copyWith(skinCareSetupStep: 6)),
      );
      if (!mounted) return true;
      await openOnboardingImportReview(
        context,
        source: onboardingImportSourceForSection(onboardingSectionSkinCare),
        autoRunAiOnLoad: false,
      );
      return true;
    }
    if (stage == 6 && !base.hasConfirmedSection('skin_care')) {
      _setInternalValidation('Review AI draft to continue.');
      return true;
    }
    final next = _nextInternalStage(stage, const [1, 2, 3, 4, 5, 6, 7]);
    if (next == null) return false;
    _updateBaseTimelineStage(
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(skinCareSetupStep: next),
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

  int? _nextInternalStage(int current, List<int> stages) {
    for (final stage in stages) {
      if (stage > current) return stage;
    }
    return null;
  }

  int? _previousInternalStage(int current, List<int> stages) {
    for (var i = stages.length - 1; i >= 0; i--) {
      if (stages[i] < current) return stages[i];
    }
    return null;
  }

  bool _sectionHasUploadOrBlocks(BaseTimelineDraft base, String sectionLabel) {
    final sectionKey = onboardingTimelineSectionKey(sectionLabel);
    final pending = base.latestImportForSection(sectionLabel);
    return base.hasConfirmedSection(sectionKey) ||
        pending?.hasUploadedAssetReference == true ||
        pending?.parsedBlocks.isNotEmpty == true;
  }

  String? _eatingDetailError(BaseTimelineDraft base) {
    if (base.eatingMode == 'self_cook') {
      if (base.foodType == null) return 'Choose veg, egg, or non-veg.';
      if (base.mealBudget == null) return 'Choose meal budget.';
      if (base.cookingAbility == null) return 'Choose cooking skill.';
      if (base.mealsPerDay == null) return 'Choose meals per day.';
    }
    return null;
  }

  List<String> _skinProductNames(BaseTimelineDraft base) {
    return base.skinCareProductNames
            ?.split(RegExp(r'[\n,]+'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false) ??
        const [];
  }
}
