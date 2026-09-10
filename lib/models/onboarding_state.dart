import 'package:optivus/models/onboarding_draft.dart';

/// Runtime-only truth about the durability of each onboarding step.
///
/// This state is intentionally not persisted. A dirty or failed value means
/// the current draft is still available in this process, not that it has been
/// written to durable local storage.
enum SaveSyncStatus { clean, dirty, saving, synced, failed }

class OnboardingState {
  final int currentStep;

  // Track step completion
  final List<bool> stepCompleted;
  final List<bool> stepDirty;
  final List<bool> stepLoading;
  final List<SaveSyncStatus> stepSaveStatus;
  final OnboardingDraft draft;

  // Custom message for disabled steps
  final String? validationMessage;

  OnboardingState({
    int? currentStep,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    List<SaveSyncStatus>? stepSaveStatus,
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
           List<bool>.from((draft ?? const OnboardingDraft()).stepLoading),
       stepSaveStatus =
           stepSaveStatus ??
           _deriveSaveStatuses(draft ?? const OnboardingDraft());

  bool hasUnsyncedChangesAt(int step) =>
      step >= 0 &&
      step < stepSaveStatus.length &&
      (stepSaveStatus[step] == SaveSyncStatus.dirty ||
          stepSaveStatus[step] == SaveSyncStatus.failed);

  OnboardingState copyWith({
    int? currentStep,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    List<SaveSyncStatus>? stepSaveStatus,
    OnboardingDraft? draft,
    String? validationMessage,
    bool clearValidation = false,
  }) {
    final nextDraft = draft ?? this.draft;
    final draftChanged = draft != null;
    final nextStepCompleted =
        stepCompleted ??
        List<bool>.from(
          draftChanged ? nextDraft.stepCompleted : this.stepCompleted,
        );
    final nextStepDirty =
        stepDirty ??
        List<bool>.from(draftChanged ? nextDraft.stepDirty : this.stepDirty);
    final nextStepLoading =
        stepLoading ??
        List<bool>.from(
          draftChanged ? nextDraft.stepLoading : this.stepLoading,
        );
    return OnboardingState(
      currentStep:
          currentStep ??
          (draftChanged ? nextDraft.currentStep : this.currentStep),
      stepCompleted: nextStepCompleted,
      stepDirty: nextStepDirty,
      stepLoading: nextStepLoading,
      stepSaveStatus:
          stepSaveStatus ??
          (draftChanged ||
                  stepDirty != null ||
                  stepCompleted != null ||
                  stepLoading != null
              ? _reconcileSaveStatuses(
                  this.stepSaveStatus,
                  nextStepDirty,
                  nextStepLoading,
                  nextStepCompleted,
                )
              : List<SaveSyncStatus>.from(this.stepSaveStatus)),
      draft: nextDraft,
      validationMessage: clearValidation
          ? null
          : (validationMessage ?? this.validationMessage),
    );
  }

  static List<SaveSyncStatus> _deriveSaveStatuses(OnboardingDraft draft) {
    return _reconcileSaveStatuses(
      const [],
      draft.stepDirty,
      draft.stepLoading,
      draft.stepCompleted,
    );
  }

  static List<SaveSyncStatus> _reconcileSaveStatuses(
    List<SaveSyncStatus> current,
    List<bool> dirty,
    List<bool> loading,
    List<bool> completed,
  ) {
    return List<SaveSyncStatus>.generate(OnboardingDraft.stepCount, (index) {
      final isLoading = index < loading.length && loading[index];
      if (isLoading) return SaveSyncStatus.saving;

      final isDirty = index < dirty.length && dirty[index];
      final isCompleted = index < completed.length && completed[index];
      final currentStatus = index < current.length
          ? current[index]
          : SaveSyncStatus.clean;

      if (currentStatus == SaveSyncStatus.failed && isDirty) {
        return SaveSyncStatus.failed;
      }
      if (isDirty) {
        return SaveSyncStatus.dirty;
      }
      if (isCompleted) {
        return SaveSyncStatus.synced;
      }
      return SaveSyncStatus.clean;
    });
  }
}
