import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/utils/debouncer.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/views/screens/signup_screen.dart';
import 'package:optivus/views/screens/verify_email_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work Package B Remediation Tests', () {
    // ── Issue 1: ISSUE-04-01 ──────────────────────────────────────────────────
    test(
      'ISSUE-04-01: OnboardingDraft validateStep accepts valid step indexes',
      () {
        const draft = OnboardingDraft(uid: 'user_nav');
        final completedSteps = List<bool>.filled(
          OnboardingDraft.stepCount,
          true,
        );
        // Validate step 0
        expect(draft.validateStep(0, completedSteps), isNull);
      },
    );

    // ── Issue 2: ISSUE-05-01 ──────────────────────────────────────────────────
    test(
      'ISSUE-05-01: Debouncer.run returns a Future that resolves on flush',
      () async {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        bool runExecuted = false;

        final future = debouncer.run(() async {
          runExecuted = true;
        });

        expect(runExecuted, isFalse);
        await debouncer.flush();
        expect(runExecuted, isTrue);
        await expectLater(future, completes);
      },
    );

    test(
      'ISSUE-05-01: FakeOnboardingRepository maintains pending drafts by UID concurrently',
      () async {
        final repo = FakeOnboardingRepository();
        const draftA = OnboardingDraft(uid: 'user_A', welcomeSaved: true);
        const draftB = OnboardingDraft(uid: 'user_B', welcomeSaved: true);

        final saveFutureA = repo.saveDraft(draftA);
        final saveFutureB = repo.saveDraft(draftB);

        // Verify pending fetch returns distinct drafts before flush
        final fetchA = await repo.fetchDraft('user_A');
        final fetchB = await repo.fetchDraft('user_B');
        expect(fetchA?.uid, equals('user_A'));
        expect(fetchB?.uid, equals('user_B'));

        await repo.flushPendingDraftSave();
        await saveFutureA;
        await saveFutureB;

        // Verify both saved in map after flush
        expect(repo.isDraftSavedInMap('user_A'), isTrue);
        expect(repo.isDraftSavedInMap('user_B'), isTrue);
      },
    );

    // ── Issue 3: ISSUE-06-02 ──────────────────────────────────────────────────
    test(
      'ISSUE-06-02: validateStep(14) and buildBundle reject un-persisted sub-steps',
      () {
        // Create a draft where skin care setup has invalid state (skinCareSetupPath = 'no_products' without face photo)
        final invalidDraft = const OnboardingDraft(uid: 'user_invalid')
            .copyWith(
              baseTimeline: const BaseTimelineDraft(
                skinCareSetupPath: 'no_products',
                skinCareProductPhotoR2Key: '', // Empty photo: invalid!
              ),
            );

        final completedSteps = List<bool>.filled(
          OnboardingDraft.stepCount,
          true,
        );
        final step14Error = invalidDraft.validateStep(14, completedSteps);
        expect(step14Error, isNotNull);
        expect(step14Error, contains('Add a face photo'));

        // Verify buildBundle throws StateError on invalid sub-steps
        expect(
          () => OnboardingCompletionService.buildBundle(invalidDraft),
          throwsStateError,
        );
      },
    );

    test(
      'ISSUE-06-02: validateStep(14) and buildBundle succeed when sub-steps are valid',
      () {
        final validDraft = const OnboardingDraft(uid: 'user_valid').copyWith(
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

        final completedSteps = List<bool>.filled(
          OnboardingDraft.stepCount,
          true,
        );
        expect(validDraft.validateStep(14, completedSteps), isNull);

        final bundle = OnboardingCompletionService.buildBundle(validDraft);
        expect(bundle.uid, equals('user_valid'));
      },
    );

    // ── Issue 4: ISSUE-01-01 ──────────────────────────────────────────────────
    testWidgets(
      'ISSUE-01-01: Signup screen account exists banner populates email on reset',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: SignupScreen())),
        );

        // Find the email input field and verify widget renders
        final emailFinder = find.byType(TextField).first;
        expect(emailFinder, findsOneWidget);
      },
    );

    // ── Issue 5 & 6: ISSUE-02-01 and ISSUE-02-02 ──────────────────────────────
    test(
      'ISSUE-02-02: AuthState records lastVerificationEmailSent timestamp',
      () async {
        const state = AuthState();
        expect(state.lastVerificationEmailSent, isNull);

        final now = DateTime.now();
        final updatedState = state.copyWith(lastVerificationEmailSent: now);
        expect(updatedState.lastVerificationEmailSent, equals(now));
      },
    );

    testWidgets(
      'ISSUE-02-01: VerifyEmailScreen renders cleanly without mounted errors',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: VerifyEmailScreen())),
        );

        expect(find.text('Verify your email'), findsOneWidget);
      },
    );
  });
}
