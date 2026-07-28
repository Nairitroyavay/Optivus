import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/screens/onboarding_recovery_screen.dart';
import 'package:optivus/features/recovery/services/diagnostic_bundle_service.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/features/recovery/widgets/partial_failure_status_banner.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group H Adversarial Stress-Test: Recovery Screen UI & State Repair', () {
    // =========================================================================
    // 1. 4-TIER RECOVERY FALLBACK STRESS TEST
    // =========================================================================
    group('1. 4-Tier Recovery Fallback Matrix', () {
      late FakeOnboardingRepository fakeOnboardingRepo;
      late FakeProfileRepository fakeProfileRepo;

      setUp(() {
        fakeOnboardingRepo = FakeOnboardingRepository();
        fakeProfileRepo = FakeProfileRepository();
      });

      test(
        'Tier 1: Returns tier1BundleFound when completion bundle exists',
        () async {
          const uid = 'user-tier-1';
          final draft = OnboardingDraft(
            uid: uid,
          ).copyWith(onboardingCompleted: true);
          final bundle = OnboardingCompletionService.buildBundle(draft);
          await fakeOnboardingRepo.saveCompletionBundle(bundle);

          final result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: fakeOnboardingRepo,
                profileRepository: fakeProfileRepo,
              );

          expect(result.tier, equals(OnboardingRecoveryTier.tier1BundleFound));
          expect(result.hasBundle, isTrue);
          expect(result.bundle?.uid, equals(uid));
        },
      );

      test(
        'Tier 2: Returns tier2RebuiltFromDraft when draft exists but bundle is missing',
        () async {
          const uid = 'user-tier-2';
          final draft = OnboardingDraft(
            uid: uid,
          ).copyWith(onboardingCompleted: false, currentStep: 3);
          await fakeOnboardingRepo.saveDraft(draft);

          final result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: fakeOnboardingRepo,
                profileRepository: fakeProfileRepo,
              );

          expect(
            result.tier,
            equals(OnboardingRecoveryTier.tier2RebuiltFromDraft),
          );
          expect(result.hasBundle, isTrue);
          expect(result.draft?.onboardingCompleted, isTrue);
          expect(
            result.draft?.currentStep,
            equals(OnboardingDraft.lastStepIndex),
          );

          // Verify bundle was written to repository
          final savedBundle = await fakeOnboardingRepo.fetchCompletionBundle(
            uid,
          );
          expect(savedBundle, isNotNull);
          expect(savedBundle?.uid, equals(uid));
        },
      );

      test(
        'Tier 3: Returns tier3Synthesized when draft & bundle missing, but user profile exists',
        () async {
          const uid = 'user-tier-3';
          final profile = UserProfile.empty(uid: uid, email: 'tier3@test.com');
          await fakeProfileRepo.saveUserProfile(profile);

          final result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: fakeOnboardingRepo,
                profileRepository: fakeProfileRepo,
              );

          expect(result.tier, equals(OnboardingRecoveryTier.tier3Synthesized));
          expect(result.hasBundle, isTrue);
          expect(result.draft, isNotNull);

          // Verify synthesized draft and bundle saved
          final savedDraft = await fakeOnboardingRepo.fetchDraft(uid);
          final savedBundle = await fakeOnboardingRepo.fetchCompletionBundle(
            uid,
          );
          expect(savedDraft, isNotNull);
          expect(savedBundle, isNotNull);
        },
      );

      test(
        'Tier 4: Returns tier4ResetRequired when no bundle, draft, or profile exists',
        () async {
          const uid = 'user-tier-4-empty';

          final result =
              await OnboardingCompletionService.recoverCompletionState(
                uid: uid,
                onboardingRepository: fakeOnboardingRepo,
                profileRepository: fakeProfileRepo,
              );

          expect(
            result.tier,
            equals(OnboardingRecoveryTier.tier4ResetRequired),
          );
          expect(result.hasBundle, isFalse);
          expect(result.bundle, isNull);
          expect(result.draft, isNull);
        },
      );

      test(
        'executeRecoveryAction executes RetryCompletionJobAction and handles Tier 4 transition',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
              profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'empty-user',
            email: 'empty@test.com',
            emailVerified: true,
          );
          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.backendRestoreFailed,
          );

          // Under empty repos, RetryCompletionJobAction encounters Tier 4
          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(const RetryCompletionJobAction());

          expect(container.read(authProvider).onboardingIncomplete, isTrue);
        },
      );

      test(
        'executeRecoveryAction executes RebuildBundleFromDraftAction when draft is absent',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
              profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'no-draft-user',
            email: 'nodraft@test.com',
            emailVerified: true,
          );
          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.backendRestoreFailed,
          );

          // When draft is absent, RebuildBundleFromDraftAction falls back to recoverCompletionState
          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(const RebuildBundleFromDraftAction());

          expect(container.read(authProvider).onboardingIncomplete, isTrue);
        },
      );

      test(
        'executeRecoveryAction executes SynthesizeBundleAction under broken state',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
              profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            ],
          );
          addTearDown(container.dispose);

          const testUser = AuthUser(
            uid: 'synth-user',
            email: 'synth@test.com',
            emailVerified: true,
          );
          container.read(authProvider.notifier).state = const AuthState(
            user: testUser,
            status: AuthFlowStatus.backendRestoreFailed,
          );

          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(const SynthesizeBundleAction());

          expect(
            container.read(authProvider).status,
            equals(AuthFlowStatus.signedInOnboardingIncomplete),
          );
        },
      );
    });

    // =========================================================================
    // 2. FORCE-RESYNC ACTION EXECUTION STRESS TEST
    // =========================================================================
    group('2. ForceResyncProjectionsAction Resilience', () {
      test(
        'ForceResyncProjectionsAction carries correct id, label, and description',
        () {
          const action = ForceResyncProjectionsAction();
          expect(action.actionId, equals('force_resync_projections'));
          expect(action.label, equals('Force Resync Projections'));
          expect(action.description, contains('projections'));
        },
      );

      test(
        'ForceResyncProjectionsAction recovers bundle when missing before resyncing',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final fakeOnboardingRepo = FakeOnboardingRepository();
          final fakeProfileRepo = FakeProfileRepository();

          const uid = 'resync-user-1';
          final profile = UserProfile.empty(uid: uid, email: 'resync@test.com');
          await fakeProfileRepo.saveUserProfile(profile);

          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              onboardingRepositoryProvider.overrideWithValue(
                fakeOnboardingRepo,
              ),
              profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
            ],
          );
          addTearDown(container.dispose);

          container.read(authProvider.notifier).state = const AuthState(
            user: AuthUser(
              uid: uid,
              email: 'resync@test.com',
              emailVerified: true,
            ),
            status: AuthFlowStatus.backendRestoreFailed,
          );

          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(const ForceResyncProjectionsAction());

          // Bundle should have been recovered/synthesized during force-resync execution
          final bundle = await fakeOnboardingRepo.fetchCompletionBundle(uid);
          expect(bundle, isNotNull);
        },
      );

      test(
        'ForceResyncProjectionsAction gracefully handles null user state',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final container = ProviderContainer(
            overrides: [authRepositoryProvider.overrideWithValue(fakeAuthRepo)],
          );
          addTearDown(container.dispose);

          // Logged out / null user state
          container.read(authProvider.notifier).state = const AuthState(
            user: null,
            status: AuthFlowStatus.signedOut,
          );

          // Should complete cleanly without exception
          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(const ForceResyncProjectionsAction());

          expect(container.read(authProvider).user, isNull);
        },
      );
    });

    // =========================================================================
    // 3. STATUS BANNER STAGE TRANSITIONS STRESS TEST
    // =========================================================================
    group('3. PartialFailureStatusBanner Stage Transition Harness', () {
      testWidgets('Renders all 5 stages in initial state (Stage 1 active)', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PartialFailureStatusBanner(
                stageStatuses: {},
                currentStage: 'persistDraft',
                projectedItemCount: 0,
                failedItemCount: 0,
              ),
            ),
          ),
        );

        expect(find.text('Partial Completion Detected'), findsOneWidget);
        expect(find.text('Draft'), findsOneWidget);
        expect(find.text('Bundle'), findsOneWidget);
        expect(find.text('Routines'), findsOneWidget);
        expect(find.text('Habits'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Items: 0 projected, 0 failed'), findsOneWidget);
      });

      testWidgets(
        'Simulates full pipeline stage transitions (Stage 1 -> 5 -> Complete)',
        (tester) async {
          final stages = PartialFailureStatusBanner.defaultStages;
          final accumulatedStatuses = <String, bool>{};

          for (int i = 0; i < stages.length; i++) {
            final currentStage = stages[i];

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: PartialFailureStatusBanner(
                    stageStatuses: Map.from(accumulatedStatuses),
                    currentStage: currentStage,
                    projectedItemCount: i * 2,
                    failedItemCount: i > 2 ? 1 : 0,
                  ),
                ),
              ),
            );
            await tester.pump();

            expect(find.text('Partial Completion Detected'), findsOneWidget);
            expect(
              find.text('Items: ${i * 2} projected, ${i > 2 ? 1 : 0} failed'),
              findsOneWidget,
            );

            // Mark current stage as done for next iteration
            accumulatedStatuses[currentStage] = true;
          }

          // Test fully completed state
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PartialFailureStatusBanner(
                  stageStatuses: accumulatedStatuses,
                  currentStage: null,
                  projectedItemCount: 10,
                  failedItemCount: 0,
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Items: 10 projected, 0 failed'), findsOneWidget);
        },
      );

      testWidgets('Hides Resume button when onResume is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PartialFailureStatusBanner(
                stageStatuses: {'persistDraft': true},
                currentStage: 'persistBundle',
                onResume: null,
              ),
            ),
          ),
        );

        expect(find.text('Resume'), findsNothing);
      });

      testWidgets('Triggers onResume callback when Resume button is tapped', (
        tester,
      ) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PartialFailureStatusBanner(
                stageStatuses: {'persistDraft': true},
                currentStage: 'persistBundle',
                onResume: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('Resume'), findsOneWidget);
        await tester.tap(find.text('Resume'));
        expect(tapped, isTrue);
      });

      testWidgets('Renders unknown or custom stage names gracefully', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PartialFailureStatusBanner(
                stageStatuses: {'customStage': true},
                currentStage: 'customStage',
              ),
            ),
          ),
        );

        expect(find.text('Partial Completion Detected'), findsOneWidget);
      });
    });

    // =========================================================================
    // 4. RECOVERY UI & STATE REPAIR EDGE CASES
    // =========================================================================
    group('4. Recovery UI & State Repair Edge Cases', () {
      test(
        'Failure reason mapping covers all OnboardingFailureReason values',
        () {
          final reasons = OnboardingFailureReason.values;
          expect(reasons.length, equals(8));
        },
      );

      testWidgets(
        'OnboardingRecoveryScreen renders correctly for all failure reasons',
        (tester) async {
          for (final reason in OnboardingFailureReason.values) {
            final fakeAuthRepo = FakeAuthRepository();
            final container = ProviderContainer(
              overrides: [
                authRepositoryProvider.overrideWithValue(fakeAuthRepo),
              ],
            );
            addTearDown(container.dispose);

            container.read(authProvider.notifier).state = AuthState(
              user: const AuthUser(
                uid: 'u1',
                email: 'test@example.com',
                emailVerified: true,
              ),
              status: AuthFlowStatus.backendRestoreFailed,
              onboardingFailureReason: reason,
              errorMessage: 'Test error message for ${reason.name}',
            );

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const MaterialApp(home: OnboardingRecoveryScreen()),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Setup Verification Incomplete'), findsOneWidget);
            expect(find.textContaining('Reason:'), findsOneWidget);
            expect(
              find.text('Test error message for ${reason.name}'),
              findsOneWidget,
            );
          }
        },
      );

      test(
        'RecoveryRetryController exponential backoff caps at 60s for attempts 1-7',
        () {
          expect(RecoveryRetryController.calculateBackoffSeconds(1), equals(2));
          expect(RecoveryRetryController.calculateBackoffSeconds(2), equals(4));
          expect(RecoveryRetryController.calculateBackoffSeconds(3), equals(8));
          expect(
            RecoveryRetryController.calculateBackoffSeconds(4),
            equals(16),
          );
          expect(
            RecoveryRetryController.calculateBackoffSeconds(5),
            equals(32),
          );
          expect(
            RecoveryRetryController.calculateBackoffSeconds(6),
            equals(60),
          );
          expect(
            RecoveryRetryController.calculateBackoffSeconds(7),
            equals(60),
          );
        },
      );

      test('DiagnosticBundleService redactPii handles edge cases', () {
        final textWithMultiple =
            'User john@a.com and alice@b.org contacted John Doe and Alice Smith';
        final redacted = DiagnosticBundleService.redactPii(
          textWithMultiple,
          userName: 'John Doe',
        );

        expect(redacted, contains('[REDACTED_EMAIL]'));
        expect(redacted, contains('[REDACTED_NAME]'));
        expect(redacted, isNot(contains('john@a.com')));
        expect(redacted, isNot(contains('alice@b.org')));
        expect(redacted, isNot(contains('John Doe')));
      });

      test(
        'DiagnosticBundleService redactPii handles null/empty inputs gracefully',
        () {
          expect(
            DiagnosticBundleService.redactPii('Hello World', userName: null),
            equals('Hello World'),
          );
          expect(
            DiagnosticBundleService.redactPii('Hello World', userName: ''),
            equals('Hello World'),
          );
          expect(
            DiagnosticBundleService.redactPii('', userName: 'John'),
            equals(''),
          );
        },
      );

      testWidgets(
        'OnboardingRecoveryScreen layout survives extreme viewports without overflow',
        (tester) async {
          final viewports = [
            const Size(320, 480), // Ultra compact mobile
            const Size(390, 844), // Modern iPhone
            const Size(1024, 768), // Tablet landscape
            const Size(800, 360), // Wide landscape
          ];

          for (final size in viewports) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            final container = ProviderContainer();

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const MaterialApp(home: OnboardingRecoveryScreen()),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason: 'Overflow error at physicalSize $size',
            );

            container.dispose();
            tester.view.resetPhysicalSize();
          }
        },
      );
    });
  });
}
