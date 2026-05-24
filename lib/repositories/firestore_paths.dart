class FirestoreUserPaths {
  const FirestoreUserPaths._();

  static String user(String uid) => 'users/$uid';
  static String onboardingDraft(String uid) => 'users/$uid/onboarding/draft';
  static String onboardingCompletionBundle(String uid) {
    return 'users/$uid/onboarding/completionBundle';
  }

  static String onboardingSetupVersion(String uid, int version) {
    return 'users/$uid/onboarding/setupVersions/$version';
  }

  static String routineItem(String uid, String itemId) {
    return 'users/$uid/routineItems/$itemId';
  }

  static String goal(String uid, String goalId) {
    return 'users/$uid/goals/$goalId';
  }

  static String habitTemplate(String uid, String habitId) {
    return 'users/$uid/habitTemplates/$habitId';
  }

  static String badHabitCheckIn(String uid, String habitId) {
    return 'users/$uid/badHabitCheckins/$habitId';
  }

  static String coachPreferences(String uid) {
    return 'users/$uid/coach/preferences/main';
  }

  static String notificationPreferences(String uid) {
    return 'users/$uid/notifications/preferences/main';
  }
}
