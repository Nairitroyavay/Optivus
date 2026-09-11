import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

class EatingBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const EatingBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<EatingBaseSetupScreen> createState() =>
      _EatingBaseSetupScreenState();
}

class _EatingBaseSetupScreenState extends ConsumerState<EatingBaseSetupScreen> {
  bool _isEditing = false;
  int _selectedDay = 1;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isExtracting = false;
  String? _errorMessage;
  String _aiActionTitle = 'Processing meal plan...';
  List<String> _aiProgressMessages = const [
    'Analyzing nutritional targets...',
    'Distributing meal timing and macros...',
    'Balancing weekly variety...',
  ];

  // Working setup state
  late List<TimelineBlockDraft> _workingBlocks;
  String? _workingGoal;
  int? _workingMealsPerDay;
  String? _workingFoodType;
  int? _workingTargetCalories;
  int? _workingTargetProtein;
  String? _workingAssetId;
  String? _workingR2Key;
  String? _workingSetupPath;

  void _initWorkingState(dynamic setup) {
    _workingBlocks = List.from(setup.eatingBlocks);
    _workingGoal = setup.mealPlanningGoal ?? 'maintain';
    _workingMealsPerDay = setup.mealsPerDay ?? 3;
    _workingFoodType = setup.foodType ?? 'Balanced';
    _workingTargetCalories = setup.targetCalories ?? 2000;
    _workingTargetProtein = setup.targetProtein ?? 130;
    _workingAssetId = setup.eatingPhotoAssetId;
    _workingR2Key = setup.eatingPhotoR2Key;
    _workingSetupPath = setup.eatingSetupPath ?? 'create';
    _isDirty = false;
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Any unsaved eating schedule edits will be lost.',
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

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

    final uploadNotifier = ref.read(uploadControllerProvider.notifier);

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _aiActionTitle = 'Analyzing meal plan photo...';
      _aiProgressMessages = const [
        'Uploading high-resolution image...',
        'Extracting meals and schedule timings...',
        'Formatting timeline entries...',
      ];
    });

    try {
      final asset = await uploadNotifier.startUpload(
        uid: uid,
        sourceFeature: 'routine_base_timeline',
        purpose: UploadedAssetPurpose.eatingMenu,
        source: source,
      );

      if (asset == null) {
        if (mounted) setState(() => _isExtracting = false);
        return;
      }

      _workingAssetId = asset.assetId;
      _workingR2Key = asset.r2Key;
      _workingSetupPath = 'has_routine';

      final reviewDraft = RoutineImportReviewDraft(
        id: 'rev_${asset.assetId}',
        uid: uid,
        source: RoutineImportReviewSource.eating,
        status: RoutineImportReviewStatus.draft,
        sourceLabel: 'Eating',
        uploadedAssetId: asset.assetId,
        uploadedAssetR2Key: asset.r2Key,
        uploadedAssetStatus: 'uploaded',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final result = await aiController.runExtraction(reviewDraft);

      if (result != null && result.candidates.isNotEmpty) {
        final extracted = result.candidates.map((c) {
          return TimelineBlockDraft(
            id: c.id,
            title: c.title,
            startMinute: c.startMinute,
            endMinute: c.endMinute,
            repeatDays: c.repeatDays.isEmpty
                ? const [1, 2, 3, 4, 5, 6, 7]
                : c.repeatDays,
            section: 'eating',
            blockType: TimelineBlockDraft.softBlockKey,
            mealCategory: c.title,
            dishes: [c.title],
          );
        }).toList();

        if (mounted) {
          setState(() {
            _workingBlocks = extracted;
            _isDirty = true;
            _isExtracting = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isExtracting = false;
            _errorMessage =
                result?.warnings.firstOrNull ??
                'No meals detected. You can add meals manually.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = 'Upload failed. Please try again or edit manually.';
        });
      }
    }
  }

  Future<void> _generateBalancedPlan() async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

    final idToken =
        await ref.read(authRepositoryProvider).currentIdToken() ?? '';
    final engine = ref.read(eatingDomainEngineProvider);
    final profile = ref.read(userProfileProvider);
    final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
    final currentSetup =
        setupAsync.value ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

    final workingSetup = currentSetup.copyWith(
      mealPlanningGoal: _workingGoal,
      mealsPerDay: _workingMealsPerDay,
      foodType: _workingFoodType,
      targetCalories: _workingTargetCalories,
      targetProtein: _workingTargetProtein,
    );

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _aiActionTitle = 'Generating balanced meal plan...';
      _aiProgressMessages = const [
        'Calculating canonical macro targets...',
        'Structuring breakfast, lunch, and dinner slots...',
        'Ensuring daily and weekly meal diversity...',
      ];
    });

    try {
      final targets = engine.calculateTargets(
        profile: profile,
        setup: workingSetup,
      );
      final inputs = engine.buildInputs(
        profile: profile,
        setup: workingSetup,
        targets: targets,
      );

      final blocks = await engine.generateEatingRoutine(
        uid: uid,
        idToken: idToken,
        inputs: inputs,
        targets: targets,
        baseTimeline: workingSetup.toBaseTimelineDraft(),
      );

      if (mounted) {
        setState(() {
          _workingBlocks = blocks;
          _workingSetupPath = 'create';
          _workingTargetCalories = targets.targetCalories;
          _workingTargetProtein = targets.proteinTarget?.round();
          // Clear photo provenance when switching to generated mode
          _workingAssetId = null;
          _workingR2Key = null;
          _isDirty = true;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('StateError: ', '');
        });
      }
    }
  }

  void _addMealBlock() {
    final newBlock = TimelineBlockDraft(
      id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Snack',
      startMinute: 16 * 60,
      endMinute: 16 * 60 + 30,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      section: 'eating',
      blockType: TimelineBlockDraft.softBlockKey,
      mealCategory: 'Snack',
      dishes: const ['Healthy Snack'],
    );

    MealTimelineAdapter.showMealEditSheet(
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

  void _editMealBlock(TimelineBlockDraft block) {
    MealTimelineAdapter.showMealEditSheet(
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

  Future<void> _saveWorkingSetup() async {
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(userProfileProvider).uid;
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.eating,
        newBlocks: _workingBlocks,
        updateSetup: (current) => current.copyWith(
          eatingBlocks: _workingBlocks,
          eatingSetupPath: _workingSetupPath,
          mealPlanningGoal: _workingGoal,
          mealsPerDay: _workingMealsPerDay,
          foodType: _workingFoodType,
          targetCalories: _workingTargetCalories,
          targetProtein: _workingTargetProtein,
          eatingPhotoAssetId: _workingAssetId,
          clearEatingPhotoAssetId: _workingAssetId == null,
          eatingPhotoR2Key: _workingR2Key,
          clearEatingPhotoR2Key: _workingR2Key == null,
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _isDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eating schedule updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update eating schedule: $e'),
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
        final snapshot = setup.snapshotFor(BaseTimelineSection.eating);
        const adapter = MealTimelineAdapter(accent: OptivusColors.roseAccent);

        if (_isEditing) {
          final entries = _workingBlocks
              .expand((b) => adapter.toEntries(b))
              .toList();

          return PopScope(
            canPop: !_isDirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop) {
                if (await _confirmDiscard()) {
                  setState(() => _isEditing = false);
                }
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
                            onPressed: () async {
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
                              'Edit Eating Schedule',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.roseAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveWorkingSetup,
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

                    // Setup Path Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: OptivusColors.roseAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                              ),
                              label: const Text('Build Balanced Plan'),
                              onPressed: _isExtracting
                                  ? null
                                  : _generateBalancedPlan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                              ),
                              label: const Text('Scan Photo'),
                              onPressed: _isExtracting
                                  ? null
                                  : _showPhotoSourceSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                            style: IconButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isExtracting ? null : _addMealBlock,
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: OptivusColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Interactive Timeline View
                    Expanded(
                      child: _isExtracting
                          ? BaseTimelineAiThinkingView(
                              initialMessage: _aiActionTitle,
                              progressMessages: _aiProgressMessages,
                            )
                          : FullScreenTimelineScaffold(
                              entries: entries,
                              selectedDay: _selectedDay,
                              onDayChanged: (day) =>
                                  setState(() => _selectedDay = day),
                              styleBuilder: (entry) =>
                                  adapter.styleForEntry(entry),
                              accent: OptivusColors.roseAccent,
                              onEntryTapped: (entry) {
                                final block = _workingBlocks
                                    .where((b) => b.id == entry.sourceId)
                                    .firstOrNull;
                                if (block != null) {
                                  _editMealBlock(block);
                                }
                              },
                              emptyDayMessage: 'No meals on this day.',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Current Setup View
        final entries = setup.eatingBlocks
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
                              'Eating',
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
                          backgroundColor: OptivusColors.roseAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          _initWorkingState(setup);
                          setState(() {
                            _isEditing = true;
                            _isDirty = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Targets card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${setup.targetCalories ?? 2100} kcal',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Daily Target',
                              style: TextStyle(
                                fontSize: 11,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        Column(
                          children: [
                            Text(
                              '${setup.targetProtein ?? 140} g',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Protein',
                              style: TextStyle(
                                fontSize: 11,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        Column(
                          children: [
                            Text(
                              '${setup.mealsPerDay ?? 3} meals',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Frequency',
                              style: TextStyle(
                                fontSize: 11,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Source Photo Preview
                if (snapshot.sourceR2Key != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BaseTimelinePhotoPreviewCard(
                      r2Key: snapshot.sourceR2Key,
                      assetId: snapshot.sourceAssetId,
                      title: 'Meal Plan Photo',
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
                    accent: OptivusColors.roseAccent,
                    mode: TimelineMode.previewReadOnly,
                    emptyDayMessage: 'No eating schedule configured.',
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
