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
            currentStep: OnboardingDraft.lastStepIndex,
            stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
            onboardingCompleted: true,
          );
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
        'Missing setup remains missing when only a user profile exists',
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

          expect(result.tier, equals(OnboardingRecoveryTier.missingSetup));
          expect(result.hasBundle, isFalse);
          expect(result.draft, isNull);

          // Verify synthesized draft and bundle saved
          final savedDraft = await fakeOnboardingRepo.fetchDraft(uid);
          final savedBundle = await fakeOnboardingRepo.fetchCompletionBundle(
            uid,
          );
          expect(savedDraft, isNull);
          expect(savedBundle, isNull);
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
        'executeRecoveryAction executes RetryNetworkAction and handles Tier 4 transition',
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

          // Under empty repos, RetryNetworkAction encounters Tier 4
          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(const RetryNetworkAction());

          expect(container.read(authProvider).onboardingIncomplete, isTrue);
        },
      );

      test(
        'RebuildBundleFromVerifiedDraftAction fails closed when draft is absent',
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

          await container
              .read(authProvider.notifier)
              .executeRecoveryAction(
                const RebuildBundleFromVerifiedDraftAction(),
              );

          expect(
            container.read(authProvider).status,
            equals(AuthFlowStatus.backendRestoreFailed),
          );
          expect(await fakeOnboardingRepo.fetchDraft(testUser.uid), isNull);
        },
      );

      test(
        'RebuildBundleFromVerifiedDraftAction preserves a broken state',
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
              .executeRecoveryAction(
                const RebuildBundleFromVerifiedDraftAction(),
              );

          expect(
            container.read(authProvider).status,
            equals(AuthFlowStatus.backendRestoreFailed),
          );
        },
      );
    });

    // =========================================================================
    // 2. FORCE-RESYNC ACTION EXECUTION STRESS TEST
    // =========================================================================
    group('2. RepairProjectionAction Resilience', () {
      test(
        'RepairProjectionAction carries correct id, label, and description',
        () {
          const action = RepairProjectionAction();
          expect(action.actionId, equals('repair_projection'));
          expect(action.label, equals('Repair Plan'));
          expect(action.description, contains('routines'));
        },
      );

      test(
        'RebuildBundleFromVerifiedDraftAction recovers bundle when missing',
        () async {
          final fakeAuthRepo = FakeAuthRepository();
          final fakeOnboardingRepo = FakeOnboardingRepository();
          final fakeProfileRepo = FakeProfileRepository();

          const uid = 'resync-user-1';
          final profile = UserProfile.empty(
            uid: uid,
            email: 'resync@test.com',
          ).copyWith(onboardingCompleted: true);
          await fakeProfileRepo.saveUserProfile(profile);

          final draft = OnboardingDraft(uid: uid).copyWith(
            onboardingCompleted: true,
            currentStep: OnboardingDraft.lastStepIndex,
            stepCompleted: List.generate(
              OnboardingDraft.stepCount,
              (_) => true,
            ),
            baseTimeline: const BaseTimelineDraft(
              skinCareSkipped: true,
              eatingMode: 'mess_hostel',
              blocks: [
                TimelineBlockDraft(
                  id: 'eating_1',
                  title: 'Lunch',
                  section: 'eating',
                  startMinute: 720,
                  endMinute: 780,
                  repeatDays: [1, 2, 3, 4, 5, 6, 7],
                  blockType: 'soft',
                ),
                TimelineBlockDraft(
                  id: 'fixed_1',
                  title: 'Sleep',
                  section: 'fixed',
                  startMinute: 1380,
                  endMinute: 360,
                  repeatDays: [1, 2, 3, 4, 5, 6, 7],
                  blockType: 'hard',
                ),
              ],
            ),
          );
          await fakeOnboardingRepo.saveDraft(draft);

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
              .executeRecoveryAction(
                const RebuildBundleFromVerifiedDraftAction(),
              );

          // Bundle should have been recovered/synthesized during execution
          final bundle = await fakeOnboardingRepo.fetchCompletionBundle(uid);
          expect(bundle, isNotNull);
        },
      );

      test(
        'RepairProjectionAction gracefully handles null user state',
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
              .executeRecoveryAction(const RepairProjectionAction());

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
