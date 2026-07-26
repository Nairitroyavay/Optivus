import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_event_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_history_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

void main() {
  test('projects created events only for templates actually created', () async {
    final harness = _ProjectionHarness();
    addTearDown(harness.dispose);

    final bundle = _bundle(uid: 'uid-a', itemCount: 3);
    final plan = RoutineOnboardingProjection.build(bundle);
    await harness.routines.createRoutineItem('uid-a', plan.items.first);

    final completion = await harness.onboarding.completeOnboarding(
      finalDraft: _completedDraft('uid-a'),
      bundle: bundle,
    );
    expect(completion.outcome, RoutineProjectionOutcome.projected);
    expect(completion.receipt.createdItemIds, hasLength(2));
    expect(
      completion.receipt.createdItemIds,
      isNot(contains(plan.items.first.id)),
    );
    expect(completion.receipt.existingItemIds, contains(plan.items.first.id));
    expect(completion.receipt.projectedItemIds, hasLength(3));

    final result = await const RoutineOnboardingEventProjector()
        .projectCreatedEvents(read: harness.container.read, bundle: bundle);

    expect(result.attemptedCount, 2);
    final receipt = await harness.routines.fetchProjectionReceipt(
      'uid-a',
      plan.projectionId,
    );
    expect(receipt?.status, 'completed');
    expect(receipt?.cursor, 3);

    final events = await harness.eventsFor('uid-a');
    expect(events, hasLength(2));
    expect(
      events.map((event) => event.routineItemId),
      isNot(contains(plan.items.first.id)),
    );
    expect(events.every((event) => event.source == 'onboarding'), isTrue);

    final second = await const RoutineOnboardingEventProjector()
        .projectCreatedEvents(read: harness.container.read, bundle: bundle);
    expect(second.attemptedCount, 0);
    expect(await harness.eventsFor('uid-a'), hasLength(2));
    expect(await harness.eventsFor('uid-b'), isEmpty);
  });

  test(
    'resumes interrupted projection without duplicating event IDs',
    () async {
      final harness = _ProjectionHarness();
      addTearDown(harness.dispose);

      final bundle = _bundle(uid: 'uid-resume', itemCount: 105);
      final plan = RoutineOnboardingProjection.build(bundle);
      await harness.onboarding.completeOnboarding(
        finalDraft: _completedDraft('uid-resume'),
        bundle: bundle,
      );

      var batchCalls = 0;
      harness.transactions.onBeforeMutation = () async {
        batchCalls++;
        if (batchCalls == 2) {
          throw StateError('Injected projector interruption');
        }
      };

      await expectLater(
        const RoutineOnboardingEventProjector().projectCreatedEvents(
          read: harness.container.read,
          bundle: bundle,
        ),
        throwsA(isA<RoutineProjectionRetryRequiredException>()),
      );

      var receipt = await harness.routines.fetchProjectionReceipt(
        'uid-resume',
        plan.projectionId,
      );
      expect(receipt?.status, 'pending');
      expect(receipt?.cursor, RoutineOnboardingEventProjector.batchSize);
      expect(await harness.eventsFor('uid-resume'), hasLength(100));

      harness.transactions.onBeforeMutation = null;
      final resumed = await const RoutineOnboardingEventProjector()
          .projectCreatedEvents(read: harness.container.read, bundle: bundle);

      expect(resumed.attemptedCount, 5);
      receipt = await harness.routines.fetchProjectionReceipt(
        'uid-resume',
        plan.projectionId,
      );
      expect(receipt?.status, 'completed');
      expect(receipt?.cursor, 105);

      final events = await harness.eventsFor('uid-resume');
      expect(events, hasLength(105));
      expect(events.map((event) => event.eventId).toSet(), hasLength(105));
      expect(events.every((event) => event.ownerUid == 'uid-resume'), isTrue);
    },
  );
}

class _ProjectionHarness {
  final FakeRoutineDatabase database = FakeRoutineDatabase();
  late final FakeRoutineRepository routines;
  late final FakeOnboardingRepository onboarding;
  late final FakeRoutineTransactionRepository transactions;
  late final ProviderContainer container;

  _ProjectionHarness() {
    routines = FakeRoutineRepository(database: database);
    onboarding = FakeOnboardingRepository(routineDatabase: database);
    transactions = FakeRoutineTransactionRepository(
      routineRepository: routines,
      historyRepository: FakeRoutineHistoryRepository(),
    );
    container = ProviderContainer(
      overrides: [
        optivusBackendModeProvider.overrideWithValue(
          OptivusBackendMode.firebase,
        ),
        routineRepositoryProvider.overrideWithValue(routines),
        onboardingRepositoryProvider.overrideWithValue(onboarding),
        routineTransactionRepositoryProvider.overrideWithValue(transactions),
      ],
    );
  }

  Future<List<RoutineEventRecord>> eventsFor(String uid) async {
    final completer = Completer<List<RoutineEventRecord>>();
    late final StreamSubscription<RoutineEventFeed> subscription;
    subscription = transactions.watchEvents(uid).listen((feed) {
      if (!completer.isCompleted) {
        completer.complete(feed.validEvents);
      }
    });
    final events = await completer.future.timeout(const Duration(seconds: 1));
    await subscription.cancel();
    return events;
  }

  void dispose() {
    container.dispose();
  }
}

OnboardingDraft _completedDraft(String uid) {
  return OnboardingDraft(
    uid: uid,
    currentStep: OnboardingDraft.lastStepIndex,
    onboardingCompleted: true,
    stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
    stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
    stepLoading: List<bool>.filled(OnboardingDraft.stepCount, false),
    createdAt: DateTime.utc(2026, 7, 24),
    updatedAt: DateTime.utc(2026, 7, 24),
  );
}

OnboardingCompletionBundle _bundle({
  required String uid,
  required int itemCount,
}) {
  final now = DateTime.utc(2026, 7, 24, 8);
  return OnboardingCompletionBundle(
    uid: uid,
    createdAt: now,
    updatedAt: now,
    userProfilePatch: const {'onboardingCompleted': true},
    baseTimelineBlocks: const [],
    finalTimelineItems: const [],
    routineItemsForApp: [
      for (var index = 0; index < itemCount; index++)
        RoutineItem(
          id: 'source-$index',
          userId: uid,
          title: 'Onboarding item $index',
          startMinute: 300 + (index % 30) * 10,
          endMinute: 305 + (index % 30) * 10,
          repeatDays: const [1, 2, 3, 4, 5],
          blockType: RoutineBlockType.flexibleTask,
          category: RoutineCategory.habit,
          source: RoutineSource.onboarding,
        ),
    ],
    goodHabitTemplates: const [],
    badHabitCheckIns: const [],
    identityGoalSystems: const [],
    notificationPreferences: NotificationPreferences(),
    coachPreferences: CoachPreferences(),
    moneyGoal: null,
    uploadedAssetReferences: const [],
    warnings: const [],
    duplicateSystemKeysMerged: const [],
  );
}
