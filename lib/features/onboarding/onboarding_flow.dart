import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  double _pageOffset = 0.0;
  int _currentPage = 0;
  bool _isSaving = false; // Double-tap prevention for Save
  bool _isNavigating = false; // Double-tap prevention for Next

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _nameController = TextEditingController();
    _nameFocus = FocusNode();

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
      }
    });

    // Populate current display name if present in mock profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentProfileName = ref.read(mockUserProfileProvider).displayName;
      if (currentProfileName.isNotEmpty && currentProfileName != 'Member') {
        _nameController.text = currentProfileName;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // Helper validation per step
  String? _validateStep(int step) {
    switch (step) {
      case 0:
        return null; // Bypassed since step 0 is just a welcome screen now
      case 1:
        final pledge = ref.read(mockOnboardingProvider).stepCompleted[1];
        if (!pledge) {
          return 'Please read and commit to the Patience Pledge to proceed.';
        }
        break;
      case 2:
        final role = ref.read(mockUserProfileProvider).lifeRole;
        if (role.isEmpty) {
          return 'Please select a lifestyle role that matches your schedule.';
        }
        break;
      case 3:
        final profile = ref.read(mockUserProfileProvider);
        if (profile.height <= 0 || profile.weight <= 0) {
          return 'Please enter non-zero height and weight measurements.';
        }
        break;
      case 4:
        final hasConflicts = ref
            .read(mockRoutineProvider)
            .any((r) => r.hasConflict);
        if (hasConflicts) {
          return 'Please resolve routine collisions (clashing sleep & shift times).';
        }
        break;
    }
    return null;
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
    if (step == 0) {
      final current = ref.read(mockUserProfileProvider);
      final enteredName = _nameController.text.trim();
      ref
          .read(mockUserProfileProvider.notifier)
          .updateProfile(
            current.copyWith(
              displayName: enteredName.isEmpty ? 'Member' : enteredName,
            ),
          );
    }

    ref.read(mockOnboardingProvider.notifier).setStepLoading(step, false);
    ref.read(mockOnboardingProvider.notifier).setStepCompleted(step, true);
    ref.read(mockOnboardingProvider.notifier).setStepDirty(step, false);

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
      if (mounted) {
        context.go('/app');
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
    bool ctaEnabled = true;

    if (_currentPage == 0) {
      ctaLabel = 'Get Started';
    } else if (_currentPage == 11) {
      ctaLabel = 'Enter Optivus';
      ctaEnabled = onboardingState.stepCompleted.sublist(0, 11).every((c) => c);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
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
            OnboardingStep0(
              nameController: _nameController,
              nameFocus: _nameFocus,
            ),
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
