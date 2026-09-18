import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/features/routine/models/routine_action_availability.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_action_executor.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/widgets/cards/routine_card_presentation.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/features/tracker/money/money_system_mock_flows.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/repositories/routine_history_repository.dart';

/// Standard 4 primary footer actions for routine timeline cards:
/// [ ▶ Start ]   [ ✓ Done ]   [ ↗ Move ]   [ ⏭ Skip ]
class RoutineCardActions extends ConsumerWidget {
  final RoutineItem item;
  final Color color;

  /// When non-null, this date is passed explicitly to all notifier action
  /// calls. This ensures that overnight continuation segments and moved-in
  /// occurrences write to the correct occurrence record rather than relying
  /// on the ambiguous _occurrenceAnchorDate inference.
  final DateTime? occurrenceDate;
  final RoutineActionContext? actionContext;

  const RoutineCardActions({
    super.key,
    required this.item,
    required this.color,
    this.occurrenceDate,
    this.actionContext,
  });

  Future<RoutineWriteResult> _executeRoutineAction(
    BuildContext context,
    WidgetRef ref, {
    required RoutineOccurrenceAction action,
    required Future<RoutineWriteResult> Function() perform,
  }) {
    final effectiveContext =
        actionContext ??
        RoutineActionContext.fallback(
          item: item,
          occurrenceDate: occurrenceDate,
        );
    return RoutineActionExecutor.execute(
      context: context,
      ref: ref,
      actionContext: effectiveContext,
      action: action,
      perform: perform,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasScope =
        context
            .getElementForInheritedWidgetOfExactType<
              UncontrolledProviderScope
            >() !=
        null;
    final notifier = hasScope
        ? ref.read(routineNotifierProvider.notifier)
        : null;
    final ownerUid = notifier?.ownerUid;
    final effectiveOccurrenceDate =
        actionContext?.occurrenceDate ?? occurrenceDate;
    final occurrenceDateKey =
        actionContext?.occurrenceDateKey ??
        (effectiveOccurrenceDate == null
            ? null
            : routineLocalDateKey(effectiveOccurrenceDate));
    final templateId = actionContext?.templateId ?? item.id;
    final occurrenceTargetId = ownerUid != null && occurrenceDateKey != null
        ? (actionContext?.occurrenceId ??
              stableRoutineOccurrenceId(
                ownerUid: ownerUid,
                routineItemId: templateId,
                occurrenceDateKey: occurrenceDateKey,
              ))
        : null;
    final actionState = hasScope
        ? ref.watch(
            routineNotifierProvider.select(
              (state) => (
                templatePending: state.pendingItemIds.contains(templateId),
                occurrencePending:
                    occurrenceTargetId != null &&
                    state.pendingOccurrenceIds.contains(occurrenceTargetId),
                activeTrackerId: state.activeTrackerLaunchIntent?.routineTaskId,
                activeTrackerOccurrenceDateKey:
                    state.activeTrackerLaunchIntent?.occurrenceDateKey,
              ),
            ),
          )
        : null;
    final isPending = occurrenceTargetId != null
        ? (actionState?.occurrencePending ?? false)
        : (actionState?.templatePending ?? false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final textDirection = Directionality.of(context);
        final availableWidth = constraints.maxWidth;

        final existingRecord = hasScope && occurrenceDateKey != null
            ? ref.watch(
                routineNotifierProvider.select((state) {
                  for (final occ in state.occurrences) {
                    if (occ.routineItemId == templateId &&
                        occ.occurrenceDateKey == occurrenceDateKey) {
                      return occ;
                    }
                  }
                  return null;
                }),
              )
            : null;
        final effectiveStatus = existingRecord?.status ?? item.status;
        final isCompleted =
            item.isCompleted || effectiveStatus == RoutineStatus.completed;
        final availability = RoutineActionAvailability.forOccurrence(
          existingRecord: existingRecord,
          status: effectiveStatus,
          blockType: item.blockType,
        );
        final startDecision = availability.startDecision;
        final completeDecision = availability.completeDecision;
        final moveDecision = availability.moveDecision;

        final hasGenericCountdown =
            !isCompleted &&
            effectiveStatus == RoutineStatus.active &&
            item.blockType != RoutineBlockType.trackerTask &&
            item.blockType != RoutineBlockType.checkIn &&
            item.blockType != RoutineBlockType.moneyTask &&
            item.startedAt != null &&
            item.countdownDurationSeconds != null;
        final isActiveTrackerOccurrence =
            actionState?.activeTrackerId == item.id &&
            actionState?.activeTrackerOccurrenceDateKey == occurrenceDateKey;
        final isTrackerActive =
            item.blockType == RoutineBlockType.trackerTask &&
            (effectiveStatus == RoutineStatus.inTracker ||
                isActiveTrackerOccurrence);

        final canUndo =
            availability.canUndo ||
            (existingRecord == null &&
                (item.undoToPlannedAllowed ||
                    effectiveStatus == RoutineStatus.skipped));

        final actionSet = RoutineCardActionSet.resolve(
          item: item,
          effectiveStatus: effectiveStatus,
          isTrackerActive: isTrackerActive,
          hasGenericCountdown: hasGenericCountdown,
          canUndo: canUndo,
        );

        final actionPlan = actionSet.resolveLayoutPlan(
          availableWidth: availableWidth,
          textScaler: textScaler,
          textDirection: textDirection,
        );

        Widget buildActionButton(RoutineCardActionConfig config) {
          switch (config.type) {
            case RoutineCardActionType.terminalBadge:
              final terminalColor = effectiveStatus == RoutineStatus.skipped
                  ? OptivusColors.warning
                  : (effectiveStatus == RoutineStatus.missed
                        ? OptivusColors.danger
                        : OptivusColors.success);
              final terminalIcon = effectiveStatus == RoutineStatus.skipped
                  ? Icons.skip_next_rounded
                  : (effectiveStatus == RoutineStatus.missed
                        ? Icons.cancel_outlined
                        : Icons.check_circle_rounded);
              final terminalKey = effectiveStatus == RoutineStatus.skipped
                  ? ValueKey('routine-action-skip-${item.id}')
                  : (effectiveStatus == RoutineStatus.missed
                        ? ValueKey('routine-action-miss-${item.id}')
                        : ValueKey('routine-action-done-${item.id}'));
              return _ActionButton(
                key: terminalKey,
                label: config.label,
                color: terminalColor,
                icon: terminalIcon,
                isSelected: true,
                isPrimary: effectiveStatus == RoutineStatus.completed,
                isDisabled: true,
                onTap: null,
              );

            case RoutineCardActionType.undo:
              return _ActionButton(
                key: ValueKey('routine-action-undo-${item.id}'),
                label: 'Undo',
                color: OptivusColors.textSecondary,
                icon: Icons.undo_rounded,
                isPrimary: false,
                isDisabled: isPending,
                onTap: () {
                  if (!hasScope) return;
                  _executeRoutineAction(
                    context,
                    ref,
                    action: RoutineOccurrenceAction.undo,
                    perform: () => ref
                        .read(routineNotifierProvider.notifier)
                        .undoOccurrenceAction(
                          item.id,
                          occurrenceDate: effectiveOccurrenceDate,
                        ),
                  );
                },
              );

            case RoutineCardActionType.countdown:
              return _ActionButton(
                key: ValueKey('routine-action-start-${item.id}'),
                label: null,
                countdownStartedAt: item.startedAt,
                countdownDurationSeconds: item.countdownDurationSeconds,
                color: OptivusColors.routineAccent,
                icon: Icons.play_arrow_rounded,
                isPrimary: false,
                isDisabled: isPending,
                onTap: null,
              );

            case RoutineCardActionType.saveMoney:
              return _ActionButton(
                key: ValueKey('routine-action-start-${item.id}'),
                label: 'Save money',
                semanticLabel: 'Save money ${item.title}',
                color: OptivusColors.routineAccent,
                icon: Icons.savings_outlined,
                isPrimary: true,
                isDisabled:
                    isPending ||
                    (!startDecision.isAllowed &&
                        effectiveStatus != RoutineStatus.inTracker),
                onTap: () {
                  if (!hasScope) return;
                  showSaveViaUpiFlow(
                    context,
                    ref,
                    source: MoneyEntrySource.routineTask,
                    routineTaskId: item.id,
                    onSaved: () => _executeRoutineAction(
                      context,
                      ref,
                      action: RoutineOccurrenceAction.complete,
                      perform: () => ref
                          .read(routineNotifierProvider.notifier)
                          .recordMoneySavedAndComplete(
                            item.id,
                            occurrenceDate: effectiveOccurrenceDate,
                          ),
                    ),
                  );
                },
              );

            case RoutineCardActionType.checkIn:
              return _ActionButton(
                key: ValueKey('routine-action-start-${item.id}'),
                label: 'Check in',
                semanticLabel: 'Check in ${item.title}',
                color: OptivusColors.routineAccent,
                icon: Icons.fact_check_outlined,
                isPrimary: true,
                isDisabled:
                    isPending ||
                    (!startDecision.isAllowed &&
                        effectiveStatus != RoutineStatus.inTracker),
                onTap: () {
                  if (!hasScope) return;
                  _showBadHabitCheckInSheet(context, ref, item);
                },
              );

            case RoutineCardActionType.openTracker:
              return _ActionButton(
                key: ValueKey('routine-action-start-${item.id}'),
                label: 'Open Tracker',
                semanticLabel: 'Open Tracker ${item.title}',
                color: OptivusColors.routineAccent,
                icon: Icons.open_in_new_rounded,
                isPrimary: true,
                isDisabled: isPending,
                onTap: () {
                  if (!hasScope) return;
                  ref
                      .read(routineNotifierProvider.notifier)
                      .openTrackerSession(
                        item.id,
                        occurrenceDate: effectiveOccurrenceDate,
                      );
                },
              );

            case RoutineCardActionType.startTracker:
              return _ActionButton(
                key: ValueKey('routine-action-start-${item.id}'),
                label: 'Start Tracker',
                semanticLabel: 'Start Tracker ${item.title}',
                color: OptivusColors.routineAccent,
                icon: Icons.play_arrow_rounded,
                isPrimary: true,
                isDisabled: isPending || !startDecision.isAllowed,
                onTap: () {
                  if (!hasScope) return;
                  _executeRoutineAction(
                    context,
                    ref,
                    action: RoutineOccurrenceAction.startTracker,
                    perform: () => ref
                        .read(routineNotifierProvider.notifier)
                        .startRoutineItem(
                          item.id,
                          occurrenceDate: effectiveOccurrenceDate,
                        ),
                  );
                },
              );

            case RoutineCardActionType.start:
              return _ActionButton(
                key: ValueKey('routine-action-start-${item.id}'),
                label: 'Start',
                semanticLabel: 'Start ${item.title}',
                color: OptivusColors.routineAccent,
                icon: Icons.play_arrow_rounded,
                isPrimary: effectiveStatus == RoutineStatus.planned,
                isDisabled:
                    isPending ||
                    (!startDecision.isAllowed &&
                        effectiveStatus != RoutineStatus.inTracker),
                onTap: () {
                  if (!hasScope) return;
                  if (isCompleted) {
                    _executeRoutineAction(
                      context,
                      ref,
                      action: RoutineOccurrenceAction.start,
                      perform: () => Future.value(
                        RoutineWriteResult.validationFailed(
                          RoutineValidationResult.invalid(
                            errorType: RoutineValidationErrorType.invalidTime,
                            userSafeMessage:
                                'Completed routine cannot be restarted.',
                          ),
                          message: 'Completed routine cannot be restarted.',
                          failureCategory:
                              RoutineFailureCategory.invalidTransition,
                        ),
                      ),
                    );
                    return;
                  }
                  _executeRoutineAction(
                    context,
                    ref,
                    action: RoutineOccurrenceAction.start,
                    perform: () => ref
                        .read(routineNotifierProvider.notifier)
                        .startRoutineItem(
                          item.id,
                          occurrenceDate: effectiveOccurrenceDate,
                        ),
                  );
                },
              );

            case RoutineCardActionType.done:
              return _ActionButton(
                key: ValueKey('routine-action-done-${item.id}'),
                label: 'Done',
                semanticLabel: 'Mark ${item.title} as done',
                color: OptivusColors.success,
                icon: Icons.check_rounded,
                isSelected: false,
                isPrimary: effectiveStatus == RoutineStatus.active,
                isDisabled: isPending || !completeDecision.isAllowed,
                onTap: () {
                  if (!hasScope) return;
                  if (!completeDecision.isAllowed) {
                    _executeRoutineAction(
                      context,
                      ref,
                      action: RoutineOccurrenceAction.complete,
                      perform: () => Future.value(
                        completeDecision.isNoOp
                            ? RoutineWriteResult.noOp(
                                message:
                                    completeDecision.message ??
                                    'Already completed.',
                                failureCategory:
                                    completeDecision.failureCategory,
                              )
                            : RoutineWriteResult.validationFailed(
                                RoutineValidationResult.invalid(
                                  errorType:
                                      RoutineValidationErrorType.invalidTime,
                                  userSafeMessage:
                                      completeDecision.message ??
                                      'Cannot complete routine.',
                                ),
                                message: completeDecision.message,
                                failureCategory:
                                    completeDecision.failureCategory,
                              ),
                      ),
                    );
                    return;
                  }
                  _executeRoutineAction(
                    context,
                    ref,
                    action: RoutineOccurrenceAction.complete,
                    perform: () => ref
                        .read(routineNotifierProvider.notifier)
                        .completeRoutineItem(
                          item.id,
                          occurrenceDate: effectiveOccurrenceDate,
                        ),
                  );
                },
              );

            case RoutineCardActionType.move:
              return _ActionButton(
                key: ValueKey('routine-action-move-${item.id}'),
                label: 'Move',
                semanticLabel: 'Move ${item.title} to another time or day',
                color: OptivusColors.textSecondary,
                icon: Icons.schedule_rounded,
                isPrimary: false,
                isDisabled: isPending || !moveDecision.isAllowed,
                onTap: () {
                  if (!hasScope) return;
                  if (!moveDecision.isAllowed) {
                    _executeRoutineAction(
                      context,
                      ref,
                      action: RoutineOccurrenceAction.move,
                      perform: () => Future.value(
                        RoutineWriteResult.validationFailed(
                          RoutineValidationResult.invalid(
                            errorType: RoutineValidationErrorType.invalidTime,
                            userSafeMessage:
                                moveDecision.message ??
                                'Completed routine cannot be moved.',
                          ),
                          message: moveDecision.message,
                          failureCategory: moveDecision.failureCategory,
                        ),
                      ),
                    );
                    return;
                  }
                  showRoutineMoveSheet(
                    context,
                    ref,
                    item,
                    occurrenceDate: effectiveOccurrenceDate,
                    displayDate: actionContext?.displayDate,
                    actionContext: actionContext,
                  );
                },
              );

            case RoutineCardActionType.skip:
              final skipDecision = availability.skipDecision;
              return _ActionButton(
                key: ValueKey('routine-action-skip-${item.id}'),
                label: 'Skip',
                semanticLabel: 'Skip ${item.title}',
                color: OptivusColors.warning,
                icon: Icons.skip_next_rounded,
                isPrimary: false,
                isDisabled: isPending || !skipDecision.isAllowed,
                onTap: () {
                  if (!hasScope) return;
                  if (!skipDecision.isAllowed) {
                    _executeRoutineAction(
                      context,
                      ref,
                      action: RoutineOccurrenceAction.skip,
                      perform: () => Future.value(
                        skipDecision.isNoOp
                            ? RoutineWriteResult.noOp(
                                message:
                                    skipDecision.message ?? 'Already skipped.',
                                failureCategory: skipDecision.failureCategory,
                              )
                            : RoutineWriteResult.validationFailed(
                                RoutineValidationResult.invalid(
                                  errorType:
                                      RoutineValidationErrorType.invalidTime,
                                  userSafeMessage:
                                      skipDecision.message ??
                                      'Cannot skip routine.',
                                ),
                                message: skipDecision.message,
                                failureCategory: skipDecision.failureCategory,
                              ),
                      ),
                    );
                    return;
                  }
                  _executeRoutineAction(
                    context,
                    ref,
                    action: RoutineOccurrenceAction.skip,
                    perform: () => ref
                        .read(routineNotifierProvider.notifier)
                        .markSkipped(
                          item.id,
                          occurrenceDate: effectiveOccurrenceDate,
                        ),
                  );
                },
              );

            case RoutineCardActionType.stop:
              return _ActionButton(
                key: ValueKey('routine-action-stop-${item.id}'),
                label: 'Stop',
                color: OptivusColors.danger,
                icon: Icons.stop_rounded,
                isPrimary: false,
                isDisabled: isPending,
                onTap: () {
                  if (!hasScope) return;
                  _executeRoutineAction(
                    context,
                    ref,
                    action: RoutineOccurrenceAction.undo,
                    perform: () => ref
                        .read(routineNotifierProvider.notifier)
                        .undoOccurrenceAction(
                          item.id,
                          occurrenceDate: effectiveOccurrenceDate,
                        ),
                  );
                },
              );
          }
        }

        Widget buildRow(
          int rowIndex,
          List<RoutineCardActionConfig> rowActions,
        ) {
          if (rowActions.isEmpty) return const SizedBox.shrink();
          if (rowActions.length == 1) {
            return KeyedSubtree(
              key: ValueKey('routine-action-row-$rowIndex'),
              child: buildActionButton(rowActions[0]),
            );
          }
          return KeyedSubtree(
            key: ValueKey('routine-action-row-$rowIndex'),
            child: Row(
              children: [
                for (int i = 0; i < rowActions.length; i++) ...[
                  if (i > 0)
                    const SizedBox(width: RoutineCardPresentation.actionGap),
                  Expanded(
                    flex: rowActions[i].flex,
                    child: buildActionButton(rowActions[i]),
                  ),
                ],
              ],
            ),
          );
        }

        if (actionPlan.rows.length == 1) {
          final singleRow = actionPlan.rows[0];
          return KeyedSubtree(
            key: const ValueKey('routine-action-row-0'),
            child: Row(
              key: const ValueKey('routine-action-row-horizontal'),
              children: [
                for (int i = 0; i < singleRow.length; i++) ...[
                  if (i > 0)
                    const SizedBox(width: RoutineCardPresentation.actionGap),
                  Expanded(
                    flex: singleRow[i].flex,
                    child: buildActionButton(singleRow[i]),
                  ),
                ],
              ],
            ),
          );
        }

        final containerKey =
            actionPlan.geometry == RoutineCardActionRowGeometry.grid2x2
            ? const ValueKey('routine-action-grid-2x2')
            : const ValueKey('routine-action-column-stacked');

        return Column(
          key: containerKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int r = 0; r < actionPlan.rows.length; r++) ...[
              if (r > 0)
                const SizedBox(height: RoutineCardPresentation.actionGap),
              buildRow(r, actionPlan.rows[r]),
            ],
          ],
        );
      },
    );
  }

  void _showBadHabitCheckInSheet(
    BuildContext context,
    WidgetRef ref,
    RoutineItem item,
  ) {
    final effectiveOccurrenceDate =
        actionContext?.occurrenceDate ?? occurrenceDate;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check-in: ${item.title}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SheetOptionButton(
                    label: 'Avoided',
                    color: OptivusColors.success,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      _executeRoutineAction(
                        context,
                        ref,
                        action: RoutineOccurrenceAction.checkIn,
                        perform: () => ref
                            .read(routineNotifierProvider.notifier)
                            .checkIn(
                              item.id,
                              'Avoided',
                              occurrenceDate: effectiveOccurrenceDate,
                            ),
                      );
                    },
                  ),
                  _SheetOptionButton(
                    label: 'Craving',
                    color: OptivusColors.warning,
                    icon: Icons.warning_amber_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      _executeRoutineAction(
                        context,
                        ref,
                        action: RoutineOccurrenceAction.checkIn,
                        perform: () => ref
                            .read(routineNotifierProvider.notifier)
                            .checkIn(
                              item.id,
                              'Craving',
                              occurrenceDate: effectiveOccurrenceDate,
                            ),
                      );
                    },
                  ),
                  _SheetOptionButton(
                    label: 'Relapsed',
                    color: OptivusColors.danger,
                    icon: Icons.close_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      _executeRoutineAction(
                        context,
                        ref,
                        action: RoutineOccurrenceAction.checkIn,
                        perform: () => ref
                            .read(routineNotifierProvider.notifier)
                            .checkIn(
                              item.id,
                              'Relapsed',
                              occurrenceDate: effectiveOccurrenceDate,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOptionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SheetOptionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String? label;
  final String? semanticLabel;
  final DateTime? countdownStartedAt;
  final int? countdownDurationSeconds;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDisabled;
  final bool isPrimary;

  const _ActionButton({
    super.key,
    this.label,
    this.semanticLabel,
    this.countdownStartedAt,
    this.countdownDurationSeconds,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.isDisabled = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? '00:00:00';
    final effectiveBgColor = isSelected
        ? color.withValues(alpha: 0.28)
        : isPrimary
        ? color.withValues(alpha: 0.22)
        : color.withValues(alpha: 0.08);
    final effectiveBorderColor = isSelected
        ? color.withValues(alpha: 0.55)
        : isPrimary
        ? color.withValues(alpha: 0.50)
        : color.withValues(alpha: 0.20);
    final effectiveTextColor = color;

    final scaler = MediaQuery.textScalerOf(context);
    final hideIcon = scaler.scale(12) > 15;

    return Semantics(
      button: true,
      label: semanticLabel ?? effectiveLabel,
      enabled: !isDisabled,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDisabled ? null : onTap,
        child: Opacity(
          opacity: isDisabled ? 0.45 : 1.0,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: RoutineCardPresentation.actionButtonMinHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: RoutineCardPresentation.actionButtonPaddingHorizontal,
              vertical: RoutineCardPresentation.actionButtonPaddingVertical,
            ),
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: effectiveBorderColor,
                width: isSelected || isPrimary ? 1.4 : 0.8,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textPainter = TextPainter(
                  text: TextSpan(
                    text: effectiveLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : (isPrimary ? FontWeight.w900 : FontWeight.w700),
                    ),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();

                final shouldHideIcon =
                    hideIcon ||
                    (constraints.hasBoundedWidth &&
                        constraints.maxWidth < textPainter.width + 18.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!shouldHideIcon) ...[
                      Icon(icon, size: 14, color: effectiveTextColor),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child:
                          countdownStartedAt != null &&
                              countdownDurationSeconds != null
                          ? _CountdownLabel(
                              startedAt: countdownStartedAt!,
                              durationSeconds: countdownDurationSeconds!,
                              color: effectiveTextColor,
                            )
                          : Text(
                              effectiveLabel,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: effectiveTextColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownLabel extends StatefulWidget {
  final DateTime startedAt;
  final int durationSeconds;
  final Color color;

  const _CountdownLabel({
    required this.startedAt,
    required this.durationSeconds,
    required this.color,
  });

  @override
  State<_CountdownLabel> createState() => _CountdownLabelState();
}

class _CountdownLabelState extends State<_CountdownLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now()
        .toUtc()
        .difference(widget.startedAt.toUtc())
        .inSeconds;
    final remaining = widget.durationSeconds - elapsed;
    if (remaining <= 0) {
      return Text(
        "Time's up",
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: widget.color,
        ),
      );
    }
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    final seconds = remaining % 60;
    return Text(
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}',
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: widget.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
