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
    int? currentStep,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    OnboardingDraft? draft,
    this.validationMessage,
  }) : draft = draft ?? const OnboardingDraft(),
       currentStep =
           currentStep ?? (draft ?? const OnboardingDraft()).currentStep,
       stepCompleted =
           stepCompleted ??
           List<bool>.from((draft ?? const OnboardingDraft()).stepCompleted),
       stepDirty =
           stepDirty ??
           List<bool>.from((draft ?? const OnboardingDraft()).stepDirty),
       stepLoading =
           stepLoading ??
           List<bool>.from((draft ?? const OnboardingDraft()).stepLoading);

  OnboardingState copyWith({
    int? currentStep,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    OnboardingDraft? draft,
    String? validationMessage,
    bool clearValidation = false,
  }) {
    final nextDraft = draft ?? this.draft;
    final draftChanged = draft != null;
    return OnboardingState(
      currentStep:
          currentStep ??
          (draftChanged ? nextDraft.currentStep : this.currentStep),
      stepCompleted:
          stepCompleted ??
          List<bool>.from(
            draftChanged ? nextDraft.stepCompleted : this.stepCompleted,
          ),
      stepDirty:
          stepDirty ??
          List<bool>.from(draftChanged ? nextDraft.stepDirty : this.stepDirty),
      stepLoading:
          stepLoading ??
          List<bool>.from(
            draftChanged ? nextDraft.stepLoading : this.stepLoading,
          ),
      draft: nextDraft,
      validationMessage: clearValidation
          ? null
          : (validationMessage ?? this.validationMessage),
    );
  }
}
