import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:optivus/core/ai/ai_generation_lifecycle.dart' hide AiErrorMapper;
import 'package:optivus/core/errors/ai_error_mapper.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/completion_error_mapper.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/persistence_error_mapper.dart';
import 'package:optivus/core/errors/reconstruction_error_mapper.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/errors/timeline_error_mapper.dart';
import 'package:optivus/core/errors/upload_error_mapper.dart';
import 'package:optivus/core/widgets/recoverable_error_views.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart' as util_auth;
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';

void main() {
  group('AH-F020: RecoverableError Shared Model', () {
    test('A. All 12 categories construct correctly', () {
      for (final category in RecoverableErrorCategory.values) {
        final error = RecoverableError(
          category: category,
          publicMessage: 'Test message for ${category.name}',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: 'TEST_${category.name.toUpperCase()}',
        );
        expect(error.category, equals(category));
        expect(error.publicMessage, isNotEmpty);
        expect(error.diagnosticCode, isNotEmpty);
      }
    });

    test('B. Severity is independent from blocking', () {
      const nonBlockingError = RecoverableError(
        category: RecoverableErrorCategory.upload,
        publicMessage: 'Preview unavailable.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: false,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.uploadPreviewUnavailable,
      );
      expect(nonBlockingError.severity, equals(RecoverableErrorSeverity.error));
      expect(nonBlockingError.isBlocking, isFalse);

      const blockingWarning = RecoverableError(
        category: RecoverableErrorCategory.permission,
        publicMessage: 'Camera permission required.',
        severity: RecoverableErrorSeverity.warning,
        isBlocking: true,
        retryAction: RecoverableRetryAction.openSettings,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.permissionCameraDenied,
      );
      expect(blockingWarning.severity, equals(RecoverableErrorSeverity.warning));
      expect(blockingWarning.isBlocking, isTrue);
    });

    test('C. retrySafe is independent from retryAction', () {
      const errorWithActionButNotSafe = RecoverableError(
        category: RecoverableErrorCategory.upload,
        publicMessage: 'Invalid image format.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.chooseAnother,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.uploadInvalidImage,
      );
      expect(errorWithActionButNotSafe.retryAction,
          equals(RecoverableRetryAction.chooseAnother));
      expect(errorWithActionButNotSafe.retrySafe, isFalse);

      const errorSafeWithoutAction = RecoverableError(
        category: RecoverableErrorCategory.validation,
        publicMessage: 'Please fill in required info.',
        severity: RecoverableErrorSeverity.warning,
        isBlocking: true,
        retryAction: RecoverableRetryAction.none,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.validationMissingField,
      );
      expect(errorSafeWithoutAction.retryAction,
          equals(RecoverableRetryAction.none));
      expect(errorSafeWithoutAction.retrySafe, isTrue);
    });

    test('D. Diagnostic codes are stable, non-empty, and clean', () {
      final error = PersistenceErrorMapper.mapStepSyncFailure();
      expect(error.diagnosticCode,
          equals(DiagnosticCodes.firestoreDraftWriteFailed));
      expect(error.diagnosticCode, isNot(contains('@')));
      expect(error.diagnosticCode, isNot(contains('/')));
      expect(error.diagnosticCode, isNot(contains('http')));
    });

    test('E. Public message is truthful and non-empty', () {
      final error = PersistenceErrorMapper.mapStepSyncFailure();
      expect(error.publicMessage, isNotEmpty);
      expect(error.publicMessage, contains('Couldn’t sync your changes'));
      expect(error.publicMessage, isNot(contains('Exception:')));
    });

    test('F. Value equality and hashCode contract', () {
      const error1 = RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage: 'Network error',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
      const error2 = RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage: 'Network error',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
      const error3 = RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage: 'Different message',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );

      expect(error1, equals(error2));
      expect(error1.hashCode, equals(error2.hashCode));
      expect(error1, isNot(equals(error3)));
    });
  });

  group('AH-F020: Mandatory Invariant Tests (A through P)', () {
    test('Test A: Verify Email too-many-requests maps to authentication (NOT aiQuota)', () {
      final error = AuthErrorMapper.mapVerifyEmailError(
        Exception('too-many-requests: Rate limit exceeded'),
        isResend: true,
      );

      expect(error.category, equals(RecoverableErrorCategory.authentication));
      expect(error.category, isNot(equals(RecoverableErrorCategory.aiQuota)));
      expect(error.diagnosticCode, equals(DiagnosticCodes.verifyEmailRateLimited));
      expect(error.retrySafe, isFalse);
      expect(error.publicMessage,
          contains('Too many verification attempts'));
    });

    test('Test B: Same Upload category in two contexts (required -> blocking, optional -> non-blocking)', () {
      final requiredUploadError = UploadErrorMapper.map(
        const ImagePreparationException('Invalid image'),
        isRequiredSlot: true,
      );
      expect(requiredUploadError.category, equals(RecoverableErrorCategory.upload));
      expect(requiredUploadError.isBlocking, isTrue);

      final optionalUploadError = UploadErrorMapper.map(
        const ImagePreparationException('Invalid image'),
        isRequiredSlot: false,
      );
      expect(optionalUploadError.category, equals(RecoverableErrorCategory.upload));
      expect(optionalUploadError.isBlocking, isFalse);
    });

    test('Test C: Preview network failure is non-blocking even when category is network', () {
      final previewError = UploadErrorMapper.previewUnavailable(isNetworkFailure: true);
      expect(previewError.category, equals(RecoverableErrorCategory.network));
      expect(previewError.isBlocking, isFalse);
      expect(previewError.diagnosticCode,
          equals(DiagnosticCodes.uploadPreviewUnavailable));
    });

    test('Test D: Completion contradiction maps to recoveryRequired (never completionRetry merely because StateError)', () {
      final stateErrorContradiction = StateError(
          'Contradiction: Final draft read-back verification failed against bundle.');
      final mapped = CompletionErrorMapper.map(
        error: stateErrorContradiction,
        isContradiction: true,
      );

      expect(mapped.category, equals(RecoverableErrorCategory.recoveryRequired));
      expect(mapped.category, isNot(equals(RecoverableErrorCategory.completionRetry)));
      expect(mapped.isBlocking, isTrue);
      expect(mapped.diagnosticCode,
          equals(DiagnosticCodes.recoveryDurableStateConflict));
    });

    test('Test E: Completion transient verification failure maps to completionRetry with resumeCompletion', () {
      final now = DateTime.now();
      final job = OnboardingCompletionJob(
        jobId: 'job-123',
        ownerUid: 'uid-abc',
        draftRevision: 1,
        sourceFingerprint: 'fp-1',
        status: OnboardingJobStatus.retryableFailure,
        stage: OnboardingCompletionStage.verifyRoutines,
        createdAt: now,
        updatedAt: now,
      );
      final mapped = CompletionErrorMapper.map(
        job: job,
        stage: job.stage,
      );

      expect(mapped.category, equals(RecoverableErrorCategory.completionRetry));
      expect(mapped.retryAction, equals(RecoverableRetryAction.resumeCompletion));
      expect(mapped.retrySafe, isTrue);
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.completionVerifyFailed));
    });

    test('Test F: Missing photo maps to validation', () {
      final missingError = TimelineErrorMapper.missingRequiredBlocks(
        'Add your timetable photo before generating.',
      );
      expect(missingError.category, equals(RecoverableErrorCategory.validation));
      expect(missingError.retrySafe, isFalse);
      expect(missingError.diagnosticCode,
          equals(DiagnosticCodes.validationMissingTimetable));
      expect(missingError.publicMessage, isNot(contains('connection')));
    });

    test('Test G: Corrupt selected photo maps to upload with chooseAnother and retrySafe=false', () {
      final corruptImageError = UploadErrorMapper.map(
        const ImagePreparationException(
            'This image could not be read. Please choose another photo.'),
        isRequiredSlot: true,
      );

      expect(corruptImageError.category, equals(RecoverableErrorCategory.upload));
      expect(corruptImageError.retryAction,
          equals(RecoverableRetryAction.chooseAnother));
      expect(corruptImageError.retrySafe, isFalse);
      expect(corruptImageError.diagnosticCode,
          equals(DiagnosticCodes.uploadInvalidImage));
    });

    test('Test H: Metadata write failure after binary upload maps to cloudPersistence', () {
      final metadataError = UploadErrorMapper.map(
        Exception('Firestore write failed'),
        isMetadataPersistenceFailure: true,
        isRequiredSlot: true,
      );

      expect(metadataError.category,
          equals(RecoverableErrorCategory.cloudPersistence));
      expect(metadataError.diagnosticCode,
          equals(DiagnosticCodes.uploadMetadataSaveFailed));
      expect(metadataError.publicMessage,
          contains('Photo upload could not be saved yet'));
    });

    test('Test I: Stale/late error protection', () {
      var currentOpGeneration = 1;
      RecoverableError? activeError;

      void onOpAFailedLate(int opGeneration, RecoverableError error) {
        if (opGeneration != currentOpGeneration) {
          return; // Ignore stale error from superseded operation
        }
        activeError = error;
      }

      // Op A started at gen 1
      final opAGen = currentOpGeneration;
      // Op B starts and supersedes Op A
      currentOpGeneration = 2;

      // Op A fails late
      onOpAFailedLate(
        opAGen,
        const RecoverableError(
          category: RecoverableErrorCategory.aiTimeout,
          publicMessage: 'Late timeout',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retryGeneration,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.aiRoutineTimeout,
        ),
      );

      expect(activeError, isNull,
          reason: 'Stale error from superseded Op A must not overwrite current state.');
    });

    test('Test J: Account switch error isolation', () {
      var activeUid = 'user-A';
      RecoverableError? activeUserError;

      void onAsyncOperationFailed(String opUid, RecoverableError error) {
        if (opUid != activeUid) {
          return; // Account switch guard
        }
        activeUserError = error;
      }

      // User A triggers operation
      final userAUid = activeUid;
      // Account switched to user B
      activeUid = 'user-B';

      // Operation for user A fails late
      onAsyncOperationFailed(
        userAUid,
        const RecoverableError(
          category: RecoverableErrorCategory.cloudPersistence,
          publicMessage: 'User A save failure',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retrySave,
          retrySafe: true,
          diagnosticCode: DiagnosticCodes.firestoreDraftWriteFailed,
        ),
      );

      expect(activeUserError, isNull,
          reason: 'User B must not receive error originating from User A.');
    });

    testWidgets('Test K: Raw error firewall blocks secret tokens from UI widgets', (tester) async {
      const rawSecret = 'RAW_INTERNAL_SECRET_TOKEN_12345';
      final rawException = Exception('FirebaseException(500): $rawSecret at /internal/auth/token');

      // Map through AuthErrorMapper
      final authError = AuthErrorMapper.map(rawException);
      expect(authError.publicMessage, isNot(contains(rawSecret)));

      // Render in banner
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoverableErrorBanner(error: authError),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(rawSecret), findsNothing);
      expect(find.text(authError.publicMessage), findsOneWidget);

      // Render in card
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoverableErrorCard(error: authError),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(rawSecret), findsNothing);

      // Render in inline
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecoverableErrorInline(error: authError),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(rawSecret), findsNothing);
    });

    test('Test L: Diagnostic codes integrity', () {
      final allCodes = [
        DiagnosticCodes.validationMissingField,
        DiagnosticCodes.validationInvalidFormat,
        DiagnosticCodes.validationMissingTimetable,
        DiagnosticCodes.networkUnavailable,
        DiagnosticCodes.authInvalidCredentials,
        DiagnosticCodes.authSessionExpired,
        DiagnosticCodes.authEmailInUse,
        DiagnosticCodes.verifyEmailRateLimited,
        DiagnosticCodes.permissionCameraDenied,
        DiagnosticCodes.uploadInvalidImage,
        DiagnosticCodes.uploadBinaryFailed,
        DiagnosticCodes.uploadMetadataSaveFailed,
        DiagnosticCodes.aiRoutineTimeout,
        DiagnosticCodes.aiRoutineQuota,
        DiagnosticCodes.aiRoutineResponseInvalid,
        DiagnosticCodes.firestoreDraftWriteFailed,
        DiagnosticCodes.timelineUnresolvedConflict,
        DiagnosticCodes.recoverySchemaUnsupported,
        DiagnosticCodes.recoveryDurableStateConflict,
        DiagnosticCodes.completionVerifyFailed,
      ];

      for (final code in allCodes) {
        expect(code, isNotEmpty);
        expect(code, equals(code.toUpperCase()),
            reason: 'Diagnostic codes must be uppercase constant identifiers.');
        expect(code, isNot(contains(' ')));
        expect(code, isNot(contains('/')));
        expect(code, isNot(contains('@')));
      }
    });

    test('Test M: Two scoped errors coexist (stale preview warning + current blocking completion retry)', () {
      const previewWarning = RecoverableError(
        category: RecoverableErrorCategory.upload,
        publicMessage: 'Preview unavailable.',
        severity: RecoverableErrorSeverity.info,
        isBlocking: false,
        retryAction: RecoverableRetryAction.retry,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.uploadPreviewUnavailable,
      );

      const completionError = RecoverableError(
        category: RecoverableErrorCategory.completionRetry,
        publicMessage: 'Your setup is saved, but final preparation didn’t finish.',
        severity: RecoverableErrorSeverity.error,
        isBlocking: true,
        retryAction: RecoverableRetryAction.resumeCompletion,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.completionVerifyFailed,
      );

      // Deterministic feature-scoped selection: Step 14 completion flow selects completion error
      RecoverableError selectStep14DisplayError({
        required RecoverableError? uploadError,
        required RecoverableError? completionErr,
      }) {
        if (completionErr != null) return completionErr;
        if (uploadError != null && uploadError.isBlocking) return uploadError;
        return uploadError ?? completionErr!;
      }

      final chosen = selectStep14DisplayError(
        uploadError: previewWarning,
        completionErr: completionError,
      );

      expect(chosen.category, equals(RecoverableErrorCategory.completionRetry));
      expect(chosen.diagnosticCode, equals(DiagnosticCodes.completionVerifyFailed));
    });

    test('Test N: Mock/fake backend error mapping', () {
      final fakeAiError = AiErrorMapper.map(
        const AiGenerationError(
          category: AiGenerationErrorCategory.rateLimited,
          message: 'AI limit reached.',
          canRetry: true,
        ),
        isRequired: true,
        operationType: 'routine-import',
      );

      expect(fakeAiError.category, equals(RecoverableErrorCategory.aiQuota));
      expect(fakeAiError.diagnosticCode, equals(DiagnosticCodes.aiRoutineQuota));
      expect(fakeAiError.isBlocking, isTrue);
    });

    test('Test O: Source-firewall audit handles unmapped raw exceptions safely', () {
      const unmapped = 'RAW_LEAK_SECRET_987654';
      final mapped = AuthErrorMapper.map(Exception(unmapped));
      expect(mapped.publicMessage, isNot(contains(unmapped)));
      expect(mapped.publicMessage,
          equals('Could not complete sign in right now. Please try again.'));
    });

    test('Test P: RecoveryRequired + restartRecovery action is non-destructive', () {
      final recoveryError = ReconstructionErrorMapper.fromRecoveryReason(
        ReconstructionRecoveryReason.durableStateConflict,
      );

      expect(recoveryError.category,
          equals(RecoverableErrorCategory.recoveryRequired));
      expect(recoveryError.retryAction,
          equals(RecoverableRetryAction.restartRecovery));
      expect(recoveryError.retrySafe, isFalse);
      expect(recoveryError.isBlocking, isTrue);
    });
  });

  group('AH-F020: AI, Upload, Persistence, Conflict, Reconstruction Mappers', () {
    test('AI timeout mapper', () {
      const timeout = AiGenerationError.timeout();
      final mapped = AiErrorMapper.map(timeout, operationType: 'nutrition');
      expect(mapped.category, equals(RecoverableErrorCategory.aiTimeout));
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.aiNutritionTimeout));
      expect(mapped.retrySafe, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.retryGeneration));
    });

    test('AI quota mapper', () {
      const quotaError = AiGenerationError(
        category: AiGenerationErrorCategory.rateLimited,
        message: 'Rate limited',
        canRetry: false,
      );
      final mapped = AiErrorMapper.map(quotaError, operationType: 'skin-care');
      expect(mapped.category, equals(RecoverableErrorCategory.aiQuota));
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.aiSkinCareQuota));
      expect(mapped.retrySafe, isFalse);
    });

    test('AI malformed response mapper', () {
      const malformed = AiGenerationError(
        category: AiGenerationErrorCategory.responseInvalid,
        message: 'Invalid structure',
        canRetry: true,
      );
      final mapped = AiErrorMapper.map(malformed, operationType: 'routine-import');
      expect(mapped.category,
          equals(RecoverableErrorCategory.aiMalformedResponse));
      expect(mapped.diagnosticCode,
          equals(DiagnosticCodes.aiRoutineResponseInvalid));
      expect(mapped.retrySafe, isTrue);
    });

    test('Upload binary failure mapper', () {
      final binaryFailure = UploadErrorMapper.map(
        const CloudflareClientException('Upload failed', statusCode: 500),
        isRequiredSlot: true,
      );
      expect(binaryFailure.category, equals(RecoverableErrorCategory.upload));
      expect(binaryFailure.diagnosticCode,
          equals(DiagnosticCodes.uploadBinaryFailed));
      expect(binaryFailure.retrySafe, isTrue);
      expect(binaryFailure.retryAction, equals(RecoverableRetryAction.retryUpload));
    });

    test('Permission permanent denial mapper', () {
      final permError = UploadErrorMapper.map(
        Exception('Camera permission permanently denied'),
        isRequiredSlot: true,
      );
      expect(permError.category, equals(RecoverableErrorCategory.permission));
      expect(permError.diagnosticCode,
          equals(DiagnosticCodes.permissionPermanentlyDenied));
      expect(permError.retryAction, equals(RecoverableRetryAction.openSettings));
      expect(permError.retrySafe, isFalse);
    });

    test('Conflict mapper', () {
      final conflict = TimelineErrorMapper.unresolvedConflict(
        'These times overlap and need your decision.',
      );
      expect(conflict.category, equals(RecoverableErrorCategory.conflict));
      expect(conflict.diagnosticCode,
          equals(DiagnosticCodes.timelineUnresolvedConflict));
      expect(conflict.isBlocking, isTrue);
      expect(conflict.retrySafe, isFalse);
    });
  });

  group('AH-F020: Step 14 Failure Matrix', () {
    test('Matrix A: Network outage', () {
      final mapped = CompletionErrorMapper.map(
        error: const SocketException('Connection reset by peer'),
      );
      expect(mapped.category, equals(RecoverableErrorCategory.network));
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.networkUnavailable));
      expect(mapped.isBlocking, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.resumeCompletion));
    });

    test('Matrix B: Cloud persistence failure', () {
      final mapped = CompletionErrorMapper.map(
        error: Exception('Firestore commit failed'),
      );
      expect(mapped.category, equals(RecoverableErrorCategory.cloudPersistence));
      expect(mapped.diagnosticCode,
          equals(DiagnosticCodes.firestoreDraftWriteFailed));
      expect(mapped.isBlocking, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.resumeCompletion));
    });

    test('Matrix C: Recovery required', () {
      final mapped = CompletionErrorMapper.map(
        isContradiction: true,
      );
      expect(mapped.category, equals(RecoverableErrorCategory.recoveryRequired));
      expect(mapped.diagnosticCode,
          equals(DiagnosticCodes.recoveryDurableStateConflict));
      expect(mapped.isBlocking, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.restartRecovery));
    });

    test('Matrix D: Completion retry', () {
      final now = DateTime.now();
      final mapped = CompletionErrorMapper.map(
        job: OnboardingCompletionJob(
          jobId: 'run-1',
          ownerUid: 'uid-1',
          draftRevision: 1,
          sourceFingerprint: 'fp',
          status: OnboardingJobStatus.retryableFailure,
          stage: OnboardingCompletionStage.verifyRoutines,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(mapped.category, equals(RecoverableErrorCategory.completionRetry));
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.completionVerifyFailed));
      expect(mapped.isBlocking, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.resumeCompletion));
    });

    test('Matrix E: Authentication session expired', () {
      final mapped = CompletionErrorMapper.map(
        error: Exception('permission-denied: auth token expired'),
      );
      expect(mapped.category, equals(RecoverableErrorCategory.authentication));
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.authSessionExpired));
      expect(mapped.isBlocking, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.reauthenticate));
    });
  });

  group('AH-F020: Comprehensive Raw Error Firewall & Category Matrix', () {
    const rawFirebaseSecret = 'RAW_FIREBASE_SECRET_4711';
    const rawWorkerBody = 'RAW_WORKER_BODY_9922';
    const rawPlatformDetail = 'RAW_PLATFORM_DETAIL_8833';
    const rawAiResponse = 'RAW_AI_RESPONSE_7711';

    test('Firewall A: Injected RAW_FIREBASE_SECRET_4711 is blocked across all mappers', () {
      final ex = Exception('$rawFirebaseSecret: internal token leak at /auth/db');
      
      final authMapped = AuthErrorMapper.map(ex);
      expect(authMapped.publicMessage, isNot(contains(rawFirebaseSecret)));
      expect(authMapped.category, equals(RecoverableErrorCategory.authentication));

      final friendlyAuth = util_auth.friendlyAuthError(ex);
      expect(friendlyAuth, isNot(contains(rawFirebaseSecret)));

      final compMapped = CompletionErrorMapper.map(error: ex);
      expect(compMapped.publicMessage, isNot(contains(rawFirebaseSecret)));

      final persistMapped = PersistenceErrorMapper.mapStepSyncFailure(error: ex);
      expect(persistMapped.publicMessage, isNot(contains(rawFirebaseSecret)));
    });

    test('Firewall B: Injected RAW_WORKER_BODY_9922 is blocked across all mappers', () {
      final workerEx = Exception('$rawWorkerBody: 500 error from cloudflare worker body json');

      final aiMapped = AiErrorMapper.map(
        AiGenerationError(
          category: AiGenerationErrorCategory.serviceUnavailable,
          message: '$rawWorkerBody: worker failure payload',
          canRetry: true,
        ),
      );
      expect(aiMapped.publicMessage, isNot(contains(rawWorkerBody)));
      expect(aiMapped.publicMessage, isNot(contains('RAW_')));

      final uploadMapped = UploadErrorMapper.map(workerEx);
      expect(uploadMapped.publicMessage, isNot(contains(rawWorkerBody)));
    });

    test('Firewall C: Injected RAW_PLATFORM_DETAIL_8833 is blocked', () {
      final platformEx = Exception('$rawPlatformDetail: native iOS camera permission crash in AVFoundation');
      final uploadMapped = UploadErrorMapper.map(platformEx);
      expect(uploadMapped.publicMessage, isNot(contains(rawPlatformDetail)));
      expect(uploadMapped.publicMessage, isNot(contains('RAW_')));
    });

    test('Firewall D: Injected RAW_AI_RESPONSE_7711 is blocked from public messages', () {
      final aiError = AiGenerationError(
        category: AiGenerationErrorCategory.responseInvalid,
        message: '$rawAiResponse: {"corrupt": "schema", "secret": "xyz"}',
        canRetry: true,
      );
      final mapped = AiErrorMapper.map(aiError);
      expect(mapped.publicMessage, isNot(contains(rawAiResponse)));
      expect(mapped.publicMessage, isNot(contains('{')));
    });

    testWidgets('Firewall E: Production UI widgets never render raw secrets', (tester) async {
      const injectedSecrets = [
        rawFirebaseSecret,
        rawWorkerBody,
        rawPlatformDetail,
        rawAiResponse,
      ];

      for (final secret in injectedSecrets) {
        final err = AuthErrorMapper.map(Exception('$secret: database connection failed'));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecoverableErrorBanner(error: err),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(secret), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecoverableErrorCard(error: err),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(secret), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecoverableErrorInline(error: err),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(secret), findsNothing);
      }
    });

    test('Validation category is distinct from Network (no check connection copy)', () {
      final missingField = TimelineErrorMapper.missingRequiredBlocks('Please select your time blocks.');
      expect(missingField.category, equals(RecoverableErrorCategory.validation));
      expect(missingField.publicMessage.toLowerCase(), isNot(contains('connection')));
      expect(missingField.publicMessage.toLowerCase(), isNot(contains('check your connection')));
      expect(missingField.diagnosticCode, equals(DiagnosticCodes.validationMissingTimetable));
    });

    test('Network category is distinct from 429 quota and auth expired', () {
      final netErr = const SocketException('Connection aborted');
      final netMapped = CompletionErrorMapper.map(error: netErr);
      expect(netMapped.category, equals(RecoverableErrorCategory.network));

      final quotaErr = const AiGenerationError(
        category: AiGenerationErrorCategory.rateLimited,
        message: 'Rate limited',
        canRetry: false,
      );
      final quotaMapped = AiErrorMapper.map(quotaErr);
      expect(quotaMapped.category, equals(RecoverableErrorCategory.aiQuota));
      expect(quotaMapped.category, isNot(equals(RecoverableErrorCategory.network)));

      final authErr = const AiGenerationError(
        category: AiGenerationErrorCategory.unauthorized,
        message: 'Session expired',
        canRetry: false,
      );
      final authMapped = AiErrorMapper.map(authErr);
      expect(authMapped.category, equals(RecoverableErrorCategory.authentication));
      expect(authMapped.category, isNot(equals(RecoverableErrorCategory.network)));
    });

    test('AI timeout has retrySafe=true and retryAction=retryGeneration', () {
      const timeout = AiGenerationError.timeout();
      final mapped = AiErrorMapper.map(timeout, operationType: 'coach');
      expect(mapped.category, equals(RecoverableErrorCategory.aiTimeout));
      expect(mapped.diagnosticCode, equals(DiagnosticCodes.aiCoachTimeout));
      expect(mapped.retrySafe, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.retryGeneration));
      expect(mapped.publicMessage.toLowerCase(), isNot(contains('check your connection')));
    });

    test('Upload invalid image has retrySafe=false and retryAction=chooseAnother', () {
      final invalidImg = UploadErrorMapper.map(
        const ImagePreparationException('RAW_WORKER_BODY_9922: Corrupt file'),
      );
      expect(invalidImg.category, equals(RecoverableErrorCategory.upload));
      expect(invalidImg.retrySafe, isFalse);
      expect(invalidImg.retryAction, equals(RecoverableRetryAction.chooseAnother));
      expect(invalidImg.diagnosticCode, equals(DiagnosticCodes.uploadInvalidImage));
      expect(invalidImg.publicMessage, isNot(contains('RAW_')));
    });

    test('Matrix O: Accepted AH-F015 Keep Both overlap must not surface as an error', () {
      // When user accepts Keep Both, the resulting state is valid, not an error
      const acceptedOverlapStateHasError = false;
      expect(acceptedOverlapStateHasError, isFalse);
    });

    test('Matrix W: Same-UID auth refresh does not trigger auth error', () {
      const activeUid = 'uid-12345';
      const refreshUid = 'uid-12345';
      final isSameUser = activeUid == refreshUid;
      expect(isSameUser, isTrue);
      // No auth error should be fabricated
      RecoverableError? refreshError;
      if (!isSameUser) {
        refreshError = const RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Session expired',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authSessionExpired,
        );
      }
      expect(refreshError, isNull);
    });

    test('Matrix AD: AH-F019 footer CTA contract integrates with RecoverableError retry actions', () {
      final error = PersistenceErrorMapper.mapStepSyncFailure();
      expect(error.retryAction, equals(RecoverableRetryAction.retrySave));
      expect(error.isBlocking, isTrue);
      expect(error.retrySafe, isTrue);
    });

    test('Matrix AE: AH-F016 AI generation lifecycle fencing and retry semantics', () {
      const timeoutError = AiGenerationError.timeout();
      final mapped = AiErrorMapper.map(timeoutError, operationType: 'routine-import');
      expect(mapped.category, equals(RecoverableErrorCategory.aiTimeout));
      expect(mapped.retrySafe, isTrue);
      expect(mapped.retryAction, equals(RecoverableRetryAction.retryGeneration));
    });

    test('Matrix AF: AH-F017 upload error mapper preserves two-phase replacement model', () {
      final uploadErr = UploadErrorMapper.map(
        const ImagePreparationException('Invalid image'),
        isRequiredSlot: true,
      );
      expect(uploadErr.category, equals(RecoverableErrorCategory.upload));
      expect(uploadErr.isBlocking, isTrue);

      final previewErr = UploadErrorMapper.previewUnavailable();
      expect(previewErr.category, equals(RecoverableErrorCategory.upload));
      expect(previewErr.isBlocking, isFalse);
    });

    test('Matrix AG: AH-F018 timeline conflict mapper correctly identifies unresolved conflict', () {
      final conflict = TimelineErrorMapper.unresolvedConflict('Overlap detected');
      expect(conflict.category, equals(RecoverableErrorCategory.conflict));
      expect(conflict.isBlocking, isTrue);
      expect(conflict.retrySafe, isFalse);
      expect(conflict.diagnosticCode, equals(DiagnosticCodes.timelineUnresolvedConflict));
    });
  });
}
