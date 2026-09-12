import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
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

  const RoutineCardActions({
    super.key,
    required this.item,
    required this.color,
    this.occurrenceDate,
  });

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
    final occurrenceTargetId = ownerUid != null && occurrenceDate != null
        ? stableRoutineOccurrenceId(
            ownerUid: ownerUid,
            routineItemId: item.id,
            occurrenceDateKey: routineLocalDateKey(occurrenceDate!),
          )
        : null;
    final actionState = hasScope
        ? ref.watch(
            routineNotifierProvider.select(
              (state) => (
                templatePending: state.pendingItemIds.contains(item.id),
                occurrencePending:
                    occurrenceTargetId != null &&
                    state.pendingOccurrenceIds.contains(occurrenceTargetId),
                activeTrackerId: state.activeTrackerLaunchIntent?.routineTaskId,
              ),
            ),
          )
        : null;
    final isPending =
        (actionState?.templatePending ?? false) ||
        (actionState?.occurrencePending ?? false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final textDirection = Directionality.of(context);
        final availableWidth = constraints.maxWidth;

        final actionLayout =
            RoutineCardPresentation.resolveRoutineCardActionLayout(
              availableWidth: availableWidth,
              textScaler: textScaler,
              textDirection: textDirection,
            );

        final startAction = _ActionButton(
          key: ValueKey('routine-action-start-${item.id}'),
          label: 'Start',
          color: color,
          icon: Icons.play_arrow_rounded,
          isDisabled: isPending,
          onTap: () {
            if (!hasScope) return;
            if (item.blockType == RoutineBlockType.moneyTask) {
              showSaveViaUpiFlow(
                context,
                ref,
                source: MoneyEntrySource.routineTask,
                routineTaskId: item.id,
                onSaved: () => ref
                    .read(routineNotifierProvider.notifier)
                    .completeRoutineItem(
                      item.id,
                      occurrenceDate: occurrenceDate,
                    ),
              );
            } else if (item.blockType == RoutineBlockType.checkIn &&
                item.category == RoutineCategory.badHabit) {
              _showBadHabitCheckInSheet(context, ref, item);
            } else if (item.blockType == RoutineBlockType.trackerTask &&
                (item.status == RoutineStatus.inTracker ||
                    actionState?.activeTrackerId == item.id)) {
              ref.read(appNavigationProvider.notifier).goToTracker();
            } else if (item.blockType == RoutineBlockType.trackerTask) {
              ref.read(routineNotifierProvider.notifier).startTrackerTask(item);
            } else {
              ref
                  .read(routineNotifierProvider.notifier)
                  .startRoutineItem(item.id, occurrenceDate: occurrenceDate);
            }
          },
        );

        final doneAction = _ActionButton(
          key: ValueKey('routine-action-done-${item.id}'),
          label: 'Done',
          color: OptivusColors.success,
          icon: Icons.check_rounded,
          isSelected: item.isCompleted,
          isDisabled: isPending,
          onTap: () {
            if (!hasScope) return;
            if (item.blockType == RoutineBlockType.trackerTask) {
              ref
                  .read(routineNotifierProvider.notifier)
                  .completeTrackerSession(item.id);
            } else {
              ref
                  .read(routineNotifierProvider.notifier)
                  .completeRoutineItem(item.id, occurrenceDate: occurrenceDate);
            }
          },
        );

        final moveAction = _ActionButton(
          key: ValueKey('routine-action-move-${item.id}'),
          label: 'Move',
          color: OptivusColors.textSecondary,
          icon: Icons.schedule_rounded,
          isDisabled: isPending,
          onTap: () {
            if (!hasScope) return;
            showRoutineMoveSheet(
              context,
              ref,
              item,
              occurrenceDate: occurrenceDate,
            );
          },
        );

        if (actionLayout == RoutineCardActionLayout.stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              startAction,
              const SizedBox(height: RoutineCardPresentation.actionGap),
              doneAction,
              const SizedBox(height: RoutineCardPresentation.actionGap),
              moveAction,
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
                      ref
                          .read(routineNotifierProvider.notifier)
                          .checkIn(
                            item.id,
                            'Avoided',
                            occurrenceDate: occurrenceDate,
                          );
                    },
                  ),
                  _SheetOptionButton(
                    label: 'Craving',
                    color: OptivusColors.warning,
                    icon: Icons.warning_amber_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(routineNotifierProvider.notifier)
                          .checkIn(
                            item.id,
                            'Craving',
                            occurrenceDate: occurrenceDate,
                          );
                    },
                  ),
                  _SheetOptionButton(
                    label: 'Relapsed',
                    color: OptivusColors.danger,
                    icon: Icons.close_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(routineNotifierProvider.notifier)
                          .checkIn(
                            item.id,
                            'Relapsed',
                            occurrenceDate: occurrenceDate,
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
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDisabled;

  const _ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = isSelected
        ? color.withValues(alpha: 0.24)
        : color.withValues(alpha: 0.10);
    final effectiveBorderColor = isSelected
        ? color.withValues(alpha: 0.50)
        : color.withValues(alpha: 0.20);
    final effectiveTextColor = color;

    final scaler = MediaQuery.textScalerOf(context);
    final hideIcon = scaler.scale(12) > 15;

    return Semantics(
      button: true,
      label: label,
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
                width: isSelected ? 1.4 : 0.8,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textPainter = TextPainter(
                  text: TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w700,
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
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: effectiveTextColor,
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
