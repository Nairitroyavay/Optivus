import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';
import 'package:optivus/features/routine/sheets/routine_move_sheet.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';

/// Conflict notification banner shown at the top of the timeline.
class ConflictBanner extends StatelessWidget {
  final int conflictCount;
  final VoidCallback? onTap;

  const ConflictBanner({super.key, required this.conflictCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (conflictCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: OptivusColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: OptivusColors.danger.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: OptivusColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$conflictCount time conflict${conflictCount > 1 ? 's' : ''} detected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.danger,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: OptivusColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

void showRoutineConflictResolverSheet(
  BuildContext parentContext,
  WidgetRef ref, {
  String? itemId,
}) {
  final state = ref.read(routineNotifierProvider);
  final items = {for (final item in state.items) item.id: item};
  final conflicts = state.conflicts
      .where(
        (conflict) =>
            itemId == null ||
            conflict.itemId == itemId ||
            conflict.otherItemId == itemId,
      )
      .toList(growable: false);
  if (conflicts.isEmpty) return;

  showModalBottomSheet(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _RoutineConflictResolverSheetContent(
        conflicts: conflicts,
        items: items,
        ref: ref,
        parentContext: parentContext,
      );
    },
  );
}

class _RoutineConflictResolverSheetContent extends StatefulWidget {
  final List<RoutineConflict> conflicts;
  final Map<String, RoutineItem> items;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _RoutineConflictResolverSheetContent({
    required this.conflicts,
    required this.items,
    required this.ref,
    required this.parentContext,
  });

  @override
  State<_RoutineConflictResolverSheetContent> createState() =>
      _RoutineConflictResolverSheetContentState();
}

class _RoutineConflictResolverSheetContentState
    extends State<_RoutineConflictResolverSheetContent> {
  int _pendingCount = 0;

  bool get _isPending => _pendingCount > 0;

  void _onPendingChanged(bool pending) {
    setState(() {
      if (pending) {
        _pendingCount++;
      } else if (_pendingCount > 0) {
        _pendingCount--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = widget.conflicts;
    final items = widget.items;

    return PopScope(
      canPop: !_isPending,
      child: DraggableScrollableSheet(
        initialChildSize: conflicts.length > 2 ? 0.72 : 0.48,
        minChildSize: 0.34,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OptivusColors.routineSheetTop,
                  OptivusColors.routineSheetBottom,
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'} found',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                    _ResolverIconButton(
                      icon: Icons.close_rounded,
                      color: OptivusColors.textSecondary,
                      onTap: _isPending
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...conflicts.map(
                  (conflict) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ConflictResolverCard(
                      conflict: conflict,
                      item: items[conflict.itemId],
                      other: conflict.otherItemId == null
                          ? null
                          : items[conflict.otherItemId],
                      ref: widget.ref,
                      parentContext: widget.parentContext,
                      isSheetPending: _isPending,
                      onPendingChanged: _onPendingChanged,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConflictResolverCard extends StatefulWidget {
  final RoutineConflict conflict;
  final RoutineItem? item;
  final RoutineItem? other;
  final WidgetRef ref;
  final BuildContext parentContext;
  final bool isSheetPending;
  final ValueChanged<bool> onPendingChanged;

  const _ConflictResolverCard({
    required this.conflict,
    required this.item,
    required this.other,
    required this.ref,
    required this.parentContext,
    required this.isSheetPending,
    required this.onPendingChanged,
  });

  @override
  State<_ConflictResolverCard> createState() => _ConflictResolverCardState();
}

class _ConflictResolverCardState extends State<_ConflictResolverCard> {
  bool _pending = false;
  String? _statusMessage;

  Future<void> _runWrite(Future<RoutineWriteResult> Function() write) async {
    if (_pending || widget.isSheetPending) return;
    setState(() {
      _pending = true;
      _statusMessage = null;
    });
    widget.onPendingChanged(true);
    try {
      final result = await write();
      if (!mounted) return;
      setState(() {
        _pending = false;
        _statusMessage = _messageForResult(result);
      });
      widget.onPendingChanged(false);
      if (_shouldClose(result)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pending = false;
        });
        widget.onPendingChanged(false);
      }
      rethrow;
    }
  }

  bool _shouldClose(RoutineWriteResult result) {
    if (result.outcome == RoutineWriteOutcome.saved) return true;
    if (result.outcome == RoutineWriteOutcome.noOp &&
        result.validation?.isValid != false) {
      return true;
    }
    return false;
  }

  String? _messageForResult(RoutineWriteResult result) {
    if (_shouldClose(result)) return null;
    return result.validation?.userSafeMessage ??
        result.message ??
        switch (result.outcome) {
          RoutineWriteOutcome.validationFailed =>
            'This conflict could not be resolved. Adjust the item and try again.',
          RoutineWriteOutcome.retryRequired =>
            'The save did not reach storage. Please retry.',
          RoutineWriteOutcome.superseded =>
            'The routine changed before this action completed.',
          _ => null,
        };
  }

  Future<bool> _confirmDelete({
    required RoutineItem keep,
    required RoutineItem delete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${delete.title}?'),
          content: Text(
            'Keeping "${keep.title}" will delete "${delete.title}". This cannot be silently undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: OptivusColors.danger,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete ${_shortTitle(delete)}'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final conflict = widget.conflict;
    final item = widget.item;
    final other = widget.other;
    final color = conflict.resolution == RoutineConflictResolution.allowedByUser
        ? OptivusColors.success
        : conflict.blocking
        ? OptivusColors.danger
        : OptivusColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                conflict.resolution == RoutineConflictResolution.allowedByUser
                    ? Icons.check_circle_rounded
                    : conflict.blocking
                    ? Icons.block_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  conflict.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (conflict.resolution ==
              RoutineConflictResolution.allowedByUser) ...[
            const Text(
              'Overlap allowed by you',
              style: TextStyle(
                color: OptivusColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            conflict.message,
            style: const TextStyle(
              fontSize: 12,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            TimelineUtils.formatTimeRange(
              conflict.startMinute,
              conflict.endMinute,
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResolverAction(
                label: 'Keep both',
                icon: Icons.layers_rounded,
                color: OptivusColors.success,
                pending: _pending,
                onTap:
                    conflict.canKeepBoth && !_pending && !widget.isSheetPending
                    ? () => _runWrite(
                        () => widget.ref
                            .read(routineNotifierProvider.notifier)
                            .keepConflictPair(conflict),
                      )
                    : null,
              ),
              if (item != null)
                _ResolverAction(
                  label: 'Edit time',
                  icon: Icons.schedule_rounded,
                  color: OptivusColors.textSecondary,
                  pending: _pending,
                  onTap: _pending || widget.isSheetPending
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (widget.parentContext.mounted) {
                              showRoutineMoveSheet(
                                widget.parentContext,
                                widget.ref,
                                item,
                              );
                            }
                          });
                        },
                ),
              if (item != null)
                _ResolverAction(
                  label: 'Mark flexible',
                  icon: Icons.flare_rounded,
                  color: OptivusColors.warning,
                  pending: _pending,
                  onTap: _pending || widget.isSheetPending
                      ? null
                      : () => _runWrite(
                          () => widget.ref
                              .read(routineNotifierProvider.notifier)
                              .markFlexible(item.id),
                        ),
                ),
              if (other != null)
                _ResolverAction(
                  label: 'Keep ${_shortTitle(other)}',
                  icon: Icons.check_rounded,
                  color: OptivusColors.aquaAccent,
                  pending: _pending,
                  onTap: item == null || _pending || widget.isSheetPending
                      ? null
                      : () async {
                          final confirmed = await _confirmDelete(
                            keep: other,
                            delete: item,
                          );
                          if (!confirmed || !mounted) return;
                          await _runWrite(
                            () => widget.ref
                                .read(routineNotifierProvider.notifier)
                                .deleteItem(item.id),
                          );
                        },
                ),
              _ResolverAction(
                label: 'Resolve later',
                icon: Icons.history_rounded,
                color: OptivusColors.textSecondary,
                pending: _pending,
                onTap: _pending || widget.isSheetPending
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMessage!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: OptivusColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolverAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool pending;
  final VoidCallback? onTap;

  const _ResolverAction({
    required this.label,
    required this.icon,
    required this.color,
    this.pending = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.46,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              if (pending && enabled) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
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

class _ResolverIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ResolverIconButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

String _shortTitle(RoutineItem item) {
  final title = item.title.trim();
  if (title.length <= 16) return title;
  return '${title.substring(0, 15)}...';
}
