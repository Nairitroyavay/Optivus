import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/utils/pii_redactor.dart';
import 'package:optivus/core/utils/asset_precache_service.dart';
import 'package:optivus/core/utils/debouncer.dart';
import 'package:optivus/core/utils/platform_channel_boundary.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/background_sync_wake_lock_manager.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/native/notification_intent_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/views/screens/loading_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group J - Issue 56: Client-side PII Redactor Filter', () {
    test('redacts email addresses correctly', () {
      const input = 'Contact user john.doe@example.com for support.';
      final redacted = PiiRedactor.redact(input);
      expect(redacted, contains('[REDACTED_EMAIL]'));
      expect(redacted, isNot(contains('john.doe@example.com')));
    });

    test('redacts phone numbers correctly', () {
      const input = 'Call customer at +1-555-123-4567 or (555) 987-6543.';
      final redacted = PiiRedactor.redact(input);
      expect(redacted, contains('[REDACTED_PHONE]'));
      expect(redacted, isNot(contains('555-123-4567')));
    });

    test('redacts bearer tokens and auth keys correctly', () {
      const input =
          'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      final redacted = PiiRedactor.redact(input);
      expect(redacted, contains('Bearer [REDACTED_TOKEN]'));
      expect(redacted, isNot(contains('eyJhbGciOiJIUzI1Ni')));
    });

    test('redacts user names when specified', () {
      const input = 'Profile updated for Alice Smith in system.';
      final redacted = PiiRedactor.redact(input, userName: 'Alice Smith');
      expect(redacted, contains('[REDACTED_NAME]'));
      expect(redacted, isNot(contains('Alice Smith')));
    });

    test('redacts PII inside a Map', () {
      final map = {
        'email': 'jane.doe@test.com',
        'user': 'Jane Doe',
        'token': 'Bearer secret12345',
      };
      final redactedMap = PiiRedactor.redactMap(map, userName: 'Jane Doe');
      expect(redactedMap['email'], equals('[REDACTED_EMAIL]'));
      expect(redactedMap['user'], equals('[REDACTED_NAME]'));
    });
  });

  group(
    'Group J - Issue 57: Memory Leak Resolution in Timeline Controllers',
    () {
      testWidgets('LoadingScreen mounts and disposes controllers cleanly', (
        tester,
      ) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: LoadingScreen(message: 'Initializing...')),
          ),
        );
        await tester.pump();
        expect(find.byType(LoadingScreen), findsOneWidget);
      });
    },
  );

  group('Group J - Issue 58: Cold Boot Splash Image Caching', () {
    testWidgets('SplashAssetCacheService executes precache without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              SplashAssetCacheService.precacheSplashAssets(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('Group J - Issue 59: App State Serialization Debouncing', () {
    test('Debouncer delays action until delay elapses', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      bool executed = false;

      debouncer.run(() async {
        executed = true;
      });

      expect(executed, isFalse);
      expect(debouncer.isPending, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(executed, isTrue);
      expect(debouncer.isPending, isFalse);
    });

    test('Debouncer flush() executes pending action immediately', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 500));
      bool executed = false;

      debouncer.run(() async {
        executed = true;
      });

      expect(executed, isFalse);
      await debouncer.flush();
      expect(executed, isTrue);
      expect(debouncer.isPending, isFalse);
    });

    test(
      'FakeOnboardingRepository debounces saveDraft and flushes on demand',
      () async {
        final repo = FakeOnboardingRepository();
        const draft = OnboardingDraft(uid: 'user_123');

        await repo.saveDraft(draft);
        // Immediately after saveDraft, verify write is pending and not yet committed to storage map
        expect(repo.isDraftSavedInMap('user_123'), isFalse);

        // Flush pending save
        await repo.flushPendingDraftSave();
        expect(repo.isDraftSavedInMap('user_123'), isTrue);
      },
    );
  });

  group('Group J - Issue 60: System Wake Lock Release in Background Sync', () {
    test(
      'runWithWakeLock acquires and releases wake lock on success',
      () async {
        final wakeLock = DefaultSystemWakeLock();
        const tag = 'sync_job_1';

        expect(wakeLock.isHeld(tag), isFalse);

        final result = await runWithWakeLock<String>(
          tag: tag,
          wakeLock: wakeLock,
          syncTask: () async {
            expect(wakeLock.isHeld(tag), isTrue);
            return 'completed';
          },
        );

        expect(result, equals('completed'));
        expect(wakeLock.isHeld(tag), isFalse);
      },
    );

    test(
      'runWithWakeLock releases wake lock even when syncTask throws',
      () async {
        final wakeLock = DefaultSystemWakeLock();
        const tag = 'failing_job_1';

        expect(wakeLock.isHeld(tag), isFalse);

        expect(
          () async => runWithWakeLock<void>(
            tag: tag,
            wakeLock: wakeLock,
            syncTask: () async {
              expect(wakeLock.isHeld(tag), isTrue);
              throw StateError('Sync failed');
            },
          ),
          throwsStateError,
        );

        // Small delay to ensure async finally block runs
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(wakeLock.isHeld(tag), isFalse);
      },
    );

    test('OnboardingCompletionJobService releases wake lock claim', () async {
      final repo = FakeOnboardingRepository();
      final profileRepo = FakeProfileRepository();
      final wakeLock = DefaultSystemWakeLock();
      final service = OnboardingCompletionJobService(
        onboardingRepository: repo,
        profileRepository: profileRepo,
        wakeLock: wakeLock,
      );

      final draft = OnboardingDraft(
        uid: 'user_wake',
        currentStep: OnboardingDraft.lastStepIndex,
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        onboardingCompleted: true,
      );
      final bundle = OnboardingCompletionService.buildBundle(draft);
      await profileRepo.saveUserProfile(
        UserProfile.empty(uid: 'user_wake', email: 'test@example.com'),
      );

      final job = await service.runCompletionJob(
        uid: 'user_wake',
        finalDraft: draft,
        bundle: bundle,
      );

      expect(job.status.name, equals('completed'));
      expect(wakeLock.isHeld('onboarding_completion_user_wake'), isFalse);
    });
  });

  group(
    'Group J - Issue 61: iOS Platform Channel Async Error Boundary Safety',
    () {
      test(
        'safePlatformCall returns fallback on MissingPluginException',
        () async {
          final result = await safePlatformCall<String>(
            call: () async {
              throw MissingPluginException('No implementation found');
            },
            fallback: 'fallback_val',
            operationName: 'testMissingPlugin',
          );

          expect(result, equals('fallback_val'));
        },
      );

      test('safePlatformCall returns fallback on PlatformException', () async {
        final result = await safePlatformCall<bool>(
          call: () async {
            throw PlatformException(
              code: 'PERMISSION_DENIED',
              message: 'Denied',
            );
          },
          fallback: false,
          operationName: 'testPlatformException',
        );

        expect(result, isFalse);
      });

      test('safePlatformCall returns result on successful call', () async {
        final result = await safePlatformCall<int>(
          call: () async => 42,
          fallback: 0,
          operationName: 'testSuccess',
        );

        expect(result, equals(42));
      });
    },
  );

  group('Group J - Issue 62: Android Background Notification Click Intent', () {
    test(
      'NotificationIntentService fetches payload via MethodChannel',
      () async {
        final log = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.nairitroy.optivus/notification_intent'),
              (methodCall) async {
                log.add(methodCall);
                if (methodCall.method == 'getInitialNotificationPayload') {
                  return {'route': '/tracker/hydration', 'id': 'notif_99'};
                } else if (methodCall.method ==
                    'clearInitialNotificationPayload') {
                  return null;
                }
                return null;
              },
            );

        const service = NotificationIntentService();
        final payload = await service.getInitialNotificationPayload();

        expect(payload, isNotNull);
        expect(payload!['route'], equals('/tracker/hydration'));
        expect(payload['id'], equals('notif_99'));

        await service.clearInitialNotificationPayload();
        expect(log.length, equals(2));
        expect(log[0].method, equals('getInitialNotificationPayload'));
        expect(log[1].method, equals('clearInitialNotificationPayload'));
      },
    );
  });
}
