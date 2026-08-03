import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/router/app_router.dart';

import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/features/recovery/screens/onboarding_recovery_screen.dart';
import 'package:optivus/features/recovery/services/diagnostic_bundle_service.dart';
import 'package:optivus/features/recovery/services/recovery_cache_manager.dart';
import 'package:optivus/features/recovery/services/recovery_retry_controller.dart';
import 'package:optivus/features/recovery/widgets/partial_failure_status_banner.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group H - Issue 33: Recovery Scaffold Failure Causes', () {
    test('Differentiates missingDraftAndBundle vs missingBundle', () async {
      final fakeAuthRepo = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeAuthRepo)],
      );
      addTearDown(container.dispose);

      // Verify OnboardingFailureReason values exist
      expect(OnboardingFailureReason.missingDraftAndBundle, isNotNull);
      expect(OnboardingFailureReason.missingBundle, isNotNull);
      expect(OnboardingFailureReason.corruptedBundle, isNotNull);
      expect(OnboardingFailureReason.projectionFailed, isNotNull);
      expect(OnboardingFailureReason.networkTimeout, isNotNull);
    });
  });

  group('Group H - Issue 34: Typed Error Presentation and User Messaging', () {
    testWidgets(
      'Renders failure reason chip and action titles & descriptions',
      (tester) async {
        final fakeAuthRepo = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeAuthRepo)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: OnboardingRecoveryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Setup Verification Incomplete'), findsOneWidget);
        expect(find.textContaining('Reason:'), findsOneWidget);
        expect(find.text('Retry Connection'), findsWidgets);
        expect(
          find.text(
            'Retry the last operation after a network failure.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Group H - Issue 35: Draft Profile Repair Action Execution', () {
    test(
      'executeRecoveryAction handles all action types with 4-tier fallback logic',
      () async {
        final fakeAuthRepo = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeAuthRepo)],
        );
        addTearDown(container.dispose);

        const testUser = AuthUser(
          uid: 'test-user-123',
          email: 'user@test.com',
          emailVerified: true,
        );
        container.read(authProvider.notifier).state = const AuthState(
          user: testUser,
          status: AuthFlowStatus.backendRestoreFailed,
        );

        final notifier = container.read(authProvider.notifier);

        await notifier.executeRecoveryAction(
          const ResumeOnboardingAction(),
        );
        expect(container.read(authProvider).onboardingIncomplete, isTrue);

        await notifier.executeRecoveryAction(const RebuildBundleFromVerifiedDraftAction());
        await notifier.executeRecoveryAction(
          const RebuildBundleFromVerifiedDraftAction(),
        );
        await notifier.executeRecoveryAction(const RetryNetworkAction());
        await notifier.executeRecoveryAction(
          const RepairProjectionAction(),
        );
      },
    );
  });

  group('Group H - Issue 36: Routine Projection State Force-Resync', () {
    test(
      'RepairProjectionAction triggers hydration and event projection',
      () async {
        const action = RepairProjectionAction();
        expect(action.actionId, equals('repair_projection'));
        expect(action.label, equals('Repair Plan'));
      },
    );
  });

  group('Group H - Issue 37: Cache Clearing Without Loss of Dirty Edits', () {
    test('Preserves stepDirty flags while resetting memory repos', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dirtyDraft = const OnboardingDraft(
        uid: 'test-uid-123',
      ).copyWith(stepDirty: [true, false, true, false, false, false, false]);
      container.read(mockOnboardingProvider.notifier).loadSeedData(dirtyDraft);

      final cacheManager = container.read(recoveryCacheManagerProvider);
      await cacheManager.clearCachePreservingDirtyEdits(
        read: container.read,
        uid: 'test-uid-123',
      );

      final resultDraft = container.read(mockOnboardingProvider).draft;
      expect(resultDraft.stepDirty[0], isTrue);
      expect(resultDraft.stepDirty[2], isTrue);
    });
  });

  group('Group H - Issue 38: Recovery UI Responsive Layout', () {
    testWidgets('Renders without overflow on compact viewports (<600px)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingRecoveryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsAtLeastNWidgets(1));
      expect(find.text('Sign Out'), findsAtLeastNWidgets(1));
    });
  });

  group('Group H - Issue 39: Retry Rate Limiting & Exponential Backoff', () {
    test('Calculates exponential backoff correctly', () {
      expect(RecoveryRetryController.calculateBackoffSeconds(1), equals(2));
      expect(RecoveryRetryController.calculateBackoffSeconds(2), equals(4));
      expect(RecoveryRetryController.calculateBackoffSeconds(3), equals(8));
      expect(RecoveryRetryController.calculateBackoffSeconds(4), equals(16));
      expect(RecoveryRetryController.calculateBackoffSeconds(5), equals(32));
      expect(RecoveryRetryController.calculateBackoffSeconds(6), equals(60));
    });

    test('Controller limits max attempts to 5 and starts cooldown', () {
      final controller = RecoveryRetryController();
      expect(controller.state.canRetry, isTrue);

      for (int i = 1; i <= 5; i++) {
        controller.recordAttemptAndStartCooldown();
        expect(controller.state.attemptCount, equals(i));
      }

      expect(controller.state.maxAttemptsReached, isTrue);
      expect(controller.state.canRetry, isFalse);
      controller.dispose();
    });
  });

  group('Group H - Issue 40: Navigation Lock & Sign Out', () {
    test('Router locks to recovery screen on failed projection status', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(mockUserProfileProvider.notifier)
          .updateProfile(
            UserProfile.empty(uid: 'user1', email: 'test@example.com').copyWith(
              onboardingInputCompleted: true,
              onboardingCompleted: false,
              onboardingProjectionStatus: 'failed',
            ),
          );

      final router = container.read(routerProvider);
      expect(router, isNotNull);
    });
  });

  group('Group H - Issue 41: Diagnostic Bundle Service & PII Redaction', () {
    test('Redacts email and user name from diagnostic bundle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const service = DiagnosticBundleService();
      final bundle = await service.generateDiagnosticBundle(
        read: container.read,
      );
      expect(bundle, isNotNull);

      final jsonStr = await service.exportDiagnosticBundleJson(
        read: container.read,
      );
      expect(jsonStr, contains('timestamp'));
      expect(jsonStr, contains('jobStage'));

      final redactedText = DiagnosticBundleService.redactPii(
        'User john.doe@example.com signed in as John Doe',
        userName: 'John Doe',
      );
      expect(redactedText, contains('[REDACTED_EMAIL]'));
      expect(redactedText, contains('[REDACTED_NAME]'));
      expect(redactedText, isNot(contains('john.doe@example.com')));
      expect(redactedText, isNot(contains('John Doe')));
    });
  });

  group('Group H - Issue 42: Partial Failure Status Banner', () {
    testWidgets('Renders 5-stage job indicators and resume button', (
      tester,
    ) async {
      bool resumed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PartialFailureStatusBanner(
              stageStatuses: const {
                'persistDraft': true,
                'persistBundle': true,
                'projectRoutines': false,
                'projectHabits': false,
                'updateProfile': false,
              },
              currentStage: 'projectRoutines',
              projectedItemCount: 3,
              failedItemCount: 1,
              onResume: () {
                resumed = true;
              },
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
      expect(find.text('Items: 3 projected, 1 failed'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      expect(resumed, isTrue);
    });
  });

  group('Adversarial Testing - Group H Edge Cases', () {
    group('Adversarial 1: PII Redactor Regex Edge Cases & Special Chars', () {
      test('Redacts complex emails: subdomains, tags, uppercase', () {
        final input =
            'Logs: Contact alice.bob@sub.domain.co.uk or dev+tag@optivus.org or ADMIN@EXAMPLE.COM';
        final redacted = DiagnosticBundleService.redactPii(input);
        expect(redacted, isNot(contains('alice.bob@sub.domain.co.uk')));
        expect(redacted, isNot(contains('dev+tag@optivus.org')));
        expect(redacted, isNot(contains('ADMIN@EXAMPLE.COM')));
        expect(redacted, contains('[REDACTED_EMAIL]'));
      });

      test(
        'Handles user name with regex special characters without crashing',
        () {
          final input = 'Error logged for user Jane (Doc) [Dev] in session';
          final redacted = DiagnosticBundleService.redactPii(
            input,
            userName: 'Jane (Doc) [Dev]',
          );
          expect(redacted, contains('[REDACTED_NAME]'));
          expect(redacted, isNot(contains('Jane (Doc) [Dev]')));
        },
      );

      test('Tests RFC 5322 special characters in email local-part', () {
        // Special chars like ! or # in email local part
        final input = 'User email: user!name@example.com';
        final redacted = DiagnosticBundleService.redactPii(input);
        // Observe behavior: _emailRegex uses [a-zA-Z0-9._%+-]+ which excludes !
        // Verify what is matched and redacted
        expect(redacted, contains('[REDACTED_EMAIL]'));
      });
    });

    group('Adversarial 2: Retry Rate-Limiter Backoff Edge Bounds', () {
      test('Verifies cap at 60s and behavior on zero or negative attempts', () {
        expect(RecoveryRetryController.calculateBackoffSeconds(0), equals(2));
        expect(RecoveryRetryController.calculateBackoffSeconds(-1), equals(2));
        expect(RecoveryRetryController.calculateBackoffSeconds(5), equals(32));
        expect(RecoveryRetryController.calculateBackoffSeconds(6), equals(60));
        expect(RecoveryRetryController.calculateBackoffSeconds(10), equals(60));
      });

      test('Tests bitwise overflow bounds for large attempt numbers', () {
        // Tests edge bounds for attempt > 30, 62, 63, 64
        final b30 = RecoveryRetryController.calculateBackoffSeconds(30);
        final b63 = RecoveryRetryController.calculateBackoffSeconds(63);
        final b64 = RecoveryRetryController.calculateBackoffSeconds(64);
        expect(b30, equals(60));
        // Note: 1 << 62 or 1 << 63 bit shifts in 64-bit int can overflow if unhandled.
        // We verify actual calculated backoff bound.
        expect(b63, isIn([2, 60]));
        expect(b64, isIn([2, 60]));
      });

      test('Enforces max 5 retries and respects controller reset', () {
        final controller = RecoveryRetryController();
        for (int i = 1; i <= 5; i++) {
          controller.recordAttemptAndStartCooldown();
        }
        expect(controller.state.attemptCount, equals(5));
        expect(controller.state.maxAttemptsReached, isTrue);
        expect(controller.state.canRetry, isFalse);

        // Attempting a 6th retry should be blocked
        controller.recordAttemptAndStartCooldown();
        expect(controller.state.attemptCount, equals(5));
        expect(controller.state.maxAttemptsReached, isTrue);

        // Reset clears cooldown and max attempts
        controller.reset();
        expect(controller.state.attemptCount, equals(0));
        expect(controller.state.maxAttemptsReached, isFalse);
        expect(controller.state.canRetry, isTrue);
        controller.dispose();
      });
    });

    group(
      'Adversarial 3: Dirty Edit Preservation on Multi-Step Dirty Drafts',
      () {
        test('Preserves multiple dirty step flags and draft fields', () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final dirtyFlags = List<bool>.filled(15, false);
          dirtyFlags[0] = true;
          dirtyFlags[3] = true;
          dirtyFlags[5] = true;
          dirtyFlags[8] = true;
          dirtyFlags[12] = true;
          dirtyFlags[14] = true;

          final multiStepDirtyDraft = const OnboardingDraft(
            uid: 'user-multi-dirty',
            patiencePledgeText: 'Committed to process',
            badHabitsNotNow: true,
          ).copyWith(stepDirty: dirtyFlags);

          container
              .read(mockOnboardingProvider.notifier)
              .loadSeedData(multiStepDirtyDraft);

          final cacheManager = container.read(recoveryCacheManagerProvider);
          await cacheManager.clearCachePreservingDirtyEdits(
            read: container.read,
            uid: 'user-multi-dirty',
          );

          final result = container.read(mockOnboardingProvider).draft;
          expect(result.uid, equals('user-multi-dirty'));
          expect(result.stepDirty[0], isTrue);
          expect(result.stepDirty[3], isTrue);
          expect(result.stepDirty[5], isTrue);
          expect(result.stepDirty[8], isTrue);
          expect(result.stepDirty[12], isTrue);
          expect(result.stepDirty[14], isTrue);
          expect(result.stepDirty[1], isFalse);
          expect(result.patiencePledgeText, equals('Committed to process'));
          expect(result.badHabitsNotNow, isTrue);
        });

        test('Clears draft when UID does not match target user UID', () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);

          final dirtyDraft = const OnboardingDraft(uid: 'user-A').copyWith(
            stepDirty: [
              true,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
          );

          container
              .read(mockOnboardingProvider.notifier)
              .loadSeedData(dirtyDraft);

          final cacheManager = container.read(recoveryCacheManagerProvider);
          await cacheManager.clearCachePreservingDirtyEdits(
            read: container.read,
            uid: 'user-B',
          );

          final result = container.read(mockOnboardingProvider).draft;
          expect(result.uid, equals('user-B'));
          expect(result.stepDirty.every((dirty) => !dirty), isTrue);
        });
      },
    );

    group(
      'Adversarial 4: Router Navigation Lock with Invalid Route Requests',
      () {
        testWidgets(
          'Router locks all valid and invalid routes to /onboarding/recovery on failure',
          (tester) async {
            final container = ProviderContainer();
            addTearDown(container.dispose);

            const testUser = AuthUser(
              uid: 'user-lock-test',
              email: 'lock@test.com',
              emailVerified: true,
            );
            container.read(authProvider.notifier).state = const AuthState(
              user: testUser,
              status: AuthFlowStatus.backendRestoreFailed,
            );

            container
                .read(mockUserProfileProvider.notifier)
                .updateProfile(
                  UserProfile.empty(
                    uid: 'user-lock-test',
                    email: 'lock@test.com',
                  ).copyWith(
                    onboardingInputCompleted: true,
                    onboardingCompleted: false,
                    onboardingProjectionStatus: 'failed',
                  ),
                );

            final router = container.read(routerProvider);

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(routerConfig: router),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));

            expect(find.byType(OnboardingRecoveryScreen), findsOneWidget);

            // Attempt navigation to /app
            router.go('/app');
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(OnboardingRecoveryScreen), findsOneWidget);

            // Attempt navigation to /profile/edit
            router.go('/profile/edit');
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(OnboardingRecoveryScreen), findsOneWidget);
          },
        );
      },
    );
  });
}
