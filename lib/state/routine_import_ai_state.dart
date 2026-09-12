import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/auth_generation.dart';

enum RoutineImportAiStatus { idle, extracting, extracted, failed }

class RoutineImportAiState {
  final AiGenerationState lifecycle;
  final RoutineImportExtractionResult? result;
  final String? errorMessage;

  const RoutineImportAiState({
    this.lifecycle = const AiGenerationState(),
    this.result,
    this.errorMessage,
  });

  const RoutineImportAiState.extracting({this.result, this.errorMessage})
    : lifecycle = const AiGenerationState(
        phase: AiGenerationPhase.generating,
        operationId: 'legacy-extracting',
        attempt: 1,
      );

  const RoutineImportAiState.extracted({this.result, this.errorMessage})
    : lifecycle = const AiGenerationState(
        phase: AiGenerationPhase.success,
        operationId: 'legacy-extracted',
        attempt: 1,
      );

  const RoutineImportAiState.failed({this.result, this.errorMessage})
    : lifecycle = const AiGenerationState(
        phase: AiGenerationPhase.error,
        operationId: 'legacy-failed',
        attempt: 1,
      );

  RoutineImportAiStatus get status => switch (lifecycle.phase) {
    AiGenerationPhase.idle => RoutineImportAiStatus.idle,
    AiGenerationPhase.success => RoutineImportAiStatus.extracted,
    AiGenerationPhase.error => RoutineImportAiStatus.failed,
    _ => RoutineImportAiStatus.extracting,
  };

  bool get isExtracting => lifecycle.isActive;

  RoutineImportAiState copyWith({
    AiGenerationState? lifecycle,
    RoutineImportExtractionResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return RoutineImportAiState(
      lifecycle: lifecycle ?? this.lifecycle,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RoutineImportAiController extends StateNotifier<RoutineImportAiState> {
  final Ref _ref;
  final RoutineImportAiClient _client;
  final AiGenerationController _lifecycle = AiGenerationController();

  RoutineImportAiController(this._ref, this._client)
    : super(const RoutineImportAiState()) {
    _lifecycle.addListener(_publishLifecycle);
  }

  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) async {
    if (_lifecycle.state.isActive) return null;

    final user = _ref.read(authProvider).user;
    final preflightError = routineImportAiPreflightError(
      review: review,
      signedIn: user != null && user.uid.trim().isNotEmpty,
      emailVerified: user?.emailVerified ?? false,
    );
    if (preflightError != null) {
      return _fail(preflightError);
    }
    final verifiedUser = user!;
    final authGeneration = _ref.read(authGenerationProvider);
    if (verifiedUser.uid.trim().isEmpty) {
      return _fail('Sign in before running AI extraction.');
    }

    final run = await _lifecycle.run<RoutineImportExtractionResult>(
      operationType: 'routine-import',
      timeoutPolicy: AiOperationTimeouts.routineImport,
      isSessionCurrent: () =>
          _ref.read(authProvider).user?.uid == verifiedUser.uid &&
          _ref.read(authGenerationProvider) == authGeneration,
      mapError: (error) {
        if (error is MissingConfigException) {
          return AiGenerationError(
            category: AiGenerationErrorCategory.serviceUnavailable,
            message: error.message,
            canRetry: true,
          );
        }
        return const AiGenerationError(
          category: AiGenerationErrorCategory.serviceUnavailable,
          message: 'AI is temporarily unavailable. Try again.',
          canRetry: true,
        );
      },
      operation: (scope) async {
        final idToken = await _ref
            .read(authRepositoryProvider)
            .currentIdToken();
        if (!scope.isCurrent) throw const _StaleAiOperation();
        if (idToken == null || idToken.trim().isEmpty) {
          throw const MissingConfigException(
            'Please sign in again before running AI extraction.',
          );
        }
        scope.transition(
          AiGenerationPhase.generating,
          message: 'Reading your schedule…',
        );
        return _client.extract(
          uid: verifiedUser.uid,
          idToken: idToken,
          review: review.copyWith(uid: verifiedUser.uid),
        );
      },
    );
    if (run.ignored || run.duplicate) return null;
    if (run.error != null) {
      debugPrint(
        '[RoutineImportAiController] AI extraction failed '
        '(${run.error!.category.name}).',
      );
      return null;
    }
    final result = run.value!;
    state = RoutineImportAiState(lifecycle: _lifecycle.state, result: result);
    return result;
  }

  /// Explicitly cancels any active in-flight extraction, invalidating late
  /// responses and resetting the shared lifecycle to idle immediately so
  /// a subsequent extraction can begin without delay.
  void cancelCurrentExtraction() {
    _lifecycle.cancel();
    state = const RoutineImportAiState();
  }

  void reset() {
    _lifecycle.reset();
    state = const RoutineImportAiState();
  }

  void resetForSignedOut() {
    _lifecycle.reset();
    state = const RoutineImportAiState();
  }

  RoutineImportExtractionResult? _fail(String message) {
    state = RoutineImportAiState(
      lifecycle: AiGenerationState(
        phase: AiGenerationPhase.error,
        phaseStartedAt: DateTime.now(),
        message: message,
        error: AiGenerationError(
          category: AiGenerationErrorCategory.invalidInput,
          message: message,
          canRetry: false,
        ),
      ),
      errorMessage: message,
    );
    return null;
  }

  void _publishLifecycle() {
    state = RoutineImportAiState(
      lifecycle: _lifecycle.state,
      result: _lifecycle.state.phase == AiGenerationPhase.success
          ? state.result
          : null,
      errorMessage: _lifecycle.state.error?.message,
    );
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_publishLifecycle);
    _lifecycle.dispose();
    super.dispose();
  }
}

class _StaleAiOperation implements Exception {
  const _StaleAiOperation();
}

String? routineImportAiPreflightError({
  required RoutineImportReviewDraft review,
  required bool signedIn,
  required bool emailVerified,
  DateTime? now,
}) {
  if (review.blocksDuplicateApply) {
    return 'Already applied reviews cannot run AI extraction.';
  }
  if (review.uploadedAssetR2Key?.trim().isEmpty ?? true) {
    return 'Upload a photo before running AI extraction.';
  }
  if (review.extractionAttemptCount >= 5) {
    return "You've reached the extraction retry limit for this review.";
  }
  final lastExtractedAt = review.lastExtractedAt;
  if (lastExtractedAt != null) {
    final elapsed = (now ?? DateTime.now()).difference(lastExtractedAt);
    if (elapsed.inSeconds < 60) {
      return 'Please wait a moment before running extraction again.';
    }
  }
  if (!signedIn) return 'Sign in before running AI extraction.';
  if (!emailVerified) return 'Verify your email before running AI extraction.';
  return null;
}

final routineImportAiControllerProvider =
    StateNotifierProvider<RoutineImportAiController, RoutineImportAiState>((
      ref,
    ) {
      final client = ref.watch(routineImportAiClientProvider);
      return RoutineImportAiController(ref, client);
    });
