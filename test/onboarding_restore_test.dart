import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/app/optivus_app.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/views/screens/app_shell.dart';

void main() {
  test(
    'new verified Firebase account opens a local Step 0 draft without entering restore',
    () async {
      const user = AuthUser(
        uid: 'brand-new-user',
        email: 'brand-new@example.com',
        displayName: 'Brand New',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = FakeProfileRepository();
      final onboardingRepository = _ControlledOnboardingRepository();
      final container = ProviderContainer(
        overrides: _firebaseOverrides(
          authRepository: authRepository,
          profileRepository: profileRepository,
          onboardingRepository: onboardingRepository,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authRepository.dispose);

      final statuses = <AuthFlowStatus>[];
      final subscription = container.listen<AuthState>(
        authProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      authRepository.emit(user);
      await pumpEventQueue(times: 20);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(authProvider).needsAction, isFalse);
      expect(statuses, isNot(contains(AuthFlowStatus.restoringOnboarding)));
      expect(onboardingRepository.draft, isNull);
      expect(
        container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .blocks
            .map((block) => block.id),
        containsAll(<String>[
          BaseTimelineDraft.fixedSleepId,
          BaseTimelineDraft.fixedBathId,
        ]),
      );
      expect(container.read(onboardingStateProvider).draft.uid, user.uid);
    },
  );

  testWidgets(
    'fresh account never shows restore copy while checking for a draft',
    (tester) async {
      const user = AuthUser(
        uid: 'fresh-delayed-user',
        email: 'fresh-delayed@example.com',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _firebaseOverrides(
            authRepository: authRepository,
            profileRepository: profileRepository,
            onboardingRepository: onboardingRepository,
          ),
          child: const OptivusApp(),
        ),
      );
      addTearDown(authRepository.dispose);

      authRepository.emit(user);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(find.text('Starting Optivus...'), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);

      draftCompleter.complete(null);
      for (var i = 0; i < 12; i++) {
        await tester.pump();
      }

      expect(find.text('Welcome to\nOptivus'), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);
      expect(onboardingRepository.draft, isNull);
    },
  );

  testWidgets(
    'completed account never publishes restoringOnboarding while final reconstruction is pending',
    (tester) async {
      const user = AuthUser(
        uid: 'completed-delayed-user',
        email: 'completed-delayed@example.com',
        emailVerified: true,
      );
      final completedDraft = _completedDraftFor(user.uid);
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: true,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
        completionBundle: _completionBundleFor(user.uid, completedDraft),
      );
      final statuses = <AuthFlowStatus>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: _firebaseOverrides(
            authRepository: authRepository,
            profileRepository: profileRepository,
            onboardingRepository: onboardingRepository,
          ),
          child: const OptivusApp(),
        ),
      );
      addTearDown(authRepository.dispose);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OptivusApp)),
      );
      final subscription = container.listen<AuthState>(
        authProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      authRepository.emit(user);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(find.text('Starting Optivus...'), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);
      expect(statuses, isNot(contains(AuthFlowStatus.restoringOnboarding)));

      draftCompleter.complete(completedDraft);
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Restoring your setup...'), findsNothing);
      expect(statuses, isNot(contains(AuthFlowStatus.restoringOnboarding)));
    },
  );

  test(
    'firebase incomplete user does not become onboarding incomplete until draft fetch completes',
    () async {
      const user = AuthUser(
        uid: 'restore-user',
        email: 'restore@example.com',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
        onboardingStep: 4,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
      );
      final container = ProviderContainer(
        overrides: _firebaseOverrides(
          authRepository: authRepository,
          profileRepository: profileRepository,
          onboardingRepository: onboardingRepository,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authRepository.dispose);

      final statuses = <AuthFlowStatus>[];
      final subscription = container.listen<AuthState>(
        authProvider,
        (_, next) => statuses.add(next.status),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      authRepository.emit(user);
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.restoringOnboarding,
      );
      expect(
        statuses,
        isNot(contains(AuthFlowStatus.signedInOnboardingIncomplete)),
      );
      expect(container.read(onboardingStateProvider).draft.currentStep, 0);

      draftCompleter.complete(_draftFor(user.uid, currentStep: 4));
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(onboardingStateProvider).draft.currentStep, 4);
    },
  );

  testWidgets('saved onboarding draft currentStep 4 opens directly at step 4', (
    tester,
  ) async {
    final draft = _draftFor('draft-user', currentStep: 4);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStateProvider.overrideWith(
            (_) => OnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(home: OnboardingFlow()),
      ),
    );
    await tester.pump();

    expect(find.text('Classes & Job'), findsOneWidget);
    expect(find.text('Welcome to\nOptivus'), findsNothing);
  });

  testWidgets(
    'router shows restoring setup and no onboarding welcome while draft is fetching',
    (tester) async {
      const user = AuthUser(
        uid: 'router-restore-user',
        email: 'router@example.com',
        emailVerified: true,
      );
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
        onboardingStep: 4,
      );
      final draftCompleter = Completer<OnboardingDraft?>();
      final onboardingRepository = _ControlledOnboardingRepository(
        draftCompleter: draftCompleter,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _firebaseOverrides(
            authRepository: authRepository,
            profileRepository: profileRepository,
            onboardingRepository: onboardingRepository,
          ),
          child: const OptivusApp(),
        ),
      );
      addTearDown(authRepository.dispose);

      authRepository.emit(user);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(find.text('Restoring your setup...'), findsOneWidget);
      expect(find.text('Welcome to\nOptivus'), findsNothing);
      expect(find.text('Get Started'), findsNothing);
    },
  );

  test(
    'draft fetch failure shows restore error, allows retry, and does not reset draft',
    () async {
      const user = AuthUser(
        uid: 'retry-restore-user',
        email: 'retry@example.com',
        emailVerified: true,
      );
      final existingDraft = _draftFor(user.uid, currentStep: 4);
      final authRepository = _ControllableAuthRepository();
      final profileRepository = await _profileRepositoryFor(
        user,
        onboardingCompleted: false,
      );
      final onboardingRepository = _ControlledOnboardingRepository(
        draft: existingDraft,
        draftFailures: 1,
      );
      final container = ProviderContainer(
        overrides: _firebaseOverrides(
          authRepository: authRepository,
          profileRepository: profileRepository,
          onboardingRepository: onboardingRepository,
        ),
      );
      addTearDown(container.dispose);
      addTearDown(authRepository.dispose);

      container
          .read(onboardingStateProvider.notifier)
          .loadSeedData(existingDraft);
      container.read(authProvider);

      authRepository.emit(user);
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.reconnectRequired,
      );
      final error = container.read(authProvider).error;
      expect(error, isNotNull);
      expect(error!.category, RecoverableErrorCategory.network);
      expect(error.diagnosticCode, DiagnosticCodes.networkUnavailable);
      expect(error.retryAction, RecoverableRetryAction.retry);
      expect(error.retrySafe, isTrue);
      expect(error.isBlocking, isTrue);
      expect(error.publicMessage, isNotEmpty);
      expect(error.publicMessage, isNot(contains('Exception')));
      expect(container.read(onboardingStateProvider).draft.currentStep, 4);

      await container.read(authProvider.notifier).retryBackendRestore();
      await pumpEventQueue(times: 10);

      expect(
        container.read(authProvider).status,
        AuthFlowStatus.signedInOnboardingIncomplete,
      );
      expect(container.read(onboardingStateProvider).draft.currentStep, 4);
    },
  );

  test('fake mode starts at welcome step when no draft exists', () async {
    const user = AuthUser(
      uid: 'fake-new-user',
      email: 'fake@example.com',
      emailVerified: true,
    );
    final authRepository = _ControllableAuthRepository();
    final container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        authRepositoryProvider.overrideWithValue(authRepository),
        onboardingRepositoryProvider.overrideWithValue(
          _ControlledOnboardingRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authRepository.dispose);

    container.read(authProvider);
    authRepository.emit(user);
    await pumpEventQueue(times: 20);

    final auth = container.read(authProvider);
    final draft = container.read(onboardingStateProvider).draft;
    expect(auth.status, AuthFlowStatus.signedInOnboardingIncomplete);
    expect(draft.uid, user.uid);
    expect(draft.currentStep, 0);
  });

  test('fake mode resumes a saved draft when one exists', () async {
    const user = AuthUser(
      uid: 'fake-saved-user',
      email: 'fake-saved@example.com',
      emailVerified: true,
    );
    final authRepository = _ControllableAuthRepository();
    final onboardingRepository = _ControlledOnboardingRepository(
      draft: _draftFor(user.uid, currentStep: 4),
    );
    final container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.fake),
        authRepositoryProvider.overrideWithValue(authRepository),
        onboardingRepositoryProvider.overrideWithValue(onboardingRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authRepository.dispose);

    container.read(authProvider);
    authRepository.emit(user);
    await pumpEventQueue(times: 20);

    expect(
      container.read(authProvider).status,
      AuthFlowStatus.signedInOnboardingIncomplete,
    );
    expect(container.read(onboardingStateProvider).draft.currentStep, 4);
  });

  group('real fresh-session durable restore pipeline', () {
    test('Steps 0 through 13 restore to the next semantic step', () async {
      const uid = 'fresh-matrix-user';
      for (
        var completedThrough = 0;
        completedThrough <= 13;
        completedThrough++
      ) {
        final onboarding = _SerializedOnboardingRepository();
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'matrix@example.com'),
          onboardingCompleted: false,
        );
        await _persistAcknowledgedStep(
          repository: onboarding,
          draft: _durableDraft(uid),
          step: completedThrough,
        );

        final restored = await _freshAuthSession(
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: FakeUploadedAssetRepository(),
        );
        expect(
          restored.auth.sessionDestination.kind,
          SessionDestinationKind.resumeOnboarding,
          reason: 'completed through Step $completedThrough',
        );
        expect(
          restored.auth.sessionDestination.resumeStep,
          completedThrough + 1,
          reason: 'completed through Step $completedThrough',
        );
        expect(restored.draft.uid, uid);
        restored.dispose();
      }
    });

    for (final mode in ['restart', 'logout_login', 'zero_cache']) {
      test('Step 5 skip survives $mode and routes Step 6', () async {
        const uid = 'step5-skip-user';
        final onboarding = _SerializedOnboardingRepository();
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'step5@example.com'),
          onboardingCompleted: false,
        );
        await _persistAcknowledgedStep(
          repository: onboarding,
          draft: _durableDraft(uid),
          step: 5,
        );
        await _expectLifecycleRestore(
          mode: mode,
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: FakeUploadedAssetRepository(),
          expectedStep: 6,
        );
      });

      test('Step 7 skip survives $mode and routes Step 8', () async {
        const uid = 'step7-skip-user';
        final onboarding = _SerializedOnboardingRepository();
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'step7@example.com'),
          onboardingCompleted: false,
        );
        await _persistAcknowledgedStep(
          repository: onboarding,
          draft: _durableDraft(uid),
          step: 7,
        );
        await _expectLifecycleRestore(
          mode: mode,
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: FakeUploadedAssetRepository(),
          expectedStep: 8,
        );
      });
    }

    test('generated weekly Step 5 restores to Step 6', () async {
      await _expectSpecialDraftRestore(
        uid: 'generated-eating-user',
        step: 5,
        draftBuilder: _generatedEatingDraft,
        expectedStep: 6,
      );
    });

    test(
      'uploaded existing-routine Step 5 restores exact source to Step 6',
      () async {
        const uid = 'imported-eating-user';
        final asset = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
        final uploads = FakeUploadedAssetRepository();
        await uploads.saveAsset(asset);
        await _expectSpecialDraftRestore(
          uid: uid,
          step: 5,
          draftBuilder: (owner) => _importedEatingDraft(owner, asset),
          expectedStep: 6,
          uploadRepository: uploads,
        );
      },
    );

    test('has-products Step 7 receipt restores to Step 8', () async {
      await _expectSpecialDraftRestore(
        uid: 'skin-products-user',
        step: 7,
        draftBuilder: _hasProductsSkinDraft,
        expectedStep: 8,
      );
    });

    test(
      'build-for-me Step 7 receipt restores exact face source to Step 8',
      () async {
        const uid = 'skin-build-user';
        final asset = _asset(uid, 'face-A', UploadedAssetPurpose.skinFace);
        final uploads = FakeUploadedAssetRepository();
        await uploads.saveAsset(asset);
        await _expectSpecialDraftRestore(
          uid: uid,
          step: 7,
          draftBuilder: (owner) => _buildForMeSkinDraft(owner, asset),
          expectedStep: 8,
          uploadRepository: uploads,
        );
      },
    );

    test(
      'completed onboarding in totally fresh local state routes Home',
      () async {
        const user = AuthUser(
          uid: 'fresh-completed-user',
          email: 'complete@example.com',
          emailVerified: true,
        );
        final draft = _completedDraftFor(user.uid);
        final onboarding = _SerializedOnboardingRepository(
          completionBundle: _completionBundleFor(user.uid, draft),
        );
        await onboarding.saveDraft(draft);
        final profiles = await _profileRepositoryFor(
          user,
          onboardingCompleted: true,
        );
        final restored = await _freshAuthSession(
          uid: user.uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: FakeUploadedAssetRepository(),
        );
        expect(
          restored.auth.sessionDestination.kind,
          SessionDestinationKind.home,
        );
        restored.dispose();
      },
    );

    test(
      'exact Step 5 source older than 150 uploads remains authoritative',
      () async {
        const uid = 'old-exact-source-user';
        final exact = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu)
            .copyWith(
              createdAt: DateTime.utc(2025),
              updatedAt: DateTime.utc(2025),
            );
        final uploads = FakeUploadedAssetRepository();
        await uploads.saveAsset(exact);
        for (var index = 0; index < 150; index++) {
          await uploads.saveAsset(
            _asset(
              uid,
              'newer-$index',
              UploadedAssetPurpose.eatingMenu,
            ).copyWith(
              createdAt: DateTime.utc(2026, 1, 1, 0, index),
              updatedAt: DateTime.utc(2026, 1, 1, 0, index),
            ),
          );
        }
        await _expectSpecialDraftRestore(
          uid: uid,
          step: 5,
          draftBuilder: (owner) => _importedEatingDraft(owner, exact),
          expectedStep: 6,
          uploadRepository: uploads,
        );
      },
    );

    test(
      'deleted exact A preserves confirmed Step 5 without adopting newer B',
      () async {
        const uid = 'deleted-source-user';
        final a = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
        final b = _asset(
          uid,
          'menu-B',
          UploadedAssetPurpose.eatingMenu,
        ).copyWith(updatedAt: DateTime.utc(2026, 2));
        final uploads = FakeUploadedAssetRepository();
        await uploads.saveAsset(a);
        await uploads.markDeleted(uid: uid, assetId: a.assetId);
        await uploads.saveAsset(b);
        final onboarding = _SerializedOnboardingRepository();
        await _persistAcknowledgedStep(
          repository: onboarding,
          draft: _importedEatingDraft(uid, a),
          step: 5,
        );
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'deleted@example.com'),
          onboardingCompleted: false,
        );
        final restored = await _freshAuthSession(
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: uploads,
        );
        expect(restored.auth.sessionDestination.resumeStep, 6);
        expect(
          restored.draft.baseTimeline
              .latestImportForSection('Eating')
              ?.uploadedAssetId,
          a.assetId,
        );
        expect(
          restored.draft.referencedUploadAssetIds,
          isNot(contains(b.assetId)),
        );
        restored.dispose();
      },
    );

    test(
      'explicit persisted replacement A to B makes B authoritative',
      () async {
        const uid = 'explicit-replacement-user';
        final a = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
        final b = _asset(
          uid,
          'menu-B',
          UploadedAssetPurpose.eatingMenu,
        ).copyWith(updatedAt: DateTime.utc(2026, 2));
        final uploads = FakeUploadedAssetRepository();
        await uploads.saveAsset(a);
        await uploads.saveAsset(b);
        final onboarding = _SerializedOnboardingRepository();
        await _persistAcknowledgedStep(
          repository: onboarding,
          draft: _importedEatingDraft(uid, b),
          step: 5,
        );
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'replacement@example.com'),
          onboardingCompleted: false,
        );
        final restored = await _freshAuthSession(
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: uploads,
        );
        expect(restored.auth.sessionDestination.resumeStep, 6);
        expect(
          restored.draft.baseTimeline
              .latestImportForSection('Eating')
              ?.uploadedAssetId,
          b.assetId,
        );
        restored.dispose();
      },
    );

    test(
      'temporary upload backend failure reconnects without demotion',
      () async {
        const uid = 'upload-network-user';
        final a = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
        final onboarding = _SerializedOnboardingRepository();
        await _persistAcknowledgedStep(
          repository: onboarding,
          draft: _importedEatingDraft(uid, a),
          step: 5,
        );
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'network@example.com'),
          onboardingCompleted: false,
        );
        final restored = await _freshAuthSession(
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: const _FailingUploadRepository(),
        );
        expect(
          restored.auth.sessionDestination.kind,
          SessionDestinationKind.reconnect,
        );
        expect((await onboarding.fetchDraft(uid))!.stepCompleted[5], isTrue);
        restored.dispose();
      },
    );

    test('wrong-owner exact asset enters typed integrity recovery', () async {
      const uid = 'asset-owner-user';
      final expected = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
      final wrongOwner = expected.copyWith(ownerUid: 'other-user');
      final onboarding = _SerializedOnboardingRepository();
      await _persistAcknowledgedStep(
        repository: onboarding,
        draft: _importedEatingDraft(uid, expected),
        step: 5,
      );
      final profiles = await _profileRepositoryFor(
        const AuthUser(uid: uid, email: 'owner@example.com'),
        onboardingCompleted: false,
      );
      final restored = await _freshAuthSession(
        uid: uid,
        onboardingRepository: onboarding,
        profileRepository: profiles,
        uploadRepository: _ExactUploadRepository(wrongOwner),
      );
      expect(
        restored.auth.sessionDestination.kind,
        SessionDestinationKind.needsAction,
      );
      final recovery =
          restored.auth.reconstructionResult as ReconstructionRecovery;
      expect(
        recovery.diagnostics['code'],
        'step5_eating_source_owner_mismatch',
      );
      restored.dispose();
    });

    test('wrong exact R2 key enters typed integrity recovery', () async {
      const uid = 'asset-r2-user';
      final asset = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
      final draft = _importedEatingDraft(uid, asset);
      final import = draft.baseTimeline.latestImportForSection('Eating')!;
      final corrupt = draft.copyWith(
        baseTimeline: draft.baseTimeline.copyWith(
          pendingFutureImports: [
            import.copyWith(uploadedAssetR2Key: '${asset.r2Key}.wrong'),
          ],
        ),
        incrementRevision: false,
      );
      final onboarding = _SerializedOnboardingRepository();
      await _persistAcknowledgedStep(
        repository: onboarding,
        draft: corrupt,
        step: 5,
      );
      final profiles = await _profileRepositoryFor(
        const AuthUser(uid: uid, email: 'r2@example.com'),
        onboardingCompleted: false,
      );
      final uploads = FakeUploadedAssetRepository();
      await uploads.saveAsset(asset);
      final restored = await _freshAuthSession(
        uid: uid,
        onboardingRepository: onboarding,
        profileRepository: profiles,
        uploadRepository: uploads,
      );
      expect(
        restored.auth.sessionDestination.kind,
        SessionDestinationKind.needsAction,
      );
      final recovery =
          restored.auth.reconstructionResult as ReconstructionRecovery;
      expect(
        recovery.diagnostics['code'],
        'step5_eating_source_r2_key_mismatch',
      );
      restored.dispose();
    });

    test('wrong exact purpose enters typed integrity recovery', () async {
      const uid = 'asset-purpose-user';
      final expected = _asset(uid, 'menu-A', UploadedAssetPurpose.eatingMenu);
      final wrongPurpose = expected.copyWith(
        purpose: UploadedAssetPurpose.skinFace,
      );
      final onboarding = _SerializedOnboardingRepository();
      await _persistAcknowledgedStep(
        repository: onboarding,
        draft: _importedEatingDraft(uid, expected),
        step: 5,
      );
      final profiles = await _profileRepositoryFor(
        const AuthUser(uid: uid, email: 'purpose@example.com'),
        onboardingCompleted: false,
      );
      final restored = await _freshAuthSession(
        uid: uid,
        onboardingRepository: onboarding,
        profileRepository: profiles,
        uploadRepository: _ExactUploadRepository(wrongPurpose),
      );
      final recovery =
          restored.auth.reconstructionResult as ReconstructionRecovery;
      expect(
        recovery.diagnostics['code'],
        'step5_eating_source_purpose_mismatch',
      );
      restored.dispose();
    });

    test(
      'missing and unsupported completion receipts expose typed reasons',
      () async {
        const uid = 'receipt-migration-user';
        final onboarding = _SerializedOnboardingRepository();
        final completed = List<bool>.filled(OnboardingDraft.stepCount, false)
          ..[0] = true;
        final map =
            _durableDraft(uid)
                .copyWith(stepCompleted: completed, incrementRevision: false)
                .toMap()
              ..remove('stepCompletionContractVersions');
        await onboarding.saveRawDraft(uid, map);
        final profiles = await _profileRepositoryFor(
          const AuthUser(uid: uid, email: 'receipt@example.com'),
          onboardingCompleted: false,
        );
        var restored = await _freshAuthSession(
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: FakeUploadedAssetRepository(),
        );
        var result =
            restored.auth.reconstructionResult as ReconstructionIncomplete;
        expect(
          result.diagnostics['reason'],
          'durableContractMigrationRequired',
        );
        expect(
          result.diagnosticCode,
          'step_0_completion_contract_migration_required',
        );
        restored.dispose();

        map['stepCompletionContractVersions'] = [2, ...List.filled(14, 1)];
        await onboarding.saveRawDraft(uid, map);
        restored = await _freshAuthSession(
          uid: uid,
          onboardingRepository: onboarding,
          profileRepository: profiles,
          uploadRepository: FakeUploadedAssetRepository(),
        );
        result = restored.auth.reconstructionResult as ReconstructionIncomplete;
        expect(result.diagnosticCode, 'step_0_completion_contract_unsupported');
        restored.dispose();
      },
    );

    test('account A logout to account B leaks no onboarding state', () async {
      const a = AuthUser(uid: 'account-A', email: 'a@example.com');
      const b = AuthUser(uid: 'account-B', email: 'b@example.com');
      final onboarding = _SerializedOnboardingRepository();
      await _persistAcknowledgedStep(
        repository: onboarding,
        draft: _durableDraft(a.uid),
        step: 5,
      );
      await _persistAcknowledgedStep(
        repository: onboarding,
        draft: _durableDraft(b.uid),
        step: 7,
      );
      final profiles = FakeProfileRepository();
      await profiles.saveUserProfile(
        UserProfile.empty(uid: a.uid, email: a.email!),
      );
      await profiles.saveUserProfile(
        UserProfile.empty(uid: b.uid, email: b.email!),
      );
      final restored = await _freshAuthSession(
        uid: a.uid,
        onboardingRepository: onboarding,
        profileRepository: profiles,
        uploadRepository: FakeUploadedAssetRepository(),
      );
      expect(restored.auth.sessionDestination.resumeStep, 6);
      restored.authRepository.emit(null);
      await pumpEventQueue(times: 20);
      restored.authRepository.emit(
        const AuthUser(
          uid: 'account-B',
          email: 'b@example.com',
          emailVerified: true,
        ),
      );
      await pumpEventQueue(times: 30);
      expect(restored.auth.sessionDestination.resumeStep, 8);
      expect(restored.draft.uid, b.uid);
      restored.dispose();
    });
  });
}

List<Override> _firebaseOverrides({
  required AuthRepository authRepository,
  required ProfileRepository profileRepository,
  required OnboardingRepository onboardingRepository,
  UploadedAssetRepository? uploadRepository,
}) {
  return [
    optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
    authRepositoryProvider.overrideWithValue(authRepository),
    profileRepositoryProvider.overrideWithValue(profileRepository),
    regionSettingsRepositoryProvider.overrideWithValue(
      FakeRegionSettingsRepository(),
    ),
    deviceCountryServiceProvider.overrideWithValue(
      const _NoDeviceCountryService(),
    ),
    appPreferencesRepositoryProvider.overrideWithValue(
      FakeAppPreferencesRepository(),
    ),
    onboardingRepositoryProvider.overrideWithValue(onboardingRepository),
    if (uploadRepository != null)
      uploadedAssetRepositoryProvider.overrideWithValue(uploadRepository),
    routineImportReviewRepositoryProvider.overrideWithValue(
      FakeRoutineImportReviewRepository(),
    ),
    routineRepositoryProvider.overrideWithValue(FakeRoutineRepository()),
    routineHistoryRepositoryProvider.overrideWithValue(
      FakeRoutineHistoryRepository(),
    ),
    routineTransactionRepositoryProvider.overrideWithValue(
      FakeRoutineTransactionRepository(
        routineRepository: FakeRoutineRepository(),
        historyRepository: FakeRoutineHistoryRepository(),
      ),
    ),
  ];
}

class _NoDeviceCountryService implements DeviceCountryService {
  const _NoDeviceCountryService();

  @override
  Future<DeviceCountry?> detectCountry() async => null;
}

Future<FakeProfileRepository> _profileRepositoryFor(
  AuthUser user, {
  required bool onboardingCompleted,
  int? onboardingStep,
}) async {
  final repository = FakeProfileRepository();
  await repository.saveUserProfile(
    UserProfile.empty(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    ).copyWith(
      onboardingCompleted: onboardingCompleted,
      onboardingStep:
          onboardingStep ??
          (onboardingCompleted ? OnboardingDraft.lastStepIndex : 0),
      updatedAt: DateTime.utc(2026, 6, 5),
    ),
  );
  return repository;
}

OnboardingDraft _draftFor(String uid, {required int currentStep}) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var i = 0; i < currentStep; i++) {
    completed[i] = true;
  }
  return OnboardingDraft(
    uid: uid,
    currentStep: currentStep,
    stepCompleted: completed,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
    createdAt: DateTime.utc(2026, 6, 5, 8),
    updatedAt: DateTime.utc(2026, 6, 5, 9),
  );
}

OnboardingDraft _completedDraftFor(String uid) {
  final draft = _draftFor(uid, currentStep: OnboardingDraft.lastStepIndex);
  return draft.copyWith(
    currentStep: OnboardingDraft.lastStepIndex,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    onboardingCompleted: true,
    finalPreview: draft.buildFinalPreview(),
    incrementRevision: false,
  );
}

OnboardingCompletionBundle _completionBundleFor(
  String uid,
  OnboardingDraft draft,
) {
  return OnboardingCompletionBundle(
    uid: uid,
    runId: 'run-completed-startup',
    createdAt: DateTime.utc(2026, 6, 5, 10),
    updatedAt: DateTime.utc(2026, 6, 5, 10),
    userProfilePatch: const {},
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: const [],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
    sourceFingerprint: draft.effectiveSourceFingerprint,
    draftRevision: draft.revision,
  );
}

Future<void> _persistAcknowledgedStep({
  required _SerializedOnboardingRepository repository,
  required OnboardingDraft draft,
  required int step,
}) async {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var index = 0; index < step; index++) {
    completed[index] = true;
  }
  final sessionA = ProviderContainer();
  sessionA
      .read(onboardingStateProvider.notifier)
      .loadSeedData(
        draft.copyWith(
          currentStep: step,
          stepCompleted: completed,
          incrementRevision: false,
        ),
      );
  sessionA
      .read(onboardingStateProvider.notifier)
      .saveStep(step, uid: draft.uid);
  await repository.saveDraft(sessionA.read(onboardingStateProvider).draft);
  await repository.flushPendingDraftSave();
  sessionA.dispose();
}

Future<_FreshSessionResult> _freshAuthSession({
  required String uid,
  required _SerializedOnboardingRepository onboardingRepository,
  required ProfileRepository profileRepository,
  required UploadedAssetRepository uploadRepository,
  OnboardingCompletionJobService? jobService,
  OnboardingCurrentRunSnapshot? currentRunSnapshot,
}) async {
  final authRepository = _ControllableAuthRepository();
  final source = _PersistentRepositoryReconstructionSource(
    profiles: profileRepository,
    onboarding: onboardingRepository,
    jobService: jobService,
    currentRunOverride: currentRunSnapshot,
  );
  final overrides =
      _firebaseOverrides(
        authRepository: authRepository,
        profileRepository: profileRepository,
        onboardingRepository: onboardingRepository,
        uploadRepository: uploadRepository,
      )..add(
        serverReconstructorProvider.overrideWithValue(
          ServerReconstructor(source: source),
        ),
      );
  final container = ProviderContainer(overrides: overrides);
  container.read(authProvider);
  authRepository.emit(
    AuthUser(uid: uid, email: '$uid@example.com', emailVerified: true),
  );
  await pumpEventQueue(times: 30);
  return _FreshSessionResult(
    container: container,
    authRepository: authRepository,
  );
}

Future<void> _expectLifecycleRestore({
  required String mode,
  required String uid,
  required _SerializedOnboardingRepository onboardingRepository,
  required ProfileRepository profileRepository,
  required UploadedAssetRepository uploadRepository,
  required int expectedStep,
}) async {
  final restored = await _freshAuthSession(
    uid: uid,
    onboardingRepository: onboardingRepository,
    profileRepository: profileRepository,
    uploadRepository: uploadRepository,
  );
  expect(restored.auth.sessionDestination.resumeStep, expectedStep);
  if (mode == 'logout_login') {
    restored.authRepository.emit(null);
    await pumpEventQueue(times: 20);
    expect(restored.container.read(onboardingStateProvider).draft.uid, isEmpty);
    restored.authRepository.emit(
      AuthUser(uid: uid, email: '$uid@example.com', emailVerified: true),
    );
    await pumpEventQueue(times: 30);
    expect(restored.auth.sessionDestination.resumeStep, expectedStep);
  }
  restored.dispose();
}

Future<void> _expectSpecialDraftRestore({
  required String uid,
  required int step,
  required OnboardingDraft Function(String uid) draftBuilder,
  required int expectedStep,
  UploadedAssetRepository? uploadRepository,
}) async {
  final onboarding = _SerializedOnboardingRepository();
  final profiles = await _profileRepositoryFor(
    AuthUser(uid: uid, email: '$uid@example.com'),
    onboardingCompleted: false,
  );
  await _persistAcknowledgedStep(
    repository: onboarding,
    draft: draftBuilder(uid),
    step: step,
  );
  final restored = await _freshAuthSession(
    uid: uid,
    onboardingRepository: onboarding,
    profileRepository: profiles,
    uploadRepository: uploadRepository ?? FakeUploadedAssetRepository(),
  );
  expect(
    restored.auth.sessionDestination.kind,
    SessionDestinationKind.resumeOnboarding,
  );
  expect(restored.auth.sessionDestination.resumeStep, expectedStep);
  restored.dispose();
}

OnboardingDraft _durableDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: const BaseTimelineDraft(
      eatingSetupPath: 'skip',
      skinCareSetupPath: 'skip',
      skinCareSkipped: true,
    ).withRequiredFixedBlocks(),
    badHabitsNotNow: true,
    goodHabitsNotNow: true,
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'consistent',
        displayName: 'Become consistent',
        systemKeys: ['daily_review'],
      ),
    ],
    coachSetup: const CoachSetupDraft(
      coachName: 'Optivus',
      coachStyle: 'supportive',
    ),
    slipUpHandling: 'restart_next_action',
    notifications: const NotificationSetupDraft(
      preferencesConfirmed: true,
      reminderIntensity: 'medium',
    ),
    createdAt: DateTime.utc(2026, 9, 1),
    updatedAt: DateTime.utc(2026, 9, 1),
  );
}

OnboardingDraft _generatedEatingDraft(String uid) {
  final draft = _durableDraft(uid);
  final fixed = draft.baseTimeline.blocks;
  final generated = <TimelineBlockDraft>[];
  const slots = [('breakfast', 480), ('lunch', 780), ('dinner', 1200)];
  for (var day = 1; day <= 7; day++) {
    for (final slot in slots) {
      generated.add(
        TimelineBlockDraft(
          id: 'meal-$day-${slot.$1}',
          section: 'eating',
          title: '${slot.$1} $day',
          mealSlot: slot.$1,
          mealCategory: slot.$1,
          dishes: ['Dish ${slot.$1} $day A', 'Dish ${slot.$1} $day B'],
          calories: 600,
          protein: 30,
          startMinute: slot.$2,
          endMinute: slot.$2 + 30,
          repeatDays: [day],
          source: 'ai_generated_meal_setup',
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      );
    }
  }
  return draft.copyWith(
    baseTimeline: draft.baseTimeline.copyWith(
      eatingSetupPath: 'create',
      mealsPerDay: 3,
      eatingGeneratedPlanVersion:
          BaseTimelineDraft.currentGate2EatingPlanVersion,
      eatingGeneratedInputFingerprint: 'gate4-generated-receipt-v2',
      blocks: [...fixed, ...generated],
    ),
    incrementRevision: false,
  );
}

OnboardingDraft _importedEatingDraft(String uid, UploadedAsset asset) {
  final draft = _durableDraft(uid);
  return draft.copyWith(
    baseTimeline: draft.baseTimeline.copyWith(
      eatingSetupPath: 'has_routine',
      pendingFutureImports: [
        PendingFutureImportDraft(
          id: 'eating-import',
          section: 'Eating',
          mode: 'Photo AI',
          createdAt: DateTime.utc(2026, 9, 1),
          uploadedAssetId: asset.assetId,
          uploadedAssetR2Key: asset.r2Key,
          status: 'applied',
        ),
      ],
      blocks: [
        ...draft.baseTimeline.blocks,
        TimelineBlockDraft(
          id: 'imported-meal',
          section: 'eating',
          title: 'Imported lunch',
          startMinute: 780,
          endMinute: 810,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          source: 'ai_import',
          blockType: TimelineBlockDraft.hardBlockKey,
          provenanceSourceIds: [asset.assetId, asset.r2Key],
        ),
      ],
    ),
    incrementRevision: false,
  );
}

OnboardingDraft _hasProductsSkinDraft(String uid) {
  final draft = _durableDraft(uid);
  var base = draft.baseTimeline.copyWith(
    skinCareSetupPath: 'has_products',
    skinCareSkipped: false,
    skinCareDesiredApplicationsPerDay: 2,
    skinCareProductNames: 'Gentle Cleanser',
    skinCareReviewedProducts: const [
      SkinCareDetectedProduct(name: 'Gentle Cleanser'),
    ],
  );
  final fingerprint = base.computeSkinCareRoutineFingerprintV1();
  base = base.copyWith(
    skinCareRoutineFingerprint: fingerprint,
    blocks: [
      ...base.blocks,
      ..._skinRoutineBlocks(fingerprint, const ['Gentle Cleanser']),
    ],
  );
  return draft.copyWith(baseTimeline: base, incrementRevision: false);
}

OnboardingDraft _buildForMeSkinDraft(String uid, UploadedAsset asset) {
  final draft = _durableDraft(uid);
  const recommendations = [
    SkinCareProductRecommendationDraft(
      name: 'Cleanser',
      brand: 'A',
      category: 'cleanser',
      estimatedPrice: '10',
      currencyCode: 'USD',
      reason: 'gentle',
    ),
    SkinCareProductRecommendationDraft(
      name: 'Moisturizer',
      brand: 'B',
      category: 'moisturizer',
      estimatedPrice: '12',
      currencyCode: 'USD',
      reason: 'hydrating',
    ),
    SkinCareProductRecommendationDraft(
      name: 'Sunscreen',
      brand: 'C',
      category: 'sunscreen',
      estimatedPrice: '15',
      currencyCode: 'USD',
      reason: 'protective',
    ),
  ];
  final selected = recommendations.map((item) => item.displayName).toList();
  var base = draft.baseTimeline.copyWith(
    skinCareSetupPath: 'no_products',
    skinCareSkipped: false,
    skinCareDesiredApplicationsPerDay: 2,
    skinCareFacePhotoAssetId: asset.assetId,
    skinCareFacePhotoR2Key: asset.r2Key,
    skinCareFacePhotoStatus: asset.status.wireName,
    skinCareSkinType: 'normal',
    skinCareProblems: const ['dryness'],
    skinCareBudget: 'medium',
    skinCarePreference: 'balanced',
    skinCareRecommendationCountryCode: 'US',
    skinCareRecommendationCurrencyCode: 'USD',
    skinCareProductRecommendations: recommendations,
    skinCareSelectedProductNames: selected,
  );
  final recommendation = base.computeSkinCareRecommendationFingerprintV1();
  base = base.copyWith(skinCareRecommendationFingerprint: recommendation);
  final routine = base.computeSkinCareRoutineFingerprintV1();
  base = base.copyWith(
    skinCareRoutineFingerprint: routine,
    blocks: [...base.blocks, ..._skinRoutineBlocks(routine, selected)],
  );
  return draft.copyWith(baseTimeline: base, incrementRevision: false);
}

List<TimelineBlockDraft> _skinRoutineBlocks(
  String fingerprint,
  List<String> products,
) => [
  for (final entry in const [('am', 480), ('pm', 1260)])
    TimelineBlockDraft(
      id: 'skin-${entry.$1}',
      section: 'skin_care',
      title: '${entry.$1.toUpperCase()} routine',
      startMinute: entry.$2,
      endMinute: entry.$2 + 15,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      source: 'ai_generated_skin_care_setup',
      blockType: TimelineBlockDraft.softBlockKey,
      skincareProducts: products,
      skincareSteps: const ['Apply in order'],
      provenanceSourceIds: ['skin-care-generation:$fingerprint'],
    ),
];

UploadedAsset _asset(String uid, String id, UploadedAssetPurpose purpose) =>
    UploadedAsset(
      assetId: id,
      ownerUid: uid,
      sourceFeature: OnboardingDraft.sourceOnboarding,
      purpose: purpose,
      fileName: '$id.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 100,
      r2Key: 'users/$uid/onboarding/${purpose.wireName}/$id.jpg',
      status: UploadedAssetStatus.uploaded,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

class _FailingUploadRepository implements UploadedAssetRepository {
  const _FailingUploadRepository();

  Never _fail() => throw Exception('temporary upload backend failure');

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async => _fail();

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async => _fail();

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async => _fail();

  @override
  Future<void> saveAsset(UploadedAsset asset) async => _fail();
}

class _ExactUploadRepository implements UploadedAssetRepository {
  final UploadedAsset exact;

  const _ExactUploadRepository(this.exact);

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async => assetId == exact.assetId ? exact : null;

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async => const [];

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {}

  @override
  Future<void> saveAsset(UploadedAsset asset) async {}
}

class _FreshSessionResult {
  final ProviderContainer container;
  final _ControllableAuthRepository authRepository;

  const _FreshSessionResult({
    required this.container,
    required this.authRepository,
  });

  AuthState get auth => container.read(authProvider);
  OnboardingDraft get draft => container.read(onboardingStateProvider).draft;

  void dispose() {
    container.dispose();
    authRepository.dispose();
  }
}

class _PersistentRepositoryReconstructionSource
    implements ServerReconstructionSource {
  final ProfileRepository profiles;
  final OnboardingRepository onboarding;
  final OnboardingCompletionJobService? jobService;
  final OnboardingCurrentRunSnapshot? currentRunOverride;

  const _PersistentRepositoryReconstructionSource({
    required this.profiles,
    required this.onboarding,
    this.jobService,
    this.currentRunOverride,
  });

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    final profile = await profiles.fetchUserProfile(uid);
    onProfileLoaded?.call(profile);
    final currentRun =
        currentRunOverride ??
        (await jobService?.loadCurrentRunSnapshot(uid)) ??
        const OnboardingCurrentRunSnapshot.none();
    return ServerReconstructionSnapshot(
      profile: profile,
      draft: await onboarding.fetchDraft(uid),
      completionBundle: await onboarding.fetchCompletionBundle(uid),
      currentRun: currentRun,
    );
  }

  @override
  Future<void> createProfileShell(UserProfile profile) =>
      profiles.saveUserProfile(profile);
}

class _SerializedOnboardingRepository implements OnboardingRepository {
  final Map<String, Map<String, dynamic>> _drafts = {};
  OnboardingCompletionBundle? completionBundle;

  _SerializedOnboardingRepository({this.completionBundle});

  Future<void> saveRawDraft(String uid, Map<String, dynamic> map) async {
    _drafts[uid] = Map<String, dynamic>.from(map);
  }

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    final map = _drafts[uid];
    return map == null ? null : OnboardingDraft.fromMap(Map.of(map));
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _drafts[draft.uid] = Map<String, dynamic>.from(draft.toMap());
  }

  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) =>
      saveDraft(draft);

  @override
  Future<void> flushPendingDraftSave() async {}

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    final bundle = completionBundle;
    return bundle?.uid == uid
        ? OnboardingCompletionBundle.fromMap(bundle!.toMap())
        : null;
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    completionBundle = bundle;
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    await saveDraft(finalDraft);
    completionBundle = bundle;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: RoutineOnboardingProjection.build(bundle).receipt,
    );
  }

  @override
  void dispose() {}
}

class _ControllableAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signInAnonymously() async =>
      _currentUser ?? const AuthUser(uid: 'anon-id', email: 'anon@test.dev');

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async =>
      _currentUser ?? AuthUser(uid: 'anon-id', email: email, displayName: name);

  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<String?> currentIdToken() async =>
      _currentUser == null ? null : 'token';

  @override
  Future<AuthUser?> reloadCurrentUser() async => _currentUser;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async {
    final user =
        _currentUser ??
        AuthUser(uid: 'login-user', email: email, emailVerified: true);
    emit(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    emit(null);
  }

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    final user = AuthUser(
      uid: 'signup-user',
      email: email,
      displayName: name,
      emailVerified: false,
    );
    emit(user);
    return user;
  }
}

class _ControlledOnboardingRepository implements OnboardingRepository {
  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    await saveDraft(draft);
  }

  final Completer<OnboardingDraft?>? draftCompleter;
  final OnboardingCompletionBundle? completionBundle;
  OnboardingDraft? draft;
  int draftFailures;

  _ControlledOnboardingRepository({
    this.draftCompleter,
    this.completionBundle,
    this.draft,
    this.draftFailures = 0,
  });

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    if (draftFailures > 0) {
      draftFailures--;
      throw Exception('draft fetch failed');
    }
    final completer = draftCompleter;
    if (completer != null) {
      return completer.future;
    }
    return draft?.uid == uid ? draft : null;
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    return completionBundle?.uid == uid ? completionBundle : null;
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    this.draft = draft;
  }

  @override
  Future<void> flushPendingDraftSave() async {}

  @override
  void dispose() {}

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {}

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    draft = finalDraft;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: RoutineOnboardingProjection.build(bundle).receipt,
    );
  }
}
