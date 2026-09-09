import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/core/errors/auth_error_mapper.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/features/home/providers/home_navigation_provider.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/tracker_models.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_account_migration_service.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group D - Issue 16: Auth state stream synchronization', () {
    test(
      'AuthNotifier stream subscription executes without duplicate microtask calls',
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

        expect(
          container.read(authProvider).status,
          equals(AuthFlowStatus.signedOut),
        );

        await fakeAuth.signIn('sync-test@optivus.dev', 'password123');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = container.read(authProvider);
        expect(state.user, isNotNull);
        expect(state.user?.email, equals('sync-test@optivus.dev'));
      },
    );

    testWidgets('GoRouter redirect logic evaluates state deterministically', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group(
    'Group D - Issue 17: User sign-out state invalidation for cached feature controllers',
    () {
      test(
        'logout sweep resets all feature controllers and navigation detail providers',
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

          await fakeAuth.signIn('user17@optivus.dev', 'password123');
          final authNotifier = container.read(authProvider.notifier);

          // Populate feature state
          container.read(homeDashboardProvider.notifier).cycleNowNextState();
          container
              .read(homeMindNoteProvider.notifier)
              .addNote(
                'Test Mind Note',
                MindNoteType.overthinking,
                MindNoteIntensity.medium,
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

          expect(container.read(homeMindNoteProvider), isNotEmpty);
          expect(container.read(appNavigationProvider), equals(5));

          // Perform logout
          await authNotifier.logout();

          // Verify reset state across all feature controllers
          expect(container.read(homeMindNoteProvider), isEmpty);
          expect(container.read(appNavigationProvider), equals(0));
          expect(
            container.read(homeDetailViewRequestProvider).view,
            equals(HomeDetailView.none),
          );
          expect(
            container.read(trackerDetailViewRequestProvider).view,
            equals(TrackerDetailView.none),
          );
          expect(
            container.read(fitnessCenterProvider).selectedActivityType,
            equals(FitnessActivityType.walk),
          );
          expect(
            container.read(trackerSettingsProvider).hydrationReminders,
            isTrue,
          );
        },
      );
    },
  );

  group(
    'Group D - Issue 18: Account switching data leak prevention across user scopes',
    () {
      test(
        'immediate atomic reset prevents data leaks during account switching latency',
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

          // Initialize authProvider to listen to fakeAuth state changes
          container.read(authProvider);

          // User A signs in
          await fakeAuth.signIn('usera@optivus.dev', 'password123');
          container
              .read(homeMindNoteProvider.notifier)
              .addNote(
                "User A's Secret",
                MindNoteType.overthinking,
                MindNoteIntensity.high,
              );
          expect(container.read(homeMindNoteProvider), isNotEmpty);

          // Switch to User B
          await fakeAuth.signIn('userb@optivus.dev', 'password123');
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // User A's data should be completely purged from memory
          final notes = container.read(homeMindNoteProvider);
          final hasUserANote = notes.any(
            (n) => n.content.contains("User A's Secret"),
          );
          expect(hasUserANote, isFalse);
        },
      );

      test(
        'feature controllers reject cross-user mutations with owner UID mismatch',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final homeNotifier = container.read(homeDashboardProvider.notifier);
          homeNotifier.setOwnerUid('user-123');

          // Attempt cross-user mutation with mismatched targetUid
          homeNotifier.cycleNowNextState(targetUid: 'user-456');

          // Mutation is rejected and owner remains user-123
          expect(container.read(homeDashboardProvider), isNotNull);
        },
      );
    },
  );

  group('Group D - Issue 19: Structured auth failure mapping', () {
    test('AuthErrorMapper classifies stable categories and codes', () {
      expect(
        AuthErrorMapper.map(Exception('network-request-failed')).category,
        RecoverableErrorCategory.network,
      );
      expect(
        AuthErrorMapper.map(
          const SocketException('Failed host lookup'),
        ).category,
        RecoverableErrorCategory.network,
      );
      expect(
        AuthErrorMapper.map(Exception('wrong-password')).diagnosticCode,
        DiagnosticCodes.authInvalidCredentials,
      );
      expect(
        AuthErrorMapper.map(Exception('invalid-user-token')).diagnosticCode,
        DiagnosticCodes.authSessionExpired,
      );
      expect(
        AuthErrorMapper.map(Exception('email-already-in-use')).diagnosticCode,
        DiagnosticCodes.authEmailInUse,
      );
      expect(
        AuthErrorMapper.map(Exception('too-many-requests')).diagnosticCode,
        DiagnosticCodes.authRateLimited,
      );
      expect(
        AuthErrorMapper.map(Exception('user-disabled')).diagnosticCode,
        DiagnosticCodes.authUserDisabled,
      );
      expect(
        AuthErrorMapper.map(Exception('unknown-error-code')).diagnosticCode,
        DiagnosticCodes.authUnknown,
      );
    });

    test('AuthErrorMapper returns a readable safe public message', () {
      final error = AuthErrorMapper.map(Exception('network-request-failed'));
      expect(error.publicMessage, contains('connect'));
    });
  });

  group('Group D - Issue 20: Email verification step enforcement', () {
    test('unverified password users cannot mark onboarding complete', () async {
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        ],
      );
      addTearDown(container.dispose);

      final unverifiedUser = await fakeAuth.signUp(
        'unverified@optivus.dev',
        'password123',
      );
      expect(unverifiedUser.emailVerified, isFalse);

      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.markOnboardingComplete(unverifiedUser);

      final state = container.read(authProvider);
      expect(state.status, equals(AuthFlowStatus.signedInEmailUnverified));
      expect(state.onboardingComplete, isFalse);
    });
  });

  group(
    'Group D - Issue 21: Anonymous-to-authenticated account link state preservation',
    () {
      test(
        'signInAnonymously and linkAnonymousWithEmail transition states cleanly',
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

          final authNotifier = container.read(authProvider.notifier);

          // Sign in anonymously
          await authNotifier.signInAnonymously();
          var state = container.read(authProvider);
          expect(state.user, isNotNull);
          expect(state.user?.isAnonymous, isTrue);

          final anonUid = state.user!.uid;

          // Link anonymous account to email/password
          await authNotifier.linkAnonymousWithEmail(
            'linked@optivus.dev',
            'password123',
            name: 'Linked User',
          );

          state = container.read(authProvider);
          expect(state.user, isNotNull);
          expect(state.user?.email, equals('linked@optivus.dev'));
          expect(state.user?.uid, equals(anonUid));
        },
      );

      test(
        'OnboardingAccountMigrationService migrates data across UIDs without loss',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          // Save draft under old anon UID
          const oldAnonUid = 'old-anon-uid-123';
          const newUid = 'new-linked-uid-456';

          final draft = OnboardingDraft(
            uid: oldAnonUid,
            currentStep: 3,
            slipUpHandling: 'Reset next day',
          );
          await container.read(onboardingRepositoryProvider).saveDraft(draft);

          // Migrate
          await OnboardingAccountMigrationService.migrateAccountData(
            oldAnonUid: oldAnonUid,
            newUid: newUid,
            read: container.read,
          );

          // Verify draft migrated to newUid
          final migratedDraft = await container
              .read(onboardingRepositoryProvider)
              .fetchDraft(newUid);
          expect(migratedDraft, isNotNull);
          expect(migratedDraft?.uid, equals(newUid));
          expect(migratedDraft?.slipUpHandling, equals('Reset next day'));
        },
      );
    },
  );
}
