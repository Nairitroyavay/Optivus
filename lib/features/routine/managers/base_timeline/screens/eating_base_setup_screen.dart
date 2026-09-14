import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

List<String> _importedMealDishes(RoutineImportCandidateBlock candidate) {
  final dishes = <String>{};
  void add(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length >= 2 &&
        clean.toLowerCase() != candidate.title.trim().toLowerCase()) {
      dishes.add(clean);
    }
  }

  for (final step in candidate.steps) {
    add(step);
  }
  final sourceText = candidate.sourceTextSnippet;
  if (dishes.isEmpty && sourceText != null) {
    for (final value in sourceText.split(RegExp(r'[,;\n|•·]+'))) {
      add(value);
    }
  }
  return dishes.toList(growable: false);
}

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
  String? _workingEatingMode;
  String? _workingFoodType;
  String? _workingFoodStyleCustomText;
  int? _workingBreakfastMinute;
  int? _workingLunchMinute;
  int? _workingDinnerMinute;
  int? _workingSnackMinute;
  int? _workingExtraSnackMinute;
  int? _workingTargetCalories;
  int? _workingTargetProtein;
  String? _workingAssetId;
  String? _workingR2Key;
  String? _initialAssetId;
  String? _initialR2Key;
  int? _editorBaseRevision;
  int? _refreshPendingRevision;
  String? _refreshPendingMessage;
  String? _frontBlockId;
  int _requestGeneration = 0;
  String? _editorOwnerUid;

  void _initWorkingState(dynamic setup) {
    _workingBlocks = List.from(setup.eatingBlocks);
    _workingGoal = setup.mealPlanningGoal ?? 'maintain';
    _workingMealsPerDay = setup.mealsPerDay ?? 3;
    _workingEatingMode = setup.eatingMode ?? 'india';
    _workingFoodType = setup.foodType ?? 'mixed';
    _workingFoodStyleCustomText = setup.foodStyleCustomText;
    _workingBreakfastMinute = setup.breakfastMinute ?? 480;
    _workingLunchMinute = setup.lunchMinute ?? 780;
    _workingDinnerMinute = setup.dinnerMinute ?? 1230;
    _workingSnackMinute = setup.snackMinute ?? 1020;
    _workingExtraSnackMinute = setup.extraSnackMinute ?? 660;
    _workingTargetCalories = setup.targetCalories ?? 2000;
    _workingTargetProtein = setup.targetProtein ?? 130;
    _workingAssetId = setup.eatingPhotoAssetId;
    _workingR2Key = setup.eatingPhotoR2Key;
    _initialAssetId = setup.eatingPhotoAssetId;
    _initialR2Key = setup.eatingPhotoR2Key;
    _editorBaseRevision = setup.revision;
    _editorOwnerUid = setup.uid;
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
    final confirmed = res ?? false;
    if (confirmed) {
      if (_workingAssetId != null && _workingAssetId != _initialAssetId) {
        try {
          final uid = ref.read(userProfileProvider).uid;
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingAssetId,
            objectKey: _workingR2Key,
          );
        } catch (_) {}
      }
    }
    return confirmed;
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
    final generation = ++_requestGeneration;
    final lifecycleHelper = ref.read(baseTimelineUploadLifecycleHelperProvider);
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

    String? candidateAssetId;
    String? candidateR2Key;

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

      candidateAssetId = asset.assetId;
      candidateR2Key = asset.r2Key;

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
      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
        return;
      }

      final validCandidates =
          result?.candidates
              .where(
                (candidate) =>
                    candidate.repeatDays.isNotEmpty &&
                    candidate.repeatDays.toSet().length ==
                        candidate.repeatDays.length &&
                    candidate.repeatDays.every((day) => day >= 1 && day <= 7) &&
                    _importedMealDishes(candidate).isNotEmpty,
              )
              .toList() ??
          [];

      if (validCandidates.isEmpty) {
        // Cleaning candidate asset while preserving existing schedule intact!
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
        if (mounted) {
          setState(() {
            _isExtracting = false;
            _errorMessage =
                result?.warnings.firstOrNull ??
                'No meals detected in photo. Your existing eating schedule was preserved.';
          });
        }
        return;
      }

      final extracted = validCandidates.map((c) {
        return TimelineBlockDraft(
          id: c.id,
          title: c.title,
          startMinute: c.startMinute,
          endMinute: c.endMinute,
          repeatDays: c.repeatDays,
          section: 'eating',
          blockType: TimelineBlockDraft.softBlockKey,
          mealCategory: c.mealCategory,
          mealSlot: c.mealSlot,
          dishes: _importedMealDishes(c),
          calories: c.caloriesEstimate,
          protein: c.proteinEstimate,
          location: c.location,
          notes: c.notes,
          source: c.extractionEngine,
          provenanceSourceIds: [
            if (c.sourceAssetId?.trim().isNotEmpty == true) c.sourceAssetId!,
          ],
        );
      }).toList();

      // Extraction succeeded: retire previous uncommitted upload if different from initial
      if (_workingAssetId != null && _workingAssetId != _initialAssetId) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingAssetId,
            objectKey: _workingR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _workingAssetId = candidateAssetId;
          _workingR2Key = candidateR2Key;
          _workingBlocks = extracted;
          _isDirty = true;
          _isExtracting = false;
          if (extracted.length != (result?.candidates.length ?? 0)) {
            _errorMessage =
                'Some imported meals need repeat-day review and were not added.';
          }
        });
      }
    } catch (e) {
      if (candidateAssetId != null) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: candidateAssetId,
            objectKey: candidateR2Key,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage =
              'Upload failed. Your existing schedule was preserved.';
        });
      }
    }
  }

  void _showBuildBalancedPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        var goal = _workingGoal ?? 'maintain';
        var meals = _workingMealsPerDay ?? 3;
        var mode = _workingEatingMode ?? 'india';
        var type = _workingFoodType ?? 'mixed';
        final customController = TextEditingController(
          text: _workingFoodStyleCustomText ?? '',
        );
        var breakfastMin = _workingBreakfastMinute ?? 480;
        var lunchMin = _workingLunchMinute ?? 780;
        var dinnerMin = _workingDinnerMinute ?? 1230;
        var snackMin = _workingSnackMinute ?? 1020;
        var extraSnackMin = _workingExtraSnackMinute ?? 660;

        String formatMin(int min) {
          final h = (min ~/ 60) % 24;
          final m = min % 60;
          final p = h >= 12 ? 'PM' : 'AM';
          final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
          return '$dh:${m.toString().padLeft(2, '0')} $p';
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Build Balanced Meal Plan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: OptivusColors.textSecondary,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Goal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final opt in const [
                            ('gain', 'Gain'),
                            ('lose', 'Lose'),
                            ('maintain', 'Maintain'),
                          ])
                            ChoiceChip(
                              label: Text(opt.$2),
                              selected: goal == opt.$1,
                              selectedColor: OptivusColors.roseAccent
                                  .withValues(alpha: 0.3),
                              onSelected: (sel) {
                                if (sel) setSheetState(() => goal = opt.$1);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Meals per Day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final count in const [3, 4, 5])
                            ChoiceChip(
                              label: Text('$count meals'),
                              selected: meals == count,
                              selectedColor: OptivusColors.roseAccent
                                  .withValues(alpha: 0.3),
                              onSelected: (sel) {
                                if (sel) setSheetState(() => meals = count);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Food Culture & Style',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final opt in const [
                            ('india', 'India'),
                            ('us', 'US'),
                            ('germany', 'Germany'),
                            ('mixed', 'Mixed'),
                            ('custom', 'Custom'),
                          ])
                            ChoiceChip(
                              label: Text(opt.$2),
                              selected: mode == opt.$1,
                              selectedColor: OptivusColors.roseAccent
                                  .withValues(alpha: 0.3),
                              onSelected: (sel) {
                                if (sel) setSheetState(() => mode = opt.$1);
                              },
                            ),
                        ],
                      ),
                      if (mode == 'custom') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Mediterranean, high protein, keto',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Dietary Preference',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final opt in const [
                            ('veg', 'Veg'),
                            ('non_veg', 'Non-veg'),
                            ('mixed', 'Mixed'),
                          ])
                            ChoiceChip(
                              label: Text(opt.$2),
                              selected: type == opt.$1,
                              selectedColor: OptivusColors.roseAccent
                                  .withValues(alpha: 0.3),
                              onSelected: (sel) {
                                if (sel) setSheetState(() => type = opt.$1);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Meal Times',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        dense: true,
                        title: const Text(
                          'Breakfast',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        trailing: Text(
                          formatMin(breakfastMin),
                          style: const TextStyle(
                            color: OptivusColors.roseAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () async {
                          final tod = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: breakfastMin ~/ 60,
                              minute: breakfastMin % 60,
                            ),
                          );
                          if (tod != null) {
                            setSheetState(
                              () => breakfastMin = tod.hour * 60 + tod.minute,
                            );
                          }
                        },
                      ),
                      if (meals == 5)
                        ListTile(
                          dense: true,
                          title: const Text(
                            'Morning Snack',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          trailing: Text(
                            formatMin(extraSnackMin),
                            style: const TextStyle(
                              color: OptivusColors.roseAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () async {
                            final tod = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: extraSnackMin ~/ 60,
                                minute: extraSnackMin % 60,
                              ),
                            );
                            if (tod != null) {
                              setSheetState(
                                () =>
                                    extraSnackMin = tod.hour * 60 + tod.minute,
                              );
                            }
                          },
                        ),
                      ListTile(
                        dense: true,
                        title: const Text(
                          'Lunch',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        trailing: Text(
                          formatMin(lunchMin),
                          style: const TextStyle(
                            color: OptivusColors.roseAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () async {
                          final tod = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: lunchMin ~/ 60,
                              minute: lunchMin % 60,
                            ),
                          );
                          if (tod != null) {
                            setSheetState(
                              () => lunchMin = tod.hour * 60 + tod.minute,
                            );
                          }
                        },
                      ),
                      if (meals >= 4)
                        ListTile(
                          dense: true,
                          title: const Text(
                            'Afternoon Snack',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          trailing: Text(
                            formatMin(snackMin),
                            style: const TextStyle(
                              color: OptivusColors.roseAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () async {
                            final tod = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: snackMin ~/ 60,
                                minute: snackMin % 60,
                              ),
                            );
                            if (tod != null) {
                              setSheetState(
                                () => snackMin = tod.hour * 60 + tod.minute,
                              );
                            }
                          },
                        ),
                      ListTile(
                        dense: true,
                        title: const Text(
                          'Dinner',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        trailing: Text(
                          formatMin(dinnerMin),
                          style: const TextStyle(
                            color: OptivusColors.roseAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () async {
                          final tod = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: dinnerMin ~/ 60,
                              minute: dinnerMin % 60,
                            ),
                          );
                          if (tod != null) {
                            setSheetState(
                              () => dinnerMin = tod.hour * 60 + tod.minute,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: OptivusColors.roseAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Generate Balanced Plan',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _workingGoal = goal;
                            _workingMealsPerDay = meals;
                            _workingEatingMode = mode;
                            _workingFoodType = type;
                            _workingFoodStyleCustomText = mode == 'custom'
                                ? customController.text.trim()
                                : null;
                            _workingBreakfastMinute = breakfastMin;
                            _workingExtraSnackMinute = extraSnackMin;
                            _workingLunchMinute = lunchMin;
                            _workingSnackMinute = snackMin;
                            _workingDinnerMinute = dinnerMin;
                          });
                          _generateBalancedPlan();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateBalancedPlan() async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;
    final generation = ++_requestGeneration;

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
      eatingMode: _workingEatingMode,
      foodType: _workingFoodType,
      foodStyleCustomText: _workingFoodStyleCustomText,
      breakfastMinute: _workingBreakfastMinute,
      lunchMinute: _workingLunchMinute,
      dinnerMinute: _workingDinnerMinute,
      snackMinute: _workingSnackMinute,
      extraSnackMinute: _workingExtraSnackMinute,
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

      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        return;
      }

      if (mounted) {
        if (_workingAssetId != null && _workingAssetId != _initialAssetId) {
          try {
            final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
            await helper.retireUncommittedUpload(
              uid: uid,
              assetId: _workingAssetId,
              objectKey: _workingR2Key,
            );
          } catch (_) {}
        }
        setState(() {
          _workingBlocks = blocks;
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

  void _deleteMealBlock(String id) {
    setState(() {
      _workingBlocks.removeWhere((block) => block.id == id);
      if (_frontBlockId == id) _frontBlockId = null;
      _isDirty = true;
    });
  }

  Future<void> _saveWorkingSetup() async {
    if (_isSaving) return;
    if (_workingBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot save an empty eating schedule. Add meals or build a plan.',
          ),
          backgroundColor: OptivusColors.danger,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(userProfileProvider).uid;
      if (uid.trim().isEmpty || uid != _editorOwnerUid) {
        throw StateError('The active account changed. Reload Eating setup.');
      }
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.eating,
        newBlocks: _workingBlocks,
        expectedRevision: _editorBaseRevision,
        updateSetup: (current) => _workingAssetId != null
            ? current.asEatingPhoto(
                photoAssetId: _workingAssetId!,
                photoR2Key: _workingR2Key!,
                blocks: _workingBlocks,
                meals: _workingMealsPerDay,
              )
            : current.asEatingGenerated(
                blocks: _workingBlocks,
                goal: _workingGoal,
                meals: _workingMealsPerDay,
                mode: _workingEatingMode,
                type: _workingFoodType,
                styleCustomText: _workingFoodStyleCustomText,
                breakfast: _workingBreakfastMinute,
                lunch: _workingLunchMinute,
                dinner: _workingDinnerMinute,
                snack: _workingSnackMinute,
                extraSnack: _workingExtraSnackMinute,
                calories: _workingTargetCalories,
                protein: _workingTargetProtein,
              ),
      );

      // Retire replaced asset if photo changed
      if (_initialAssetId != null && _initialAssetId != _workingAssetId) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: _initialAssetId!,
            oldObjectKey: _initialR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        _initialAssetId = _workingAssetId;
        _initialR2Key = _workingR2Key;
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
                  : 'Eating schedule updated successfully',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isConflict =
            e.toString().toLowerCase().contains('conflict') ||
            e.toString().toLowerCase().contains('concurrency');
        setState(() {
          _isSaving = false;
          _errorMessage = isConflict
              ? 'This setup changed elsewhere. Reload the latest setup before saving again.'
              : 'Failed to save Eating setup. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update eating schedule: $e'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _resetEatingSetup(BaseTimelineSetup currentSetup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Eating Setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will remove your custom eating schedule and reset all meal planning preferences to default. This action cannot be undone.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

    try {
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.eating,
        newBlocks: const [],
        expectedRevision: currentSetup.revision,
        updateSetup: (current) => current.asEatingReset(),
      );

      if (currentSetup.eatingPhotoAssetId != null) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: currentSetup.eatingPhotoAssetId!,
            oldObjectKey: currentSetup.eatingPhotoR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isDirty = false;
          _refreshPendingRevision = result.routineRefreshPending
              ? result.revision
              : null;
          _refreshPendingMessage = result.routineRefreshMessage;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.routineRefreshPending
                  ? 'Reset saved. Routine needs to refresh.'
                  : 'Eating schedule reset successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset eating schedule: $e'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
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
          final workingMap = {
            for (final block in _workingBlocks) block.id: block,
          };

          return PopScope(
            canPop: !_isDirty && !_isSaving && !_isExtracting,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop || _isSaving || _isExtracting) return;
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
                            onPressed: (_isSaving || _isExtracting)
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
                                  : _showBuildBalancedPlanSheet,
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
                              overlapPresentation:
                                  TimelineOverlapPresentation.frontAndExposed,
                              frontEntryId: _frontBlockId,
                              onFrontSelected: (id) =>
                                  setState(() => _frontBlockId = id),
                              blockBuilder: (context, positioned) {
                                final block =
                                    workingMap[positioned.entry.sourceId];
                                if (block == null) {
                                  return const SizedBox.shrink();
                                }
                                return BaseTimelineDomainCard(
                                  positioned: positioned,
                                  block: block,
                                  domain: BaseTimelineCardDomain.eating,
                                  accent: OptivusColors.roseAccent,
                                  isEditable: true,
                                  onTap: () {
                                    if (positioned.hasOverlap &&
                                        !positioned.isFront) {
                                      HapticFeedback.lightImpact();
                                      setState(
                                        () =>
                                            _frontBlockId = positioned.entry.id,
                                      );
                                    } else {
                                      _editMealBlock(block);
                                    }
                                  },
                                  onDelete: () => _deleteMealBlock(block.id),
                                );
                              },
                              accent: OptivusColors.roseAccent,
                              onEntryTapped: null,
                              visibleRangePolicy:
                                  TimelineVisibleRangePolicy.contentAdaptive,
                              stretchPolicy:
                                  TimelineStretchPolicy.constraintBased,
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
        final blockMap = {
          for (final block in setup.eatingBlocks) block.id: block,
        };

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BaseTimelineCurrentSetupHeader(
                  title: 'Eating',
                  summary: snapshot.summary,
                  accent: OptivusColors.roseAccent,
                  onBack: widget.onBack,
                  primaryButtonLabel: snapshot.isConfigured
                      ? 'Change setup'
                      : 'Set up Eating',
                  onPrimaryAction: () {
                    _initWorkingState(setup);
                    setState(() {
                      _isEditing = true;
                      _isDirty = false;
                    });
                  },
                  resetLabel: snapshot.isConfigured
                      ? 'Reset Eating Setup'
                      : null,
                  onReset: snapshot.isConfigured
                      ? () => _resetEatingSetup(setup)
                      : null,
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
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${setup.targetCalories ?? 2100} kcal',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Text(
                                'Daily Target',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${setup.targetProtein ?? 140} g',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Text(
                                'Protein',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 24,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${setup.mealsPerDay ?? 3} meals',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Text(
                                'Frequency',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
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
                        domain: BaseTimelineCardDomain.eating,
                        accent: OptivusColors.roseAccent,
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
                    accent: OptivusColors.roseAccent,
                    mode: TimelineMode.previewReadOnly,
                    visibleRangePolicy:
                        TimelineVisibleRangePolicy.contentAdaptive,
                    stretchPolicy: TimelineStretchPolicy.constraintBased,
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
