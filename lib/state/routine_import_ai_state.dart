import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/state/auth_state.dart';

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

  RoutineImportAiController(this._ref, this._client)
    : super(const RoutineImportAiState());

  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) async {
    if (state.isExtracting) return null;

    final user = _ref.read(authProvider).user;
    final preflightError = routineImportAiPreflightError(
      review: review,
      signedIn: user != null,
      emailVerified: user?.emailVerified ?? false,
    );
    if (preflightError != null) {
      return _fail(preflightError);
    }
    final verifiedUser = user!;

    final idToken = await _ref.read(authRepositoryProvider).currentIdToken();
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
      state = RoutineImportAiState(
        status: RoutineImportAiStatus.extracted,
        result: result,
      );
      return result;
    } on MissingConfigException catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('AI extraction failed. Try again later.');
    }
  }

  void reset() {
    state = const RoutineImportAiState();
  }

  void resetForSignedOut() {
    state = const RoutineImportAiState();
  }

  RoutineImportExtractionResult? _fail(String message) {
    state = RoutineImportAiState(
      status: RoutineImportAiStatus.failed,
      errorMessage: message,
    );
    return null;
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
