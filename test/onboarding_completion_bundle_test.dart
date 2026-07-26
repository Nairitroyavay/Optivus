import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  test(
    'completion bundle merges duplicate language and meditation systems',
    () {
      final bundle = OnboardingCompletionService.buildBundle(_draft());

      final languageItems = bundle.routineItemsForApp
          .where((item) => item.title.toLowerCase().contains('language'))
          .toList();
      final meditationItems = bundle.routineItemsForApp
          .where((item) => item.title.toLowerCase().contains('meditation'))
          .toList();

      expect(languageItems, hasLength(1));
      expect(meditationItems, hasLength(1));
      expect(bundle.duplicateSystemKeysMerged, contains('language_practice'));
      expect(bundle.duplicateSystemKeysMerged, contains('meditation'));
    },
  );

  test('mock app state starts empty and accepts onboarding bundle output', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mockRoutineProvider), isEmpty);
    expect(container.read(mockGoalProvider), isEmpty);

    container.read(mockRoutineProvider.notifier).loadSeedData();
    expect(container.read(mockRoutineProvider), isNotEmpty);
    container.read(mockRoutineProvider.notifier).resetEmpty();
    expect(container.read(mockRoutineProvider), isEmpty);

    final bundle = OnboardingCompletionService.buildBundle(_draft());
    container
        .read(mockUserProfileProvider.notifier)
        .resetEmpty(
          uid: 'test-user',
          email: 'test@optivus.dev',
          displayName: 'Test',
        );
    container
        .read(mockRoutineProvider.notifier)
        .replaceWith(bundle.routineItemsForApp);
    container
        .read(mockGoalProvider.notifier)
        .replaceWith(bundle.identityGoalSystems);
    container.read(mockTrackerProvider.notifier).applyOnboardingBundle(bundle);
    container
        .read(mockUserProfileProvider.notifier)
        .applyOnboardingBundle(bundle);
    container.read(mockUserProfileProvider.notifier).completeOnboarding();

    expect(container.read(mockRoutineProvider), isNotEmpty);
    expect(container.read(mockGoalProvider), isNotEmpty);
    expect(container.read(mockTrackerProvider).trackerSessions, isNotEmpty);
    expect(container.read(mockUserProfileProvider).onboardingCompleted, isTrue);
  });
}

OnboardingDraft _draft() {
  return OnboardingDraft(
    uid: 'test-user',
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.studentKey,
      exerciseLevel: '3_4_days',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '18-24',
      heightCm: 172,
      weightKg: 68,
      gender: 'male',
    ).withEstimates(),
    baseTimeline: const BaseTimelineDraft(
      eatingMode: 'home',
      blocks: [
        TimelineBlockDraft(
          id: 'class-main',
          section: 'classes',
          title: 'Morning class',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: [1, 2, 3, 4, 5],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
        TimelineBlockDraft(
          id: 'meal-lunch',
          section: 'eating',
          title: 'Lunch',
          startMinute: 12 * 60,
          endMinute: 13 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: 'Lunch',
        ),
        TimelineBlockDraft(
          id: 'fixed-sleep',
          section: 'fixed',
          title: 'Sleep',
          startMinute: 0,
          endMinute: 7 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
    badHabits: const [
      BadHabitDraft(
        id: 'bad-doom',
        habitKey: 'doom_scrolling',
        displayName: 'Doom Scrolling',
        dailySpend: 25,
        lostTimeMinutes: 45,
      ),
    ],
    goodHabits: const [
      GoodHabitDraft(
        id: 'good-language-learning',
        habitKey: GoodHabitDraft.languageLearningKey,
        displayName: 'Language Learning',
        subtypeKey: 'spanish',
        durationMinutes: 15,
        bestTime: 'evening',
      ),
      GoodHabitDraft(
        id: 'good-skill-language',
        habitKey: GoodHabitDraft.skillPracticeKey,
        displayName: 'Skill Practice',
        subtypeKey: 'language',
        durationMinutes: 30,
        bestTime: 'morning',
        priority: GoodHabitDraft.mustDoPriority,
      ),
      GoodHabitDraft(
        id: 'good-meditation',
        habitKey: GoodHabitDraft.meditationKey,
        displayName: 'Meditation',
        durationMinutes: 10,
        bestTime: 'night',
      ),
    ],
    identityGoals: const [
      IdentityGoalDraft(
        goalKey: 'new_language',
        displayName: 'New Language',
        systemKeys: ['five_words_daily', 'language_practice'],
      ),
      IdentityGoalDraft(
        goalKey: 'inner_peace',
        displayName: 'Inner Peace',
        systemKeys: ['meditation', 'journaling'],
      ),
    ],
    coachSetup: const CoachSetupDraft(
      coachName: 'Coach',
      coachStyle: 'supportive',
    ),
    slipUpHandling: 'direct_but_kind',
  );
}
