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
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_day_summary_bar.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_import_review_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_meal_detail_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_meal_edit_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_settings_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_summary_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_source_selection_view.dart';

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
  String? _workingSetupPath;
  int? _workingGeneratedPlanVersion;
  String? _workingGeneratedInputFingerprint;
  bool _workingCustomized = false;
  String? _initialAssetId;
  String? _initialR2Key;
  int? _editorBaseRevision;
  int? _refreshPendingRevision;
  String? _refreshPendingMessage;
  String? _frontBlockId;
  int _requestGeneration = 0;
  String? _editorOwnerUid;
  String? _candidateAssetId;
  String? _candidateR2Key;

  void _cancelAiOperation() {
    _requestGeneration++;
    final uid = ref.read(userProfileProvider).uid;
    if (_candidateAssetId != null) {
      try {
        final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
        helper.retireUncommittedUpload(
          uid: uid,
          assetId: _candidateAssetId,
          objectKey: _candidateR2Key,
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isExtracting = false;
        _candidateAssetId = null;
        _candidateR2Key = null;
        _errorMessage = null;
      });
    }
  }

  bool _isPlanStale(BaseTimelineSetup setup) {
    if (setup.eatingSetupPath != 'create') return false;
    final savedFingerprint = setup.eatingGeneratedInputFingerprint;
    if (savedFingerprint == null || savedFingerprint.isEmpty) return false;

    try {
      final engine = ref.read(eatingDomainEngineProvider);
      final profile = ref.read(userProfileProvider);
      final targets = engine.calculateTargets(
        profile: profile,
        setup: setup,
      );
      final currentInputs = engine.buildInputs(
        profile: profile,
        setup: setup,
        targets: targets,
      );
      return currentInputs.computeFingerprint() != savedFingerprint;
    } catch (_) {
      return false;
    }
  }

  String _sourceLabelForPath(String? setupPath, bool customized) {
    return switch (setupPath) {
      'photo' => 'Imported from meal plan',
      'manual' => 'Manual plan',
      'create' => customized ? 'Built for me · Customized' : 'Built for me',
      _ => 'Eating plan',
    };
  }

  void _initWorkingState(dynamic setup) {
    _workingBlocks = List.from(setup.eatingBlocks);
    _workingGoal = setup.mealPlanningGoal;
    _workingMealsPerDay = setup.mealsPerDay;
    _workingEatingMode = setup.eatingMode;
    _workingFoodType = setup.foodType;
    _workingFoodStyleCustomText = setup.foodStyleCustomText;
    _workingBreakfastMinute = setup.breakfastMinute;
    _workingLunchMinute = setup.lunchMinute;
    _workingDinnerMinute = setup.dinnerMinute;
    _workingSnackMinute = setup.snackMinute;
    _workingExtraSnackMinute = setup.extraSnackMinute;
    _workingTargetCalories = setup.targetCalories;
    _workingTargetProtein = setup.targetProtein;
    _workingSetupPath = setup.eatingSetupPath;
    _workingGeneratedPlanVersion = setup.eatingGeneratedPlanVersion;
    _workingGeneratedInputFingerprint = setup.eatingGeneratedInputFingerprint;
    _workingCustomized = setup.eatingCustomized ?? false;
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

      final candidateBlocks = (result?.candidates ?? []).map((c) {
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

      if (candidateBlocks.isEmpty) {
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

      if (mounted) {
        setState(() => _isExtracting = false);
      }

      final reviewed = await EatingImportReviewSheet.show(
        context,
        candidates: candidateBlocks,
      );

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

      if (reviewed != null && reviewed.isNotEmpty) {
        // Extraction and review succeeded: retire previous uncommitted upload if different from initial
        if (_workingAssetId != null && _workingAssetId != _initialAssetId) {
          try {
            await lifecycleHelper.retireUncommittedUpload(
              uid: uid,
              assetId: _workingAssetId,
              objectKey: _workingR2Key,
            );
          } catch (_) {}
        }

        setState(() {
          _workingAssetId = candidateAssetId;
          _workingR2Key = candidateR2Key;
          _workingBlocks = reviewed;
          _workingSetupPath = 'has_routine';
          _workingCustomized = false;
          _isEditing = true;
          _isDirty = true;
        });
      } else {
        // Cancelled review: retire candidate asset while preserving existing schedule intact!
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAssetId,
          objectKey: candidateR2Key,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal import cancelled. Schedule preserved.'),
            ),
          );
        }
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

  Future<void> _openPlanSettingsSheet({bool isBuildingNew = false}) async {
    final isNew = isBuildingNew || _workingBlocks.isEmpty;
    final result = await EatingPlanSettingsSheet.show(
      context,
      title: isNew ? 'Build Balanced Meal Plan' : 'Plan Settings & Preferences',
      regenerateActionLabel:
          isNew ? 'Generate Balanced Plan' : 'Regenerate Plan',
      initialGoal: _workingGoal,
      initialMealsPerDay: _workingMealsPerDay,
      initialEatingMode: _workingEatingMode,
      initialFoodType: _workingFoodType,
      initialFoodStyleCustomText: _workingFoodStyleCustomText,
      initialBreakfastMinute: _workingBreakfastMinute,
      initialLunchMinute: _workingLunchMinute,
      initialDinnerMinute: _workingDinnerMinute,
      initialSnackMinute: _workingSnackMinute,
      initialExtraSnackMinute: _workingExtraSnackMinute,
      initialTargetCalories: _workingTargetCalories,
      initialTargetProtein: _workingTargetProtein,
      showRegenerateAction: true,
    );

    if (result == null || !mounted) return;

    setState(() {
      _workingGoal = result.goal;
      _workingMealsPerDay = result.mealsPerDay;
      _workingEatingMode = result.eatingMode;
      _workingFoodType = result.foodType;
      _workingFoodStyleCustomText = result.foodStyleCustomText;
      _workingBreakfastMinute = result.breakfastMinute;
      _workingLunchMinute = result.lunchMinute;
      _workingDinnerMinute = result.dinnerMinute;
      _workingSnackMinute = result.snackMinute;
      _workingExtraSnackMinute = result.extraSnackMinute;
      _workingTargetCalories = result.targetCalories;
      _workingTargetProtein = result.targetProtein;
      if (!result.shouldRegenerate) {
        _isDirty = true;
        _isEditing = true;
      }
    });

    if (result.shouldRegenerate) {
      setState(() => _isEditing = true);
      await _generateBalancedPlan();
    }
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
          _workingGeneratedPlanVersion =
              BaseTimelineDraft.currentGate2EatingPlanVersion;
          _workingGeneratedInputFingerprint = inputs.computeFingerprint();
          _workingCustomized = false;
          _workingSetupPath = 'create';
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

  void _addMealBlock({VoidCallback? onCancel}) {
    final newBlock = TimelineBlockDraft(
      id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      startMinute: 12 * 60,
      endMinute: 12 * 60 + 30,
      repeatDays: [_selectedDay],
      section: 'eating',
      blockType: TimelineBlockDraft.softBlockKey,
      dishes: const [],
    );

    EatingMealEditSheet.show(
      context: context,
      block: newBlock,
      onSave: (updated) async {
        setState(() {
          _workingBlocks.add(updated);
          if (_workingSetupPath == null) {
            _workingSetupPath = 'manual';
          } else if (_workingSetupPath == 'create') {
            _workingCustomized = true;
          }
          _isDirty = true;
        });
        return true;
      },
    ).then((saved) {
      if ((saved == null || !saved) && _workingBlocks.isEmpty) {
        onCancel?.call();
      }
    });
  }

  void _editMealBlock(TimelineBlockDraft block) {
    EatingMealEditSheet.show(
      context: context,
      block: block,
      onSave: (updated) async {
        setState(() {
          final index = _workingBlocks.indexWhere((b) => b.id == block.id);
          if (index != -1) {
            _workingBlocks[index] = updated;
            if (_workingSetupPath == 'create') {
              _workingCustomized = true;
            }
            _isDirty = true;
          }
        });
        return true;
      },
      onDelete: () => _deleteMealBlock(block.id),
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

    final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
    final currentSetup = setupAsync.value ??
        BaseTimelineSetup(
          uid: ref.read(userProfileProvider).uid,
          updatedAt: DateTime.now(),
        );
    final validationSetup = currentSetup.copyWith(
      eatingBlocks: _workingBlocks,
      eatingSetupPath: _workingSetupPath,
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
      eatingGeneratedPlanVersion: _workingGeneratedPlanVersion,
      eatingGeneratedInputFingerprint: _workingGeneratedInputFingerprint,
      eatingCustomized: _workingCustomized,
      eatingPhotoAssetId: _workingAssetId,
      eatingPhotoR2Key: _workingR2Key,
    );
    final engine = ref.read(eatingDomainEngineProvider);
    NutritionTargets? targets;
    if (_workingSetupPath == 'create') {
      try {
        final profile = ref.read(userProfileProvider);
        targets = engine.calculateTargets(
          profile: profile,
          setup: validationSetup,
        );
      } catch (_) {}
    }
    final validationErr = engine.validateBeforeSave(
      blocks: _workingBlocks,
      setup: validationSetup,
      targets: targets,
    );
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationErr),
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
        updateSetup: (current) {
          if (_workingAssetId != null) {
            return current.asEatingPhoto(
              photoAssetId: _workingAssetId!,
              photoR2Key: _workingR2Key!,
              blocks: _workingBlocks,
              meals: _workingMealsPerDay,
            );
          } else if (_workingSetupPath == 'manual') {
            return current.asEatingManual(
              blocks: _workingBlocks,
              meals: _workingMealsPerDay,
              targetCalories: _workingTargetCalories,
              targetProtein: _workingTargetProtein,
            );
          } else {
            return current.asEatingGenerated(
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
              planVersion: _workingGeneratedPlanVersion,
              inputFingerprint: _workingGeneratedInputFingerprint,
              customized: _workingCustomized,
            );
          }
        },
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
        final errorText = EatingSetupErrorMapper.mapError(e);
        setState(() {
          _isSaving = false;
          _errorMessage = errorText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
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
          'Remove Eating Plan?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will delete your current eating schedule and clear your meal plan setup. This action cannot be undone.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty || uid != _editorOwnerUid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The active account changed. Reload Eating setup.'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
      return;
    }

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
                  ? 'Eating plan removed. Routine needs to refresh.'
                  : 'Eating plan removed.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = EatingSetupErrorMapper.mapError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  void _showPhotoViewer(String r2Key, String? assetId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: r2Key,
                assetId: assetId,
                title: 'Meal Plan Photo',
                height: MediaQuery.sizeOf(context).height * 0.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeSourceSheet(BaseTimelineSetup setup) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Change Eating Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: OptivusColors.roseAccent,
                ),
                title: const Text(
                  'Build with AI',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                subtitle: const Text(
                  'Generate a personalized meal plan based on your targets',
                  style: TextStyle(
                    color: OptivusColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _initWorkingState(setup);
                  _openPlanSettingsSheet(isBuildingNew: true);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.document_scanner_rounded,
                  color: OptivusColors.roseAccent,
                ),
                title: const Text(
                  'Import from Photo',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                subtitle: const Text(
                  'Scan a meal timetable or diet chart',
                  style: TextStyle(
                    color: OptivusColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _initWorkingState(setup);
                  _showPhotoSourceSheet();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_note_rounded,
                  color: OptivusColors.roseAccent,
                ),
                title: const Text(
                  'Create Manually',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                subtitle: const Text(
                  'Add and configure meals by hand',
                  style: TextStyle(
                    color: OptivusColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _initWorkingState(setup);
                  setState(() {
                    _workingSetupPath = 'manual';
                    _workingBlocks = [];
                    _isEditing = true;
                    _isDirty = true;
                  });
                  _addMealBlock();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                            onPressed: (!_isDirty || _isSaving || _isExtracting)
                                ? null
                                : _saveWorkingSetup,
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

                    // Source label & Add Meal action
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Source: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                          Text(
                            _sourceLabelForPath(
                              _workingSetupPath,
                              _workingCustomized,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            key: const Key('base-timeline-edit-add-meal-button'),
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.roseAccent.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: OptivusColors.roseAccent,
                              side: BorderSide(
                                color: OptivusColors.roseAccent.withValues(
                                  alpha: 0.35,
                                ),
                                width: 0.8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text(
                              'Add meal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _isExtracting ? null : () => _addMealBlock(),
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

                    // Day summary bar
                    EatingDaySummaryBar(
                      blocks: _workingBlocks,
                      selectedDay: _selectedDay,
                      targetCalories: _workingTargetCalories,
                      targetProtein: _workingTargetProtein,
                    ),

                    // Interactive Timeline View
                    Expanded(
                      child: _isExtracting
                          ? BaseTimelineAiThinkingView(
                              initialMessage: _aiActionTitle,
                              progressMessages: _aiProgressMessages,
                              onCancel: _cancelAiOperation,
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

        if (!snapshot.isConfigured) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: _isExtracting
                  ? BaseTimelineAiThinkingView(
                      initialMessage: _aiActionTitle,
                      progressMessages: _aiProgressMessages,
                      onCancel: _cancelAiOperation,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Eating',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: OptivusColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Choose how to set up your meal plan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: OptivusColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: EatingSourceSelectionView(
                            onBuildPersonalized: () {
                              _initWorkingState(setup);
                              _openPlanSettingsSheet(isBuildingNew: true);
                            },
                            onImportPhoto: () {
                              _initWorkingState(setup);
                              _showPhotoSourceSheet();
                            },
                            onCreateManually: () {
                              _initWorkingState(setup);
                              setState(() {
                                _workingSetupPath = 'manual';
                                _workingBlocks = [];
                                _isEditing = true;
                                _isDirty = false;
                              });
                              _addMealBlock(onCancel: () {
                                if (mounted && _workingBlocks.isEmpty) {
                                  setState(() {
                                    _isEditing = false;
                                    _isDirty = false;
                                  });
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }

        // Current Setup View (Configured)
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
                  primaryButtonLabel: 'Edit schedule',
                  onPrimaryAction: () {
                    _initWorkingState(setup);
                    setState(() {
                      _isEditing = true;
                      _isDirty = false;
                    });
                  },
                  onChangeSource: () => _showChangeSourceSheet(setup),
                  changeSourceLabel: 'Change source',
                  onRemove: () => _resetEatingSetup(setup),
                  removeLabel: 'Remove Eating Plan',
                ),

                // Plan Summary Card (truthful summary with settings/stale/photo actions)
                EatingPlanSummaryCard(
                  setup: setup,
                  isStale: _isPlanStale(setup),
                  onOpenSettings: () {
                    _initWorkingState(setup);
                    _openPlanSettingsSheet(isBuildingNew: false);
                  },
                  onRegenerate: () {
                    _initWorkingState(setup);
                    _openPlanSettingsSheet(isBuildingNew: false);
                  },
                  onViewPhoto: snapshot.sourceR2Key != null
                      ? () => _showPhotoViewer(
                            snapshot.sourceR2Key!,
                            snapshot.sourceAssetId,
                          )
                      : null,
                ),

                // Day summary bar
                EatingDaySummaryBar(
                  blocks: setup.eatingBlocks,
                  selectedDay: _selectedDay,
                  targetCalories: setup.targetCalories,
                  targetProtein: setup.targetProtein,
                ),

                // Add Meal quick action
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        key: const Key('base-timeline-configured-add-meal-button'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: OptivusColors.roseAccent,
                        ),
                        onPressed: () {
                          _initWorkingState(setup);
                          setState(() {
                            _isEditing = true;
                            _isDirty = false;
                          });
                          _addMealBlock(onCancel: () {
                            if (mounted && !_isDirty) {
                              setState(() => _isEditing = false);
                            }
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Add meal',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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
                        domain: BaseTimelineCardDomain.eating,
                        accent: OptivusColors.roseAccent,
                        isEditable: false,
                        onTap: () {
                          if (positioned.hasOverlap && !positioned.isFront) {
                            HapticFeedback.lightImpact();
                            setState(
                              () => _frontBlockId = positioned.entry.id,
                            );
                          } else {
                            EatingMealDetailSheet.show(
                              context,
                              block,
                              onEdit: () {
                                _initWorkingState(setup);
                                setState(() {
                                  _isEditing = true;
                                  _isDirty = false;
                                });
                                _editMealBlock(block);
                              },
                            );
                          }
                        },
                      );
                    },
                    accent: OptivusColors.roseAccent,
                    mode: TimelineMode.previewReadOnly,
                    visibleRangePolicy:
                        TimelineVisibleRangePolicy.contentAdaptive,
                    stretchPolicy: TimelineStretchPolicy.constraintBased,
                    emptyDayMessage: 'No meals scheduled.',
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
