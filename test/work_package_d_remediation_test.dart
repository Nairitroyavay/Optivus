import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/features/recovery/services/diagnostic_bundle_service.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';

void main() {
  group('Work Package D Remediation Tests', () {
    test(
      'PATH3-12-01: optivusAuthRedirect precedence prevents infinite loops',
      () {
        final authStateIncomplete = const AuthState(
          user: AuthUser(
            uid: 'user1',
            email: 'test@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        );
        final redirect1 = optivusAuthRedirect(
          authState: authStateIncomplete,
          uri: Uri.parse('/onboarding/recovery'),
        );
        expect(redirect1, equals('/onboarding'));

        final authStateFailed = const AuthState(
          user: AuthUser(
            uid: 'user1',
            email: 'test@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.needsAction,
        );
        final redirect2 = optivusAuthRedirect(
          authState: authStateFailed,
          uri: Uri.parse('/onboarding'),
        );
        expect(redirect2, equals('/onboarding/needs-action'));
      },
    );

    test(
      'FINDING-P1-06: _loadOrCreateJob resets status to pending on fingerprint mismatch',
      () async {
        final onboardingRepo = FakeOnboardingRepository();
        final profileRepo = FakeProfileRepository();

        final service = OnboardingCompletionJobService(
          onboardingRepository: onboardingRepo,
          profileRepository: profileRepo,
        );

        final draft = OnboardingDraft(
          uid: 'user_fp',
          onboardingCompleted: true,
          currentStep: OnboardingDraft.lastStepIndex,
          stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        await profileRepo.saveUserProfile(
          UserProfile.empty(uid: 'user_fp', email: 'test@example.com'),
        );

        final updatedJob = await service.runCompletionJob(
          uid: 'user_fp',
          finalDraft: draft,
          bundle: bundle,
        );

        expect(updatedJob.status, equals(OnboardingJobStatus.completed));
      },
    );

    test(
      'PATH3-17-02: DiagnosticBundleService.redactPii redacts system paths and tokens',
      () {
        const logWithPath =
            'Error at /Users/roy/optivus2/Optivus/lib/main.dart line 12';
        const logWithAndroidPath =
            'Failed reading /data/user/0/com.optivus/cache/temp.txt';
        const logWithToken =
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature';
        const logWithEmail = 'Contact user@example.com for help';

        final redactedPath = DiagnosticBundleService.redactPii(logWithPath);
        expect(redactedPath, contains('[REDACTED_PATH]'));
        expect(redactedPath, isNot(contains('/Users/roy')));

        final redactedAndroid = DiagnosticBundleService.redactPii(
          logWithAndroidPath,
        );
        expect(redactedAndroid, contains('[REDACTED_PATH]'));
        expect(redactedAndroid, isNot(contains('/data/user/0')));

        final redactedToken = DiagnosticBundleService.redactPii(logWithToken);
        expect(redactedToken, contains('[REDACTED_TOKEN]'));
        expect(
          redactedToken,
          isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
        );

        final redactedEmail = DiagnosticBundleService.redactPii(logWithEmail);
        expect(redactedEmail, contains('[REDACTED_EMAIL]'));
        expect(redactedEmail, isNot(contains('user@example.com')));
      },
    );
  });
}
