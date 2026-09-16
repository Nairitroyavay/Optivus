import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
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

/// Standard 3 primary footer actions for routine timeline cards:
/// [ ▶ Start ]   [ ✓ Done ]   [ ↗ Move ]
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

        final isMoney = item.blockType == RoutineBlockType.moneyTask;
        final isBadHabit = item.blockType == RoutineBlockType.checkIn &&
            item.category == RoutineCategory.badHabit;
        final isTrackerPlanned =
            item.blockType == RoutineBlockType.trackerTask && !isTrackerActive;

        final actionSet = RoutineCardActionSet.resolve(
          item: item,
          effectiveStatus: effectiveStatus,
          isTrackerActive: isTrackerActive,
          hasGenericCountdown: hasGenericCountdown,
          canUndo: availability.canUndo,
        );

        final actionLayout =
            RoutineCardPresentation.resolveRoutineCardActionLayout(
              availableWidth: availableWidth,
              textScaler: textScaler,
              textDirection: textDirection,
              labels: actionSet.labels,
              actionCount: actionSet.count,
            );

        // Contextual terminal states (Part L): show clear state and optional Undo,
        // without wasting card space on dead Start and dead Move controls.
        if (isCompleted || effectiveStatus == RoutineStatus.completed) {
          final completedBadge = _ActionButton(
            key: ValueKey('routine-action-done-${item.id}'),
            label: 'Completed',
            color: OptivusColors.success,
            icon: Icons.check_circle_rounded,
            isSelected: true,
            isPrimary: true,
            isDisabled: true,
            onTap: null,
          );

          if (availability.canUndo) {
            final undoAction = _ActionButton(
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
            if (actionLayout == RoutineCardActionLayout.stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  completedBadge,
                  const SizedBox(height: RoutineCardPresentation.actionGap),
                  undoAction,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: completedBadge),
                const SizedBox(width: RoutineCardPresentation.actionGap),
                Expanded(flex: 2, child: undoAction),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: completedBadge),
            ],
          );
        }

        if (effectiveStatus == RoutineStatus.skipped) {
          final skippedBadge = _ActionButton(
            key: ValueKey('routine-action-skip-${item.id}'),
            label: 'Skipped',
            color: OptivusColors.warning,
            icon: Icons.skip_next_rounded,
            isSelected: true,
            isPrimary: false,
            isDisabled: true,
            onTap: null,
          );

          if (availability.canUndo) {
            final undoAction = _ActionButton(
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
            if (actionLayout == RoutineCardActionLayout.stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  skippedBadge,
                  const SizedBox(height: RoutineCardPresentation.actionGap),
                  undoAction,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: skippedBadge),
                const SizedBox(width: RoutineCardPresentation.actionGap),
                Expanded(flex: 2, child: undoAction),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: skippedBadge),
            ],
          );
        }

        if (effectiveStatus == RoutineStatus.missed) {
          final missedBadge = _ActionButton(
            key: ValueKey('routine-action-miss-${item.id}'),
            label: 'Missed',
            color: OptivusColors.danger,
            icon: Icons.cancel_outlined,
            isSelected: true,
            isPrimary: false,
            isDisabled: true,
            onTap: null,
          );

          if (availability.canUndo) {
            final undoAction = _ActionButton(
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
            if (actionLayout == RoutineCardActionLayout.stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  missedBadge,
                  const SizedBox(height: RoutineCardPresentation.actionGap),
                  undoAction,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: missedBadge),
                const SizedBox(width: RoutineCardPresentation.actionGap),
                Expanded(flex: 2, child: undoAction),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: missedBadge),
            ],
          );
        }

        final String? startLabel = hasGenericCountdown
            ? null
            : (isMoney
                ? 'Save money'
                : (isBadHabit
                    ? 'Check in'
                    : (isTrackerActive
                        ? 'Open Tracker'
                        : (isTrackerPlanned ? 'Start Tracker' : 'Start'))));

        final IconData startIcon = isMoney
            ? Icons.savings_outlined
            : (isBadHabit
                ? Icons.fact_check_outlined
                : (isTrackerActive
                    ? Icons.open_in_new_rounded
                    : Icons.play_arrow_rounded));

        final startAction = _ActionButton(
          key: ValueKey('routine-action-start-${item.id}'),
          label: startLabel,
          countdownStartedAt: hasGenericCountdown ? item.startedAt : null,
          countdownDurationSeconds: hasGenericCountdown
              ? item.countdownDurationSeconds
              : null,
          color: OptivusColors.routineAccent,
          icon: startIcon,
          isPrimary: !hasGenericCountdown &&
              (effectiveStatus == RoutineStatus.planned || isTrackerActive),
          isDisabled:
              isPending ||
              (!startDecision.isAllowed &&
                  effectiveStatus != RoutineStatus.inTracker &&
                  !hasGenericCountdown),
          onTap: hasGenericCountdown
              ? null
              : () {
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
                  if (item.blockType == RoutineBlockType.moneyTask) {
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
                  } else if (item.blockType == RoutineBlockType.checkIn &&
                      item.category == RoutineCategory.badHabit) {
                    _showBadHabitCheckInSheet(context, ref, item);
                  } else if (item.blockType == RoutineBlockType.trackerTask &&
                      (effectiveStatus == RoutineStatus.inTracker ||
                          isActiveTrackerOccurrence)) {
                    ref.read(appNavigationProvider.notifier).goToTracker();
                  } else if (item.blockType == RoutineBlockType.trackerTask) {
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
                  } else {
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
                  }
                },
        );

        final stopAction = _ActionButton(
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

        final doneAction = _ActionButton(
          key: ValueKey('routine-action-done-${item.id}'),
          label: 'Done',
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
                          message: completeDecision.message ??
                              'Already completed.',
                          failureCategory: completeDecision.failureCategory,
                        )
                      : RoutineWriteResult.validationFailed(
                          RoutineValidationResult.invalid(
                            errorType: RoutineValidationErrorType.invalidTime,
                            userSafeMessage: completeDecision.message ??
                                'Cannot complete routine.',
                          ),
                          message: completeDecision.message,
                          failureCategory: completeDecision.failureCategory,
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

        final moveAction = _ActionButton(
          key: ValueKey('routine-action-move-${item.id}'),
          label: 'Move',
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
                      userSafeMessage: moveDecision.message ??
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

        // Active generic task layout: Countdown + Done (primary) + Stop (secondary), Move hidden.
        if (hasGenericCountdown) {
          if (actionLayout == RoutineCardActionLayout.stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                startAction,
                const SizedBox(height: RoutineCardPresentation.actionGap),
                Row(
                  children: [
                    Expanded(child: doneAction),
                    const SizedBox(width: RoutineCardPresentation.actionGap),
                    Expanded(child: stopAction),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: startAction),
              const SizedBox(width: RoutineCardPresentation.actionGap),
              Expanded(flex: 2, child: doneAction),
              const SizedBox(width: RoutineCardPresentation.actionGap),
              Expanded(flex: 2, child: stopAction),
            ],
          );
        }

        // Active tracker layout: Open Tracker (primary) + Done (secondary), Move hidden.
        if (isTrackerActive) {
          if (actionLayout == RoutineCardActionLayout.stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                startAction,
                const SizedBox(height: RoutineCardPresentation.actionGap),
                doneAction,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: startAction),
              const SizedBox(width: RoutineCardPresentation.actionGap),
              Expanded(flex: 2, child: doneAction),
            ],
          );
        }

        // 2-Action Cards: Money ('Save money' + 'Move'), Bad Habit ('Check in' + 'Move'), Planned Tracker ('Start Tracker' + 'Move').
        // Done is NEVER shown.
        if (isMoney || isBadHabit || isTrackerPlanned) {
          if (actionLayout == RoutineCardActionLayout.stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                startAction,
                const SizedBox(height: RoutineCardPresentation.actionGap),
                moveAction,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: startAction),
              const SizedBox(width: RoutineCardPresentation.actionGap),
              Expanded(flex: 2, child: moveAction),
            ],
          );
        }

        if (actionLayout == RoutineCardActionLayout.stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              startAction,
              const SizedBox(height: RoutineCardPresentation.actionGap),
              Row(
                children: [
                  Expanded(child: doneAction),
                  const SizedBox(width: RoutineCardPresentation.actionGap),
                  Expanded(child: moveAction),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: startAction),
            const SizedBox(width: RoutineCardPresentation.actionGap),
            Expanded(child: doneAction),
            const SizedBox(width: RoutineCardPresentation.actionGap),
            Expanded(child: moveAction),
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
      label: effectiveLabel,
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
