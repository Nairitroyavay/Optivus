import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';

class RoutineWriteStatusBanner extends ConsumerStatefulWidget {
  const RoutineWriteStatusBanner({super.key});

  @override
  ConsumerState<RoutineWriteStatusBanner> createState() =>
      _RoutineWriteStatusBannerState();
}

class _RoutineWriteStatusBannerState
    extends ConsumerState<RoutineWriteStatusBanner> {
  String? _retryingKey;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final operation = _firstFailedOperation(ref.watch(routineNotifierProvider));
    if (operation == null) return const SizedBox.shrink();

    final retrying = _retryingKey == operation.key;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OptivusColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OptivusColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: OptivusColors.danger,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  operation.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.danger,
                  ),
                ),
                Text(
                  _message ?? operation.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.danger,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: retrying ? null : () => _retry(operation),
            child: retrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Retry',
                    style: TextStyle(color: OptivusColors.danger),
                  ),
          ),
          TextButton(
            onPressed: retrying ? null : () => _dismiss(operation),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: OptivusColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(_FailedRoutineWrite operation) async {
    setState(() {
      _retryingKey = operation.key;
      _message = null;
    });
    final result = await operation.retry(ref);
    if (!mounted) return;
    setState(() {
      _retryingKey = null;
      _message = result.closesUserFlow
          ? null
          : result.validation?.userSafeMessage ??
                result.message ??
                'Retry failed. Please try again.';
    });
  }

  void _dismiss(_FailedRoutineWrite operation) {
    operation.dismiss(ref);
    if (!mounted) return;
    setState(() {
      _retryingKey = null;
      _message = null;
    });
  }

  _FailedRoutineWrite? _firstFailedOperation(RoutineState state) {
    if (state.failedIntentsByItemId.isNotEmpty) {
      final intent = state.failedIntentsByItemId.values.first;
      final item = intent.attemptedItem ?? intent.previousItem;
      final itemTitle = item?.title.trim();
      final title = switch (intent.action) {
        RoutineWriteAction.create => 'Routine item was not saved',
        RoutineWriteAction.update => 'Routine item update was not saved',
        RoutineWriteAction.delete => 'Routine item delete was not saved',
        RoutineWriteAction.moveTemplate => 'Routine move was not saved',
        RoutineWriteAction.batchCreate => 'Routine batch was not saved',
        RoutineWriteAction.keepBoth => 'Schedule update was not saved',
      };
      return _FailedRoutineWrite(
        key: 'template:${intent.itemId}',
        title: title,
        subtitle: itemTitle == null || itemTitle.isEmpty
            ? 'Retry the original ${intent.action.name} operation.'
            : '"$itemTitle" needs retry before it is durable.',
        retry: (ref) => ref
            .read(routineNotifierProvider.notifier)
            .retryFailedOperation(intent.itemId),
        dismiss: (ref) {
          final notifier = ref.read(routineNotifierProvider.notifier);
          if (intent.action == RoutineWriteAction.create) {
            notifier.discardFailedCreate(intent.itemId);
          } else {
            notifier.dismissFailedOperation(intent.itemId);
          }
        },
      );
    }

    if (state.failedOccurrenceIntentsById.isNotEmpty) {
      final intent = state.failedOccurrenceIntentsById.values.first;
      final snapshotTitle =
          intent.event?.itemSnapshot['title'] as String? ??
          intent.attemptedRecord.displayTitleOverride;
      return _FailedRoutineWrite(
        key: 'occurrence:${intent.occurrenceId}',
        title: 'Routine action was not saved',
        subtitle: snapshotTitle == null || snapshotTitle.trim().isEmpty
            ? 'Retry the original ${intent.action.name} action.'
            : '"$snapshotTitle" ${intent.action.name} needs retry before it is durable.',
        retry: (ref) => ref
            .read(routineNotifierProvider.notifier)
            .retryFailedOccurrenceAction(intent.occurrenceId),
        dismiss: (ref) => ref
            .read(routineNotifierProvider.notifier)
            .dismissFailedOccurrenceAction(intent.occurrenceId),
      );
    }

    if (state.failedBatchIntentsByOperationId.isNotEmpty) {
      final intent = state.failedBatchIntentsByOperationId.values.first;
      final isKeepBoth = intent.action == RoutineWriteAction.keepBoth;
      return _FailedRoutineWrite(
        key: 'batch:${intent.operationId}',
        title: isKeepBoth
            ? 'Schedule update was not saved'
            : 'Routine import batch was not saved',
        subtitle: isKeepBoth
            ? 'Retry the schedule update.'
            : 'Retry adding ${intent.attemptedItems.length} imported routine item${intent.attemptedItems.length == 1 ? '' : 's'}.',
        retry: (ref) => ref
            .read(routineNotifierProvider.notifier)
            .retryFailedBatchOperation(intent.operationId),
        dismiss: (ref) => ref
            .read(routineNotifierProvider.notifier)
            .discardFailedBatchOperation(intent.operationId),
      );
    }

    return null;
  }
}

class _FailedRoutineWrite {
  final String key;
  final String title;
  final String subtitle;
  final Future<RoutineWriteResult> Function(WidgetRef ref) retry;
  final void Function(WidgetRef ref) dismiss;

  const _FailedRoutineWrite({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.retry,
    required this.dismiss,
  });
}
