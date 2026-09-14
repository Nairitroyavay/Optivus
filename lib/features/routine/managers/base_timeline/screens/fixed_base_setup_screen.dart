import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/fixed_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';

class FixedBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const FixedBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<FixedBaseSetupScreen> createState() =>
      _FixedBaseSetupScreenState();
}

class _FixedBaseSetupScreenState extends ConsumerState<FixedBaseSetupScreen> {
  bool _isEditing = false;
  int _selectedDay = 1;
  bool _isSaving = false;
  bool _isDirty = false;
  int? _editorBaseRevision;
  int? _refreshPendingRevision;
  String? _refreshPendingMessage;
  String? _frontBlockId;
  String? _editorOwnerUid;
  String? _errorMessage;

  late List<TimelineBlockDraft> _workingBlocks;

  void _initWorkingBlocks(
    List<TimelineBlockDraft> existing,
    int revision,
    String ownerUid,
  ) {
    _editorBaseRevision = revision;
    _editorOwnerUid = ownerUid;
    if (existing.isEmpty) {
      _workingBlocks = [
        TimelineBlockDraft(
          id: BaseTimelineDraft.fixedSleepId,
          title: 'Sleep',
          startMinute: 23 * 60,
          endMinute: 7 * 60,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          section: 'fixed',
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
          endsNextDay: true,
        ),
        TimelineBlockDraft(
          id: BaseTimelineDraft.fixedBathId,
          title: 'Bath & Grooming',
          startMinute: 7 * 60 + 15,
          endMinute: 7 * 60 + 45,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          section: 'fixed',
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ];
    } else {
      _workingBlocks = List.from(existing);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard this setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          "Your current Fixed setup won't be affected.",
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _addCustomBlock() {
    final newBlock = TimelineBlockDraft(
      id: 'fixed_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Fixed Block',
      startMinute: 12 * 60,
      endMinute: 13 * 60,
      repeatDays: const [1, 2, 3, 4, 5],
      section: 'fixed',
      blockType: TimelineBlockDraft.hardBlockKey,
    );

    FixedTimelineAdapter.showFixedEditSheet(
      context: context,
      block: newBlock,
      onSave: (updated) async {
        setState(() {
          _workingBlocks.add(updated);
          _isDirty = true;
        });
        return true;
      },
    );
  }

  void _editBlock(TimelineBlockDraft block) {
    FixedTimelineAdapter.showFixedEditSheet(
      context: context,
      block: block,
      onSave: (updated) async {
        setState(() {
          final index = _workingBlocks.indexWhere((b) => b.id == block.id);
          if (index != -1) {
            _workingBlocks[index] = updated;
            _isDirty = true;
          }
        });
        return true;
      },
    );
  }

  bool _isRequiredBlock(TimelineBlockDraft block) =>
      block.id == BaseTimelineDraft.fixedSleepId ||
      block.id == BaseTimelineDraft.fixedBathId;

  void _deleteCustomBlock(TimelineBlockDraft block) {
    if (_isRequiredBlock(block)) return;
    setState(() {
      _workingBlocks.removeWhere((candidate) => candidate.id == block.id);
      if (_frontBlockId == block.id) _frontBlockId = null;
      _isDirty = true;
    });
  }

  Future<void> _saveWorkingBlocks() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(userProfileProvider).uid;
      if (uid.trim().isEmpty || uid != _editorOwnerUid) {
        throw StateError('The active account changed. Reload Fixed setup.');
      }
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.fixed,
        newBlocks: _workingBlocks,
        expectedRevision: _editorBaseRevision,
        updateSetup: (current) => current.copyWith(
          fixedBlocks: _workingBlocks,
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _isDirty = false;
          _editorBaseRevision = result.revision;
          _refreshPendingRevision = result.routineRefreshPending
              ? result.revision
              : null;
          _refreshPendingMessage = result.routineRefreshMessage;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.routineRefreshPending
                  ? 'Saved. Routine needs to refresh.'
                  : 'Fixed routine blocks updated successfully',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isConflict = e.toString().toLowerCase().contains('conflict') ||
            e.toString().toLowerCase().contains('concurrency');
        setState(() {
          _isSaving = false;
          _errorMessage = isConflict
              ? 'This setup changed elsewhere. Reload the latest setup before saving again.'
              : 'Failed to save Fixed setup. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update fixed blocks: $e'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);

    return setupAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Failed to load setup',
                style: TextStyle(color: OptivusColors.textPrimary),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(baseTimelineSetupNotifierProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (setup) {
        final snapshot = setup.snapshotFor(BaseTimelineSection.fixed);
        const adapter = FixedTimelineAdapter(
          accent: OptivusColors.purpleAccent,
        );

        if (_isEditing) {
          final entries = _workingBlocks
              .expand((b) => adapter.toEntries(b))
              .toList();
          final workingMap = {
            for (final block in _workingBlocks) block.id: block,
          };
          final sleepBlock = _workingBlocks
              .where((b) => b.id == BaseTimelineDraft.fixedSleepId)
              .firstOrNull;
          final bathBlock = _workingBlocks
              .where((b) => b.id == BaseTimelineDraft.fixedBathId)
              .firstOrNull;

          return PopScope(
            canPop: !_isDirty && !_isSaving,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop || _isSaving) return;
              if (await _confirmDiscard()) {
                setState(() => _isEditing = false);
              }
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: OptivusColors.textPrimary,
                            ),
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    if (await _confirmDiscard()) {
                                      setState(() => _isEditing = false);
                                    }
                                  },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Edit Fixed Blocks',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.purpleAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveWorkingBlocks,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Sleep and Bath Quick Editors
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: OptivusColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (_errorMessage!.contains('changed elsewhere'))
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(
                                        baseTimelineSetupNotifierProvider
                                            .notifier,
                                      )
                                      .load();
                                  if (mounted) {
                                    setState(() => _isEditing = false);
                                  }
                                },
                                child: const Text('Reload latest'),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          if (sleepBlock != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.bedtime_rounded,
                                          size: 16,
                                          color: OptivusColors.purpleAccent,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Sleep',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _editBlock(sleepBlock),
                                      child: Text(
                                        '${TimelineUtils.formatMinute(sleepBlock.startMinute)} – ${TimelineUtils.formatMinute(sleepBlock.endMinute)}',
                                        style: const TextStyle(
                                          color: OptivusColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          if (bathBlock != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.bathtub_rounded,
                                          size: 16,
                                          color: OptivusColors.purpleAccent,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Bath',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _editBlock(bathBlock),
                                      child: Text(
                                        '${TimelineUtils.formatMinute(bathBlock.startMinute)} – ${TimelineUtils.formatMinute(bathBlock.endMinute)}',
                                        style: const TextStyle(
                                          color: OptivusColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Add Custom Block Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Custom Fixed Block'),
                        onPressed: _addCustomBlock,
                      ),
                    ),

                    // Interactive Timeline View
                    Expanded(
                      child: FullScreenTimelineScaffold(
                        entries: entries,
                        selectedDay: _selectedDay,
                        onDayChanged: (day) =>
                            setState(() => _selectedDay = day),
                        styleBuilder: (entry) => adapter.styleForEntry(entry),
                        overlapPresentation:
                            TimelineOverlapPresentation.frontAndExposed,
                        frontEntryId: _frontBlockId,
                        onFrontSelected: (id) =>
                            setState(() => _frontBlockId = id),
                        blockBuilder: (context, positioned) {
                          final block = workingMap[positioned.entry.sourceId];
                          if (block == null) return const SizedBox.shrink();
                          return BaseTimelineDomainCard(
                            positioned: positioned,
                            block: block,
                            domain: BaseTimelineCardDomain.fixed,
                            accent: OptivusColors.purpleAccent,
                            isEditable: true,
                            onTap: () {
                              if (positioned.hasOverlap &&
                                  !positioned.isFront) {
                                HapticFeedback.lightImpact();
                                setState(
                                  () => _frontBlockId = positioned.entry.id,
                                );
                              } else {
                                _editBlock(block);
                              }
                            },
                            onDelete: _isRequiredBlock(block)
                                ? null
                                : () => _deleteCustomBlock(block),
                          );
                        },
                        accent: OptivusColors.purpleAccent,
                        onEntryTapped: null,
                        visibleRangePolicy:
                            TimelineVisibleRangePolicy.contentAdaptive,
                        stretchPolicy: TimelineStretchPolicy.constraintBased,
                        emptyDayMessage: 'No fixed blocks on this day.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Current Setup View
        final entries = setup.fixedBlocks
            .expand((b) => adapter.toEntries(b))
            .toList();
        final blockMap = {
          for (final block in setup.fixedBlocks) block.id: block,
        };

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Nav Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: OptivusColors.textPrimary,
                        ),
                        onPressed: widget.onBack,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fixed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                            Text(
                              snapshot.summary,
                              style: const TextStyle(
                                fontSize: 12,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                        label: Text(
                          snapshot.isConfigured
                              ? 'Change setup'
                              : 'Set up Fixed',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: OptivusColors.purpleAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          _initWorkingBlocks(
                            setup.fixedBlocks,
                            setup.revision,
                            setup.uid,
                          );
                          setState(() {
                            _isEditing = true;
                            _isDirty = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Timeline View
                if (_refreshPendingRevision != null)
                  BaseTimelineRefreshPendingBanner(
                    message: _refreshPendingMessage,
                    onRetry: () async {
                      final result = await ref
                          .read(baseTimelineTransactionCoordinatorProvider)
                          .retryRoutineRefresh(
                            uid: ref.read(userProfileProvider).uid,
                            targetRevision: _refreshPendingRevision,
                          );
                      if (mounted && result.isRefreshed) {
                        setState(() {
                          _refreshPendingRevision = null;
                          _refreshPendingMessage = null;
                        });
                      }
                    },
                  ),
                Expanded(
                  child: FullScreenTimelineScaffold(
                    entries: entries,
                    selectedDay: _selectedDay,
                    onDayChanged: (day) => setState(() => _selectedDay = day),
                    styleBuilder: (entry) => adapter.styleForEntry(entry),
                    overlapPresentation:
                        TimelineOverlapPresentation.frontAndExposed,
                    frontEntryId: _frontBlockId,
                    onFrontSelected: (id) => setState(() => _frontBlockId = id),
                    blockBuilder: (context, positioned) {
                      final block = blockMap[positioned.entry.sourceId];
                      if (block == null) return const SizedBox.shrink();
                      return BaseTimelineDomainCard(
                        positioned: positioned,
                        block: block,
                        domain: BaseTimelineCardDomain.fixed,
                        accent: OptivusColors.purpleAccent,
                        isEditable: false,
                        onTap: positioned.hasOverlap && !positioned.isFront
                            ? () {
                                HapticFeedback.lightImpact();
                                setState(
                                  () => _frontBlockId = positioned.entry.id,
                                );
                              }
                            : null,
                      );
                    },
                    accent: OptivusColors.purpleAccent,
                    mode: TimelineMode.previewReadOnly,
                    visibleRangePolicy:
                        TimelineVisibleRangePolicy.contentAdaptive,
                    stretchPolicy: TimelineStretchPolicy.constraintBased,
                    emptyDayMessage: 'No fixed blocks configured.',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
