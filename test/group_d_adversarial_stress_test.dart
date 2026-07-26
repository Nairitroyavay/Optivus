import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/goals/providers/goals_navigation_provider.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/providers/home_navigation_provider.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/habit_systems_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/onboarding_account_migration_service.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Group D Adversarial Test - Account switching latency & data isolation',
    () {
      test(
        'Account switching purges previous user state prior to loading new user state',
        () async {
          final fakeAuth = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuth),
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
            ],
          );
          addTearDown(container.dispose);

          // 1. Log in User A and populate sensitive state
          final authNotifier = container.read(authProvider.notifier);
          await authNotifier.login('usera@optivus.dev', 'password123');

          container
              .read(homeMindNoteProvider.notifier)
              .addNote(
                "User A Secret Note",
                MindNoteType.overthinking,
                MindNoteIntensity.high,
              );
          container.read(appNavigationProvider.notifier).goToProfile();
          container
              .read(trackerSettingsProvider.notifier)
              .setHydrationReminders(false);

          expect(container.read(homeMindNoteProvider), isNotEmpty);
          expect(container.read(appNavigationProvider), equals(5));

          // 2. Perform login for User B
          await authNotifier.login('userb@optivus.dev', 'password123');

          // State now belongs to User B and User A's data is purged
          final currentUser = container.read(authProvider).user;
          expect(currentUser?.email, equals('userb@optivus.dev'));
          expect(
            container
                .read(homeMindNoteProvider)
                .any((n) => n.content.contains("User A Secret Note")),
            isFalse,
            reason: "User A's notes must be purged after user transition",
          );
          expect(container.read(homeMindNoteProvider), isEmpty);
          expect(container.read(appNavigationProvider), equals(0));
        },
      );

      test('Sequential account switching maintains data isolation', () async {
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
          ],
        );
        addTearDown(container.dispose);

        final authNotifier = container.read(authProvider.notifier);

        await authNotifier.login('rapid1@optivus.dev', 'password123');
        container
            .read(homeMindNoteProvider.notifier)
            .addNote(
              "Rapid 1 Note",
              MindNoteType.overthinking,
              MindNoteIntensity.low,
            );

        await authNotifier.login('rapid2@optivus.dev', 'password123');
        await authNotifier.login('rapid3@optivus.dev', 'password123');

        final activeUser = container.read(authProvider).user;
        expect(activeUser?.email, equals('rapid3@optivus.dev'));
        expect(
          container
              .read(homeMindNoteProvider)
              .any((n) => n.content.contains("Rapid 1 Note")),
          isFalse,
        );
      });
    },
  );

  group(
    'Group D Adversarial Test - Email verification enforcement & bypass prevention',
    () {
      test(
        'markOnboardingComplete rejects unverified password accounts',
        () async {
          final fakeAuth = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuth),
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
            ],
          );
          addTearDown(container.dispose);

          final unverifiedUser = await fakeAuth.signUp(
            'bypass-test@optivus.dev',
            'password123',
          );
          expect(unverifiedUser.emailVerified, isFalse);
          expect(unverifiedUser.providerId, equals('password'));

          final authNotifier = container.read(authProvider.notifier);

          // Attempt explicit bypass by invoking markOnboardingComplete directly
          await authNotifier.markOnboardingComplete(unverifiedUser);

          final state = container.read(authProvider);
          expect(state.status, equals(AuthFlowStatus.signedInEmailUnverified));
          expect(state.onboardingComplete, isFalse);
        },
      );

      test(
        'AuthState.statusFor enforces signedInEmailUnverified even if onboardingCompleted is true',
        () {
          const unverifiedUser = AuthUser(
            uid: 'uv-123',
            email: 'unverified@optivus.dev',
            emailVerified: false,
            providerId: 'password',
          );

          final statusWithCompletedTrue = AuthNotifier.statusFor(
            unverifiedUser,
            true,
          );
          final statusWithCompletedFalse = AuthNotifier.statusFor(
            unverifiedUser,
            false,
          );

          expect(
            statusWithCompletedTrue,
            equals(AuthFlowStatus.signedInEmailUnverified),
          );
          expect(
            statusWithCompletedFalse,
            equals(AuthFlowStatus.signedInEmailUnverified),
          );
        },
      );

      test(
        'GoRouter redirect traps unverified password user on /verify-email',
        () async {
          final fakeAuth = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuth),
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
            ],
          );
          addTearDown(container.dispose);

          final unverifiedUser = await fakeAuth.signUp(
            'router-verify@optivus.dev',
            'password123',
          );

          final authState = AuthState(
            user: unverifiedUser,
            status: AuthFlowStatus.signedInEmailUnverified,
          );
          final redirect = optivusAuthRedirect(
            authState: authState,
            userProfile: UserProfile.empty(
              uid: unverifiedUser.uid,
              email: unverifiedUser.email ?? '',
            ).copyWith(onboardingCompleted: true),
            uri: Uri.parse('/app?tab=0'),
          );

          expect(
            authState.status,
            equals(AuthFlowStatus.signedInEmailUnverified),
          );
          expect(redirect, equals('/verify-email'));
          expect(unverifiedUser.emailVerified, isFalse);
        },
      );
    },
  );

  group('Group D Adversarial Test - Comprehensive Sign-out Controller Sweep', () {
    test(
      'Logout sweep completely clears all feature state and detail request providers',
      () async {
        final fakeAuth = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
          ],
        );
        addTearDown(container.dispose);

        await fakeAuth.signIn('sweep-test@optivus.dev', 'password123');
        final authNotifier = container.read(authProvider.notifier);

        // Mutate every feature controller
        container.read(homeDashboardProvider.notifier).cycleNowNextState();
        container
            .read(homeMindNoteProvider.notifier)
            .addNote(
              'Sweep Note',
              MindNoteType.overthinking,
              MindNoteIntensity.high,
            );
        container
            .read(fitnessCenterProvider.notifier)
            .selectActivityType(FitnessActivityType.cycling);
        container
            .read(trackerSettingsProvider.notifier)
            .setHydrationReminders(false);
        container.read(appNavigationProvider.notifier).goToProfile();
        container.read(homeDetailViewRequestProvider.notifier).state =
            const HomeDetailTarget.mission();
        container.read(trackerDetailViewRequestProvider.notifier).state =
            TrackerDetailTarget.view(TrackerDetailView.hydration);
        container.read(profileDetailViewRequestProvider.notifier).state =
            const ProfileDetailTarget(view: ProfileDetailView.privacySecurity);
        container.read(routineDetailViewRequestProvider.notifier).state =
            const RoutineDetailTarget(view: RoutineDetailView.routineSettings);
        container.read(coachDetailViewRequestProvider.notifier).state =
            CoachDetailView.sessionHistory;
        container.read(goalsDetailViewRequestProvider.notifier).state =
            const GoalsDetailTarget(view: GoalsDetailView.goalSettings);
        container
            .read(profileSettingsProvider.notifier)
            .loadProfileSettings(const UserProfileSettings(name: 'Sweep User'));

        // Confirm non-default values before logout
        expect(container.read(homeMindNoteProvider), isNotEmpty);
        expect(container.read(appNavigationProvider), equals(5));
        expect(
          container.read(trackerSettingsProvider).hydrationReminders,
          isFalse,
        );

        // Perform Logout
        await authNotifier.logout();

        // Assert full reset across all 15+ providers
        expect(
          container.read(authProvider).status,
          equals(AuthFlowStatus.signedOut),
        );
        expect(container.read(homeMindNoteProvider), isEmpty);
        expect(container.read(appNavigationProvider), equals(0));
        expect(
          container.read(fitnessCenterProvider).selectedActivityType,
          equals(FitnessActivityType.walk),
        );
        expect(
          container.read(trackerSettingsProvider).hydrationReminders,
          isTrue,
        );
        expect(
          container.read(homeDetailViewRequestProvider).view,
          equals(HomeDetailView.none),
        );
        expect(
          container.read(trackerDetailViewRequestProvider).view,
          equals(TrackerDetailView.none),
        );
        expect(
          container.read(profileDetailViewRequestProvider).view,
          equals(ProfileDetailView.none),
        );
        expect(
          container.read(routineDetailViewRequestProvider).view,
          equals(RoutineDetailView.none),
        );
        expect(
          container.read(coachDetailViewRequestProvider),
          equals(CoachDetailView.none),
        );
        expect(
          container.read(goalsDetailViewRequestProvider).view,
          equals(GoalsDetailView.none),
        );
        expect(container.read(profileSettingsProvider).profile.name, isEmpty);
      },
    );
  });

  group(
    'Group D Adversarial Test - Anonymous Account Migration with Populated Data',
    () {
      test(
        'OnboardingAccountMigrationService preserves draft, routines, history, habits, and preferences across UIDs',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          const oldAnonUid = 'anon-user-777';
          const newUid = 'linked-user-888';
          final now = DateTime.now();

          // 1. Populate Anonymous User Data
          const draft = OnboardingDraft(
            uid: oldAnonUid,
            currentStep: 4,
            slipUpHandling: 'Reset next day',
          );
          await container.read(onboardingRepositoryProvider).saveDraft(draft);

          final routineItem = RoutineItem(
            id: 'item-1',
            userId: oldAnonUid,
            title: 'Morning Yoga',
            category: RoutineCategory.health,
            blockType: RoutineBlockType.softBlock,
            source: RoutineSource.manual,
            status: RoutineStatus.planned,
            priority: RoutinePriority.goodToDo,
            startMinute: 480,
            endMinute: 540,
            createdAt: now,
            updatedAt: now,
          );
          await container
              .read(routineRepositoryProvider)
              .createRoutineItem(oldAnonUid, routineItem);

          final historyRecord = RoutineOccurrenceRecord(
            id: 'history-1',
            ownerUid: oldAnonUid,
            routineItemId: 'item-1',
            occurrenceDateKey: '2026-07-25',
            status: RoutineStatus.completed,
            source: 'routine',
            action: 'complete',
            operationKey: 'op-1',
            createdAt: now,
            updatedAt: now,
          );
          await container
              .read(routineHistoryRepositoryProvider)
              .appendHistory(oldAnonUid, historyRecord);

          final habitSystem = HabitSystemRecord(
            systemId: 'habit-1',
            ownerUid: oldAnonUid,
            title: 'Daily Hydration',
            category: RoutineCategory.health,
            systemType: HabitSystemType.goodHabit,
            createdAt: now,
            updatedAt: now,
          );
          await container
              .read(habitSystemsRepositoryProvider)
              .reconcileProjectedSystems(
                ownerUid: oldAnonUid,
                projectionId: 'init-anon',
                systems: [habitSystem],
              );

          const prefs = UserPreferences(themeMode: 'Dark', haptics: false);
          await container
              .read(appPreferencesRepositoryProvider)
              .saveAppPreferences(oldAnonUid, prefs);

          // 2. Perform Account Migration
          await OnboardingAccountMigrationService.migrateAccountData(
            oldAnonUid: oldAnonUid,
            newUid: newUid,
            read: container.read,
          );

          // 3. Verify all data transferred cleanly to newUid
          final migratedDraft = await container
              .read(onboardingRepositoryProvider)
              .fetchDraft(newUid);
          expect(migratedDraft, isNotNull);
          expect(migratedDraft?.uid, equals(newUid));
          expect(migratedDraft?.slipUpHandling, equals('Reset next day'));

          final migratedItems = await container
              .read(routineRepositoryProvider)
              .fetchRoutineItems(newUid);
          expect(migratedItems.length, equals(1));
          expect(migratedItems.first.userId, equals(newUid));
          expect(migratedItems.first.title, equals('Morning Yoga'));

          final migratedHistory = await container
              .read(routineHistoryRepositoryProvider)
              .fetchHistory(newUid);
          expect(migratedHistory.length, equals(1));
          expect(migratedHistory.first.ownerUid, equals(newUid));
          expect(migratedHistory.first.routineItemId, equals('item-1'));

          final migratedHabits = await container
              .read(habitSystemsRepositoryProvider)
              .fetchHabitSystems(newUid);
          expect(migratedHabits.length, equals(1));
          expect(migratedHabits.first.ownerUid, equals(newUid));
          expect(migratedHabits.first.title, equals('Daily Hydration'));

          final migratedPrefs = await container
              .read(appPreferencesRepositoryProvider)
              .fetchAppPreferences(newUid);
          expect(migratedPrefs, isNotNull);
          expect(migratedPrefs?.themeMode, equals('Dark'));
          expect(migratedPrefs?.haptics, isFalse);
        },
      );

      test(
        'Migration gracefully handles empty or identical UIDs without crashing',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Same UIDs -> no-op
          await OnboardingAccountMigrationService.migrateAccountData(
            oldAnonUid: 'same-uid',
            newUid: 'same-uid',
            read: container.read,
          );

          // Empty UIDs -> no-op
          await OnboardingAccountMigrationService.migrateAccountData(
            oldAnonUid: '',
            newUid: 'new-uid',
            read: container.read,
          );

          expect(true, isTrue);
        },
      );
    },
  );

  group('Group D Adversarial Test - Typed Auth Error Mapping', () {
    test(
      'mapAuthError correctly maps edge case exceptions and returns friendly messages',
      () {
        final netErr = mapAuthError(
          const SocketException('Failed host lookup'),
        );
        expect(netErr.reason, equals(AuthFailureReason.networkFailure));
        expect(friendlyAuthError(netErr), contains('Network error'));

        final pwdErr = mapAuthError(Exception('wrong-password'));
        expect(pwdErr.reason, equals(AuthFailureReason.invalidCredentials));

        final dupErr = mapAuthError(Exception('email-already-in-use'));
        expect(dupErr.reason, equals(AuthFailureReason.emailAlreadyInUse));
        expect(isEmailAlreadyInUseError(dupErr), isTrue);

        final tokenErr = mapAuthError(Exception('invalid-user-token'));
        expect(tokenErr.reason, equals(AuthFailureReason.invalidToken));

        final unknownErr = mapAuthError(Exception('Custom error string'));
        expect(unknownErr.reason, equals(AuthFailureReason.unknown));
        expect(unknownErr.message, equals('Custom error string'));
      },
    );
  });
}
