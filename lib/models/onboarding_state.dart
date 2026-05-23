import 'package:optivus/models/onboarding_draft.dart';

class OnboardingState {
  final int currentStep;

  // Track step completion
  final List<bool> stepCompleted;
  final List<bool> stepDirty;
  final List<bool> stepLoading;
  final OnboardingDraft draft;

  // Custom message for disabled steps
  final String? validationMessage;

  OnboardingState({
    this.currentStep = 0,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    OnboardingDraft? draft,
    this.validationMessage,
  }) : stepCompleted = stepCompleted ?? List<bool>.filled(12, false),
       stepDirty = stepDirty ?? List<bool>.filled(12, false),
       stepLoading = stepLoading ?? List<bool>.filled(12, false),
       draft = draft ?? const OnboardingDraft();

  OnboardingState copyWith({
    int? currentStep,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    OnboardingDraft? draft,
    String? validationMessage,
    bool clearValidation = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      stepCompleted: stepCompleted ?? List<bool>.from(this.stepCompleted),
      stepDirty: stepDirty ?? List<bool>.from(this.stepDirty),
      stepLoading: stepLoading ?? List<bool>.from(this.stepLoading),
      draft: draft ?? this.draft,
      validationMessage: clearValidation
          ? null
          : (validationMessage ?? this.validationMessage),
    );
  }
}
