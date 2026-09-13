import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_import_review_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/onboarding_frontend_hydration_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/features/routine/services/routine_materializer.dart';

void main() {
  group('Routine template Firestore contract', () {
    const codec = RoutineTemplateFirestoreCodec();

    test('serializes canonical fields with Firestore timestamps', () {
      final item = _routineItem();

      final map = codec.toFirestore(ownerUid: 'user-a', item: item);

      expect(
        map.keys.toSet().difference(
          RoutineTemplateFirestoreCodec.allowedFields,
        ),
        isEmpty,
      );
      expect(map['ownerUid'], 'user-a');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
      expect(map['schemaVersion'], RoutineItem.currentSchemaVersion);
      expect(map, isNot(contains('status')));
      expect(map, isNot(contains('isCompleted')));
      expect(map, isNot(contains('isMissed')));
      expect(map, isNot(contains('hasConflict')));
      expect(map, isNot(contains('conflictMessage')));
      expect(map, isNot(contains('subtasksCompleted')));
      expect(map, isNot(contains('isContinuation')));
      expect(map, isNot(contains('skincareProducts')));
      expect(map, isNot(contains('allowedOverlaps')));
      expect(
        RoutineTemplateFirestoreCodec.allowedFields,
        isNot(contains('allowedOverlaps')),
      );
    });

    test(
      'serializes and validates skincare metadata for routine templates',
      () {
        final item = _routineItem().copyWith(
          category: RoutineCategory.skinCare,
          skincareMissingItems: const ['Cleanser', 'SPF'],
          skincareSlotLabel: ' Morning ',
        );

        final map = codec.toFirestore(ownerUid: 'user-a', item: item);

        expect(map['skincareMissingItems'], ['Cleanser', 'SPF']);
        expect(map['skincareSlotLabel'], 'Morning');

        final decoded = codec.fromFirestore(documentId: 'routine-a', data: map);
        expect(decoded.skincareMissingItems, ['Cleanser', 'SPF']);
        expect(decoded.skincareSlotLabel, 'Morning');

        expect(
          () => codec.toFirestore(
            ownerUid: 'user-a',
            item: item.copyWith(
              skincareMissingItems: List<String>.filled(101, 'SPF'),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => codec.toFirestore(
            ownerUid: 'user-a',
            item: item.copyWith(skincareSlotLabel: ' '),
          ),
          throwsArgumentError,
        );
        expect(
          () => codec.toFirestore(
            ownerUid: 'user-a',
            item: item.copyWith(
              skincareSlotLabel: List<String>.filled(51, 'x').join(),
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects legacy allowedOverlaps in current Firestore schema', () {
      final map = codec.toFirestore(ownerUid: 'user-a', item: _routineItem());
      map['allowedOverlaps'] = ['routine-b'];

      expect(
        () => codec.fromFirestore(documentId: 'routine-a', data: map),
        throwsFormatException,
      );
    });

    test('reads Firestore Timestamp values', () {
      final map = codec.toFirestore(ownerUid: 'user-a', item: _routineItem());
      final createdAt = DateTime.utc(2026, 7, 23, 8, 30);
      map['createdAt'] = Timestamp.fromDate(createdAt);
      map['updatedAt'] = Timestamp.fromDate(
        createdAt.add(const Duration(minutes: 5)),
      );

      final decoded = codec.fromFirestore(documentId: 'routine-a', data: map);

      expect(decoded.createdAt, createdAt);
      expect(decoded.updatedAt, createdAt.add(const Duration(minutes: 5)));
    });

    test('reads supported legacy Routine shape and normalizes daily state', () {
      final decoded = codec.fromFirestore(
        documentId: 'legacy-routine',
        data: {
          'id': 'legacy-routine',
          'userId': 'user-a',
          'title': 'Legacy breakfast',
          'startMinute': 8 * 60,
          'endMinute': 8 * 60 + 30,
          'repeatDays': [1, 2, 3, 4, 5],
          'blockType': 'unknown_legacy_block',
          'category': 'unknown_legacy_category',
          'source': 'unknown_legacy_source',
          'priority': 'unknown_legacy_priority',
          'trackerType': 'unknown_legacy_tracker',
          'status': 'completed',
          'isCompleted': true,
          'hasConflict': true,
          'createdAt': '2026-07-20T08:00:00.000Z',
          'updatedAt': '2026-07-20T09:00:00.000Z',
        },
      );

      expect(decoded.userId, 'user-a');
      expect(decoded.blockType, RoutineBlockType.flexibleTask);
      expect(decoded.category, RoutineCategory.fixed);
      expect(decoded.source, RoutineSource.manual);
      expect(decoded.priority, RoutinePriority.goodToDo);
      expect(decoded.trackerType, TrackerType.none);
      expect(decoded.status, RoutineStatus.planned);
      expect(decoded.isCompleted, isFalse);
      expect(decoded.hasConflict, isFalse);
    });

    test('rejects malformed canonical enum values safely', () {
      final map = codec.toFirestore(ownerUid: 'user-a', item: _routineItem());
      map['category'] = 'not-a-category';

      expect(
        () => codec.fromFirestore(documentId: 'routine-a', data: map),
        throwsFormatException,
      );
    });

    test('rejects unknown future schema versions safely', () {
      final map = codec.toFirestore(ownerUid: 'user-a', item: _routineItem());
      map['schemaVersion'] = RoutineItem.currentSchemaVersion + 1;

      expect(
        () => codec.fromFirestore(documentId: 'routine-a', data: map),
        throwsFormatException,
      );
    });

    test('rejects invalid repeat days', () {
      expect(
        () => codec.toFirestore(
          ownerUid: 'user-a',
          item: _routineItem().copyWith(repeatDays: const [1, 1, 8]),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid time and date ranges', () {
      expect(
        () => codec.toFirestore(
          ownerUid: 'user-a',
          item: _routineItem().copyWith(endMinute: 8 * 60),
        ),
        throwsArgumentError,
      );
      expect(
        () => codec.toFirestore(
          ownerUid: 'user-a',
          item: _routineItem().copyWith(
            date: DateTime(2026, 7, 30),
            endDate: DateTime(2026, 7, 23),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => codec.toFirestore(
          ownerUid: 'user-a',
          item: _routineItem().copyWith(
            startMinute: 23 * 60,
            endMinute: 7 * 60,
            crossesMidnight: false,
            endsNextDay: false,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid IDs and owner UIDs', () {
      expect(
        () => codec.toFirestore(ownerUid: 'user/a', item: _routineItem()),
        throwsArgumentError,
      );
      expect(
        () => codec.toFirestore(
          ownerUid: 'user-a',
          item: _routineItem().copyWith(id: 'bad/id'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Routine occurrence contract', () {
    test('completion is dated and does not mutate the repeating template', () {
      final template = _routineItem().copyWith(
        repeatDays: const [DateTime.thursday],
        status: RoutineStatus.planned,
        isCompleted: false,
        isMissed: false,
        isContinuation: false,
      );
      final firstThursday = DateTime(2026, 7, 23);
      final nextThursday = DateTime(2026, 7, 30);
      final dateKey = routineLocalDateKey(firstThursday);
      final occurrence = RoutineOccurrenceRecord(
        id: stableRoutineOccurrenceId(
          ownerUid: 'user-a',
          routineItemId: template.id,
          occurrenceDateKey: dateKey,
        ),
        ownerUid: 'user-a',
        routineItemId: template.id,
        occurrenceDateKey: dateKey,
        status: RoutineStatus.completed,
        source: 'routine',
        action: 'complete',
        operationKey: 'complete:${template.id}:$dateKey',
        createdAt: DateTime.utc(2026, 7, 23, 9),
        updatedAt: DateTime.utc(2026, 7, 23, 9),
      );

      final first = RoutineOccurrenceProjector.itemsForDay(
        [template],
        [occurrence],
        firstThursday,
      ).single;
      final future = RoutineOccurrenceProjector.itemsForDay(
        [template],
        [occurrence],
        nextThursday,
      ).single;

      expect(first.status, RoutineStatus.completed);
      expect(first.isCompleted, isTrue);
      expect(future.status, RoutineStatus.planned);
      expect(future.isCompleted, isFalse);
      expect(template.status, RoutineStatus.planned);
      expect(template.isCompleted, isFalse);
    });

    test('occurrence codec uses one strict owner-scoped dated document', () {
      const codec = RoutineOccurrenceFirestoreCodec();
      final dateKey = '2026-07-23';
      final id = stableRoutineOccurrenceId(
        ownerUid: 'user-a',
        routineItemId: 'routine-a',
        occurrenceDateKey: dateKey,
      );
      final record = RoutineOccurrenceRecord(
        id: id,
        ownerUid: 'user-a',
        routineItemId: 'routine-a',
        occurrenceDateKey: dateKey,
        status: RoutineStatus.skipped,
        source: 'routine',
        action: 'skip',
        operationKey: '$id:skip',
        createdAt: DateTime.utc(2026, 7, 23),
        updatedAt: DateTime.utc(2026, 7, 23),
      );

      final map = codec.toFirestore(record);
      final decoded = codec.fromFirestore(documentId: id, data: map);

      expect(
        map.keys.toSet().difference(
          RoutineOccurrenceFirestoreCodec.allowedFields,
        ),
        isEmpty,
      );
      expect(decoded.ownerUid, 'user-a');
      expect(decoded.occurrenceDateKey, dateKey);
      expect(decoded.status, RoutineStatus.skipped);
      expect(decoded.operationKey, '$id:skip');

      map['schemaVersion'] = RoutineOccurrenceRecord.currentSchemaVersion + 1;
      expect(
        () => codec.fromFirestore(documentId: id, data: map),
        throwsArgumentError,
      );
      expect(
        () => codec.toFirestore(
          record.copyWith(completedSubtaskIndexes: const [100]),
        ),
        throwsArgumentError,
      );
    });

    test('recurring date ranges include both boundaries only', () {
      final template = _routineItem().copyWith(
        date: DateTime(2026, 7, 23),
        endDate: DateTime(2026, 7, 30),
        repeatDays: const [DateTime.thursday],
        status: RoutineStatus.planned,
        isCompleted: false,
        isMissed: false,
        isContinuation: false,
      );

      expect(
        RoutineMaterializer.itemsForDay([template], DateTime(2026, 7, 16)),
        isEmpty,
      );
      expect(
        RoutineMaterializer.itemsForDay([template], DateTime(2026, 7, 23)),
        hasLength(1),
      );
      expect(
        RoutineMaterializer.itemsForDay([template], DateTime(2026, 7, 30)),
        hasLength(1),
      );
      expect(
        RoutineMaterializer.itemsForDay([template], DateTime(2026, 8, 6)),
        isEmpty,
      );
    });
  });

  group('Onboarding Routine projection', () {
    test('stable IDs and fingerprint ignore completion timestamps', () {
      final firstDraft = _completedDraft('user-a');
      final secondDraft = firstDraft.copyWith(
        updatedAt: DateTime.utc(2026, 7, 24),
        incrementRevision: false,
      );
      final first = RoutineOnboardingProjection.build(
        OnboardingCompletionService.buildBundle(firstDraft),
      );
      final second = RoutineOnboardingProjection.build(
        OnboardingCompletionService.buildBundle(secondDraft),
      );

      expect(first.projectionId, '${first.receipt.slot}-v1');
      expect(
        first.items.map((item) => item.id),
        second.items.map((item) => item.id),
      );
      expect(first.fingerprint, second.fingerprint);
    });

    test(
      'completion creates normalized templates and receipt exactly once',
      () async {
        final database = FakeRoutineDatabase();
        final onboarding = FakeOnboardingRepository(routineDatabase: database);
        final routines = FakeRoutineRepository(database: database);
        final draft = _completedDraft('user-a');
        final bundle = OnboardingCompletionService.buildBundle(draft);

        final first = await onboarding.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );
        final second = await onboarding.completeOnboarding(
          finalDraft: draft,
          bundle: bundle,
        );
        final saved = await routines.fetchRoutineItems('user-a');

        expect(first.outcome, RoutineProjectionOutcome.projected);
        expect(second.outcome, RoutineProjectionOutcome.noOp);
        expect(saved, isNotEmpty);
        expect(saved.map((item) => item.id).toSet(), hasLength(saved.length));
        expect(
          saved.every(
            (item) =>
                item.userId == 'user-a' &&
                item.source == RoutineSource.onboarding &&
                item.onboardingProjectionId == first.receipt.id &&
                item.status == RoutineStatus.planned,
          ),
          isTrue,
        );
        expect(second.receipt.projectedItemIds, first.receipt.projectedItemIds);
      },
    );

    test('retry never overwrites a user edit', () async {
      final harness = await _projectedHarness('user-a');
      final original = (await harness.routines.fetchRoutineItems(
        'user-a',
      )).single;
      await harness.routines.updateRoutineItem(
        'user-a',
        original.copyWith(title: 'My edited class', notes: 'Keep this'),
      );

      final result = await harness.onboarding.completeOnboarding(
        finalDraft: harness.draft,
        bundle: harness.bundle,
      );
      final saved = (await harness.routines.fetchRoutineItems('user-a')).single;

      expect(result.outcome, RoutineProjectionOutcome.noOp);
      expect(saved.title, 'My edited class');
      expect(saved.notes, 'Keep this');
    });

    test(
      'retry with same fingerprint repairs deletion while changed fingerprint re-projects',
      () async {
        final harness = await _projectedHarness('user-a');
        final original = (await harness.routines.fetchRoutineItems(
          'user-a',
        )).single;
        await harness.routines.deleteRoutineItem('user-a', original.id);

        // Retry with same draft/bundle restores the expected projected item.
        final retryResult = await harness.onboarding.completeOnboarding(
          finalDraft: harness.draft,
          bundle: harness.bundle,
        );
        expect(retryResult.outcome, RoutineProjectionOutcome.projected);
        expect(
          await harness.routines.fetchRoutineItems('user-a'),
          hasLength(1),
        );

        // Rebuilt draft with changed fingerprint triggers re-projection
        final changedDraft = _completedDraft(
          'user-a',
          title: 'Changed onboarding title',
        );
        final changedBundle = OnboardingCompletionService.buildBundle(
          changedDraft,
        );

        final reprojectResult = await harness.onboarding.completeOnboarding(
          finalDraft: changedDraft,
          bundle: changedBundle,
        );
        expect(reprojectResult.outcome, RoutineProjectionOutcome.projected);
        expect(
          await harness.routines.fetchRoutineItems('user-a'),
          hasLength(1),
        );
      },
    );

    test('different users receive isolated paths and IDs', () async {
      final first = await _projectedHarness('user-a');
      final second = await _projectedHarness('user-b');
      final firstId = (await first.routines.fetchRoutineItems(
        'user-a',
      )).single.id;
      final secondId = (await second.routines.fetchRoutineItems(
        'user-b',
      )).single.id;

      expect(firstId, isNot(secondId));
      expect(await first.routines.fetchRoutineItems('user-b'), isEmpty);
    });

    test('injected failure is atomic and retry is truthful', () async {
      final database = FakeRoutineDatabase();
      final onboarding = FakeOnboardingRepository(routineDatabase: database);
      final routines = FakeRoutineRepository(database: database);
      final draft = _completedDraft('user-a');
      final bundle = OnboardingCompletionService.buildBundle(draft);
      final plan = RoutineOnboardingProjection.build(bundle);
      onboarding.failNextCompletionBeforeCommit();

      await expectLater(
        onboarding.completeOnboarding(finalDraft: draft, bundle: bundle),
        throwsA(
          isA<RoutineProjectionRetryRequiredException>().having(
            (error) => error.outcome,
            'outcome',
            RoutineProjectionOutcome.retryRequired,
          ),
        ),
      );
      expect(await onboarding.fetchDraft('user-a'), isNull);
      expect(await onboarding.fetchCompletionBundle('user-a'), isNull);
      expect(await routines.fetchRoutineItems('user-a'), isEmpty);
      expect(
        await routines.fetchProjectionReceipt('user-a', plan.projectionId),
        isNull,
      );

      final retry = await onboarding.completeOnboarding(
        finalDraft: draft,
        bundle: bundle,
      );
      expect(retry.outcome, RoutineProjectionOutcome.projected);
      expect(await routines.fetchRoutineItems('user-a'), hasLength(1));
    });

    test(
      'Firebase hydration loads canonical Routine and leaves mock empty',
      () async {
        final harness = await _projectedHarness('user-a');
        final container = ProviderContainer(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.firebase,
            ),
            routineRepositoryProvider.overrideWithValue(harness.routines),
            routineHistoryRepositoryProvider.overrideWithValue(
              FakeRoutineHistoryRepository(),
            ),
            routineTransactionRepositoryProvider.overrideWith(
              (ref) => FakeRoutineTransactionRepository(
                routineRepository: ref.read(routineRepositoryProvider),
                historyRepository: ref.read(routineHistoryRepositoryProvider),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final first = await const OnboardingFrontendHydrationService().hydrate(
          read: container.read,
          bundle: harness.bundle,
        );
        final second = await const OnboardingFrontendHydrationService().hydrate(
          read: container.read,
          bundle: harness.bundle,
        );

        // Projection hydration does not load remote controllers mid-job; the
        // dedicated reload checkpoint owns that read.
        expect(first.routineItemIds, isEmpty);
        expect(second.routineItemIds, isEmpty);
        await const OnboardingFrontendHydrationService().reloadControllers(
          read: container.read,
          bundle: harness.bundle,
        );
        expect(container.read(routineNotifierProvider).items, hasLength(1));
        expect(first.mockRoutineItemIds, isEmpty);
      },
    );

    test(
      'Firebase auth reconstruction defers receipt-backed Routine until post-route load',
      () async {
        const user = AuthUser(
          uid: 'user-a',
          email: 'user-a@example.com',
          emailVerified: true,
        );
        final harness = await _projectedHarness(user.uid);
        final profileRepository = FakeProfileRepository();
        await profileRepository.saveUserProfile(
          UserProfile.empty(uid: user.uid, email: user.email ?? '').copyWith(
            onboardingCompleted: true,
            onboardingStep: OnboardingDraft.lastStepIndex,
            updatedAt: DateTime.utc(2026, 7, 23),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.firebase,
            ),
            authRepositoryProvider.overrideWithValue(
              _StaticAuthRepository(user),
            ),
            onboardingRepositoryProvider.overrideWithValue(harness.onboarding),
            routineRepositoryProvider.overrideWithValue(harness.routines),
            routineHistoryRepositoryProvider.overrideWithValue(
              FakeRoutineHistoryRepository(),
            ),
            routineTransactionRepositoryProvider.overrideWith(
              (ref) => FakeRoutineTransactionRepository(
                routineRepository: ref.read(routineRepositoryProvider),
                historyRepository: ref.read(routineHistoryRepositoryProvider),
              ),
            ),
            profileRepositoryProvider.overrideWithValue(profileRepository),
            regionSettingsRepositoryProvider.overrideWithValue(
              FakeRegionSettingsRepository(),
            ),
            appPreferencesRepositoryProvider.overrideWithValue(
              FakeAppPreferencesRepository(),
            ),
            routineImportReviewRepositoryProvider.overrideWithValue(
              FakeRoutineImportReviewRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authProvider.notifier)
            .login(user.email!, 'password');
        await container.read(authProvider.notifier).retryBackendRestore();

        expect(
          container.read(authProvider).status,
          AuthFlowStatus.signedInOnboardingComplete,
        );
        expect(container.read(routineNotifierProvider).items, hasLength(1));
        await container
            .read(routineNotifierProvider.notifier)
            .loadForOwner(user.uid);
        expect(container.read(routineNotifierProvider).items, hasLength(1));
      },
    );
  });

  group('repository selection and rule source gates', () {
    test('Firebase mode selects Firestore-capable Routine repositories', () {
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(
            OptivusBackendMode.firebase,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(routineRepositoryProvider),
        isA<FirestoreRoutineRepository>(),
      );
      expect(
        container.read(routineHistoryRepositoryProvider),
        isA<FirestoreRoutineHistoryRepository>(),
      );
    });

    test('Firebase Routine waits for an authenticated owner UID', () async {
      final container = ProviderContainer(
        overrides: [
          optivusBackendModeProvider.overrideWithValue(
            OptivusBackendMode.firebase,
          ),
          routineRepositoryProvider.overrideWithValue(FakeRoutineRepository()),
          routineHistoryRepositoryProvider.overrideWithValue(
            FakeRoutineHistoryRepository(),
          ),
          routineTransactionRepositoryProvider.overrideWith(
            (ref) => FakeRoutineTransactionRepository(
              routineRepository: ref.read(routineRepositoryProvider),
              historyRepository: ref.read(routineHistoryRepositoryProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(routineNotifierProvider.notifier)
            .addItem(_routineItem()),
        throwsStateError,
      );
      await container
          .read(routineNotifierProvider.notifier)
          .loadForOwner('user-a');
      await container
          .read(routineNotifierProvider.notifier)
          .addItem(_routineItem());

      expect(
        container.read(routineNotifierProvider).items.single.userId,
        'user-a',
      );
    });

    test('strict Routine rules are not bypassed by the catch-all', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /users/{uid}/routineItems/{itemId}'));
      expect(
        rules,
        contains('match /users/{uid}/routineHistory/{occurrenceId}'),
      );
      expect(
        rules,
        contains('match /users/{uid}/routineProjections/{projectionId}'),
      );
      expect(rules, contains('validRoutineTemplate(request.resource.data'));
      expect(rules, contains('validRoutineOccurrence(request.resource.data'));
      expect(rules, contains('validRoutineProjectionReceipt('));
      expect(rules, contains('days.size() == days.toSet().size()'));
      expect(rules, contains('data.endDateKey >= data.dateKey'));
      expect(
        rules,
        contains('request.resource.data.ownerUid == request.auth.uid'),
      );
      expect(rules, contains('match /users/{uid}/routineItems/{itemId}'));
      expect(
        rules,
        contains('match /users/{uid}/routineHistory/{occurrenceId}'),
      );
      expect(
        rules,
        contains('match /users/{uid}/routineProjections/{projectionId}'),
      );
      expect(rules, contains('"localPreviewPath"'));
    });
  });
}

RoutineItem _routineItem() {
  return RoutineItem(
    id: 'routine-a',
    userId: 'user-a',
    title: 'Breakfast',
    startMinute: 8 * 60,
    endMinute: 8 * 60 + 30,
    repeatDays: const [1, 2, 3, 4, 5],
    repeatRule: 'weekly',
    blockType: RoutineBlockType.softBlock,
    category: RoutineCategory.eating,
    source: RoutineSource.onboarding,
    priority: RoutinePriority.mustDo,
    subtasks: const ['Prepare', 'Eat'],
    subtasksCompleted: const [true, false],
    steps: const ['Prepare oats'],
    skincareProducts: const ['local-only compatibility field'],
    status: RoutineStatus.completed,
    isCompleted: true,
    isMissed: true,
    hasConflict: true,
    conflictMessage: 'UI-only conflict',
    isContinuation: true,
    createdAt: DateTime.utc(2026, 7, 20, 8),
    updatedAt: DateTime.utc(2026, 7, 20, 9),
  );
}

OnboardingDraft _completedDraft(String uid, {String title = 'Morning class'}) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    baseTimeline: BaseTimelineDraft(
      blocks: [
        TimelineBlockDraft(
          id: 'class-main',
          section: 'classes',
          title: title,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
    createdAt: DateTime.utc(2026, 7, 20),
    updatedAt: DateTime.utc(2026, 7, 23),
  );
}

Future<_ProjectionHarness> _projectedHarness(String uid) async {
  final database = FakeRoutineDatabase();
  final onboarding = FakeOnboardingRepository(routineDatabase: database);
  final routines = FakeRoutineRepository(database: database);
  final draft = _completedDraft(uid);
  final bundle = OnboardingCompletionService.buildBundle(draft);
  await onboarding.completeOnboarding(finalDraft: draft, bundle: bundle);
  final plan = RoutineOnboardingProjection.build(bundle);
  final receipt = database.receiptsByUid[uid]![plan.projectionId]!;
  database.receiptsByUid[uid]![plan.projectionId] = receipt.copyWith(
    status: 'completed',
    cursor: receipt.totalCount,
    completedAt: DateTime.now().toUtc(),
  );
  return _ProjectionHarness(
    onboarding: onboarding,
    routines: routines,
    draft: draft,
    bundle: bundle,
  );
}

class _ProjectionHarness {
  final FakeOnboardingRepository onboarding;
  final FakeRoutineRepository routines;
  final OnboardingDraft draft;
  final OnboardingCompletionBundle bundle;

  const _ProjectionHarness({
    required this.onboarding,
    required this.routines,
    required this.draft,
    required this.bundle,
  });
}

class _StaticAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> signInWithGoogle() async => null;

  final AuthUser user;

  const _StaticAuthRepository(this.user);

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInAnonymously() async => user;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => user;

  @override
  Future<String?> currentIdToken() async => 'token';

  @override
  Future<AuthUser?> reloadCurrentUser() async => user;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signUp(String email, String password, {String? name}) async {
    return user;
  }
}
