import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/schedule_setup_flow.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';

class ClassesBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ClassesBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<ClassesBaseSetupScreen> createState() =>
      _ClassesBaseSetupScreenState();
}

class _ClassesBaseSetupScreenState
    extends ConsumerState<ClassesBaseSetupScreen> {
  bool _isEditing = false;
  int _selectedDay = 1;

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
        final snapshot = setup.snapshotFor(BaseTimelineSection.classes);

        if (_isEditing) {
          return ScheduleSetupFlow(
            config: ScheduleSetupConfig.classSetup,
            initialBlocks: setup.classBlocks,
            initialAssetId: setup.classLogicalAssetId,
            initialR2Key: setup.classLogicalAssetR2Key,
            onCancel: () => setState(() => _isEditing = false),
            onSave: (newBlocks, assetId, r2Key) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final uid = ref.read(userProfileProvider).uid;
                final coordinator = ref.read(
                  baseTimelineTransactionCoordinatorProvider,
                );
                await coordinator.replaceSection(
                  uid: uid,
                  section: BaseTimelineSection.classes,
                  newBlocks: newBlocks,
                  updateSetup: (current) => current.copyWith(
                    classBlocks: newBlocks,
                    classLogicalAssetId: assetId,
                    clearClassLogicalAssetId: assetId == null,
                    classLogicalAssetR2Key: r2Key,
                    clearClassLogicalAssetR2Key: r2Key == null,
                    updatedAt: DateTime.now(),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _isEditing = false;
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Classes schedule updated successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to update classes: $err'),
                      backgroundColor: OptivusColors.danger,
                    ),
                  );
                }
              }
            },
          );
        }

        // Current Setup View
        const adapter = ClassTimelineAdapter(accent: OptivusColors.blueAccent);
        final routineBlocks = setup.classBlocks.map((b) {
          return ClassRoutineBlock(
            id: b.id,
            subject: b.title,
            room: b.location ?? '',
            professor: '',
            startMinute: b.startMinute,
            endMinute: b.endMinute,
            repeatDays: b.repeatDays.isEmpty
                ? const [1, 2, 3, 4, 5]
                : b.repeatDays,
          );
        }).toList();

        final entries = routineBlocks
            .expand((b) => adapter.toEntries(b))
            .toList();

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
                              'Classes',
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
                        label: const Text('Change setup'),
                        style: FilledButton.styleFrom(
                          backgroundColor: OptivusColors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                    ],
                  ),
                ),

                // Source Photo Preview (Truthful Presigned R2)
                if (snapshot.sourceR2Key != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BaseTimelinePhotoPreviewCard(
                      r2Key: snapshot.sourceR2Key,
                      assetId: snapshot.sourceAssetId,
                      title: 'Timetable Photo',
                      height: 140,
                    ),
                  ),

                // Timeline View
                Expanded(
                  child: FullScreenTimelineScaffold(
                    entries: entries,
                    selectedDay: _selectedDay,
                    onDayChanged: (day) => setState(() => _selectedDay = day),
                    styleBuilder: (entry) => adapter.styleForEntry(entry),
                    accent: OptivusColors.blueAccent,
                    mode: TimelineMode.previewReadOnly,
                    emptyDayMessage: 'No classes on this day.',
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
