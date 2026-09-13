import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/state/app_state.dart';

class _HookableRoutineTransactionRepository
    extends FakeRoutineTransactionRepository {
  int replaceCallCount = 0;
  void Function()? onAfterCommit;

  _HookableRoutineTransactionRepository({
    super.routineRepository,
    super.setupRepository,
  });

  @override
  Future<BaseTimelineSectionCommitResult> replaceBaseTimelineSection({
    required String uid,
    required BaseTimelineSection section,
    required int expectedRevision,
    required List<RoutineItem> newRoutineItems,
    List<String> additionalDeleteIds = const [],
    required BaseTimelineSetup Function(BaseTimelineSetup liveSetup)
    buildUpdatedSetup,
  }) async {
    replaceCallCount++;
    final result = await super.replaceBaseTimelineSection(
      uid: uid,
      section: section,
      expectedRevision: expectedRevision,
      newRoutineItems: newRoutineItems,
      additionalDeleteIds: additionalDeleteIds,
      buildUpdatedSetup: buildUpdatedSetup,
    );
    onAfterCommit?.call();
    return result;
  }
}

class _ControllableRoutineRepository extends FakeRoutineRepository {
  int fetchCallCount = 0;
  Completer<void>? f1Gate;
  List<RoutineItem>? f1OverrideItems;

  _ControllableRoutineRepository();

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    fetchCallCount++;
    if (fetchCallCount == 1 && f1Gate != null) {
      await f1Gate!.future;
      if (f1OverrideItems != null) {
        return f1OverrideItems!;
      }
    }
    return super.fetchRoutineItems(uid);
  }
}

void main() {
  group('Base Timeline R3 Post-Commit Reconciliation Safety Tests', () {
    const userA = 'user-account-a';
    const userB = 'user-account-b';

    const testBlockA = TimelineBlockDraft(
      id: 'work-block-a',
      section: 'work',
      title: 'Deep Work A',
      startMinute: 540,
      endMinute: 660,
      repeatDays: [1, 2, 3, 4, 5],
      blockType: TimelineBlockDraft.hardBlockKey,
    );

    const testBlockB = TimelineBlockDraft(
      id: 'work-block-b',
      section: 'work',
      title: 'Strategy Session B',
      startMinute: 600,
      endMinute: 720,
      repeatDays: [1, 3, 5],
      blockType: TimelineBlockDraft.hardBlockKey,
    );

    test(
      'Req 19: Account switch immediately after commit does NOT convert durable success to failure',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeRoutineRepo = FakeRoutineRepository();
        final hookTxRepo = _HookableRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        // Initial state: User A has revision 1 setup
        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );
        await fakeSetupRepo.saveSetup(
          userB,
          BaseTimelineSetup(
            uid: userB,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        late ProviderContainer container;
        container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(hookTxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Warm up User A's setup notifier
        await container.read(baseTimelineSetupNotifierProvider.notifier).load();

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // Configure race hook: as soon as transaction commits for A, switch active profile to B
        hookTxRepo.onAfterCommit = () {
          container
              .read(userProfileProvider.notifier)
              .loadSeedData(
                UserProfile(
                  uid: userB,
                  email: 'b@optivus.app',
                  displayName: 'User B',
                ),
              );
        };

        // Execute replaceSection for User A
        final result = await coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        // 1. Transaction succeeded durably
        expect(result.revision, 2);
        expect(hookTxRepo.replaceCallCount, 1);

        // 2. Post-commit reconciliation was not attempted due to account change
        expect(
          result.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          result.routineRefreshMessage,
          contains(
            'Saved for the previous account; local refresh was skipped because the active account changed.',
          ),
        );

        // 3. User A's durable repository state has the committed setup and routine items
        final setupA = await fakeSetupRepo.fetchSetup(userA);
        expect(setupA.revision, 2);
        expect(setupA.workBlocks.length, 1);
        expect(setupA.workBlocks.first.id, 'work-block-a');

        final itemsA = await fakeRoutineRepo.fetchRoutineItems(userA);
        expect(itemsA.length, 1);
        expect(itemsA.first.title, 'Deep Work A');

        // 4. User B's state was NOT corrupted with User A's data
        final setupNotifierB = container.read(
          baseTimelineSetupNotifierProvider.notifier,
        );
        expect(setupNotifierB.uid, userB);
        final currentBSetup =
            container.read(baseTimelineSetupNotifierProvider).valueOrNull;
        expect(currentBSetup?.workBlocks.isEmpty ?? true, isTrue);

        final routineItemsB = container.read(routineNotifierProvider).items;
        expect(
          routineItemsB.any((item) => item.userId == userA),
          isFalse,
          reason: "User A's items must never leak into User B's session",
        );

        // 5. Switching back to User A allows clean reconstruction of committed data
        container
            .read(userProfileProvider.notifier)
            .loadSeedData(
              UserProfile(
                uid: userA,
                email: 'a@optivus.app',
                displayName: 'User A',
              ),
            );
        await container.read(routineNotifierProvider.notifier).loadForOwner(
          userA,
        );
        final reconstructedItems =
            container.read(routineNotifierProvider).items;
        expect(reconstructedItems.length, 1);
        expect(reconstructedItems.first.title, 'Deep Work A');
        expect(reconstructedItems.first.userId, userA);
      },
    );

    test(
      'Req 20: Retry owner guard with stale Routine owner rejects and does NOT leak data',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Load Routine for User A
        final routineNotifier = container.read(
          routineNotifierProvider.notifier,
        );
        await routineNotifier.loadForOwner(userA);
        expect(routineNotifier.ownerUid, userA);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // Active profile switches to User B, but routineNotifier.ownerUid is still userA
        container
            .read(userProfileProvider.notifier)
            .loadSeedData(
              UserProfile(
                uid: userB,
                email: 'b@optivus.app',
                displayName: 'User B',
              ),
            );

        // Calling retryRoutineRefresh for User A must be rejected
        final staleRetryResult = await coordinator.retryRoutineRefresh(
          uid: userA,
        );
        expect(
          staleRetryResult.status,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          staleRetryResult.message,
          contains('Active session does not match requested owner.'),
        );

        // Calling retryRoutineRefresh for User B must ALSO be rejected because RoutineNotifier is still bound to userA
        final contradictoryRetryResult = await coordinator.retryRoutineRefresh(
          uid: userB,
        );
        expect(
          contradictoryRetryResult.status,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          contradictoryRetryResult.message,
          contains('Active session does not match requested owner.'),
        );

        // Verify no data from A was loaded into B
        expect(container.read(routineNotifierProvider).items.isEmpty, isTrue);
      },
    );

    test(
      'Req 21: Pre-commit in-flight Routine load ensures a subsequent fresh fetch begins after commit',
      () async {
        final controllableRoutineRepo = _ControllableRoutineRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: controllableRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(
              controllableRoutineRepo,
            ),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final routineNotifier = container.read(
          routineNotifierProvider.notifier,
        );
        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // 1. Start pre-commit in-flight Routine load F1, blocked on f1Gate
        final f1Gate = Completer<void>();
        controllableRoutineRepo.f1Gate = f1Gate;
        controllableRoutineRepo.f1OverrideItems = const []; // F1 sees empty/old

        final inFlightF1 = routineNotifier.loadForOwner(userA);

        // 2. Base Timeline section commits revision 2
        // Coordinator begins post-commit reconciliation while F1 is in flight
        final replaceFuture = coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        // Give coordinator a turn to await F1
        await Future<void>.delayed(Duration.zero);

        // 3. Release F1 with OLD data
        f1Gate.complete();
        await inFlightF1;

        // 4. Coordinator replaceSection must NOT accept F1! It must perform F2.
        final result = await replaceFuture;
        expect(
          result.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.refreshed,
        );

        // Verify fetch count proves at least 2 fetches occurred (F1 pre-commit + F2 post-commit)
        expect(
          controllableRoutineRepo.fetchCallCount,
          greaterThanOrEqualTo(2),
          reason: 'Post-commit reconciliation must start a fresh fetch',
        );

        // Verify RoutineNotifier contains the new projection
        final items = container.read(routineNotifierProvider).items;
        expect(items.length, 1);
        expect(items.first.title, 'Deep Work A');
      },
    );

    test(
      'Req 22: Two quick commits: latest revision wins and older reconciliation cannot downgrade newer status',
      () async {
        final adversarialRepo = _AdversarialRoutineRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: adversarialRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(adversarialRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // Delay commit 1's post-commit routine fetch #3
        final delayGate = Completer<void>();
        adversarialRepo.delayFetch3 = delayGate;

        // Also delay commit 2's post-commit routine fetch #6
        final delayGate6 = Completer<void>();
        adversarialRepo.delayFetch6 = delayGate6;

        // Commit 1: commits revision 2 durably, then pauses inside post-commit routine reload
        final commit1Future = coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        // Yield turns to allow commit 1 transaction to commit and pause at fetch #3
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Commit 2: starts while commit 1 reconciliation is in-flight.
        // It reads committed revision 2, commits revision 3 durably,
        // and queues its post-commit reconciliation behind commit 1.
        final commit2Future = coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockB],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockB]),
        );

        // Yield turns so commit 2 commits durably
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Confirm revision 3 is already durable in repository!
        final interimSetup = await fakeSetupRepo.fetchSetup(userA);
        expect(interimSetup.revision, 3);

        // Release delayed post-commit fetch for commit 1
        delayGate.complete();

        // Await commit 1 explicitly
        final res1 = await commit1Future;
        expect(res1.revision, 2);

        // CRUCIAL INTERMEDIATE CHECK (Section 15):
        // Before R3 reconciliation finishes:
        // revision-2 reconciliation MUST NOT publish "refreshed"
        // as the latest state after revision 3 has committed!
        expect(
          coordinator.latestRefreshStatusFor(userA),
          isNot(BaseTimelineRoutineRefreshStatus.refreshed),
          reason: 'Revision 2 must not publish refreshed after revision 3 committed',
        );
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          coordinator.latestRefreshRevisionFor(userA),
          3,
        );

        // Release commit 2's post-commit reload fetch #6
        delayGate6.complete();

        final res2 = await commit2Future;
        expect(res2.revision, 3);
        expect(
          res2.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.refreshed,
        );

        // Final durable state must be revision 3
        final finalSetup = await fakeSetupRepo.fetchSetup(userA);
        expect(finalSetup.revision, 3);
        expect(finalSetup.workBlocks.first.id, 'work-block-b');

        // Routine frontend contains revision 3 projection
        final items = container.read(routineNotifierProvider).items;
        expect(items.length, 1);
        expect(items.first.title, 'Strategy Session B');

        // Latest refresh status belongs to revision 3
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.refreshed,
        );
        expect(
          coordinator.latestRefreshRevisionFor(userA),
          3,
        );
      },
    );

    test(
      'Req 23: Refresh failure then retry reconciles without repeating transaction',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeRoutineRepo = FakeRoutineRepository();
        final badRoutineRepo = _FailingFollowUpRoutineRepository(
          delegate: fakeRoutineRepo,
        );
        final hookTxRepo = _HookableRoutineTransactionRepository(
          routineRepository: badRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(badRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(hookTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // replaceSection succeeds with refreshPending when post-commit routine reload fails
        final replaceResult = await coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        // Durable commit succeeded, but Routine refresh is pending
        expect(replaceResult.revision, 2);
        expect(
          replaceResult.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.refreshPending,
        );
        expect(replaceResult.routineRefreshPending, isTrue);
        expect(
          replaceResult.routineRefreshMessage,
          'Saved, but Routine needs to refresh.',
        );
        expect(hookTxRepo.replaceCallCount, 1);

        // Now transient failure resolves
        badRoutineRepo.failOnFollowUp = false;

        // Retry Routine refresh
        final retryResult = await coordinator.retryRoutineRefresh(
          uid: userA,
          targetRevision: 2,
        );

        expect(
          retryResult.status,
          BaseTimelineRoutineRefreshStatus.refreshed,
        );
        expect(retryResult.isRefreshed, isTrue);
        // Transaction was NOT called again
        expect(
          hookTxRepo.replaceCallCount,
          1,
          reason: 'retryRoutineRefresh must never rerun the transaction',
        );

        final setup = await fakeSetupRepo.fetchSetup(userA);
        expect(setup.revision, 2, reason: 'Revision must remain unchanged');

        final items = container.read(routineNotifierProvider).items;
        expect(items.length, 1);
        expect(items.first.title, 'Deep Work A');
      },
    );

    test(
      'Req 24: No ref coordinator returns notAttempted without touching Riverpod',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final coordinator = BaseTimelineTransactionCoordinator(
          routineRepo: fakeRoutineRepo,
          transactionRepo: fakeTxRepo,
          setupRepo: fakeSetupRepo,
          ref: null,
        );

        final result = await coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        expect(result.revision, 2);
        expect(
          result.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );

        final retry = await coordinator.retryRoutineRefresh(uid: userA);
        expect(retry.status, BaseTimelineRoutineRefreshStatus.notAttempted);
      },
    );

    test(
      'Req 25: Reconciliation joins in-flight post-commit load, observes failure as refreshPending, and retry succeeds',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final gatedRoutineRepo = _GatedRoutineRepository();
        final hookTxRepo = _HookableRoutineTransactionRepository(
          routineRepository: gatedRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(fakeSetupRepo),
            routineRepositoryProvider.overrideWithValue(gatedRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(hookTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );
        final routineNotifier = container.read(
          routineNotifierProvider.notifier,
        );

        // Pre-load userA
        await routineNotifier.loadForOwner(userA);

        // Fetch #1: pre-test routineNotifier.loadForOwner
        // Fetch #2: coordinator pre-commit read
        // Fetch #3: transaction repo pre-commit snapshot
        // Fetch #4: coordinator post-commit reload
        final fetch4Gate = Completer<void>();
        gatedRoutineRepo.gateForFetchNumber(fetchNum: 4, gate: fetch4Gate);
        gatedRoutineRepo.failOnFetchNumber(
          fetchNum: 4,
          error: StateError('Simulated concurrent post-commit Routine failure'),
        );

        // When fetch #4 begins (post-commit reload), launch concurrent load L_concurrent.
        // It must join the already in-flight fetch #4.
        late Future<void> concurrentPostCommitLoad;
        gatedRoutineRepo.onFetchStartedForNumber(
          fetchNum: 4,
          callback: () {
            concurrentPostCommitLoad = routineNotifier.loadForOwner(userA);
          },
        );

        final replaceFuture = coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        // Yield turns so coordinator reaches fetch #4 and triggers concurrent load
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Release fetch #4 so it fails
        fetch4Gate.complete();

        // The concurrent load throws because it shared the failed in-flight fetch
        await expectLater(concurrentPostCommitLoad, throwsA(isA<StateError>()));

        // The coordinator replaceSection finishes with refreshPending (NOT refreshed!)
        final result = await replaceFuture;
        expect(result.revision, 2);
        expect(result.routineRefreshPending, isTrue);
        expect(
          result.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.refreshPending,
        );
        expect(
          result.routineRefreshMessage,
          'Saved, but Routine needs to refresh.',
        );
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.refreshPending,
        );
        expect(
          coordinator.latestRefreshRevisionFor(userA),
          2,
        );
        expect(hookTxRepo.replaceCallCount, 1);

        // Now retryRoutineRefresh succeeds without repeating transaction
        final retryResult = await coordinator.retryRoutineRefresh(
          uid: userA,
          targetRevision: 2,
        );

        expect(retryResult.isRefreshed, isTrue);
        expect(
          retryResult.status,
          BaseTimelineRoutineRefreshStatus.refreshed,
        );
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.refreshed,
        );
        expect(
          coordinator.latestRefreshRevisionFor(userA),
          2,
        );
        // Transaction call count must remain 1
        expect(hookTxRepo.replaceCallCount, 1);
        final setup = await fakeSetupRepo.fetchSetup(userA);
        expect(setup.revision, 2);
        final items = container.read(routineNotifierProvider).items;
        expect(items.length, 1);
        expect(items.first.title, 'Deep Work A');
      },
    );

    test(
      'Req 26: Account switch DURING fresh post-commit fetch skips refresh safely without leaking data into new account',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final gatedRoutineRepo = _GatedRoutineRepository();
        final hookTxRepo = _HookableRoutineTransactionRepository(
          routineRepository: gatedRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );
        await fakeSetupRepo.saveSetup(
          userB,
          BaseTimelineSetup(
            uid: userB,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(fakeSetupRepo),
            routineRepositoryProvider.overrideWithValue(gatedRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(hookTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );
        final routineNotifier = container.read(
          routineNotifierProvider.notifier,
        );

        // Pre-load userA
        await routineNotifier.loadForOwner(userA);

        // Configure gate on fetch #3 (User A post-commit routine reload)
        final postCommitFetchGate = Completer<void>();
        gatedRoutineRepo.gateForFetchNumber(fetchNum: 3, gate: postCommitFetchGate);

        // Start replaceSection for User A
        final replaceFuture = coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );

        // Yield turns so commit completes and post-commit fetch #3 starts and pauses at gate
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // While fetch #3 is blocked: switch profile to User B and start User B Routine load
        container.read(userProfileProvider.notifier).loadSeedData(
          UserProfile(
            uid: userB,
            email: 'b@optivus.app',
            displayName: 'User B',
          ),
        );
        final loadBFuture = routineNotifier.loadForOwner(userB);

        // Release User A's blocked fetch #3
        postCommitFetchGate.complete();

        final result = await replaceFuture;
        await loadBFuture;

        // 1. User A durable commit remains revision 2
        expect(result.revision, 2);
        expect(hookTxRepo.replaceCallCount, 1);
        final setupA = await fakeSetupRepo.fetchSetup(userA);
        expect(setupA.revision, 2);

        // 2. A replaceSection does NOT throw as save failure
        // 3. A reconciliation result is NOT refreshed (is notAttempted)
        expect(
          result.routineRefreshStatus,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(result.routineRefreshPending, isFalse);
        expect(
          result.routineRefreshMessage,
          contains('active account changed'),
        );

        // 4. Latest A refresh state is not falsely refreshed
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          coordinator.latestRefreshRevisionFor(userA),
          2,
        );

        // 5. User B Routine state contains NO User A data
        final itemsB = container.read(routineNotifierProvider).items;
        expect(itemsB.any((item) => item.userId == userA), isFalse);

        // 6. No second transaction occurred
        expect(hookTxRepo.replaceCallCount, 1);
      },
    );

    test(
      'Req 27: Retry revision validation strictly guards real latest committed revision',
      () async {
        final fakeSetupRepo = FakeBaseTimelineSetupRepository();
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await fakeSetupRepo.saveSetup(
          userA,
          BaseTimelineSetup(
            uid: userA,
            updatedAt: DateTime.now(),
            revision: 1,
            schemaVersion: 3,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            fakeDataAllowedProvider.overrideWithValue(false),
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: userA,
                    email: 'a@optivus.app',
                    displayName: 'User A',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(fakeSetupRepo),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          ],
        );
        addTearDown(container.dispose);

        final coordinator = container.read(
          baseTimelineTransactionCoordinatorProvider,
        );

        // 1. Unknown latest: no commit has occurred yet for userA in coordinator
        final unknownRetry = await coordinator.retryRoutineRefresh(
          uid: userA,
          targetRevision: 1,
        );
        expect(
          unknownRetry.status,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          unknownRetry.message,
          'No committed Base Timeline revision found to retry.',
        );
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );

        // 2. Commit revision 2
        final replaceRes = await coordinator.replaceSection(
          uid: userA,
          section: BaseTimelineSection.work,
          newBlocks: const [testBlockA],
          updateSetup: (s) => s.copyWith(workBlocks: const [testBlockA]),
        );
        expect(replaceRes.revision, 2);
        expect(coordinator.latestRefreshRevisionFor(userA), 2);

        // 3. target < latest (target 1, latest 2) -> superseded
        final supersededRetry = await coordinator.retryRoutineRefresh(
          uid: userA,
          targetRevision: 1,
        );
        expect(supersededRetry.message, contains('Superseded by newer revision'));
        expect(
          supersededRetry.status,
          coordinator.latestRefreshStatusFor(userA),
        );

        // 4. target > latest (target 999, latest 2) -> rejected
        final futureRetry = await coordinator.retryRoutineRefresh(
          uid: userA,
          targetRevision: 999,
        );
        expect(
          futureRetry.status,
          BaseTimelineRoutineRefreshStatus.notAttempted,
        );
        expect(
          futureRetry.message,
          'Target revision exceeds latest committed revision.',
        );
        // Bookkeeping remains unpoisoned:
        expect(coordinator.latestRefreshRevisionFor(userA), 2);
        expect(
          coordinator.latestRefreshStatusFor(userA),
          BaseTimelineRoutineRefreshStatus.refreshed,
        );

        // 5. target == latest (target 2, latest 2) -> allowed
        final validRetry = await coordinator.retryRoutineRefresh(
          uid: userA,
          targetRevision: 2,
        );
        expect(validRetry.status, BaseTimelineRoutineRefreshStatus.refreshed);
        expect(coordinator.latestRefreshRevisionFor(userA), 2);
      },
    );
  });
}

class _AdversarialRoutineRepository extends FakeRoutineRepository {
  int fetchCalls = 0;
  Completer<void>? delayFetch3;
  Completer<void>? delayFetch6;

  _AdversarialRoutineRepository();

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    fetchCalls++;
    if (fetchCalls == 3 && delayFetch3 != null) {
      await delayFetch3!.future;
    }
    if (fetchCalls == 6 && delayFetch6 != null) {
      await delayFetch6!.future;
    }
    return super.fetchRoutineItems(uid);
  }
}

class _GatedRoutineRepository extends FakeRoutineRepository {
  int fetchCalls = 0;
  final Map<int, Completer<void>> _gates = {};
  final Map<int, Object> _errors = {};
  final Map<int, void Function()> _onFetchStarted = {};

  void gateForFetchNumber({required int fetchNum, required Completer<void> gate}) {
    _gates[fetchNum] = gate;
  }

  void failOnFetchNumber({required int fetchNum, required Object error}) {
    _errors[fetchNum] = error;
  }

  void onFetchStartedForNumber({
    required int fetchNum,
    required void Function() callback,
  }) {
    _onFetchStarted[fetchNum] = callback;
  }

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) async {
    fetchCalls++;
    final callNum = fetchCalls;
    _onFetchStarted[callNum]?.call();
    final gate = _gates[callNum];
    if (gate != null) {
      await gate.future;
    }
    final err = _errors[callNum];
    if (err != null) {
      throw err;
    }
    return super.fetchRoutineItems(uid);
  }
}

class _FailingFollowUpRoutineRepository implements RoutineRepository {
  int fetchCalls = 0;
  bool failOnFollowUp = true;
  final RoutineRepository delegate;

  _FailingFollowUpRoutineRepository({
    required this.delegate,
  });

  @override
  Future<List<RoutineItem>> fetchRoutineItems(String uid) {
    fetchCalls++;
    // fetch #1: coordinator pre-commit read
    // fetch #2: transaction repo pre-commit snapshot
    // fetch #3+: post-commit routine reload
    if (fetchCalls > 2 && failOnFollowUp) {
      throw StateError('Simulated routine network timeout on follow-up');
    }
    return delegate.fetchRoutineItems(uid);
  }

  @override
  Future<RoutineItem> createRoutineItem(String uid, RoutineItem item) =>
      delegate.createRoutineItem(uid, item);

  @override
  Future<RoutineItem> updateRoutineItem(String uid, RoutineItem item) =>
      delegate.updateRoutineItem(uid, item);

  @override
  Future<List<String>> createRoutineItemsIfMissing(
    String uid,
    List<RoutineItem> items,
  ) => delegate.createRoutineItemsIfMissing(uid, items);

  @override
  Future<void> deleteRoutineItem(String uid, String itemId) =>
      delegate.deleteRoutineItem(uid, itemId);

  @override
  Future<RoutineProjectionReceipt?> fetchProjectionReceipt(
    String uid,
    String projectionId,
  ) => delegate.fetchProjectionReceipt(uid, projectionId);

  @override
  Future<bool> reconcileOnboardingProjection(
    String uid,
    RoutineOnboardingProjectionPlan plan,
  ) => delegate.reconcileOnboardingProjection(uid, plan);
}
