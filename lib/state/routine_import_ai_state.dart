import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/auth_generation.dart';

enum RoutineImportAiStatus { idle, extracting, extracted, failed }

class RoutineImportAiState {
  final RoutineImportAiStatus status;
  final RoutineImportExtractionResult? result;
  final String? errorMessage;

  const RoutineImportAiState({
    this.status = RoutineImportAiStatus.idle,
    this.result,
    this.errorMessage,
  });

  bool get isExtracting => status == RoutineImportAiStatus.extracting;

  RoutineImportAiState copyWith({
    RoutineImportAiStatus? status,
    RoutineImportExtractionResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return RoutineImportAiState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RoutineImportAiController extends StateNotifier<RoutineImportAiState> {
  final Ref _ref;
  final RoutineImportAiClient _client;
  int _operationGeneration = 0;

  RoutineImportAiController(this._ref, this._client)
    : super(const RoutineImportAiState());

  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) async {
    if (state.isExtracting) return null;

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
    final operationGeneration = ++_operationGeneration;
    final authGeneration = _ref.read(authGenerationProvider);
    if (verifiedUser.uid.trim().isEmpty) {
      return _fail('Sign in before running AI extraction.');
    }

    final startAssetKey = review.uploadedAssetR2Key;

    final idToken = await _ref.read(authRepositoryProvider).currentIdToken();
    if (!_isCurrentOperation(
      verifiedUser.uid,
      operationGeneration,
      authGeneration,
    )) {
      return null;
    }
    if (idToken == null || idToken.trim().isEmpty) {
      return _fail('Please sign in again before running AI extraction.');
    }

    state = const RoutineImportAiState(
      status: RoutineImportAiStatus.extracting,
    );

    try {
      final result = await _client.extract(
        uid: verifiedUser.uid,
        idToken: idToken,
        review: review.copyWith(uid: verifiedUser.uid),
      );
      final currentUser = _ref.read(authProvider).user;
      final currentAssetKey = review.uploadedAssetR2Key;
      if (currentUser == null ||
          currentUser.uid.trim().isEmpty ||
          currentUser.uid != verifiedUser.uid ||
          currentAssetKey != startAssetKey ||
          !_isCurrentOperation(
            verifiedUser.uid,
            operationGeneration,
            authGeneration,
          ) ||
          state.status != RoutineImportAiStatus.extracting) {
        // Session, account, or source asset changed mid-flight; ignore stale AI extraction result.
        return null;
      }
      state = RoutineImportAiState(
        status: RoutineImportAiStatus.extracted,
        result: result,
      );
      return result;
    } on MissingConfigException catch (e) {
      final currentUser = _ref.read(authProvider).user;
      if (currentUser == null || currentUser.uid != verifiedUser.uid) {
        return null;
      }
      return _fail(e.message);
    } catch (e) {
      debugPrint(
        '[RoutineImportAiController] AI extraction failed (${e.runtimeType}).',
      );
      final currentUser = _ref.read(authProvider).user;
      if (currentUser == null || currentUser.uid != verifiedUser.uid) {
        return null;
      }
      return _fail('AI extraction failed. Try again later.');
    }
  }

  void reset() {
    _operationGeneration++;
    state = const RoutineImportAiState();
  }

  void resetForSignedOut() {
    _operationGeneration++;
    state = const RoutineImportAiState();
  }

  RoutineImportExtractionResult? _fail(String message) {
    state = RoutineImportAiState(
      status: RoutineImportAiStatus.failed,
      errorMessage: message,
    );
    return null;
  }

  bool _isCurrentOperation(
    String uid,
    int operationGeneration,
    int authGeneration,
  ) {
    return _operationGeneration == operationGeneration &&
        _ref.read(authGenerationProvider) == authGeneration &&
        _ref.read(authProvider).user?.uid == uid;
  }
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
