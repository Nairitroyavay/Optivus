import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/utils/pii_redactor.dart';
import 'package:optivus/core/utils/debouncer.dart';
import 'package:optivus/core/utils/platform_channel_boundary.dart';
import 'package:optivus/services/background_sync_wake_lock_manager.dart';
import 'package:optivus/services/native/notification_intent_service.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group J Edge Case 1: PII Redaction on Combined & Complex Patterns', () {
    test(
      'redacts combined PII elements (email, phone, bearer token, auth token, user name) in single text',
      () {
        const input =
            'User Alice Johnson (alice.j@domain.co, +1 (800) 555-0199) authenticated with Bearer secretTokenABC123 and apiKey: "super_secret_key_777".';
        final redacted = PiiRedactor.redact(input, userName: 'Alice Johnson');

        expect(redacted, isNot(contains('alice.j@domain.co')));
        expect(redacted, isNot(contains('555-0199')));
        expect(redacted, isNot(contains('secretTokenABC123')));
        expect(redacted, isNot(contains('super_secret_key_777')));
        expect(redacted, isNot(contains('Alice Johnson')));
        expect(redacted, contains('[REDACTED_EMAIL]'));
        expect(redacted, contains('[REDACTED_PHONE]'));
        expect(redacted, contains('Bearer [REDACTED_TOKEN]'));
        expect(redacted, contains('[REDACTED_SECRET]'));
        expect(redacted, contains('[REDACTED_NAME]'));
      },
    );

    test('handles empty strings and null userName gracefully', () {
      expect(PiiRedactor.redact(''), equals(''));
      expect(
        PiiRedactor.redact('No PII here', userName: null),
        equals('No PII here'),
      );
      expect(
        PiiRedactor.redact('No PII here', userName: ''),
        equals('No PII here'),
      );
      expect(
        PiiRedactor.redact('No PII here', userName: ' a '),
        equals('No PII here'),
      ); // Short trimmed name < 2 chars
    });

    test('redacts complex nested map structures', () {
      final map = {
        'info': {
          'user': 'Bob Smith',
          'email': 'bob.smith@company.org',
          'phone': '+1-555-987-6543',
          'config': {'secret_key': '12345-abcde'},
        },
        'count': 42,
      };
      final redactedMap = PiiRedactor.redactMap(map, userName: 'Bob Smith');
      final info = redactedMap['info'] as Map<String, dynamic>;
      expect(info['email'], equals('[REDACTED_EMAIL]'));
      expect(info['user'], equals('[REDACTED_NAME]'));
      expect(info['phone'], equals('[REDACTED_PHONE]'));
    });

    test('documents international vs US phone number regex coverage', () {
      // US 3-3-4 pattern: redacted
      expect(
        PiiRedactor.redact('+1-555-123-4567'),
        contains('[REDACTED_PHONE]'),
      );
      expect(
        PiiRedactor.redact('(555) 987-6543'),
        contains('[REDACTED_PHONE]'),
      );
      expect(PiiRedactor.redact('5551234567'), contains('[REDACTED_PHONE]'));

      // International non-3-3-4 pattern (e.g. UK +44 20 7946 0912 with 2-digit city code):
      // Empirical observation: _phoneRegex expects \d{3} for area code, so 2-digit city codes are unredacted.
      final intlResult = PiiRedactor.redact('+44 20 7946 0912');
      final isIntlRedacted = intlResult.contains('[REDACTED_PHONE]');
      // Document empirical behavior
      expect(
        isIntlRedacted,
        isFalse,
        reason:
            'PiiRedactor regex assumes 3-digit area code (\\d{3}), leaving 2-digit international area codes unredacted.',
      );
    });
  });

  group(
    'Group J Edge Case 2: Debouncer Flush Behavior during Rapid Navigation',
    () {
      test(
        'rapid consecutive executions cancel previous tasks and only run the latest',
        () async {
          final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
          final executed = <int>[];

          for (int i = 1; i <= 5; i++) {
            final taskNum = i;
            debouncer.run(() async {
              executed.add(taskNum);
            });
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }

          expect(debouncer.isPending, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(executed, equals([5]));
          expect(debouncer.isPending, isFalse);
        },
      );

      test('flush() when no action is pending is a safe no-op', () async {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
        expect(debouncer.isPending, isFalse);
        await debouncer.flush();
        expect(debouncer.isPending, isFalse);
      });

      test(
        'flush() on pending action prevents duplicate execution when delay elapses',
        () async {
          final debouncer = Debouncer(delay: const Duration(milliseconds: 200));
          int runCount = 0;

          debouncer.run(() async {
            runCount++;
          });

          await debouncer.flush();
          expect(runCount, equals(1));
          expect(debouncer.isPending, isFalse);

          await Future<void>.delayed(const Duration(milliseconds: 250));
          expect(runCount, equals(1)); // Should NOT run a second time
        },
      );

      test(
        'cancel() prevents execution even if flush() is called after',
        () async {
          final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
          bool executed = false;

          debouncer.run(() async {
            executed = true;
          });

          debouncer.cancel();
          expect(debouncer.isPending, isFalse);

          await debouncer.flush();
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(executed, isFalse);
        },
      );
    },
  );

  group('Group J Edge Case 3: Wake Lock Release Safety on Sub-Action Failure', () {
    test(
      'runWithWakeLock releases lock when syncTask throws an async error late in execution',
      () async {
        final wakeLock = DefaultSystemWakeLock();
        const tag = 'async_failure_job';

        expect(
          () async => runWithWakeLock<void>(
            tag: tag,
            wakeLock: wakeLock,
            syncTask: () async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              throw const FormatException(
                'Malformed response in background sync',
              );
            },
          ),
          throwsFormatException,
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(wakeLock.isHeld(tag), isFalse);
      },
    );

    test(
      'OnboardingCompletionJobService releases wake lock when profile repo throws error in stage 5',
      () async {
        final repo = FakeOnboardingRepository();
        final failingProfileRepo = FailingProfileRepository();
        final wakeLock = DefaultSystemWakeLock();
        final service = OnboardingCompletionJobService(
          onboardingRepository: repo,
          profileRepository: failingProfileRepo,
          wakeLock: wakeLock,
        );

        final draft = OnboardingDraft(
          uid: 'user_fail',
          currentStep: OnboardingDraft.lastStepIndex,
          stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
          onboardingCompleted: true,
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);

        await expectLater(
          service.runCompletionJob(
            uid: 'user_fail',
            finalDraft: draft,
            bundle: bundle,
          ),
          throwsStateError,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(wakeLock.isHeld('onboarding_completion_user_fail'), isFalse);
      },
    );
  });

  group('Group J Edge Case 4: Platform Channel Safe Fallback Defaults', () {
    test(
      'safePlatformCall catches generic Exception/Error and triggers onError callback',
      () async {
        Object? capturedError;
        StackTrace? capturedStack;

        final result = await safePlatformCall<int>(
          call: () async {
            throw TypeError();
          },
          fallback: -1,
          operationName: 'testTypeError',
          onError: (e, st) {
            capturedError = e;
            capturedStack = st;
          },
        );

        expect(result, equals(-1));
        expect(capturedError, isA<TypeError>());
        expect(capturedStack, isNotNull);
      },
    );

    test(
      'NotificationIntentService returns fallback when channel returns unexpected types or throws exception',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.nairitroy.optivus/notification_intent'),
              (methodCall) async {
                throw PlatformException(
                  code: 'UNAVAILABLE',
                  message: 'Service down',
                );
              },
            );

        const service = NotificationIntentService();
        final payload = await service.getInitialNotificationPayload();
        expect(payload, isNull);
      },
    );
  });
}

class FailingProfileRepository extends FakeProfileRepository {
  @override
  Future<UserProfile?> fetchUserProfile(String uid) async {
    return UserProfile.empty(uid: uid, email: 'test@example.com');
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    throw StateError('Database connection broken during profile update');
  }
}
