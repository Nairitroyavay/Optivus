import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_current_setup_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_review_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/views/classes_source_selection_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_schedule_draft_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/class_setup_error_mapper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Explicit staged state machine for Classes Base Timeline setup.
enum ClassesSetupStage {
  currentSetup,
  chooseSource,
  uploading,
  extracting,
  review,
  editingBlock,
  saving,
  saveSuccess,
  error,
}

/// Computes the initial weekday tab to display for a list of class blocks.
///
/// Rules:
/// 1. If today's weekday has classes, select today.
/// 2. If today has no classes, select the earliest scheduled weekday (1-7).
/// 3. If there are no scheduled classes, default to today.
int computeInitialClassWeekday(
  List<ClassRoutineBlock> blocks, {
  DateTime? now,
}) {
  final currentWeekday = (now ?? DateTime.now()).weekday;
  final activeDays = blocks
      .expand((b) => b.repeatDays)
      .where((d) => d >= 1 && d <= 7)
      .toSet();
  if (activeDays.contains(currentWeekday)) return currentWeekday;
  if (activeDays.isNotEmpty) return (activeDays.toList()..sort()).first;
  return currentWeekday;
}

/// Host coordinator screen for Base Timeline Classes setup.
class ClassesBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ClassesBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<ClassesBaseSetupScreen> createState() =>
      _ClassesBaseSetupScreenState();
}

class _ClassesBaseSetupScreenState
    extends ConsumerState<ClassesBaseSetupScreen> {
  ClassesSetupStage _stage = ClassesSetupStage.currentSetup;
  int? _currentSelectedDay;
  int? _workingSelectedDay;

  // Working state (isolated from durable setup until save commits)
  List<ClassRoutineBlock> _workingBlocks = [];
  String? _workingAssetId;
  String? _workingR2Key;
  String? _workingLocalPreviewPath;

  // Candidate upload state (isolated while in upload/extraction)
  String? _candidateAssetId;
  String? _candidateR2Key;

  int _droppedCount = 0;
  List<String> _droppedExamples = const [];
  bool _isDirty = false;
  String? _errorMessage;

  int _aiSessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = ref.read(userProfileProvider).uid;
      final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
      final setup =
          setupAsync.value ??
          BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
      ref
          .read(baseTimelineUploadLifecycleHelperProvider)
          .cleanupStaleUncommittedAssets(
            uid: uid,
            committedAssetId: setup.classLogicalAssetId,
          );
    });
  }

  Future<bool> _confirmDiscard(BaseTimelineSetup setup) async {
    final hasUnsavedPhoto =
        (_workingAssetId != null &&
            _workingAssetId != setup.classLogicalAssetId) ||
        (_candidateAssetId != null &&
            _candidateAssetId != setup.classLogicalAssetId);
    if (!_isDirty && !hasUnsavedPhoto) {
      return true;
    }
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
          "Your current Classes setup won't be affected.",
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
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

  Future<void> _retireCandidateUpload(BaseTimelineSetup setup) async {
    if (_candidateAssetId != null &&
        _candidateAssetId != setup.classLogicalAssetId) {
      final uid = ref.read(userProfileProvider).uid;
      final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
      final assetToRetire = _candidateAssetId;
      final keyToRetire = _candidateR2Key;
      _candidateAssetId = null;
      _candidateR2Key = null;
      try {
        await helper.retireUncommittedUpload(
          uid: uid,
          assetId: assetToRetire,
          objectKey: keyToRetire,
        );
      } catch (_) {}
    }
  }

  Future<void> _cancelWorkingSetup(BaseTimelineSetup setup) async {
    if (_stage == ClassesSetupStage.saving ||
        _stage == ClassesSetupStage.saveSuccess) {
      return;
    }

    if (_stage == ClassesSetupStage.uploading ||
        _stage == ClassesSetupStage.extracting) {
      _aiSessionGeneration++;
      await _retireCandidateUpload(setup);
      if (mounted) {
        setState(() {
          _stage = _workingBlocks.isNotEmpty
              ? ClassesSetupStage.review
              : ClassesSetupStage.chooseSource;
        });
      }
      return;
    }

    if (_stage == ClassesSetupStage.chooseSource) {
      await _retireCandidateUpload(setup);
      if (mounted) {
        setState(() {
          _stage = _workingBlocks.isNotEmpty
              ? ClassesSetupStage.review
              : ClassesSetupStage.currentSetup;
        });
      }
      return;
    }

    if (_stage == ClassesSetupStage.error) {
      await _retireCandidateUpload(setup);
      if (mounted) {
        setState(() {
          if (_workingBlocks.isNotEmpty) {
            _stage = ClassesSetupStage.review;
          } else {
            _stage = ClassesSetupStage.currentSetup;
            _workingBlocks = [];
            _workingAssetId = null;
            _workingR2Key = null;
            _workingLocalPreviewPath = null;
            _candidateAssetId = null;
            _candidateR2Key = null;
            _isDirty = false;
            _droppedCount = 0;
            _droppedExamples = const [];
          }
          _errorMessage = null;
        });
      }
      return;
    }

    if (_stage == ClassesSetupStage.review ||
        _stage == ClassesSetupStage.editingBlock) {
      final canDiscard = await _confirmDiscard(setup);
      if (!canDiscard || !mounted) return;

      final uid = ref.read(userProfileProvider).uid;
      final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);

      if (_workingAssetId != null &&
          _workingAssetId != setup.classLogicalAssetId) {
        try {
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingAssetId,
            objectKey: _workingR2Key,
          );
        } catch (_) {}
      }

      await _retireCandidateUpload(setup);

      if (mounted) {
        setState(() {
          _stage = ClassesSetupStage.currentSetup;
          _workingBlocks = [];
          _workingAssetId = null;
          _workingR2Key = null;
          _workingLocalPreviewPath = null;
          _isDirty = false;
          _errorMessage = null;
          _droppedCount = 0;
          _droppedExamples = const [];
        });
      }
      return;
    }

    if (_stage == ClassesSetupStage.currentSetup) {
      widget.onBack();
    }
  }

  Future<void> _handleClassesBack(BaseTimelineSetup setup) =>
      _cancelWorkingSetup(setup);

  void _startManualSetup(BaseTimelineSetup setup) {
    _retireCandidateUpload(setup);
    final existing = ClassScheduleDraftMapper.toClassRoutineBlocks(
      setup.classBlocks,
    );
    setState(() {
      _workingBlocks = List.of(existing);
      _workingAssetId = setup.classLogicalAssetId;
      _workingR2Key = setup.classLogicalAssetR2Key;
      _workingLocalPreviewPath = null;
      _isDirty = false;
      _errorMessage = null;
      _droppedCount = 0;
      _droppedExamples = const [];
      _workingSelectedDay = computeInitialClassWeekday(_workingBlocks);
      _stage = ClassesSetupStage.review;
    });
  }

  Future<void> _pickAndUploadPhoto(
    ImageSource source,
    BaseTimelineSetup setup,
  ) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;
    final currentAuthGen = ref.read(authGenerationProvider);
    final sessionGen = ++_aiSessionGeneration;

    setState(() {
      _stage = ClassesSetupStage.uploading;
      _errorMessage = null;
    });

    try {
      final uploadNotifier = ref.read(uploadControllerProvider.notifier);
      final asset = await uploadNotifier.startUpload(
        uid: uid,
        purpose: UploadedAssetPurpose.classTimetable,
        sourceFeature: UploadSourceFeature.routineBaseTimeline,
        source: source,
      );

      if (!mounted ||
          _aiSessionGeneration != sessionGen ||
          ref.read(authGenerationProvider) != currentAuthGen ||
          ref.read(userProfileProvider).uid != uid) {
        if (asset != null) {
          ref
              .read(baseTimelineUploadLifecycleHelperProvider)
              .retireUncommittedUpload(
                uid: uid,
                assetId: asset.assetId,
                objectKey: asset.r2Key,
              );
        }
        return;
      }

      if (asset == null) {
        if (mounted) {
          setState(() {
            _stage = _workingBlocks.isNotEmpty
                ? ClassesSetupStage.review
                : ClassesSetupStage.chooseSource;
          });
        }
        return;
      }

      _candidateAssetId = asset.assetId;
      _candidateR2Key = asset.r2Key;

      if (mounted) {
        setState(() {
          _stage = ClassesSetupStage.extracting;
        });
      }

      final reviewDraft = RoutineImportReviewDraft(
        id: 'rev_${asset.assetId}',
        uid: uid,
        source: RoutineImportReviewSource.classes,
        status: RoutineImportReviewStatus.draft,
        sourceLabel: 'Classes',
        uploadedAssetId: asset.assetId,
        uploadedAssetR2Key: asset.r2Key,
        uploadedAssetStatus: 'uploaded',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final result = await aiController
          .runExtraction(reviewDraft)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () =>
                throw TimeoutException('AI timetable extraction timed out.'),
          );

      if (!mounted ||
          _aiSessionGeneration != sessionGen ||
          ref.read(authGenerationProvider) != currentAuthGen ||
          ref.read(userProfileProvider).uid != uid ||
          _candidateAssetId != asset.assetId) {
        ref
            .read(baseTimelineUploadLifecycleHelperProvider)
            .retireUncommittedUpload(
              uid: uid,
              assetId: asset.assetId,
              objectKey: asset.r2Key,
            );
        return;
      }

      if (result != null && result.candidates.isNotEmpty) {
        final mappingResult = mapOnboarding4Candidates(
          candidates: result.candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        if (mappingResult.blocks.isNotEmpty) {
          if (_workingAssetId != null &&
              _workingAssetId != setup.classLogicalAssetId &&
              _workingAssetId != asset.assetId) {
            try {
              final helper = ref.read(
                baseTimelineUploadLifecycleHelperProvider,
              );
              await helper.retireUncommittedUpload(
                uid: uid,
                assetId: _workingAssetId,
                objectKey: _workingR2Key,
              );
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              _workingAssetId = asset.assetId;
              _workingR2Key = asset.r2Key;
              _workingLocalPreviewPath = asset.localPreviewPath;
              _candidateAssetId = null;
              _candidateR2Key = null;
              _workingBlocks = mappingResult.blocks;
              _droppedCount = mappingResult.droppedTotal;
              _droppedExamples = mappingResult.droppedExamples;
              _isDirty = true;
              _workingSelectedDay = computeInitialClassWeekday(_workingBlocks);
              _stage = ClassesSetupStage.review;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = ClassSetupErrorMapper.mapAiExtractionError(
            null,
            warnings: result?.warnings,
          );
          _stage = ClassesSetupStage.error;
        });
      }
    } catch (e) {
      if (!mounted || _aiSessionGeneration != sessionGen) return;

      if (ref.read(authGenerationProvider) == currentAuthGen &&
          ref.read(userProfileProvider).uid == uid) {
        setState(() {
          _errorMessage = ClassSetupErrorMapper.mapAiExtractionError(e);
          _stage = ClassesSetupStage.error;
        });
      }
    }
  }

  Future<void> _retryCandidateExtraction(BaseTimelineSetup setup) async {
    final assetId = _candidateAssetId;
    final r2Key = _candidateR2Key;
    if (assetId == null || r2Key == null) {
      setState(() => _stage = ClassesSetupStage.chooseSource);
      return;
    }
    final uid = ref.read(userProfileProvider).uid;
    final currentAuthGen = ref.read(authGenerationProvider);
    final sessionGen = ++_aiSessionGeneration;

    setState(() {
      _stage = ClassesSetupStage.extracting;
      _errorMessage = null;
    });

    try {
      final reviewDraft = RoutineImportReviewDraft(
        id: 'rev_$assetId',
        uid: uid,
        source: RoutineImportReviewSource.classes,
        status: RoutineImportReviewStatus.draft,
        sourceLabel: 'Classes',
        uploadedAssetId: assetId,
        uploadedAssetR2Key: r2Key,
        uploadedAssetStatus: 'uploaded',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final result = await aiController
          .runExtraction(reviewDraft)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () =>
                throw TimeoutException('AI timetable extraction timed out.'),
          );

      if (!mounted ||
          _aiSessionGeneration != sessionGen ||
          ref.read(authGenerationProvider) != currentAuthGen ||
          ref.read(userProfileProvider).uid != uid ||
          _candidateAssetId != assetId) {
        return;
      }

      if (result != null && result.candidates.isNotEmpty) {
        final mappingResult = mapOnboarding4Candidates(
          candidates: result.candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        if (mappingResult.blocks.isNotEmpty) {
          if (_workingAssetId != null &&
              _workingAssetId != setup.classLogicalAssetId &&
              _workingAssetId != assetId) {
            try {
              final helper = ref.read(
                baseTimelineUploadLifecycleHelperProvider,
              );
              await helper.retireUncommittedUpload(
                uid: uid,
                assetId: _workingAssetId,
                objectKey: _workingR2Key,
              );
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              _workingAssetId = assetId;
              _workingR2Key = r2Key;
              _workingLocalPreviewPath = null;
              _candidateAssetId = null;
              _candidateR2Key = null;
              _workingBlocks = mappingResult.blocks;
              _droppedCount = mappingResult.droppedTotal;
              _droppedExamples = mappingResult.droppedExamples;
              _isDirty = true;
              _workingSelectedDay = computeInitialClassWeekday(_workingBlocks);
              _stage = ClassesSetupStage.review;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = ClassSetupErrorMapper.mapAiExtractionError(
            null,
            warnings: result?.warnings,
          );
          _stage = ClassesSetupStage.error;
        });
      }
    } catch (e) {
      if (!mounted || _aiSessionGeneration != sessionGen) return;

      if (ref.read(authGenerationProvider) == currentAuthGen &&
          ref.read(userProfileProvider).uid == uid) {
        setState(() {
          _errorMessage = ClassSetupErrorMapper.mapAiExtractionError(e);
          _stage = ClassesSetupStage.error;
        });
      }
    }
  }

  Future<void> _handleSave(BaseTimelineSetup setup) async {
    if (_stage == ClassesSetupStage.saving ||
        _stage == ClassesSetupStage.saveSuccess) {
      return;
    }

    setState(() {
      _stage = ClassesSetupStage.saving;
      _errorMessage = null;
    });

    try {
      final uid = ref.read(userProfileProvider).uid;
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);

      final drafts = ClassScheduleDraftMapper.toTimelineDrafts(
        _workingBlocks,
        section: BaseTimelineSection.classes.name,
        provenanceAssetId: _workingAssetId,
        provenanceR2Key: _workingR2Key,
      );

      await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: drafts,
        updateSetup: (current) => current.copyWith(
          classBlocks: drafts,
          classLogicalAssetId: _workingAssetId,
          clearClassLogicalAssetId: _workingAssetId == null,
          classLogicalAssetR2Key: _workingR2Key,
          clearClassLogicalAssetR2Key: _workingR2Key == null,
          updatedAt: DateTime.now(),
        ),
      );

      final updatedSetup = await ref
          .read(baseTimelineSetupRepositoryProvider)
          .fetchSetup(uid);
      ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(updatedSetup);

      if (setup.classLogicalAssetId != null &&
          setup.classLogicalAssetId != _workingAssetId) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: setup.classLogicalAssetId!,
            oldObjectKey: setup.classLogicalAssetR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        final savedBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
          drafts,
        );
        final newInitialDay = computeInitialClassWeekday(savedBlocks);
        setState(() {
          _currentSelectedDay = newInitialDay;
          _stage = ClassesSetupStage.saveSuccess;
          _workingBlocks = [];
          _workingAssetId = null;
          _workingR2Key = null;
          _workingLocalPreviewPath = null;
          _candidateAssetId = null;
          _candidateR2Key = null;
          _isDirty = false;
          _errorMessage = null;
          _droppedCount = 0;
          _droppedExamples = const [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = ClassesSetupStage.review;
          _errorMessage = ClassSetupErrorMapper.mapSaveError(e);
        });
      }
    }
  }

  Future<void> _handleRemoveSetup(BaseTimelineSetup setup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Classes setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will remove all scheduled classes from your Base Timeline. This action cannot be undone.',
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

    try {
      final uid = ref.read(userProfileProvider).uid;
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);

      await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.classes,
        newBlocks: const [],
        updateSetup: (current) => current.copyWith(
          classBlocks: const [],
          clearClassLogicalAssetId: true,
          clearClassLogicalAssetR2Key: true,
          updatedAt: DateTime.now(),
        ),
      );

      final updatedSetup = await ref
          .read(baseTimelineSetupRepositoryProvider)
          .fetchSetup(uid);
      ref
          .read(baseTimelineSetupNotifierProvider.notifier)
          .updateInMemory(updatedSetup);

      if (setup.classLogicalAssetId != null) {
        try {
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: setup.classLogicalAssetId!,
            oldObjectKey: setup.classLogicalAssetR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _currentSelectedDay = 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Classes setup removed.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ClassSetupErrorMapper.mapSaveError(e)),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  void _showScanAgainSheet(BaseTimelineSetup setup) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan Timetable Photo',
                style: TextStyle(
                  color: OptivusColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: OptivusColors.aquaAccent,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(ImageSource.gallery, setup);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: OptivusColors.aquaAccent,
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(color: OptivusColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(ImageSource.camera, setup);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addNewBlock() async {
    final initialDay = _workingSelectedDay ?? 1;
    final newBlock = ClassRoutineBlock(
      id: 'cls_${DateTime.now().millisecondsSinceEpoch}',
      subject: '',
      room: '',
      professor: '',
      courseCode: '',
      classType: '',
      section: '',
      notes: '',
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      repeatDays: [initialDay],
    );

    setState(() => _stage = ClassesSetupStage.editingBlock);
    await ClassTimelineAdapter.showClassEditSheet(
      context: context,
      block: newBlock,
      accent: OptivusColors.blueAccent,
      onSave: (updated) async {
        setState(() {
          _workingBlocks = [..._workingBlocks, updated];
          _isDirty = true;
        });
        return true;
      },
    );
    if (mounted && _stage == ClassesSetupStage.editingBlock) {
      setState(() => _stage = ClassesSetupStage.review);
    }
  }

  Future<void> _editBlock(ClassRoutineBlock block) async {
    setState(() => _stage = ClassesSetupStage.editingBlock);
    await ClassTimelineAdapter.showClassEditSheet(
      context: context,
      block: block,
      accent: OptivusColors.blueAccent,
      onSave: (updated) async {
        setState(() {
          final index = _workingBlocks.indexWhere((b) => b.id == block.id);
          if (index != -1) {
            _workingBlocks[index] = updated;
          } else {
            _workingBlocks.add(updated);
          }
          _isDirty = true;
        });
        return true;
      },
      onDelete: (toDelete) async {
        setState(() {
          _workingBlocks.removeWhere((b) => b.id == toDelete.id);
          _isDirty = true;
        });
        return true;
      },
    );
    if (mounted && _stage == ClassesSetupStage.editingBlock) {
      setState(() => _stage = ClassesSetupStage.review);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);
    final uid = ref.watch(userProfileProvider).uid;

    if (_stage == ClassesSetupStage.currentSetup &&
        setupAsync.isLoading &&
        !setupAsync.hasValue) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          widget.onBack();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildCurrentSetupSkeletonView(),
        ),
      );
    }

    final setup =
        setupAsync.value ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleClassesBack(setup);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildStageContent(setup),
      ),
    );
  }

  Widget _buildStageContent(BaseTimelineSetup setup) {
    switch (_stage) {
      case ClassesSetupStage.uploading:
        return SafeArea(
          child: Column(
            children: [
              _buildTopCancelBar(() => _handleClassesBack(setup)),
              const Expanded(
                child: BaseTimelineAiThinkingView(
                  initialMessage: 'Uploading timetable photo...',
                  progressMessages: [
                    'Encrypting and uploading to private storage...',
                    'Preparing document for analysis...',
                  ],
                ),
              ),
            ],
          ),
        );

      case ClassesSetupStage.extracting:
        return SafeArea(
          child: Column(
            children: [
              _buildTopCancelBar(() => _handleClassesBack(setup)),
              const Expanded(
                child: BaseTimelineAiThinkingView(
                  initialMessage: 'Reading your timetable',
                  progressMessages: [
                    'Finding subjects',
                    'Reading rooms and faculty',
                    'Matching weekdays',
                    'Checking exact times',
                    'Building your new timetable',
                  ],
                ),
              ),
            ],
          ),
        );

      case ClassesSetupStage.chooseSource:
        return ClassesSourceSelectionView(
          setup: setup,
          onCancel: () => _handleClassesBack(setup),
          onPickPhoto: (source) => _pickAndUploadPhoto(source, setup),
          onManualSetup: () => _startManualSetup(setup),
        );

      case ClassesSetupStage.error:
        return _buildErrorView(setup);

      case ClassesSetupStage.saveSuccess:
        return _ClassesSaveSuccessView(
          onComplete: () {
            if (!mounted) return;
            setState(() {
              _stage = ClassesSetupStage.currentSetup;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Classes updated. Your new timetable is now active.',
                ),
                duration: Duration(seconds: 3),
                backgroundColor: OptivusColors.routineAccent,
              ),
            );
          },
        );

      case ClassesSetupStage.review:
      case ClassesSetupStage.editingBlock:
      case ClassesSetupStage.saving:
        final activeWorkingDays = _workingBlocks
            .expand((b) => b.repeatDays)
            .where((d) => d >= 1 && d <= 7)
            .toSet();
        final isWorkingDayValid =
            activeWorkingDays.isEmpty ||
            (_workingSelectedDay != null &&
                activeWorkingDays.contains(_workingSelectedDay));
        final reviewSelectedDay = isWorkingDayValid
            ? (_workingSelectedDay ??
                  computeInitialClassWeekday(_workingBlocks))
            : computeInitialClassWeekday(_workingBlocks);

        return ClassesReviewView(
          workingBlocks: _workingBlocks,
          workingAssetId: _workingAssetId,
          workingR2Key: _workingR2Key,
          workingLocalPreviewPath: _workingLocalPreviewPath,
          selectedDay: reviewSelectedDay,
          onDayChanged: (d) => setState(() => _workingSelectedDay = d),
          droppedCount: _droppedCount,
          droppedExamples: _droppedExamples,
          errorMessage: _errorMessage,
          onClearError: () => setState(() => _errorMessage = null),
          isSaving: _stage == ClassesSetupStage.saving,
          onCancel: () => _handleClassesBack(setup),
          onScanAgain: () => _showScanAgainSheet(setup),
          onAddClass: _addNewBlock,
          onEditBlock: _editBlock,
          onSave: () => _handleSave(setup),
        );

      case ClassesSetupStage.currentSetup:
        final routineBlocks = ClassScheduleDraftMapper.toClassRoutineBlocks(
          setup.classBlocks,
        );
        final activeDays = routineBlocks
            .expand((b) => b.repeatDays)
            .where((d) => d >= 1 && d <= 7)
            .toSet();
        final isCurrentDayValid =
            activeDays.isEmpty ||
            (_currentSelectedDay != null &&
                activeDays.contains(_currentSelectedDay));
        final initialDay = isCurrentDayValid
            ? (_currentSelectedDay ?? computeInitialClassWeekday(routineBlocks))
            : computeInitialClassWeekday(routineBlocks);

        return ClassesCurrentSetupView(
          setup: setup,
          routineBlocks: routineBlocks,
          selectedDay: initialDay,
          onDayChanged: (d) => setState(() => _currentSelectedDay = d),
          onBack: () => _handleClassesBack(setup),
          onChangeSetup: () =>
              setState(() => _stage = ClassesSetupStage.chooseSource),
          onRemoveSetup: () => _handleRemoveSetup(setup),
        );
    }
  }

  Widget _buildTopCancelBar(VoidCallback onCancel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: OptivusColors.textPrimary,
            ),
            onPressed: onCancel,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSetupSkeletonView() {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Loading timetable...',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    height: 110,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, index) => Container(
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: OptivusColors.blueAccent.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BaseTimelineSetup setup) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: OptivusColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: OptivusColors.danger,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Timetable Processing Issue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ??
                      'An error occurred while processing the photo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OptivusColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                if (_candidateAssetId != null && _candidateR2Key != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OptivusColors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _retryCandidateExtraction(setup),
                          child: const Text('Retry AI'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            _retireCandidateUpload(setup);
                            setState(() {
                              _stage = ClassesSetupStage.chooseSource;
                              _errorMessage = null;
                            });
                          },
                          child: const Text('Choose another photo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _startManualSetup(setup),
                      child: const Text('Add Manually'),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            _retireCandidateUpload(setup);
                            setState(() {
                              _stage = ClassesSetupStage.chooseSource;
                              _errorMessage = null;
                            });
                          },
                          child: const Text('Try Again'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OptivusColors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _startManualSetup(setup),
                          child: const Text('Add Manually'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_workingBlocks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _retireCandidateUpload(setup);
                        setState(() {
                          _stage = ClassesSetupStage.review;
                          _errorMessage = null;
                        });
                      },
                      child: const Text('Keep previous draft'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _handleClassesBack(setup),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: OptivusColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassesSaveSuccessView extends StatefulWidget {
  final VoidCallback onComplete;

  const _ClassesSaveSuccessView({required this.onComplete});

  @override
  State<_ClassesSaveSuccessView> createState() =>
      _ClassesSaveSuccessViewState();
}

class _ClassesSaveSuccessViewState extends State<_ClassesSaveSuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: OptivusColors.routineAccent.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: OptivusColors.routineAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Classes updated',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your new timetable is now active.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
