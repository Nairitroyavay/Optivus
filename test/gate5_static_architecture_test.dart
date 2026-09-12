import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gate 5 Static Architecture & Contract Enforcement (R1, R2, R3, R6)', () {
    final libDir = Directory('lib');

    List<File> allLibDartFiles() {
      expect(
        libDir.existsSync(),
        isTrue,
        reason: 'lib directory must exist in workspace root.',
      );
      return libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    }

    test(
      'R1: Zero active occurrences of forbidden legacy identifiers in lib/',
      () {
        final forbiddenSymbols = [
          'mockUserProfileProvider',
          'mockOnboardingProvider',
          'backendRestoreFailed',
        ];

        final violations = <String>[];
        for (final file in allLibDartFiles()) {
          final content = file.readAsStringSync();
          for (final symbol in forbiddenSymbols) {
            if (content.contains(symbol)) {
              violations.add('${file.path}: contains "$symbol"');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Retired legacy symbols must not appear anywhere in production lib/:\n'
              '${violations.join('\n')}',
        );
      },
    );

    test('R2: RouterNotifier depends exclusively on authProvider', () {
      final routerFile = File('lib/core/router/app_router.dart');
      expect(routerFile.existsSync(), isTrue);

      final content = routerFile.readAsStringSync();

      // Locate RouterNotifier class definition
      final notifierMatch = RegExp(
        r'class RouterNotifier extends ChangeNotifier\s*\{([\s\S]*?)\}',
      ).firstMatch(content);

      expect(
        notifierMatch,
        isNotNull,
        reason: 'RouterNotifier class must exist in app_router.dart',
      );

      final notifierBody = notifierMatch!.group(1)!;

      // Must listen to authProvider
      expect(
        notifierBody.contains('_ref.listen(authProvider,'),
        isTrue,
        reason: 'RouterNotifier must listen to authProvider',
      );

      // Must NOT listen to userProfileProvider, onboardingStateProvider, completion, or reconstructor
      final forbiddenListeners = [
        'userProfileProvider',
        'onboardingStateProvider',
        'onboardingCompletion',
        'serverReconstructor',
        'serverReconstruction',
      ];

      for (final forbidden in forbiddenListeners) {
        expect(
          notifierBody.contains(forbidden),
          isFalse,
          reason: 'RouterNotifier must not depend on or listen to $forbidden',
        );
      }
    });

    test(
      'R2: optivusAuthRedirect reads AuthState.sessionDestination without provider queries',
      () {
        final routerFile = File('lib/core/router/app_router.dart');
        expect(routerFile.existsSync(), isTrue);

        final content = routerFile.readAsStringSync();

        final redirectMatch = RegExp(
          r'String\?\s+optivusAuthRedirect\s*\(\{[\s\S]*?\}\)\s*\{([\s\S]*?^\})',
          multiLine: true,
        ).firstMatch(content);

        expect(
          redirectMatch,
          isNotNull,
          reason: 'optivusAuthRedirect function must exist in app_router.dart',
        );

        final redirectBody = redirectMatch!.group(1)!;

        // Must read authState.sessionDestination
        expect(
          redirectBody.contains('authState.sessionDestination'),
          isTrue,
          reason: 'optivusAuthRedirect must read authState.sessionDestination',
        );

        // Must not read ref or query providers directly
        expect(
          redirectBody.contains('ref.read'),
          isFalse,
          reason:
              'optivusAuthRedirect must not query providers directly via ref',
        );
        expect(
          redirectBody.contains('userProfileProvider'),
          isFalse,
          reason:
              'optivusAuthRedirect must not directly inspect userProfileProvider',
        );
        expect(
          redirectBody.contains('onboardingStateProvider'),
          isFalse,
          reason:
              'optivusAuthRedirect must not directly inspect onboardingStateProvider',
        );
      },
    );

    test('R3: Verify Email failure taxonomy is unified under RecoverableError', () {
      final violations = <String>[];

      for (final file in allLibDartFiles()) {
        final content = file.readAsStringSync();
        if (content.contains('VerificationMessageKind')) {
          violations.add(
            '${file.path}: contains "VerificationMessageKind" (parallel enum prohibited)',
          );
        }
        if (content.contains('showAccountError(String')) {
          violations.add(
            '${file.path}: contains untyped "showAccountError(String" signature',
          );
        }
        if (content.contains("'Couldn\\'t sign out. Please try again.'") ||
            content.contains('"Couldn\'t sign out. Please try again."')) {
          violations.add(
            '${file.path}: contains hardcoded logout error override string',
          );
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Verify Email must use canonical RecoverableError taxonomy:\n'
            '${violations.join('\n')}',
      );
    });

    test(
      'R3: VerificationLifecycleState defines RecoverableError and successMessage',
      () {
        final stateFile = File('lib/state/verification_lifecycle_state.dart');
        expect(stateFile.existsSync(), isTrue);

        final content = stateFile.readAsStringSync();

        expect(
          content.contains('final RecoverableError? error;'),
          isTrue,
          reason: 'VerificationLifecycleState must have typed error field',
        );
        expect(
          content.contains('final String? successMessage;'),
          isTrue,
          reason: 'VerificationLifecycleState must have successMessage field',
        );
        expect(
          content.contains('void showAccountError(RecoverableError error)'),
          isTrue,
          reason:
              'VerificationLifecycleController must expose typed showAccountError(RecoverableError error)',
        );
        expect(
          content.contains('messageKind'),
          isFalse,
          reason: 'VerificationLifecycleState must not have messageKind field',
        );
      },
    );

    test(
      'R4: Auth identity reset delegates strictly through AuthSessionResetCoordinator',
      () {
        final authFile = File('lib/state/auth_state.dart');
        expect(authFile.existsSync(), isTrue);

        final content = authFile.readAsStringSync();

        // _resetSignedOutState must delegate to authSessionResetCoordinatorProvider.resetIdentityBoundary
        expect(
          content.contains('authSessionResetCoordinatorProvider'),
          isTrue,
          reason:
              'auth_state.dart must reference authSessionResetCoordinatorProvider',
        );

        final resetSignedOutMatch = RegExp(
          r'void _resetSignedOutState\(\{String\? preserveOnboardingUid\}\)\s*\{([\s\S]*?)\}',
        ).firstMatch(content);

        expect(
          resetSignedOutMatch,
          isNotNull,
          reason: '_resetSignedOutState method must exist in auth_state.dart',
        );

        final resetBody = resetSignedOutMatch!.group(1)!;
        expect(
          resetBody.contains('authSessionResetCoordinatorProvider'),
          isTrue,
          reason:
              '_resetSignedOutState must read authSessionResetCoordinatorProvider',
        );
        expect(
          resetBody.contains('resetIdentityBoundary'),
          isTrue,
          reason: '_resetSignedOutState must call resetIdentityBoundary',
        );

        // _clearStateForIdentityBoundary must call _resetSignedOutState
        final clearBoundaryMatch = RegExp(
          r'void _clearStateForIdentityBoundary\([^)]*\)\s*\{([\s\S]*?)\}',
        ).firstMatch(content);

        expect(
          clearBoundaryMatch,
          isNotNull,
          reason:
              '_clearStateForIdentityBoundary method must exist in auth_state.dart',
        );

        final clearBody = clearBoundaryMatch!.group(1)!;
        expect(
          clearBody.contains('_resetSignedOutState'),
          isTrue,
          reason:
              '_clearStateForIdentityBoundary must delegate to _resetSignedOutState',
        );
      },
    );

    test(
      'R4 & TD-039: Gate 5 session inventory covers all AuthSessionResetCoordinator providers',
      () {
        final coordinatorFile = File(
          'lib/services/auth_session_reset_coordinator.dart',
        );
        expect(coordinatorFile.existsSync(), isTrue);

        final content = coordinatorFile.readAsStringSync();

        const validClassifications = {
          'USER_SCOPED_RESET',
          'USER_SCOPED_UID_KEYED',
          'USER_SCOPED_AUTO_DISPOSE',
          'USER_SCOPED_GENERATION_FENCED',
          'SESSION_UI_RESET',
          'REPOSITORY_UID_SCOPED',
          'NOT_USER_SCOPED',
        };

        const gate5SessionInventory = <String, String>{
          'authGenerationProvider': 'NOT_USER_SCOPED',
          'onboardingCompletionJobServiceProvider': 'USER_SCOPED_RESET',
          'onboardingCompletionJobProvider': 'USER_SCOPED_UID_KEYED',
          'recoveryRetryControllerProvider': 'USER_SCOPED_RESET',
          'routineNotifierProvider': 'USER_SCOPED_RESET',
          'trackerSessionLinksProvider': 'USER_SCOPED_RESET',
          'habitSystemsNotifierProvider': 'USER_SCOPED_RESET',
          'userProfileProvider': 'USER_SCOPED_RESET',
          'onboardingStateProvider': 'USER_SCOPED_RESET',
          'onboardingClassTimelineProvider': 'USER_SCOPED_AUTO_DISPOSE',
          'onboardingWorkTimelineProvider': 'USER_SCOPED_AUTO_DISPOSE',
          'profileSettingsProvider': 'USER_SCOPED_RESET',
          'homeDashboardProvider': 'USER_SCOPED_RESET',
          'fitnessCenterProvider': 'USER_SCOPED_RESET',
          'trackerSettingsProvider': 'USER_SCOPED_RESET',
          'routineImportAiControllerProvider': 'USER_SCOPED_RESET',
          'uploadControllerProvider': 'USER_SCOPED_RESET',
          'onboardingUploadInteractionProvider': 'USER_SCOPED_RESET',
          'restoredUploadsProvider': 'USER_SCOPED_RESET',
          'aiRoutineSuggestionsEnabledProvider': 'SESSION_UI_RESET',
          'routineNotificationsEnabledProvider': 'SESSION_UI_RESET',
          'appNavigationProvider': 'SESSION_UI_RESET',
          'toastQueueProvider': 'SESSION_UI_RESET',
          'homeDetailViewRequestProvider': 'SESSION_UI_RESET',
          'trackerDetailViewRequestProvider': 'SESSION_UI_RESET',
          'profileDetailViewRequestProvider': 'SESSION_UI_RESET',
          'routineDetailViewRequestProvider': 'SESSION_UI_RESET',
          'coachDetailViewRequestProvider': 'SESSION_UI_RESET',
          'goalsDetailViewRequestProvider': 'SESSION_UI_RESET',
          'regionSettingsProvider': 'USER_SCOPED_RESET',
          'mockTrackerProvider': 'USER_SCOPED_RESET',
          'mockGoalProvider': 'USER_SCOPED_RESET',
          'mockMindNoteProvider': 'USER_SCOPED_RESET',
          'homeMindNoteProvider': 'USER_SCOPED_RESET',
          'mockCoachProvider': 'USER_SCOPED_RESET',
          'mockCoachPreferencesProvider': 'USER_SCOPED_RESET',
          'mockNotificationPreferencesProvider': 'USER_SCOPED_RESET',
          'mockPermissionProvider': 'USER_SCOPED_RESET',
        };

        // 1. Every classification in inventory must be valid
        for (final entry in gate5SessionInventory.entries) {
          expect(
            validClassifications.contains(entry.value),
            isTrue,
            reason:
                'Provider ${entry.key} has invalid classification "${entry.value}"',
          );
        }

        // 2. Every provider in the inventory must be present in AuthSessionResetCoordinator
        for (final provider in gate5SessionInventory.keys) {
          expect(
            content.contains(provider),
            isTrue,
            reason: 'Coordinator must touch inventory provider $provider',
          );
        }
      },
    );
  });
}
