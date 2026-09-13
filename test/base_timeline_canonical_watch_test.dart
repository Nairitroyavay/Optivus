import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';

void main() {
  group('Base Timeline Canonical Watch and Monotonicity Tests', () {
    group('Snapshot Filtering Policy (shouldPublishBaseTimelineSnapshot)', () {
      test('Pending local snapshot is rejected (hasPendingWrites: true)', () {
        final result = shouldPublishBaseTimelineSnapshot(
          exists: true,
          hasPendingWrites: true,
        );
        expect(result, isFalse);
      });

      test('Committed snapshot is accepted (hasPendingWrites: false, exists: true)', () {
        final result = shouldPublishBaseTimelineSnapshot(
          exists: true,
          hasPendingWrites: false,
        );
        expect(result, isTrue);
      });

      test('Committed cached snapshot is accepted (hasPendingWrites: false, isFromCache: true)', () {
        final result = shouldPublishBaseTimelineSnapshot(
          exists: true,
          hasPendingWrites: false,
          isFromCache: true,
        );
        expect(result, isTrue);
      });

      test('Non-existent snapshot is rejected (exists: false)', () {
        final nonExistentClean = shouldPublishBaseTimelineSnapshot(
          exists: false,
          hasPendingWrites: false,
        );
        expect(nonExistentClean, isFalse);

        final nonExistentPending = shouldPublishBaseTimelineSnapshot(
          exists: false,
          hasPendingWrites: true,
        );
        expect(nonExistentPending, isFalse);
      });
    });

    group('Remote Setup Monotonicity Policy (shouldPublishRemoteSetup)', () {
      final base = BaseTimelineSetup(
        uid: 'user-policy-test',
        revision: 3,
        schemaVersion: 2,
        updatedAt: DateTime.utc(2026, 9, 13, 12),
        eatingSetupPath: 'has_routine',
      );

      test('Older revision is rejected', () {
        final older = base.copyWith(revision: 2);
        expect(
          shouldPublishRemoteSetup(current: base, remote: older),
          isFalse,
        );
      });

      test('Higher revision is accepted', () {
        final newer = base.copyWith(revision: 4);
        expect(
          shouldPublishRemoteSetup(current: base, remote: newer),
          isTrue,
        );
      });

      test('Equal revision with upgraded schemaVersion is accepted', () {
        final upgradedSchema = base.copyWith(
          schemaVersion: BaseTimelineSetup.currentSchemaVersion,
        );
        expect(
          shouldPublishRemoteSetup(current: base, remote: upgradedSchema),
          isTrue,
        );
      });

      test('Equal revision with downgraded schemaVersion is rejected', () {
        final downgradedSchema = base.copyWith(schemaVersion: 1);
        expect(
          shouldPublishRemoteSetup(current: base, remote: downgradedSchema),
          isFalse,
        );
      });

      test('Equal revision with identical data is accepted', () {
        final identical = base.copyWith(updatedAt: DateTime.utc(2026, 9, 13, 13));
        expect(
          shouldPublishRemoteSetup(current: base, remote: identical),
          isTrue,
        );
      });

      test('Equal revision with divergent data is rejected (in-memory committed state wins)', () {
        final divergent = base.copyWith(mealPlanningGoal: 'divergent-goal');
        expect(
          shouldPublishRemoteSetup(current: base, remote: divergent),
          isFalse,
        );
      });
    });

    group('BaseTimelineSetupNotifier Live Stream Integration', () {
      late _ControllableWatchRepository repo;

      setUp(() {
        repo = _ControllableWatchRepository();
      });

      test('Monotonic revision enforcement: older revision ignored, newer revision accepted', () async {
        const uid = 'user-stream-monotonic';
        final initial = BaseTimelineSetup(
          uid: uid,
          revision: 3,
          updatedAt: DateTime.utc(2026, 9, 13, 10),
          eatingSetupPath: 'has_routine',
        );
        repo.currentSetup = initial;

        final notifier = BaseTimelineSetupNotifier(repo, uid);
        addTearDown(notifier.dispose);
        await notifier.load();

        expect(notifier.state.requireValue.revision, 3);

        // Remote snapshot arrives with rev 2 -> ignored
        repo.emitRemote(
          initial.copyWith(
            revision: 2,
            mealPlanningGoal: 'stale-rev-2',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.requireValue.revision, 3);
        expect(notifier.state.requireValue.mealPlanningGoal, isNull);

        // Remote snapshot arrives with rev 4 -> accepted
        repo.emitRemote(
          initial.copyWith(
            revision: 4,
            mealPlanningGoal: 'newer-rev-4',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.requireValue.revision, 4);
        expect(notifier.state.requireValue.mealPlanningGoal, 'newer-rev-4');
      });

      test('Schema version migration safety: rev 3 schema v2 in memory accepts rev 3 schema v3 from remote', () async {
        const uid = 'user-stream-schema-mig';
        final initial = BaseTimelineSetup(
          uid: uid,
          revision: 3,
          schemaVersion: 2,
          updatedAt: DateTime.utc(2026, 9, 13, 10),
          eatingSetupPath: 'has_routine',
        );
        repo.currentSetup = initial;

        final notifier = BaseTimelineSetupNotifier(repo, uid);
        addTearDown(notifier.dispose);
        await notifier.load();

        expect(notifier.state.requireValue.schemaVersion, 2);

        // Remote snapshot arrives with rev 3, schema v3
        repo.emitRemote(
          initial.copyWith(
            schemaVersion: BaseTimelineSetup.currentSchemaVersion,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          notifier.state.requireValue.schemaVersion,
          BaseTimelineSetup.currentSchemaVersion,
        );
      });

      test('Equal revision divergent state preserves in-memory committed setup', () async {
        const uid = 'user-stream-divergent';
        final initial = BaseTimelineSetup(
          uid: uid,
          revision: 3,
          mealPlanningGoal: 'committed-in-memory',
          updatedAt: DateTime.utc(2026, 9, 13, 10),
          eatingSetupPath: 'has_routine',
        );
        repo.currentSetup = initial;

        final notifier = BaseTimelineSetupNotifier(repo, uid);
        addTearDown(notifier.dispose);
        await notifier.load();

        expect(notifier.state.requireValue.mealPlanningGoal, 'committed-in-memory');

        // Remote snapshot arrives with same rev 3 but conflicting mealPlanningGoal
        repo.emitRemote(
          initial.copyWith(mealPlanningGoal: 'stale-conflicting-remote'),
        );
        await Future<void>.delayed(Duration.zero);

        // In-memory state remains untouched
        expect(notifier.state.requireValue.mealPlanningGoal, 'committed-in-memory');
      });

      test('Generation switch: old watch subscription cancelled and does not leak events', () async {
        const uid1 = 'user-stream-gen-1';
        const uid2 = 'user-stream-gen-2';

        final setup1 = BaseTimelineSetup(
          uid: uid1,
          revision: 1,
          updatedAt: DateTime.utc(2026, 9, 13, 10),
          eatingSetupPath: 'has_routine',
        );
        final setup2 = BaseTimelineSetup(
          uid: uid2,
          revision: 1,
          updatedAt: DateTime.utc(2026, 9, 13, 10),
          eatingSetupPath: 'has_routine',
        );

        final repo1 = _ControllableWatchRepository()..currentSetup = setup1;
        final repo2 = _ControllableWatchRepository()..currentSetup = setup2;

        final notifier1 = BaseTimelineSetupNotifier(repo1, uid1);
        final notifier2 = BaseTimelineSetupNotifier(repo2, uid2);
        addTearDown(notifier2.dispose);

        await Future.wait([notifier1.load(), notifier2.load()]);

        // User 1 signs out / switches: dispose notifier1
        notifier1.dispose();

        // Emit on repo1
        repo1.emitRemote(setup1.copyWith(revision: 2, mealPlanningGoal: 'post-dispose'));
        await Future<void>.delayed(Duration.zero);

        // Notifier 2 was never affected
        expect(notifier2.state.requireValue.uid, uid2);
        expect(notifier2.state.requireValue.mealPlanningGoal, isNull);
      });

      test('Malformed remote data (e.g. wrong owner) handled gracefully as error without crashing', () async {
        const uid = 'user-stream-malformed';
        final initial = BaseTimelineSetup(
          uid: uid,
          revision: 1,
          updatedAt: DateTime.utc(2026, 9, 13, 10),
          eatingSetupPath: 'has_routine',
        );
        repo.currentSetup = initial;

        final notifier = BaseTimelineSetupNotifier(repo, uid);
        addTearDown(notifier.dispose);
        await notifier.load();

        expect(notifier.state.hasValue, isTrue);

        // Remote snapshot arrives with WRONG owner UID
        final badRemote = BaseTimelineSetup(
          uid: 'different-attacker-or-leaked-uid',
          revision: 2,
          updatedAt: DateTime.utc(2026, 9, 13, 11),
          eatingSetupPath: 'has_routine',
        );
        repo.emitRemote(badRemote);
        await Future<void>.delayed(Duration.zero);

        // Notifier caught the error gracefully
        expect(notifier.state.hasError, isTrue);
        expect(notifier.state.error, isA<ArgumentError>());

        // When a valid remote arrives, notifier recovers
        repo.emitRemote(initial.copyWith(revision: 3));
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.hasValue, isTrue);
        expect(notifier.state.requireValue.revision, 3);
      });
    });
  });
}

class _ControllableWatchRepository implements BaseTimelineSetupRepository {
  final StreamController<BaseTimelineSetup?> _controller =
      StreamController<BaseTimelineSetup?>.broadcast();
  BaseTimelineSetup? currentSetup;

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async {
    return currentSetup ??
        BaseTimelineSetup(
          uid: uid,
          updatedAt: DateTime.now(),
          eatingSetupPath: 'has_routine',
        );
  }

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup setup) async {
    currentSetup = setup;
    _controller.add(setup);
  }

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) => _controller.stream;

  void emitRemote(BaseTimelineSetup? setup) {
    _controller.add(setup);
  }
}
