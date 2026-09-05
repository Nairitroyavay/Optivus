import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/domain/conflict_policy.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_conflict_engine.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/repositories/conflict_acceptance_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/state/region_settings_provider.dart';

const _uidA = 'ah-f015-user-a';
const _uidB = 'ah-f015-user-b';
const _timezone = 'Asia/Kolkata';
final _monday = DateTime(2026, 8, 31);
final _acceptedAt = DateTime.utc(2026, 8, 31, 3);

void main() {
  group('AH-F015 deterministic conflict identity', () {
    test('baseline ID and fingerprints survive pair reversal and rebuild', () {
      final fixture = _routineFixture();
      final forward = _acceptRoutine(fixture.$1, fixture.$2);
      final reverse = _acceptRoutine(fixture.$2, fixture.$1);

      expect(
        forward.acceptanceId,
        'ca_b11d2ece31ea577cb7b87a9603385ff8b06f0b0f',
      );
      expect(
        forward.combinedScheduleFingerprint,
        '1a22426f659a949fcdb08e3b2b83d4f321cbdabda658d280692ddeb571550cdd',
      );
      expect(forward.acceptanceId, reverse.acceptanceId);
      expect(forward.canonicalPairHash, reverse.canonicalPairHash);
      expect(
        forward.combinedScheduleFingerprint,
        reverse.combinedScheduleFingerprint,
      );
      expect(
        RoutineConflictEngine.scheduleFingerprint(
          fixture.$1,
          fixture.$2,
          RoutineConflictType.compatibleOverlap,
          timezoneId: _timezone,
        ),
        RoutineConflictEngine.scheduleFingerprint(
          fixture.$2,
          fixture.$1,
          RoutineConflictType.compatibleOverlap,
          timezoneId: _timezone,
        ),
      );
    });

    test('recurrence order is canonical but recurrence semantics matter', () {
      final fixture = _routineFixture();
      final reordered = fixture.$1.copyWith(repeatDays: const [5, 1, 3]);
      final changed = fixture.$1.copyWith(repeatDays: const [2, 4]);

      expect(
        _descriptor(fixture.$1).scheduleFingerprint,
        _descriptor(reordered).scheduleFingerprint,
      );
      expect(
        _descriptor(changed).scheduleFingerprint,
        isNot(_descriptor(fixture.$1).scheduleFingerprint),
      );
    });

    test('timezone and owner are fingerprint security boundaries', () {
      final fixture = _routineFixture();
      final acceptance = _acceptRoutine(fixture.$1, fixture.$2);
      final otherZone = _acceptRoutine(
        fixture.$1,
        fixture.$2,
        timezoneId: 'UTC',
      );
      final ownerBFirst = fixture.$1.copyWith(userId: _uidB);
      final ownerBSecond = fixture.$2.copyWith(userId: _uidB);
      final ownerB = _acceptRoutine(ownerBFirst, ownerBSecond, ownerUid: _uidB);

      expect(otherZone.acceptanceId, isNot(acceptance.acceptanceId));
      expect(ownerB.acceptanceId, isNot(acceptance.acceptanceId));
      expect(_isAccepted(ownerBFirst, ownerBSecond, [acceptance]), isFalse);
    });

    test('display-only title edit does not change schedule fingerprint', () {
      final fixture = _routineFixture();
      final renamed = fixture.$1.copyWith(title: 'Morning Meal');
      expect(
        _descriptor(renamed).scheduleFingerprint,
        _descriptor(fixture.$1).scheduleFingerprint,
      );
    });

    test('similar many-pair conflicts remain independently addressable', () {
      final a = _fixed('a', 510, 570);
      final b = _meal('b', 525, 555);
      final c = _meal('c', 530, 560);
      final ids = {
        _acceptRoutine(a, b).acceptanceId,
        _acceptRoutine(a, c).acceptanceId,
        _acceptRoutine(b, c, conflictType: 'informationalOverlap').acceptanceId,
      };
      expect(ids, hasLength(3));
    });
  });

  group('AH-F015 serialization and durable authority', () {
    test(
      'Firestore codec roundtrip preserves every acceptance identity field',
      () {
        final fixture = _routineFixture();
        final original = _acceptRoutine(fixture.$1, fixture.$2);
        final restored = ConflictAcceptance.fromMap(original.toFirestoreMap());

        expect(restored.toMap(), original.toMap());
        expect(_isAccepted(fixture.$1, fixture.$2, [restored]), isTrue);
      },
    );

    test(
      'duplicate and unknown-outcome retries are one logical durable write',
      () async {
        final database = FakeRoutineDatabase();
        final repository = FakeConflictAcceptanceRepository(database);
        final fixture = _routineFixture();
        final acceptance = _acceptRoutine(fixture.$1, fixture.$2);

        await repository.upsert(_uidA, acceptance);
        // The first response may be lost after the durable mutation. Retrying the
        // deterministic document ID must converge to the same logical record.
        await repository.upsert(_uidA, _acceptRoutine(fixture.$2, fixture.$1));

        expect(await repository.fetchForOwner(_uidA), hasLength(1));
        expect(
          (await repository.fetchForOwner(_uidA)).single.acceptanceId,
          acceptance.acceptanceId,
        );
      },
    );

    test('failed save has no durable authority after restart', () async {
      final database = FakeRoutineDatabase();
      final failing = _FailingAcceptanceRepository(database);
      final fixture = _routineFixture();

      await expectLater(
        failing.upsert(_uidA, _acceptRoutine(fixture.$1, fixture.$2)),
        throwsStateError,
      );

      final restarted = FakeConflictAcceptanceRepository(database);
      expect(await restarted.fetchForOwner(_uidA), isEmpty);
      expect(_isAccepted(fixture.$1, fixture.$2, const []), isFalse);
    });

    test(
      'process kill and zero-cache reconstruction use only server data',
      () async {
        final database = FakeRoutineDatabase();
        final fixture = _routineFixture();
        final durable = FakeConflictAcceptanceRepository(database);
        final routines = FakeRoutineRepository(database: database);
        await routines.createRoutineItem(_uidA, fixture.$1);
        await routines.createRoutineItem(_uidA, fixture.$2);
        await durable.upsert(_uidA, _acceptRoutine(fixture.$1, fixture.$2));

        // Replace the stored object with a codec reconstruction, then create a
        // completely fresh ProviderContainer. No old model/provider survives.
        final encoded = database.acceptancesByUid[_uidA]!.values.single
            .toFirestoreMap();
        database.acceptancesByUid[_uidA] = {
          encoded['acceptanceId'] as String: ConflictAcceptance.fromMap(
            encoded,
          ),
        };
        final container = _freshContainer(database);
        addTearDown(container.dispose);
        container
            .read(regionSettingsProvider.notifier)
            .loadSettings(RegionSettings.india(userId: _uidA));
        await container
            .read(routineNotifierProvider.notifier)
            .loadForOwner(_uidA);
        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(_monday);

        final state = container.read(routineNotifierProvider);
        expect(state.conflictAcceptances, hasLength(1));
        expect(
          state.conflicts.where(
            (conflict) =>
                conflict.type == RoutineConflictType.compatibleOverlap,
          ),
          hasLength(1),
        );
        expect(
          state.conflicts
              .firstWhere(
                (conflict) =>
                    conflict.type == RoutineConflictType.compatibleOverlap,
              )
              .resolution,
          RoutineConflictResolution.allowedByUser,
        );
      },
    );

    test(
      'logout/login, account switch, and switch-back preserve isolation',
      () async {
        final database = FakeRoutineDatabase();
        final fixtureA = _routineFixture();
        final fixtureB = (
          fixtureA.$1.copyWith(userId: _uidB),
          fixtureA.$2.copyWith(userId: _uidB),
        );
        final routines = FakeRoutineRepository(database: database);
        for (final item in [fixtureA.$1, fixtureA.$2]) {
          await routines.createRoutineItem(_uidA, item);
        }
        for (final item in [fixtureB.$1, fixtureB.$2]) {
          await routines.createRoutineItem(_uidB, item);
        }
        await FakeConflictAcceptanceRepository(
          database,
        ).upsert(_uidA, _acceptRoutine(fixtureA.$1, fixtureA.$2));

        final container = _freshContainer(database);
        addTearDown(container.dispose);
        final notifier = container.read(routineNotifierProvider.notifier);
        container
            .read(regionSettingsProvider.notifier)
            .loadSettings(RegionSettings.india(userId: _uidA));
        await notifier.loadForOwner(_uidA);
        expect(
          container.read(routineNotifierProvider).conflictAcceptances,
          hasLength(1),
        );

        notifier.resetForSignedOut();
        expect(
          container.read(routineNotifierProvider).conflictAcceptances,
          isEmpty,
        );
        await notifier.loadForOwner(_uidB);
        expect(
          container.read(routineNotifierProvider).conflictAcceptances,
          isEmpty,
        );

        notifier.resetForSignedOut();
        await notifier.loadForOwner(_uidA);
        expect(
          container.read(routineNotifierProvider).conflictAcceptances,
          hasLength(1),
        );
      },
    );

    test('same-UID refresh preserves acceptance without reset churn', () async {
      final database = FakeRoutineDatabase();
      final fixture = _routineFixture();
      final routines = FakeRoutineRepository(database: database);
      await routines.createRoutineItem(_uidA, fixture.$1);
      await routines.createRoutineItem(_uidA, fixture.$2);
      await FakeConflictAcceptanceRepository(
        database,
      ).upsert(_uidA, _acceptRoutine(fixture.$1, fixture.$2));
      final container = _freshContainer(database);
      addTearDown(container.dispose);
      container
          .read(regionSettingsProvider.notifier)
          .loadSettings(RegionSettings.india(userId: _uidA));
      final notifier = container.read(routineNotifierProvider.notifier);
      await notifier.loadForOwner(_uidA);
      final id = container
          .read(routineNotifierProvider)
          .conflictAcceptances
          .single
          .acceptanceId;

      await notifier.loadForOwner(_uidA);
      expect(
        container
            .read(routineNotifierProvider)
            .conflictAcceptances
            .single
            .acceptanceId,
        id,
      );
    });

    test(
      'stale async A write completion cannot populate B client state',
      () async {
        final database = FakeRoutineDatabase();
        final fixture = _routineFixture();
        final routines = FakeRoutineRepository(database: database);
        final history = FakeRoutineHistoryRepository();
        final transactions = FakeRoutineTransactionRepository(
          routineRepository: routines,
          historyRepository: history,
        );
        await routines.createRoutineItem(_uidA, fixture.$1);
        await routines.createRoutineItem(_uidA, fixture.$2);
        final container = ProviderContainer(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.firebase,
            ),
            routineRepositoryProvider.overrideWithValue(routines),
            routineHistoryRepositoryProvider.overrideWithValue(history),
            conflictAcceptanceRepositoryProvider.overrideWithValue(
              FakeConflictAcceptanceRepository(database),
            ),
            routineTransactionRepositoryProvider.overrideWithValue(
              transactions,
            ),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(regionSettingsProvider.notifier)
            .loadSettings(RegionSettings.india(userId: _uidA));
        final notifier = container.read(routineNotifierProvider.notifier);
        await notifier.loadForOwner(_uidA);
        notifier.updateSelectedDay(_monday);
        final conflict = container
            .read(routineNotifierProvider)
            .conflicts
            .firstWhere((candidate) => candidate.canKeepBoth);
        final mutationStarted = Completer<void>();
        final allowCommit = Completer<void>();
        transactions.onBeforeMutation = () async {
          mutationStarted.complete();
          await allowCommit.future;
        };

        final pendingAWrite = notifier.keepConflictPair(conflict);
        await mutationStarted.future;
        await notifier.loadForOwner(_uidB);
        allowCommit.complete();
        await pendingAWrite;

        expect(container.read(routineNotifierProvider).items, isEmpty);
        expect(
          container.read(routineNotifierProvider).conflictAcceptances,
          isEmpty,
        );
        expect(database.acceptancesByUid[_uidA], hasLength(1));
        expect(database.acceptancesByUid[_uidB], isNull);
      },
    );
  });

  group('AH-F015 exact invalidation', () {
    test(
      'time edits to either schedule and both schedules reject stale F1',
      () {
        final fixture = _routineFixture();
        final acceptance = _acceptRoutine(fixture.$1, fixture.$2);

        expect(
          _isAccepted(fixture.$1.copyWith(startMinute: 570), fixture.$2, [
            acceptance,
          ]),
          isFalse,
        );
        expect(
          _isAccepted(fixture.$1, fixture.$2.copyWith(endMinute: 615), [
            acceptance,
          ]),
          isFalse,
        );
        expect(
          _isAccepted(
            fixture.$1.copyWith(startMinute: 500),
            fixture.$2.copyWith(endMinute: 620),
            [acceptance],
          ),
          isFalse,
        );
      },
    );

    test('recurrence and timezone edits reject stale F1', () {
      final fixture = _routineFixture();
      final acceptance = _acceptRoutine(fixture.$1, fixture.$2);

      expect(
        _isAccepted(fixture.$1.copyWith(repeatDays: const [2, 4]), fixture.$2, [
          acceptance,
        ]),
        isFalse,
      );
      expect(
        _isAccepted(fixture.$1, fixture.$2, [acceptance], timezoneId: 'UTC'),
        isFalse,
      );
    });

    test(
      'conflict disappearance does not make history authorize another pair',
      () {
        final fixture = _routineFixture();
        final acceptance = _acceptRoutine(fixture.$1, fixture.$2);
        final moved = fixture.$1.copyWith(startMinute: 600, endMinute: 630);

        expect(
          RoutineConflictEngine.detect(
            [moved, fixture.$2],
            _monday,
            conflictAcceptances: [acceptance],
            timezoneId: _timezone,
          ),
          isEmpty,
        );
        expect(
          _isAccepted(_meal('new-meal', 525, 550), fixture.$2, [acceptance]),
          isFalse,
        );
      },
    );

    test('targeted multi-conflict edit preserves A-C and D-E', () {
      final a = _fixed('a', 510, 570);
      final b = _meal('b', 525, 555);
      final c = _meal('c', 530, 560);
      final d = _fixed('d', 700, 760);
      final e = _meal('e', 715, 745);
      final ab = _acceptRoutine(a, b);
      final ac = _acceptRoutine(a, c);
      final de = _acceptRoutine(d, e);
      final editedB = b.copyWith(startMinute: 535);

      expect(_isAccepted(a, editedB, [ab, ac, de]), isFalse);
      expect(_isAccepted(a, c, [ab, ac, de]), isTrue);
      expect(_isAccepted(d, e, [ab, ac, de]), isTrue);
    });

    test('change-back follows historical-fingerprint contract', () {
      final fixture = _routineFixture();
      final acceptance = _acceptRoutine(fixture.$1, fixture.$2);
      final changed = fixture.$1.copyWith(startMinute: 500);

      expect(_isAccepted(changed, fixture.$2, [acceptance]), isFalse);
      expect(_isAccepted(fixture.$1, fixture.$2, [acceptance]), isTrue);
    });

    test('source edit invalidates only acceptances involving that block', () {
      final source = _sourceMultiConflictFixture();
      final edited = source.$1.upsertBlock(
        source.$2.copyWith(startMinute: 535),
      );
      final byPair = {
        for (final acceptance in edited.conflictAcceptances)
          acceptance.sourceBlockIds.join('|'): acceptance,
      };

      expect(
        edited.conflictAcceptances
            .where((a) => a.sourceBlockIds.contains('b'))
            .single
            .isActive,
        isFalse,
      );
      expect(
        edited.conflictAcceptances
            .where((a) => a.sourceBlockIds.containsAll({'a', 'c'}))
            .single
            .isActive,
        isTrue,
      );
      expect(
        edited.conflictAcceptances
            .where((a) => a.sourceBlockIds.containsAll({'d', 'e'}))
            .single
            .isActive,
        isTrue,
      );
      expect(byPair, hasLength(3));
    });

    test('non-schedule source rename preserves acceptance', () {
      final draft = _acceptedSourceDraft();
      final breakfast = draft.baseTimeline.blockById('breakfast')!;
      final renamed = draft.baseTimeline.upsertBlock(
        breakfast.copyWith(title: 'Morning Meal'),
      );

      expect(renamed.conflictAcceptances.single.isActive, isTrue);
      expect(
        renamed
            .detectConflicts(ownerUid: _uidA, timezoneId: _timezone)
            .every((conflict) => conflict.accepted),
        isTrue,
      );
    });

    test('stale acceptance cannot bypass corrupt recurrence blocker', () {
      final fixture = _routineFixture();
      final acceptance = _acceptRoutine(fixture.$1, fixture.$2);
      final corrupt = fixture.$1.copyWith(repeatDays: const []);
      final decision = ConflictPolicy.classify(
        _descriptor(corrupt),
        _descriptor(fixture.$2),
      );

      expect(decision.type, ConflictPolicyType.corruptSchedule);
      expect(decision.canKeepBoth, isFalse);
      expect(_isAccepted(corrupt, fixture.$2, [acceptance]), isFalse);
    });

    test(
      'editing A invalidates both A-B and A-C while D-E remains accepted',
      () {
        final source = _sourceMultiConflictFixture();
        final blockA = source.$1.blockById('a')!;
        final edited = source.$1.upsertBlock(
          blockA.copyWith(startMinute: 500, endMinute: 560),
        );

        expect(
          edited.conflictAcceptances
              .where((a) => a.sourceBlockIds.contains('a'))
              .every((a) => !a.isActive),
          isTrue,
        );
        expect(
          edited.conflictAcceptances
              .where((a) => a.sourceBlockIds.containsAll({'d', 'e'}))
              .single
              .isActive,
          isTrue,
        );
      },
    );

    test(
      'reinstall then edit follows standard invalidation without bypass',
      () async {
        final database = FakeRoutineDatabase();
        final fixture = _routineFixture();
        final durable = FakeConflictAcceptanceRepository(database);
        final routines = FakeRoutineRepository(database: database);
        await routines.createRoutineItem(_uidA, fixture.$1);
        await routines.createRoutineItem(_uidA, fixture.$2);
        await durable.upsert(_uidA, _acceptRoutine(fixture.$1, fixture.$2));

        // 1. Zero-cache reinstall
        final container = _freshContainer(database);
        addTearDown(container.dispose);
        container
            .read(regionSettingsProvider.notifier)
            .loadSettings(RegionSettings.india(userId: _uidA));
        await container
            .read(routineNotifierProvider.notifier)
            .loadForOwner(_uidA);
        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(_monday);

        var state = container.read(routineNotifierProvider);
        expect(
          state.conflicts
              .firstWhere(
                (c) => c.type == RoutineConflictType.compatibleOverlap,
              )
              .resolution,
          RoutineConflictResolution.allowedByUser,
        );

        // 2. Edit schedule B after reinstall
        final editedItem2 = fixture.$2.copyWith(startMinute: 535);
        await routines.updateRoutineItem(_uidA, editedItem2);
        await container
            .read(routineNotifierProvider.notifier)
            .loadForOwner(_uidA);
        container
            .read(routineNotifierProvider.notifier)
            .updateSelectedDay(_monday);

        state = container.read(routineNotifierProvider);
        expect(
          state.conflicts
              .firstWhere(
                (c) => c.type == RoutineConflictType.compatibleOverlap,
              )
              .resolution,
          RoutineConflictResolution.unresolved,
        );
      },
    );
  });

  group('AH-F015 completion and reconstruction integration', () {
    test(
      'completionBundle and expectedAcceptanceIds roundtrip deterministically',
      () {
        final draft = _acceptedSourceDraft().copyWith(
          onboardingCompleted: true,
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        final restored = OnboardingCompletionBundle.fromMap(
          bundle.toFirestoreMap(),
        );
        final before = RoutineOnboardingProjection.build(
          bundle,
          now: _acceptedAt,
        );
        final after = RoutineOnboardingProjection.build(
          restored,
          now: _acceptedAt,
        );

        expect(bundle.conflictAcceptances, isEmpty);
        expect(bundle.expectedAcceptanceIds, isEmpty);
        expect(restored.expectedAcceptanceIds, bundle.expectedAcceptanceIds);
        expect(after.fingerprint, before.fingerprint);
        expect(after.conflictAcceptances, isEmpty);
      },
    );

    test(
      'Step 14 projection restart recognizes durable acceptance idempotently',
      () async {
        final draft = _acceptedSourceDraft().copyWith(
          onboardingCompleted: true,
        );
        final bundle = OnboardingCompletionService.buildBundle(draft);
        final database = FakeRoutineDatabase();
        final repository = FakeOnboardingRepository(routineDatabase: database);

        await repository.completeOnboarding(finalDraft: draft, bundle: bundle);
        final firstItems = Map<String, RoutineItem>.from(
          database.itemsByUid[_uidA]!,
        );
        final firstAcceptances = Map<String, ConflictAcceptance>.from(
          database.acceptancesByUid[_uidA]!,
        );
        await repository.completeOnboarding(
          finalDraft: OnboardingDraft.fromMap(draft.toFirestoreMap()),
          bundle: OnboardingCompletionBundle.fromMap(bundle.toFirestoreMap()),
        );

        expect(database.itemsByUid[_uidA]!.keys, firstItems.keys);
        expect(database.acceptancesByUid[_uidA]!.keys, firstAcceptances.keys);
        final restoredItems = database.itemsByUid[_uidA]!.values.toList();
        final restoredAcceptances = database.acceptancesByUid[_uidA]!.values
            .toList();
        expect(restoredAcceptances, isEmpty);
        final conflict = RoutineConflictEngine.detect(
          restoredItems,
          _monday,
          conflictAcceptances: restoredAcceptances,
          timezoneId: _timezone,
        ).single;
        expect(conflict.resolution, RoutineConflictResolution.unresolved);
        expect(conflict.acceptanceId, isNull);
      },
    );

    test(
      'time normalization minute roundtrip creates identical fingerprint',
      () {
        final item = _meal('breakfast', 510, 540); // 08:30 to 09:00 (510 min)
        final descriptorBefore = _descriptor(item);
        final jsonMap = item.toMap();
        final itemAfter = RoutineItem.fromMap(jsonMap);
        final descriptorAfter = _descriptor(itemAfter);

        expect(
          descriptorAfter.scheduleFingerprint,
          descriptorBefore.scheduleFingerprint,
        );
      },
    );

    test(
      'expectedAcceptanceIds with F1 cannot satisfy newly edited F2 schedule',
      () {
        final draft = _acceptedSourceDraft();
        final bundle = OnboardingCompletionService.buildBundle(draft);
        expect(bundle.expectedAcceptanceIds, isEmpty);

        // Edit schedule A time in draft -> newly generated bundle has different acceptanceId F2
        final breakfast = draft.baseTimeline.blockById('breakfast')!;
        final editedDraft = draft.copyWith(
          baseTimeline: draft.baseTimeline.upsertBlock(
            breakfast.copyWith(startMinute: 500, endMinute: 530),
          ),
        );
        final editedBundle = OnboardingCompletionService.buildBundle(
          editedDraft,
        );
        expect(editedBundle.expectedAcceptanceIds, isEmpty);
      },
    );

    test('backend read failure returns no fake or mock acceptances', () async {
      final database = FakeRoutineDatabase();
      final repo = FakeConflictAcceptanceRepository(database);

      final results = await repo.fetchForOwner(_uidA);
      expect(results, isEmpty);
    });
  });
}

(RoutineItem, RoutineItem) _routineFixture() =>
    (_meal('breakfast', 510, 540), _fixed('class', 525, 585));

RoutineItem _meal(String id, int start, int end) => RoutineItem(
  id: id,
  userId: _uidA,
  title: id == 'breakfast' ? 'Breakfast' : id.toUpperCase(),
  category: RoutineCategory.eating,
  blockType: RoutineBlockType.flexibleTask,
  startMinute: start,
  endMinute: end,
  repeatRule: 'weekly',
  repeatDays: const [1, 3, 5],
);

RoutineItem _fixed(String id, int start, int end) => RoutineItem(
  id: id,
  userId: _uidA,
  title: id == 'class' ? 'Class' : id.toUpperCase(),
  category: RoutineCategory.fixed,
  blockType: RoutineBlockType.hardBlock,
  hardBlock: true,
  startMinute: start,
  endMinute: end,
  repeatRule: 'weekly',
  repeatDays: const [1, 3, 5],
);

ConflictScheduleDescriptor _descriptor(
  RoutineItem item, {
  String timezoneId = _timezone,
}) => RoutineConflictEngine.scheduleDescriptor(
  item,
  timezoneId: timezoneId,
  fallbackOwnerUid: item.userId ?? _uidA,
);

ConflictAcceptance _acceptRoutine(
  RoutineItem first,
  RoutineItem second, {
  String ownerUid = _uidA,
  String timezoneId = _timezone,
  String conflictType = 'compatibleOverlap',
}) => ConflictAcceptance.create(
  ownerUid: ownerUid,
  first: _descriptor(first, timezoneId: timezoneId),
  second: _descriptor(second, timezoneId: timezoneId),
  conflictType: conflictType,
  scope: ConflictAcceptanceScope.recurringWeekdays,
  applicableWeekdays: const [5, 1, 3],
  timezoneId: timezoneId,
  acceptedFrom: ConflictAcceptanceOrigin.routineResolver,
  firstProjectedRoutineId: first.id,
  secondProjectedRoutineId: second.id,
  acceptedAt: _acceptedAt,
);

bool _isAccepted(
  RoutineItem first,
  RoutineItem second,
  List<ConflictAcceptance> acceptances, {
  String timezoneId = _timezone,
}) {
  final conflicts = RoutineConflictEngine.detect(
    [first, second],
    _monday,
    conflictAcceptances: acceptances,
    timezoneId: timezoneId,
  );
  return conflicts.any(
    (conflict) =>
        conflict.type == RoutineConflictType.compatibleOverlap &&
        conflict.resolution == RoutineConflictResolution.allowedByUser,
  );
}

OnboardingDraft _acceptedSourceDraft() {
  final draft = OnboardingDraft(
    uid: _uidA,
    timezoneId: _timezone,
    baseTimeline: BaseTimelineDraft(
      skinCareSkipped: true,
      blocks: const [
        TimelineBlockDraft(
          id: 'breakfast',
          section: 'eating',
          title: 'Breakfast',
          startMinute: 510,
          endMinute: 540,
          repeatDays: [1, 3, 5],
          blockType: TimelineBlockDraft.flexibleTaskKey,
        ),
        TimelineBlockDraft(
          id: 'class',
          section: 'fixed',
          title: 'Class',
          startMinute: 525,
          endMinute: 585,
          repeatDays: [1, 3, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
  );
  final conflict = draft.timelineConflictsRequiringAcceptance().first;
  return draft.acceptTimelineConflictGroup(
    conflict: conflict,
    weekdays: const [5, 1, 3],
    timezoneId: _timezone,
    acceptedAt: _acceptedAt,
  );
}

(BaseTimelineDraft, TimelineBlockDraft) _sourceMultiConflictFixture() {
  const blocks = [
    TimelineBlockDraft(
      id: 'a',
      section: 'fixed',
      title: 'A',
      startMinute: 510,
      endMinute: 570,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
    ),
    TimelineBlockDraft(
      id: 'b',
      section: 'eating',
      title: 'B',
      startMinute: 525,
      endMinute: 555,
      repeatDays: [1],
      blockType: TimelineBlockDraft.flexibleTaskKey,
    ),
    TimelineBlockDraft(
      id: 'c',
      section: 'eating',
      title: 'C',
      startMinute: 530,
      endMinute: 560,
      repeatDays: [1],
      blockType: TimelineBlockDraft.flexibleTaskKey,
    ),
    TimelineBlockDraft(
      id: 'd',
      section: 'fixed',
      title: 'D',
      startMinute: 700,
      endMinute: 760,
      repeatDays: [1],
      blockType: TimelineBlockDraft.hardBlockKey,
    ),
    TimelineBlockDraft(
      id: 'e',
      section: 'eating',
      title: 'E',
      startMinute: 715,
      endMinute: 745,
      repeatDays: [1],
      blockType: TimelineBlockDraft.flexibleTaskKey,
    ),
  ];
  ConflictAcceptance acceptance(String firstId, String secondId) {
    final first = blocks.firstWhere((block) => block.id == firstId);
    final second = blocks.firstWhere((block) => block.id == secondId);
    return ConflictAcceptance.create(
      ownerUid: _uidA,
      first: timelineScheduleDescriptor(
        first,
        ownerUid: _uidA,
        timezoneId: _timezone,
      ),
      second: timelineScheduleDescriptor(
        second,
        ownerUid: _uidA,
        timezoneId: _timezone,
      ),
      conflictType: 'compatibleOverlap',
      scope: ConflictAcceptanceScope.recurringWeekdays,
      applicableWeekdays: const [1],
      timezoneId: _timezone,
      acceptedFrom: ConflictAcceptanceOrigin.onboarding,
      acceptedAt: _acceptedAt,
    );
  }

  return (
    BaseTimelineDraft(
      blocks: blocks,
      conflictAcceptances: [
        acceptance('a', 'b'),
        acceptance('a', 'c'),
        acceptance('d', 'e'),
      ],
    ),
    blocks[1],
  );
}

ProviderContainer _freshContainer(FakeRoutineDatabase database) {
  final routines = FakeRoutineRepository(database: database);
  final history = FakeRoutineHistoryRepository();
  return ProviderContainer(
    overrides: [
      optivusBackendModeProvider.overrideWithValue(OptivusBackendMode.firebase),
      routineRepositoryProvider.overrideWithValue(routines),
      routineHistoryRepositoryProvider.overrideWithValue(history),
      conflictAcceptanceRepositoryProvider.overrideWithValue(
        FakeConflictAcceptanceRepository(database),
      ),
      routineTransactionRepositoryProvider.overrideWith(
        (_) => FakeRoutineTransactionRepository(
          routineRepository: routines,
          historyRepository: history,
        ),
      ),
    ],
  );
}

class _FailingAcceptanceRepository extends FakeConflictAcceptanceRepository {
  _FailingAcceptanceRepository(super.database);

  @override
  Future<void> upsert(String uid, ConflictAcceptance acceptance) async {
    throw StateError('simulated durable acceptance failure');
  }
}
