import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/routine_item.dart';

/// One shared execution and feedback coordinator for all Routine occurrence actions.
class RoutineActionExecutor {
  RoutineActionExecutor._();

  @visibleForTesting
  static ValueChanged<RoutineActionExecutionObservation>? observer;

  /// Executes an action with structured observability and user-facing feedback.
  ///
  /// Always awaits [perform] and never fires-and-forgets.
  static Future<RoutineWriteResult> execute({
    BuildContext? context,
    required WidgetRef ref,
    required RoutineActionContext actionContext,
    required RoutineOccurrenceAction action,
    required Future<RoutineWriteResult> Function() perform,
    bool showFeedback = true,
  }) async {
    final oldStatus = actionContext.item.status;
    final ownerUidAtStart = ref.read(routineNotifierProvider.notifier).ownerUid;
    RoutineWriteResult result;

    try {
      result = await perform();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RoutineActionExecutor caught unexpected error: $error');
      }
      result = const RoutineWriteResult.retryRequired(
        message: 'Could not update routine. Please try again.',
        failureCategory: RoutineFailureCategory.unknown,
      );
    }

    final observation = RoutineActionExecutionObservation(
      ownerUidAtStart: ownerUidAtStart,
      routineItemId: actionContext.templateId,
      instanceId: actionContext.instanceId,
      occurrenceId: actionContext.occurrenceId,
      occurrenceDateKey: actionContext.occurrenceDateKey,
      displayDateKey: actionContext.displayDateKey,
      entryKind: actionContext.kind,
      oldStatus: oldStatus,
      requestedAction: action,
      operationId: result.operationId,
      writeOutcome: result.outcome,
      resultingStatus: result.resultingStatus,
      failureCategory: result.failureCategory ?? RoutineFailureCategory.none,
    );
    observer?.call(observation);

    if (kDebugMode) {
      debugPrint(
        'RoutineActionExecution: '
        'uid=${ownerUidAtStart ?? "anonymous"} '
        'routineItemId=${actionContext.templateId} '
        'instanceId=${actionContext.instanceId} '
        'occurrenceId=${actionContext.occurrenceId ?? "none"} '
        'occurrenceDateKey=${actionContext.occurrenceDateKey} '
        'displayDateKey=${actionContext.displayDateKey} '
        'kind=${actionContext.kind.name} '
        'oldStatus=${oldStatus.name} '
        'requestedAction=${action.name} '
        'operationId=${result.operationId ?? "locally_rejected"} '
        'outcome=${result.outcome.name} '
        'newStatus=${result.resultingStatus?.name ?? "unavailable"} '
        'failureCategory=${result.failureCategory?.name ?? "none"}',
      );
    }

    if (showFeedback && context != null && context.mounted) {
      showOutcomeFeedback(context, result);
    }

    return result;
  }

  /// Displays user-safe, accessible feedback for the given write result.
  static void showOutcomeFeedback(
    BuildContext context,
    RoutineWriteResult result,
  ) {
    showOutcomeFeedbackWithMessenger(
      ScaffoldMessenger.maybeOf(context),
      result,
    );
  }

  /// Displays user-safe, accessible feedback via an existing [ScaffoldMessengerState].
  static void showOutcomeFeedbackWithMessenger(
    ScaffoldMessengerState? messenger,
    RoutineWriteResult result,
  ) {
    if (messenger == null) return;

    final String message;
    final Color bgColor;
    Duration duration = const Duration(seconds: 2);

    switch (result.outcome) {
      case RoutineWriteOutcome.saved:
        if (result.resultingStatus == RoutineStatus.skipped) {
          message = 'Routine skipped';
        } else {
          message = result.message ?? 'Saved';
        }
        bgColor = OptivusColors.success;
        duration = const Duration(milliseconds: 1400);
        break;

      case RoutineWriteOutcome.noOp:
        if (result.failureCategory == RoutineFailureCategory.alreadyCompleted ||
            (result.message != null &&
                result.message!.toLowerCase().contains('completed'))) {
          message = 'Already completed';
        } else if (result.failureCategory ==
                RoutineFailureCategory.alreadyActive ||
            (result.message != null &&
                result.message!.toLowerCase().contains('active'))) {
          message = 'Already active';
        } else if (result.resultingStatus == RoutineStatus.skipped ||
            (result.message != null &&
                result.message!.toLowerCase().contains('skipped'))) {
          message = 'Already skipped';
        } else {
          message = result.message ?? 'No change needed';
        }
        bgColor = OptivusColors.routineAccent;
        duration = const Duration(milliseconds: 1500);
        break;

      case RoutineWriteOutcome.validationFailed:
        message =
            result.validation?.userSafeMessage ??
            result.message ??
            'Validation failed';
        bgColor = OptivusColors.danger;
        duration = const Duration(seconds: 3);
        break;

      case RoutineWriteOutcome.retryRequired:
        if (result.failureCategory ==
            RoutineFailureCategory.offlineOrUnavailable) {
          message = 'Offline / sync pending';
        } else {
          message = result.message ?? 'Retry needed';
        }
        bgColor = OptivusColors.danger;
        duration = const Duration(seconds: 3);
        break;

      case RoutineWriteOutcome.superseded:
        message = 'Operation superseded';
        bgColor = OptivusColors.textSecondary;
        duration = const Duration(seconds: 2);
        break;
    }

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        backgroundColor: bgColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

@immutable
class RoutineActionExecutionObservation {
  final String? ownerUidAtStart;
  final String routineItemId;
  final String instanceId;
  final String? occurrenceId;
  final String occurrenceDateKey;
  final String displayDateKey;
  final RoutineDayEntryKind entryKind;
  final RoutineStatus oldStatus;
  final RoutineOccurrenceAction requestedAction;
  final String? operationId;
  final RoutineWriteOutcome writeOutcome;
  final RoutineStatus? resultingStatus;
  final RoutineFailureCategory failureCategory;

  const RoutineActionExecutionObservation({
    required this.ownerUidAtStart,
    required this.routineItemId,
    required this.instanceId,
    required this.occurrenceId,
    required this.occurrenceDateKey,
    required this.displayDateKey,
    required this.entryKind,
    required this.oldStatus,
    required this.requestedAction,
    required this.operationId,
    required this.writeOutcome,
    required this.resultingStatus,
    required this.failureCategory,
  });
}
