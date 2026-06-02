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

import 'package:optivus/features/onboarding/steps/onboarding_steps.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';

// ── Main Onboarding Flow Wizard ──────────────────────────────────────────────
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late final PageController _pageController;

  double _pageOffset = 0.0;
  int _currentPage = 0;
  bool _isSaving = false; // Double-tap prevention for Save
  bool _isNavigating = false; // Double-tap prevention for Next

  @override
  void initState() {
    super.initState();
    final initialStep = ref
        .read(mockOnboardingProvider)
        .draft
        .currentStep
        .clamp(0, OnboardingDraft.lastStepIndex);
    _currentPage = initialStep;
    _pageOffset = initialStep.toDouble();
    _pageController = PageController(initialPage: initialStep);

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
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
          if (step == 11) {
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

    ref
        .read(mockRoutineProvider.notifier)
        .replaceWith(bundle.routineItemsForApp);
    ref.read(mockGoalProvider.notifier).replaceWith(bundle.identityGoalSystems);
    ref.read(mockTrackerProvider.notifier).applyOnboardingBundle(bundle);
    ref
        .read(mockCoachPreferencesProvider.notifier)
        .updatePreferences(bundle.coachPreferences);
    ref
        .read(mockNotificationPreferencesProvider.notifier)
        .updatePreferences(bundle.notificationPreferences);
    ref.read(mockUserProfileProvider.notifier).applyOnboardingBundle(bundle);
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
  }

  void _onDotTapped(int index) => _navigateToIndicatorStep(index);

  void _onIndicatorDraggedTo(int index) => _navigateToIndicatorStep(index);

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(mockOnboardingProvider);
    final bool isSaved =
        onboardingState.stepCompleted[_currentPage] &&
        !onboardingState.stepDirty[_currentPage];
    final bool showSave = _currentPage >= 2;

    String ctaLabel = 'Next Step';
    bool ctaEnabled = !_isNavigating && !_isSaving;

    if (_currentPage == 0) {
      ctaLabel = 'Get Started';
    } else if (_currentPage == 11) {
      ctaLabel = 'Enter Optivus';
      ctaEnabled = !_isNavigating && !_isSaving;
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
        onSave: showSave ? () => _saveStep(_currentPage) : null,
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
            OnboardingStep11(onJumpToStep: _onDotTapped),
          ],
        ),
      ),
    );
  }
}
