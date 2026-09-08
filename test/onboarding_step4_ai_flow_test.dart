import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';

void main() {
  group('Onboarding Step 4 AI Flow Logic', () {
    test(
      'onboarding4SourceFailureMessage returns strict upload error for 0 candidates',
      () {
        final message = onboarding4SourceFailureMessage(
          source: RoutineImportReviewSource.classes,
          role: 'student',
          rawCandidateCount: 0,
          mappedBlockCount: 0,
          warnings: const [],
        );

        expect(
          message,
          'AI could not read this timetable. Please upload a clearer image and try again.',
        );
      },
    );

    test(
      'onboarding4SourceFailureMessage returns strict upload error for 0 mapped candidates',
      () {
        final message = onboarding4SourceFailureMessage(
          source: RoutineImportReviewSource.classes,
          role: 'student',
          rawCandidateCount: 5, // AI read something
          mappedBlockCount: 0, // but mapped nothing
          warnings: const [],
        );

        expect(
          message,
          'AI could not read this timetable. Please upload a clearer image and try again.',
        );
      },
    );

    test(
      'onboarding4SourceFailureMessage handles standard provider errors',
      () {
        final message = onboarding4SourceFailureMessage(
          source: RoutineImportReviewSource.work,
          role: 'working',
          rawCandidateCount: 0,
          mappedBlockCount: 0,
          warnings: const ['provider_request_failed'],
        );

        expect(message, 'AI import failed. Please try again.');
      },
    );

    test(
      'onboarding4SourceFailureMessage surfaces missing worker url properly',
      () {
        final message = onboarding4SourceFailureMessage(
          source: RoutineImportReviewSource.classes,
          role: 'student',
          rawCandidateCount: 0,
          mappedBlockCount: 0,
          warnings: const ['worker is not configured'],
        );

        expect(
          message,
          'Real AI is not configured. Missing routine import worker URL.',
        );
      },
    );

    test('onboarding4SourceFailureMessage handles quota exceeded', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['provider_quota_exceeded'],
      );

      expect(message, 'AI is busy right now. Please try again.');
    });

    test('onboarding4SourceFailureMessage handles missing student photo', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: 'student',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['Upload a photo before running AI extraction.'],
      );

      expect(message, 'Please upload your class timetable.');
    });

    test('onboarding4SourceFailureMessage handles missing working photo', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['Upload a photo before running AI extraction.'],
      );

      expect(message, 'Please upload your work/job timetable.');
    });

    test('onboarding4SourceFailureMessage handles incomplete R2 upload', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'student_working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['Upload incomplete. Please upload again.'],
      );

      expect(message, 'Upload incomplete. Please upload again.');
    });
  });

  group('Onboarding Step 4 AI Loading UI', () {
    testWidgets('shows AiThinkingCard during class timetable extraction', (
      tester,
    ) async {
      final draft = OnboardingDraft(
        uid: 'test-user',
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      );
      final authRepository = DummyAuthRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (ref) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
            authRepositoryProvider.overrideWithValue(authRepository),
            onboardingUploadInteractionProvider.overrideWith(
              (ref) => MockUploadInteractionController(
                assetRepository: DummyAssetRepo(),
                authRepository: authRepository,
                imagePrepareService: DummyImageService(),
                r2UploadClient: DummyR2Client(),
              ),
            ),
            routineImportAiControllerProvider.overrideWith(
              (ref) => MockRoutineImportAiController(
                ref,
                FakeDelayedRoutineImportAiClient(),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: OnboardingStep4Unified()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to upload class photo (via the school icon inside the upload button)
      final uploadCard = find.byIcon(Icons.school_rounded);
      expect(uploadCard, findsOneWidget);
      await tester.tap(uploadCard);
      await tester.pumpAndSettle();

      // Now tap Generate timeline (arrow button)
      final generateButton = find.byIcon(Icons.arrow_upward_rounded);
      expect(generateButton, findsOneWidget);
      await tester.tap(generateButton);
      await tester.pump();

      // Verify the thinking card appears
      expect(find.byType(AiThinkingCard), findsOneWidget);
      expect(
        find.textContaining('AI is reading your class timetable'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Looking for subjects, rooms, days, and time blocks',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Reading the timetable layout'), findsNothing);
      expect(find.textContaining('Checking weekly structure'), findsNothing);

      // Force cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}

class FakeDelayedRoutineImportAiClient implements RoutineImportAiClient {
  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) async {
    return Completer<RoutineImportExtractionResult>().future; // Hang forever
  }
}

class MockUploadInteractionController extends UploadInteractionController {
  MockUploadInteractionController({
    required super.assetRepository,
    required super.authRepository,
    required super.imagePrepareService,
    required super.r2UploadClient,
  }) : super(
         shellConfig: onboardingUploadShellConfig,
         permissionService: const DefaultUploadPermissionService(),
       );

  @override
  Future<UploadedAsset?> chooseFromGallery(
    String slotKey, {
    required String uid,
    required String sourceFeature,
    bool deferReplacement = false,
  }) async {
    final purpose = slotKey == onboardingClassUploadSlot
        ? UploadedAssetPurpose.classTimetable
        : UploadedAssetPurpose.workSchedule;
    final assetId = 'test_asset_${purpose.name}';
    final asset = UploadedAsset(
      assetId: assetId,
      ownerUid: uid,
      r2Key: 'users/$uid/onboarding/${purpose.wireName}/$assetId.jpg',
      fileName: 'photo.jpg',
      purpose: purpose,
      sourceFeature: sourceFeature,
      sizeBytes: 100,
      contentType: 'image/jpeg',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: UploadedAssetStatus.uploaded,
    );
    final next = Map<String, UploadSlotRuntimeState>.from(state);
    final current = state[slotKey]!;
    next[slotKey] = current.copyWith(
      phase: UploadInteractionPhase.uploaded,
      durableAsset: asset,
    );
    state = Map.unmodifiable(next);
    return asset;
  }
}

class DummyAssetRepo implements UploadedAssetRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyAuthRepo implements AuthRepository {
  static const user = AuthUser(
    uid: 'test-user',
    email: 'test@optivus.dev',
    emailVerified: true,
  );

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyImageService implements ImagePrepareService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyR2Client implements R2UploadClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRoutineImportAiController extends RoutineImportAiController {
  MockRoutineImportAiController(super.ref, super.client);

  @override
  Future<RoutineImportExtractionResult?> runExtraction(
    RoutineImportReviewDraft review,
  ) async {
    state = const RoutineImportAiState.extracting();
    // Hang forever so _isGenerating stays true
    return Completer<RoutineImportExtractionResult>().future;
  }
}
