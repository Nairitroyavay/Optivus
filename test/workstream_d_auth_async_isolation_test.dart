import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';

class TestFakeAuthRepository implements AuthRepository {
  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();

  TestFakeAuthRepository([this._currentUser]);

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  void emitUser(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<String?> currentIdToken() async => 'fake_token';

  @override
  Future<AuthUser?> reloadCurrentUser() async => _currentUser;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    final u = AuthUser(uid: 'u1', email: email, emailVerified: true);
    emitUser(u);
    return u;
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    final u = const AuthUser(uid: 'anon', isAnonymous: true);
    emitUser(u);
    return u;
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    final u = AuthUser(
      uid: 'u1',
      email: email,
      displayName: name,
      emailVerified: true,
    );
    emitUser(u);
    return u;
  }

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    final u = AuthUser(
      uid: 'u1',
      email: email,
      displayName: name,
      emailVerified: true,
    );
    emitUser(u);
    return u;
  }

  @override
  Future<void> signOut() async {
    emitUser(null);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  void dispose() {
    _controller.close();
  }
}

class DelayingAiClient implements RoutineImportAiClient {
  final Duration delay;
  DelayingAiClient(this.delay);

  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) async {
    await Future.delayed(delay);
    return RoutineImportExtractionResult(
      id: 'ext1',
      uid: uid,
      source: review.source,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  group('Workstream D - Authentication & Async Isolation', () {
    test(
      'OnboardingCompletionJobService resetForSignedOut clears in-flight jobs and rejects empty UID',
      () async {
        OnboardingCompletionJobService.resetForSignedOut();

        final service = OnboardingCompletionJobService(
          onboardingRepository: FakeOnboardingRepository(),
          profileRepository: FakeProfileRepository(),
        );

        final emptyBundle = OnboardingCompletionBundle(
          uid: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          userProfilePatch: const {},
          baseTimelineBlocks: const [],
          finalTimelineItems: const [],
          routineItemsForApp: const [],
          goodHabitTemplates: const [],
          badHabitCheckIns: const [],
          identityGoalSystems: const [],
          notificationPreferences: NotificationPreferences(),
          coachPreferences: CoachPreferences(),
          moneyGoal: null,
          uploadedAssetReferences: const [],
          warnings: const [],
          duplicateSystemKeysMerged: const [],
        );

        expect(
          () => service.runCompletionJob(
            uid: '',
            finalDraft: const OnboardingDraft(),
            bundle: emptyBundle,
          ),
          throwsArgumentError,
        );

        final nullJob = await service.loadCurrentJob('');
        expect(nullJob, isNull);
      },
    );

    test(
      'RoutineImportAiController ignores stale AI results if user signs out or switches accounts mid-flight',
      () async {
        final fakeAuthRepo = TestFakeAuthRepository(
          const AuthUser(
            uid: 'user_a',
            email: 'a@test.com',
            emailVerified: true,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            routineImportAiClientProvider.overrideWithValue(
              DelayingAiClient(const Duration(milliseconds: 100)),
            ),
          ],
        );
        addTearDown(() {
          container.dispose();
          fakeAuthRepo.dispose();
        });

        final controller = container.read(
          routineImportAiControllerProvider.notifier,
        );
        final review = RoutineImportReviewDraft(
          id: 'rev1',
          uid: 'user_a',
          source: RoutineImportReviewSource.classes,
          status: RoutineImportReviewStatus.draft,
          sourceLabel: 'classes',
          uploadedAssetR2Key: 'key_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final extractionFuture = controller.runExtraction(review);

        // Mid-flight account switch
        fakeAuthRepo.emitUser(
          const AuthUser(
            uid: 'user_b',
            email: 'b@test.com',
            emailVerified: true,
          ),
        );

        final result = await extractionFuture;
        expect(
          result,
          isNull,
          reason:
              'Stale AI result from user_a should be ignored on account switch to user_b',
        );
        expect(
          container.read(routineImportAiControllerProvider).status,
          isNot(equals(RoutineImportAiStatus.extracted)),
        );
      },
    );

    test(
      'Account B receives no Account A local state on account switch',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // User A writes mind note
        container
            .read(homeMindNoteProvider.notifier)
            .addNote(
              'User A Secret Data',
              MindNoteType.overthinking,
              MindNoteIntensity.high,
            );

        expect(container.read(homeMindNoteProvider), isNotEmpty);

        // Account switch triggers resetSignedOutState
        container.read(homeMindNoteProvider.notifier).resetForSignedOut();

        expect(container.read(homeMindNoteProvider), isEmpty);
      },
    );
  });
}
