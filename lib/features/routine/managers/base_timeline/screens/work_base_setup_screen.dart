import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/schedule_setup_flow.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';

class WorkBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const WorkBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<WorkBaseSetupScreen> createState() =>
      _WorkBaseSetupScreenState();
}

class _WorkBaseSetupScreenState extends ConsumerState<WorkBaseSetupScreen> {
  bool _isEditing = false;
  int _selectedDay = 1;
  String? _frontBlockId;
  int? _refreshPendingRevision;
  String? _refreshPendingMessage;
  int? _editorBaseRevision;
  String? _editorOwnerUid;

  Future<void> _handleRemoveWorkSetup(
    BaseTimelineSetup setup,
    String uid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Work Setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will remove all work and business blocks from your Base Timeline. This action cannot be undone.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('work-confirm-remove-button'),
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final expectedRevision = _editorBaseRevision ?? setup.revision;
    final oldAssetId = setup.workLogicalAssetId;
    final oldObjectKey = setup.workLogicalAssetR2Key;

    try {
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.work,
        newBlocks: const [],
        expectedRevision: expectedRevision,
        updateSetup: (current) => current.copyWith(
          workBlocks: const [],
          clearWorkLogicalAssetId: true,
          clearWorkLogicalAssetR2Key: true,
          updatedAt: DateTime.now(),
        ),
      );

      if (oldAssetId != null) {
        try {
          final lifecycleHelper = ref.read(
            baseTimelineUploadLifecycleHelperProvider,
          );
          await lifecycleHelper.retireReplacedAsset(
            uid: uid,
            oldAssetId: oldAssetId,
            oldObjectKey: oldObjectKey,
          );
        } catch (err) {
          debugPrint('Failed retiring old work asset on remove: $err');
        }
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _editorBaseRevision = result.revision;
          _refreshPendingRevision = result.routineRefreshPending
              ? result.revision
              : null;
          _refreshPendingMessage = result.routineRefreshMessage;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.routineRefreshPending
                  ? 'Work setup removed. Routine needs to refresh.'
                  : 'Work setup removed.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to remove Work setup: $e'),
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
        final snapshot = setup.snapshotFor(BaseTimelineSection.work);

        if (_isEditing) {
          return ScheduleSetupFlow(
            config: ScheduleSetupConfig.workSetup,
            initialBlocks: setup.workBlocks,
            initialAssetId: setup.workLogicalAssetId,
            initialR2Key: setup.workLogicalAssetR2Key,
            onCancel: () => setState(() {
              _isEditing = false;
              _editorBaseRevision = null;
              _editorOwnerUid = null;
            }),
            onSave: (newBlocks, assetId, r2Key) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final uid =
                    _editorOwnerUid ?? ref.read(userProfileProvider).uid;
                if (uid.trim().isEmpty ||
                    ref.read(userProfileProvider).uid != uid) {
                  throw StateError(
                    'The active account changed. Reload Work setup.',
                  );
                }
                final coordinator = ref.read(
                  baseTimelineTransactionCoordinatorProvider,
                );
                final result = await coordinator.replaceSection(
                  uid: uid,
                  section: BaseTimelineSection.work,
                  newBlocks: newBlocks,
                  expectedRevision: _editorBaseRevision,
                  updateSetup: (current) => current.copyWith(
                    workBlocks: newBlocks,
                    workLogicalAssetId: assetId,
                    clearWorkLogicalAssetId: assetId == null,
                    workLogicalAssetR2Key: r2Key,
                    clearWorkLogicalAssetR2Key: r2Key == null,
                    updatedAt: DateTime.now(),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _isEditing = false;
                    _editorBaseRevision = result.revision;
                    _refreshPendingRevision = result.routineRefreshPending
                        ? result.revision
                        : null;
                    _refreshPendingMessage = result.routineRefreshMessage;
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        result.routineRefreshPending
                            ? 'Saved. Routine needs to refresh.'
                            : 'Work schedule updated successfully',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to update work schedule: $err'),
                      backgroundColor: OptivusColors.danger,
                    ),
                  );
                }
                rethrow;
              }
            },
          );
        }

        // Current Setup View
        const adapter = BaseTimelineWorkAdapter(accent: OptivusColors.warning);
        final entries = setup.workBlocks
            .expand((b) => adapter.toEntries(b))
            .toList();
        final draftMap = {
          for (final block in setup.workBlocks) block.id: block,
        };

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BaseTimelineCurrentSetupHeader(
                  title: 'Work / Business',
                  summary: snapshot.summary,
                  accent: OptivusColors.warning,
                  onBack: widget.onBack,
                  primaryButtonLabel: snapshot.isConfigured
                      ? 'Change setup'
                      : 'Set up Work',
                  onPrimaryAction: () => setState(() {
                    _editorBaseRevision = setup.revision;
                    _editorOwnerUid = setup.uid;
                    _isEditing = true;
                  }),
                  removeLabel: 'Remove Work Setup',
                  onRemove: snapshot.isConfigured
                      ? () => _handleRemoveWorkSetup(setup, setup.uid)
                      : null,
                ),

                // Source Photo Preview
                if (snapshot.sourceR2Key != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BaseTimelinePhotoPreviewCard(
                      r2Key: snapshot.sourceR2Key,
                      assetId: snapshot.sourceAssetId,
                      title: 'Work Schedule Photo',
                      height: 140,
                    ),
                  ),

                if (_refreshPendingRevision != null)
                  BaseTimelineRefreshPendingBanner(
                    message: _refreshPendingMessage,
                    onRetry: () async {
                      final uid = ref.read(userProfileProvider).uid;
                      final result = await ref
                          .read(baseTimelineTransactionCoordinatorProvider)
                          .retryRoutineRefresh(
                            uid: uid,
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

                // Timeline View
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
                      final block = draftMap[positioned.entry.sourceId];
                      if (block == null) return const SizedBox.shrink();
                      return BaseTimelineDomainCard(
                        positioned: positioned,
                        block: block,
                        domain: BaseTimelineCardDomain.work,
                        accent: OptivusColors.warning,
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
                    accent: OptivusColors.warning,
                    mode: TimelineMode.previewReadOnly,
                    visibleRangePolicy:
                        TimelineVisibleRangePolicy.contentAdaptive,
                    stretchPolicy: TimelineStretchPolicy.constraintBased,
                    emptyDayMessage: 'No work blocks on this day.',
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
