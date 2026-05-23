import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:optivus/state/mock_auth_state.dart';
import 'package:optivus/state/mock_app_state.dart';

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
    _pageController = PageController();

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

  // Core Save step action — with double-tap prevention
  Future<bool> _saveStep(int step) async {
    if (_isSaving) return false; // Prevent double tap
    setState(() => _isSaving = true);

    final validationError = _validateStep(step);
    if (validationError != null) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage(validationError);
      setState(() => _isSaving = false);
      return false;
    }

    ref.read(mockOnboardingProvider.notifier).setStepLoading(step, true);
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    // Simulate offline-first save database delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Save corresponding states
    final onboardingNotifier = ref.read(mockOnboardingProvider.notifier);
    if (step == 0) {
      onboardingNotifier.updateDraft(
        (draft) => draft.copyWith(welcomeSaved: true),
      );
    } else if (step == 3) {
      onboardingNotifier.updateDraft(
        (draft) => draft.copyWith(bodyBasics: draft.bodyBasics.withEstimates()),
      );
    } else if (step == 11) {
      onboardingNotifier.saveFinalPreview();
    }

    onboardingNotifier.setStepLoading(step, false);
    onboardingNotifier.setStepCompleted(step, true);
    onboardingNotifier.setStepDirty(step, false);

    if (mounted) setState(() => _isSaving = false);
    return true;
  }

  // Next step trigger action — with double-tap prevention
  void _onNextPressed() async {
    if (_isNavigating) return; // Prevent double tap
    setState(() => _isNavigating = true);

    final onboardingState = ref.read(mockOnboardingProvider);
    final isDirty = onboardingState.stepDirty[_currentPage];
    final isCompleted = onboardingState.stepCompleted[_currentPage];

    // If dirty or not completed, force save logic
    if (isDirty || !isCompleted) {
      final saveSuccess = await _saveStep(_currentPage);
      if (!saveSuccess) {
        if (mounted) setState(() => _isNavigating = false);
        return; // Stop if invalid
      }
    }

    // Double check gate transition
    if (_currentPage == 11) {
      ref.read(mockUserProfileProvider.notifier).completeOnboarding();
      ref.read(mockAuthProvider.notifier).completeOnboarding();
      if (mounted) {
        context.go('/app?tab=1');
      }
      if (mounted) setState(() => _isNavigating = false);
      return;
    }

    // Otherwise slide to the next step
    _currentPage++;
    ref.read(mockOnboardingProvider.notifier).setStep(_currentPage);
    await _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    if (mounted) setState(() => _isNavigating = false);
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

  void _navigateToIndicatorStep(int index) {
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
    _pageController.animateToPage(
      boundedIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
      ctaEnabled =
          !_isNavigating &&
          !_isSaving &&
          onboardingState.stepCompleted.take(11).every((c) => c) &&
          onboardingState.stepCompleted[11] &&
          !onboardingState.stepDirty[11] &&
          onboardingState.draft.validateStep(
                11,
                onboardingState.stepCompleted,
              ) ==
              null;
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
        ctaLoading: false,
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
