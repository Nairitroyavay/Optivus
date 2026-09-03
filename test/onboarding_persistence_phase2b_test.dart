import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'helpers/fake_habit_systems_repository.dart';

void main() {
  test('OnboardingDraft toMap/fromMap preserves currentStep', () {
    final draft = _draftWithUploadReferences().copyWith(currentStep: 4);

    final roundTrip = OnboardingDraft.fromMap(draft.toMap());

    expect(roundTrip.currentStep, 4);
  });

  test(
    'OnboardingDraft toMap/fromMap preserves stepCompleted and stepDirty',
    () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
      completed[0] = true;
      completed[1] = true;
      completed[4] = true;
      final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
      dirty[2] = true;
      dirty[5] = true;
      final draft = _draftWithUploadReferences().copyWith(
        stepCompleted: completed,
        stepDirty: dirty,
      );

      final roundTrip = OnboardingDraft.fromMap(draft.toMap());

      expect(roundTrip.stepCompleted, completed);
      expect(roundTrip.stepDirty, dirty);
    },
  );

  test('legacy 12-step onboarding draft migrates to 15-step indexes', () {
    final legacyCompleted = List<bool>.filled(12, true);
    final legacyDirty = List<bool>.filled(12, false);
    legacyDirty[5] = true;

    final migrated = OnboardingDraft.fromMap({
      'schemaVersion': 1,
      'uid': 'legacy-user',
      'currentStep': 11,
      'stepCompleted': legacyCompleted,
      'stepDirty': legacyDirty,
      'stepLoading': List<bool>.filled(12, false),
    });

    expect(migrated.currentStep, OnboardingDraft.lastStepIndex);
    expect(migrated.stepCompleted, hasLength(OnboardingDraft.stepCount));
    expect(migrated.stepCompleted.every((done) => done), isTrue);
    expect(migrated.stepDirty[8], isTrue);
  });

  test(
    'OnboardingDraft toMap/fromMap preserves PendingFutureImportDraft uploaded asset references',
    () {
      final draft = _draftWithUploadReferences();

      final roundTrip = OnboardingDraft.fromMap(draft.toMap());
      final imports = roundTrip.baseTimeline.pendingFutureImports;

      expect(imports, hasLength(4));
      expect(imports[0].uploadedAssetId, 'class-asset');
      expect(imports[0].uploadedAssetR2Key, contains('class_timetable'));
      expect(imports[0].uploadedAssetStatus, 'uploaded');
      expect(imports[1].uploadedAssetId, 'menu-asset');
      expect(imports[1].uploadedAssetR2Key, contains('eating_menu'));
      expect(imports[1].uploadedAssetStatus, 'uploaded');
      expect(imports[2].uploadedAssetId, 'skin-asset');
      expect(imports[2].uploadedAssetR2Key, contains('skin_care'));
      expect(imports[2].uploadedAssetStatus, 'uploaded');
      expect(roundTrip.baseTimeline.skinCareProductPhotoAssetId, 'skin-asset');
      expect(
        roundTrip.baseTimeline.skinCareProductPhotoR2Key,
        contains('skin_care'),
      );
      expect(roundTrip.baseTimeline.skinCareProductPhotoStatus, 'uploaded');
      expect(
        roundTrip.baseTimeline.skinCareProductPhotoCreatedAt,
        DateTime.utc(2026, 6, 2, 8),
      );
      expect(
        roundTrip.baseTimeline.skinCareProductPhotoUpdatedAt,
        DateTime.utc(2026, 6, 2, 8, 30),
      );
    },
  );

  test('OnboardingCompletionBundle.toMap includes uploadedAssetReferences', () {
    final bundle = OnboardingCompletionService.buildBundle(
      _draftWithUploadReferences(),
    );

    final map = bundle.toMap();
    final references = (map['uploadedAssetReferences'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    expect(references, hasLength(3));
    expect(references.map((item) => item['id']), contains('classes_photo'));
    expect(references.map((item) => item['id']), contains('eating_photo'));
    expect(references.map((item) => item['id']), contains('skin-asset'));
    final skinReference = references.singleWhere(
      (item) => item['uploadedAssetId'] == 'skin-asset',
    );
    expect(skinReference['section'], 'skin_care');
    expect(skinReference['mode'], 'has_products');
    expect(skinReference['uploadedAssetR2Key'], contains('skin_care'));
    expect(skinReference['uploadedAssetStatus'], 'uploaded');
    expect(skinReference['createdAt'], '2026-06-02T08:00:00.000Z');
    expect(skinReference['updatedAt'], '2026-06-02T08:30:00.000Z');
    expect(
      references.any((item) => item.containsKey('uploadPlaceholderPath')),
      isFalse,
    );
  });

  test('no-products face photo is persisted as a face-photo reference', () {
    final now = DateTime.utc(2026, 7, 22, 8);
    final bundle = OnboardingCompletionService.buildBundle(
      OnboardingDraft(
        uid: 'no-products-user',
        baseTimeline: BaseTimelineDraft(
          skinCareSetupPath: 'no_products',
          skinCareSkipped: true,
          skinCareFacePhotoAssetId: 'face-asset',
          skinCareFacePhotoR2Key:
              'users/no-products-user/onboarding/skin_face/face-asset.jpg',
          skinCareFacePhotoStatus: 'uploaded',
          skinCareFacePhotoCreatedAt: now,
          skinCareFacePhotoUpdatedAt: now,
        ),
      ),
    );

    final reference = bundle.uploadedAssetReferences.single;
    expect(reference.id, 'face-asset');
    expect(reference.section, 'skin_care');
    expect(reference.mode, 'no_products');
    expect(reference.uploadedAssetR2Key, contains('face-asset.jpg'));
  });

  test('FakeOnboardingRepository saves and fetches draft', () async {
    final repository = FakeOnboardingRepository();
    final draft = _draftWithUploadReferences().copyWith(currentStep: 6);

    await repository.saveDraft(draft);

    final saved = await repository.fetchDraft(draft.uid);
    expect(saved, isNotNull);
    expect(saved!.currentStep, 6);
    expect(
      saved.baseTimeline.pendingFutureImports.first.uploadedAssetId,
      'class-asset',
    );
    expect(saved.baseTimeline.skinCareProductPhotoAssetId, 'skin-asset');
    expect(saved.baseTimeline.skinCareProductPhotoR2Key, contains('skin_care'));
  });

  test(
    'FakeOnboardingRepository persists backward currentStep changes',
    () async {
      final repository = FakeOnboardingRepository();
      final draft = _draftWithUploadReferences().copyWith(currentStep: 3);

      await repository.saveDraft(draft);
      await repository.saveDraft(draft.copyWith(currentStep: 2));

      final saved = await repository.fetchDraft(draft.uid);
      expect(saved, isNotNull);
      expect(saved!.currentStep, 2);
    },
  );

  test(
    'FakeOnboardingRepository completeOnboarding saves final draft and completion bundle',
    () async {
      final repository = FakeOnboardingRepository();
      final finalDraft = _draftWithUploadReferences().copyWith(
        currentStep: OnboardingDraft.lastStepIndex,
        onboardingCompleted: true,
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
      );
      final bundle = OnboardingCompletionService.buildBundle(finalDraft);

      await repository.completeOnboarding(
        finalDraft: finalDraft,
        bundle: bundle,
      );

      final savedDraft = await repository.fetchDraft(finalDraft.uid);
      final savedBundle = repository.savedCompletionBundle(finalDraft.uid);
      expect(savedDraft, isNotNull);
      expect(savedDraft!.onboardingCompleted, isTrue);
      expect(savedBundle, isNotNull);
      expect(savedBundle!.uploadedAssetReferences, hasLength(3));
      expect(
        savedBundle.uploadedAssetReferences
            .singleWhere((entry) => entry.uploadedAssetId == 'skin-asset')
            .mode,
        'has_products',
      );
    },
  );

  test('Firestore onboarding paths remain correct', () {
    expect(
      FirestoreUserPaths.onboardingDraft('abc'),
      'users/abc/onboarding/draft',
    );
    expect(
      FirestoreUserPaths.onboardingCompletionBundle('abc'),
      'users/abc/onboarding/completionBundle',
    );
  });

  test(
    'completion bundle round trip preserves routine item contract fields',
    () {
      final bundle = OnboardingCompletionService.buildBundle(
        _completedHydrationDraft(),
      );

      final roundTrip = OnboardingCompletionBundle.fromMap(bundle.toMap());
      final item = roundTrip.routineItemsForApp.firstWhere(
        (candidate) => candidate.id == 'class-main',
      );

      expect(item.userId, 'phase2b-user');
      expect(item.category, RoutineCategory.classBlock);
      expect(item.source, RoutineSource.onboarding);
      expect(item.priority, RoutinePriority.mustDo);
      expect(item.hardBlock, isTrue);
      expect(item.blockType, RoutineBlockType.hardBlock);
    },
  );

  test('completed onboarding bundle hydrates local frontend state', () async {
    final container = ProviderContainer(
      overrides: [
        habitSystemsRepositoryProvider.overrideWithValue(
          FakeHabitSystemsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final finalDraft = _completedHydrationDraft().copyWith(
      onboardingCompleted: true,
      currentStep: OnboardingDraft.lastStepIndex,
      stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    );
    final bundle = OnboardingCompletionService.buildBundle(finalDraft);
    await container
        .read(onboardingRepositoryProvider)
        .completeOnboarding(finalDraft: finalDraft, bundle: bundle);

    final result = await const OnboardingFrontendHydrationService().hydrate(
      read: container.read,
      bundle: bundle,
    );

    expect(result.changed, isTrue);
    expect(container.read(mockRoutineProvider), isNotEmpty);
    expect(container.read(routineNotifierProvider).items, isNotEmpty);
    expect(container.read(mockGoalProvider), isNotEmpty);
    expect(container.read(mockTrackerProvider).trackerSessions, isNotEmpty);
    expect(
      container.read(mockUserProfileProvider).onboardingCompleted,
      isFalse,
    );
    expect(container.read(mockTrackerProvider).moneyGoal.dailyTarget, 25);
    expect(container.read(mockCoachPreferencesProvider).name, 'Mira');
    expect(container.read(mockCoachPreferencesProvider).style, 'Strict Mentor');
    expect(
      container.read(mockNotificationPreferencesProvider).morningStart,
      isFalse,
    );
    expect(
      container.read(mockNotificationPreferencesProvider).nightReflection,
      isFalse,
    );
    expect(
      container.read(mockNotificationPreferencesProvider).intensity,
      NotificationIntensity.high,
    );

    final second = await const OnboardingFrontendHydrationService().hydrate(
      read: container.read,
      bundle: bundle,
    );
    expect(second.routineItemIds, isEmpty);
    expect(second.mockRoutineItemIds, isEmpty);
    expect(second.goalIds, isEmpty);
    expect(
      container
          .read(routineNotifierProvider)
          .items
          .where((item) => item.onboardingSourceItemId == 'class-main'),
      hasLength(1),
    );
    expect(
      container
          .read(mockRoutineProvider)
          .where((item) => item.onboardingSourceItemId == 'class-main'),
      hasLength(1),
    );
  });

  test('missing completion bundle fetch is null-safe', () async {
    final repository = FakeOnboardingRepository();

    await expectLater(
      repository.fetchCompletionBundle('missing-user'),
      completion(isNull),
    );
  });

  test(
    'completed firebase login blocks on a missing completion snapshot',
    () async {
      final user = AuthUser(
        uid: 'phase2b-user',
        email: 'completed@example.com',
        displayName: 'Completed User',
        emailVerified: true,
      );
      final profileRepository = FakeProfileRepository();
      await profileRepository.saveUserProfile(
        UserProfile.empty(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
        ).copyWith(
          onboardingCompleted: true,
          onboardingStep: OnboardingDraft.lastStepIndex,
          updatedAt: DateTime.utc(2026, 6, 2),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(
            OptivusBackendMode.firebase,
          ),
          authRepositoryProvider.overrideWithValue(
            _ImmediateAuthRepository(user),
          ),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          regionSettingsRepositoryProvider.overrideWithValue(
            FakeRegionSettingsRepository(),
          ),
          appPreferencesRepositoryProvider.overrideWithValue(
            FakeAppPreferencesRepository(),
          ),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
          routineImportReviewRepositoryProvider.overrideWithValue(
            FakeRoutineImportReviewRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .login('completed@example.com', 'password');

      expect(container.read(authProvider).status, AuthFlowStatus.needsAction);
      expect(
        container.read(authProvider).errorMessage,
        contains('both draft and completion snapshot are missing'),
      );
      expect(
        container.read(authProvider).onboardingFailureReason,
        OnboardingFailureReason.missingDraftAndBundle,
      );
      expect(container.read(routineNotifierProvider).items, isEmpty);
    },
  );
}

OnboardingDraft _draftWithUploadReferences() {
  final now = DateTime.utc(2026, 6, 2, 8);
  return OnboardingDraft(
    uid: 'phase2b-user',
    currentStep: 4,
    baseTimeline: BaseTimelineDraft(
      skinCareProductPhotoAssetId: 'skin-asset',
      skinCareProductPhotoR2Key:
          'users/phase2b-user/onboarding/skin_care/skin-asset.jpg',
      skinCareProductPhotoStatus: 'uploaded',
      skinCareProductPhotoCreatedAt: now,
      skinCareProductPhotoUpdatedAt: DateTime.utc(2026, 6, 2, 8, 30),
      pendingFutureImports: [
        PendingFutureImportDraft(
          id: 'classes_photo',
          section: 'Classes',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'class-asset',
          uploadedAssetR2Key:
              'users/phase2b-user/onboarding/class_timetable/class-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'eating_photo',
          section: 'Eating',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'menu-asset',
          uploadedAssetR2Key:
              'users/phase2b-user/onboarding/eating_menu/menu-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'skin_photo',
          section: 'Skin Care',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'skin-asset',
          uploadedAssetR2Key:
              'users/phase2b-user/onboarding/skin_care/skin-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'manual_text',
          section: 'Classes',
          mode: 'Pasted Text',
          createdAt: now,
          pastedText: 'Monday 9 AM class',
        ),
      ],
    ),
  );
}

class _ImmediateAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  final AuthUser user;

  const _ImmediateAuthRepository(this.user);

  @override
  Stream<AuthUser?> get authStateChanges => const Stream<AuthUser?>.empty();

  @override
  AuthUser? get currentUser => user;

  @override
  Future<String?> currentIdToken() async => 'firebase-token';

  @override
  Future<AuthUser> signInAnonymously() async => user;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => user;

  @override
  Future<AuthUser?> reloadCurrentUser() async => user;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => user;
}

OnboardingDraft _completedHydrationDraft() {
  return OnboardingDraft(
    uid: 'phase2b-user',
    baseTimeline: const BaseTimelineDraft(
      blocks: [
        TimelineBlockDraft(
          id: 'class-main',
          section: 'classes',
          title: 'Morning class',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
    badHabits: const [
      BadHabitDraft(
        id: 'bad-scroll',
        habitKey: 'doom_scrolling',
        displayName: 'Doom Scrolling',
        dailySpend: 25,
        lostTimeMinutes: 30,
      ),
    ],
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'focused_student',
        displayName: 'Focused Student',
        systemKeys: ['study_block'],
      ),
    ],
    coachSetup: const CoachSetupDraft(
      coachName: 'Sensei',
      customCoachName: 'Mira',
      coachStyle: 'strict_mentor',
    ),
    notifications: const NotificationSetupDraft(
      preferencesConfirmed: true,
      morningStartReminder: false,
      nextTaskReminder: true,
      eatingReminder: false,
      badHabitCheckInReminder: true,
      savingsReminder: true,
      nightReflectionReminder: false,
      reminderIntensity: 'high',
    ),
  );
}
