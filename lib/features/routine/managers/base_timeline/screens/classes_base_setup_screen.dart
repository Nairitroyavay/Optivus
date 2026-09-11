import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';
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
  saving,
  saveSuccess,
  error,
}

/// Computes the initial weekday tab to display for a list of class blocks.
///
/// Rules:
/// 1. If today's weekday has classes, select today.
/// 2. If today has no classes, select the earliest scheduled weekday (1-7).
/// 3. If there are no scheduled classes, default to 1 (Monday).
int computeInitialClassWeekday(
  List<ClassRoutineBlock> blocks, {
  DateTime? now,
}) {
  final activeDays = blocks
      .expand((b) => b.repeatDays)
      .where((d) => d >= 1 && d <= 7)
      .toSet();
  if (activeDays.isEmpty) return 1;
  final currentWeekday = (now ?? DateTime.now()).weekday;
  if (activeDays.contains(currentWeekday)) return currentWeekday;
  return (activeDays.toList()..sort()).first;
}

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
  String? _candidateAssetId;
  String? _candidateR2Key;
  int _droppedCount = 0;
  List<String> _droppedExamples = const [];
  bool _isDirty = false;
  String? _errorMessage;

  ClassRoutineBlock _draftToRoutineBlock(TimelineBlockDraft b) {
    return ClassRoutineBlock(
      id: b.id,
      subject: b.title,
      room: b.location ?? '',
      professor: b.professor ?? '',
      courseCode: b.courseCode ?? '',
      classType: b.classType ?? '',
      section: b.sectionLabel ?? '',
      notes: b.notes ?? '',
      startMinute: b.startMinute,
      endMinute: b.endMinute,
      repeatDays: b.repeatDays.isEmpty ? const [1, 2, 3, 4, 5] : b.repeatDays,
    );
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

  Future<void> _handleCancelWorkingSetup(BaseTimelineSetup setup) async {
    if (_stage == ClassesSetupStage.saving ||
        _stage == ClassesSetupStage.uploading ||
        _stage == ClassesSetupStage.extracting) {
      return;
    }

    if (await _confirmDiscard(setup)) {
      final uid = ref.read(userProfileProvider).uid;
      final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);

      // Retire uncommitted working upload if different from committed asset
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

      // Retire uncommitted candidate upload if different from committed asset
      if (_candidateAssetId != null &&
          _candidateAssetId != setup.classLogicalAssetId) {
        try {
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: _candidateAssetId,
            objectKey: _candidateR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _stage = ClassesSetupStage.currentSetup;
          _workingBlocks = [];
          _workingAssetId = null;
          _workingR2Key = null;
          _candidateAssetId = null;
          _candidateR2Key = null;
          _isDirty = false;
          _errorMessage = null;
          _droppedCount = 0;
          _droppedExamples = const [];
        });
      }
    }
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

  Future<void> _pickAndUploadPhoto(
    ImageSource source,
    BaseTimelineSetup setup,
  ) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;
    final currentAuthGen = ref.read(authGenerationProvider);

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

      // Guard against stale callback if user navigated away or auth changed
      if (!mounted ||
          ref.read(authGenerationProvider) != currentAuthGen ||
          ref.read(userProfileProvider).uid != uid) {
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

      // Store as candidate; do NOT retire previous working photo yet!
      _candidateAssetId = asset.assetId;
      _candidateR2Key = asset.r2Key;

      if (mounted) {
        setState(() {
          _stage = ClassesSetupStage.extracting;
        });
      }

      // Run AI Extraction via Routine Import Worker
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

      // Verify session freshness & candidate photo matches
      if (!mounted ||
          ref.read(authGenerationProvider) != currentAuthGen ||
          ref.read(userProfileProvider).uid != uid ||
          _candidateAssetId != asset.assetId) {
        return;
      }

      if (result != null && result.candidates.isNotEmpty) {
        final mappingResult = mapOnboarding4Candidates(
          candidates: result.candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        if (mappingResult.blocks.isNotEmpty) {
          // Extraction succeeded!
          // Retire previous temporary working photo now that candidate B succeeded
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
          _errorMessage =
              result?.warnings.firstOrNull ??
              'No class blocks detected in photo. You can try another photo or add classes manually.';
          _stage = ClassesSetupStage.error;
        });
      }
    } catch (e) {
      if (mounted &&
          ref.read(authGenerationProvider) == currentAuthGen &&
          ref.read(userProfileProvider).uid == uid) {
        setState(() {
          _errorMessage =
              'Failed to analyze timetable photo. Please try again or add classes manually.';
          _stage = ClassesSetupStage.error;
        });
      }
    }
  }

  Future<void> _handleSave(BaseTimelineSetup setup) async {
    if (_stage == ClassesSetupStage.saving) return;

    setState(() {
      _stage = ClassesSetupStage.saving;
      _errorMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      final uid = ref.read(userProfileProvider).uid;
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);

      final drafts = _workingBlocks.map((b) {
        return TimelineBlockDraft(
          id: b.id,
          title: b.subject,
          location: b.room,
          startMinute: b.startMinute,
          endMinute: b.endMinute,
          repeatDays: b.repeatDays,
          section: BaseTimelineSection.classes.name,
          blockType: TimelineBlockDraft.hardBlockKey,
          professor: b.professor,
          courseCode: b.courseCode,
          classType: b.classType,
          sectionLabel: b.section,
          notes: b.notes,
        );
      }).toList();

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

      // Succeeded: Retire old committed asset if replaced
      if (setup.classLogicalAssetId != null &&
          _workingAssetId != setup.classLogicalAssetId) {
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
          _stage = ClassesSetupStage.currentSetup;
          _workingBlocks = [];
          _workingAssetId = null;
          _workingR2Key = null;
          _candidateAssetId = null;
          _candidateR2Key = null;
          _isDirty = false;
          _errorMessage = null;
          _droppedCount = 0;
          _droppedExamples = const [];
        });

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Classes updated. Your new timetable is now active.'),
            duration: Duration(seconds: 3),
            backgroundColor: OptivusColors.routineAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        final isStale =
            errStr.contains('stale') ||
            errStr.contains('revision') ||
            errStr.contains('conflict');
        setState(() {
          _stage = ClassesSetupStage.review;
          _errorMessage = isStale
              ? 'Your Classes setup changed while you were editing.\nReload the latest setup before saving again.'
              : 'Failed to save timetable: $e';
        });
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

  void _addNewBlock() {
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
      repeatDays: [_workingSelectedDay ?? 1],
    );

    ClassTimelineAdapter.showClassEditSheet(
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
  }

  Widget _buildClassCard({
    required BuildContext context,
    required PositionedTimelineEntry positioned,
    required ClassRoutineBlock? block,
    required bool isEditable,
    Color accent = OptivusColors.blueAccent,
    VoidCallback? onTap,
  }) {
    final height = positioned.height;
    final width = positioned.width;
    final entry = positioned.entry;
    final isTiny = height < 44;
    final isCompact = height < 105;
    final isNarrow = width < 120;

    final subject = block?.subject.isNotEmpty == true
        ? block!.subject
        : entry.title;
    final courseCode = block?.courseCode ?? '';
    final classType = block?.classType ?? '';
    final room = block?.room.isNotEmpty == true
        ? block!.room
        : (entry.subtitle ?? '');
    final professor = block?.professor ?? '';
    final timeLabel = TimelineUtils.formatTimeRange(
      entry.startMinute,
      entry.endMinute,
    );

    final semanticLabel =
        '$subject, $timeLabel'
        '${room.isNotEmpty ? ", Room $room" : ""}'
        '${professor.isNotEmpty ? ", $professor" : ""}'
        '${isEditable ? ", tap to edit" : ""}';

    final cardWidget = Semantics(
      button: isEditable || onTap != null,
      label: semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.0),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.16),
              accent.withValues(alpha: 0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 8 : 12,
              vertical: isTiny ? 2 : (isCompact ? 4 : 6),
            ),
            child: _buildCardBody(
              height: height,
              width: width,
              isTiny: isTiny,
              isCompact: isCompact,
              isNarrow: isNarrow,
              subject: subject,
              courseCode: courseCode,
              classType: classType,
              room: room,
              professor: professor,
              timeLabel: timeLabel,
              isEditable: isEditable,
              accent: accent,
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: cardWidget,
            )
          : cardWidget,
    );
  }

  Widget _buildCardBody({
    required double height,
    required double width,
    required bool isTiny,
    required bool isCompact,
    required bool isNarrow,
    required String subject,
    required String courseCode,
    required String classType,
    required String room,
    required String professor,
    required String timeLabel,
    required bool isEditable,
    required Color accent,
  }) {
    if (isTiny) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          courseCode.isNotEmpty ? '$courseCode · $subject' : subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: accent.withValues(alpha: 0.95),
          ),
        ),
      );
    }

    if (isCompact) {
      return ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                if (isEditable && !isNarrow)
                  Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: accent.withValues(alpha: 0.7),
                  ),
              ],
            ),
            if (courseCode.isNotEmpty || classType.isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  if (courseCode.isNotEmpty) _buildBadge(courseCode, accent),
                  if (classType.isNotEmpty)
                    _buildBadge(classType, OptivusColors.routineAccent),
                ],
              ),
            ],
            const SizedBox(height: 2),
            Text(
              timeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.90),
              ),
            ),
            if (room.isNotEmpty || professor.isNotEmpty) ...[
              const SizedBox(height: 1),
              Row(
                children: [
                  if (room.isNotEmpty)
                    Flexible(
                      child: Text(
                        room,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ),
                  if (room.isNotEmpty && professor.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ),
                  if (professor.isNotEmpty)
                    Flexible(
                      child: Text(
                        professor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Standard / Full stretch card
    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.school_rounded, size: 12, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              if (isEditable)
                Icon(
                  Icons.edit_rounded,
                  size: 13,
                  color: accent.withValues(alpha: 0.7),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (courseCode.isNotEmpty || classType.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                if (courseCode.isNotEmpty) _buildBadge(courseCode, accent),
                if (classType.isNotEmpty)
                  _buildBadge(classType, OptivusColors.routineAccent),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Text(
            timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.90),
            ),
          ),
          if (room.isNotEmpty || professor.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                if (room.isNotEmpty) ...[
                  const Icon(
                    Icons.location_on_outlined,
                    size: 11,
                    color: OptivusColors.textSecondary,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      room,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (room.isNotEmpty && professor.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '·',
                      style: TextStyle(
                        fontSize: 10,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                if (professor.isNotEmpty) ...[
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 11,
                    color: OptivusColors.textSecondary,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      professor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeletonView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                5,
                (index) => Container(
                  width: 48,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                  3,
                  (index) => Container(
                    height: 84,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveSuccessView() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: OptivusColors.routineAccent,
            ),
            SizedBox(height: 16),
            Text(
              'Classes updated',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your new timetable is now active.',
              style: TextStyle(
                fontSize: 14,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(List<int> repeatDays) {
    if (repeatDays.isEmpty) return 'No days scheduled';
    final sorted = repeatDays.toSet().toList()..sort();
    if (sorted.length == 7) return 'Every day';
    if (sorted.length == 5 &&
        sorted[0] == 1 &&
        sorted[1] == 2 &&
        sorted[2] == 3 &&
        sorted[3] == 4 &&
        sorted[4] == 5) {
      return 'Mon – Fri';
    }
    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return sorted.map((d) => dayNames[d] ?? '$d').join(', ');
  }

  void _showClassDetailSheet(ClassRoutineBlock block) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: OptivusColors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: OptivusColors.blueAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.subject,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        if (block.courseCode.isNotEmpty ||
                            block.classType.isNotEmpty ||
                            block.section.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (block.courseCode.isNotEmpty)
                                _buildBadge(
                                  block.courseCode,
                                  OptivusColors.blueAccent,
                                ),
                              if (block.classType.isNotEmpty)
                                _buildBadge(
                                  block.classType,
                                  OptivusColors.routineAccent,
                                ),
                              if (block.section.isNotEmpty)
                                _buildBadge(
                                  'Sec ${block.section}',
                                  OptivusColors.aquaAccent,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: OptivusColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: OptivusColors.borderStandard, height: 1),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: TimelineUtils.formatTimeRange(
                  block.startMinute,
                  block.endMinute,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Days',
                value: _formatDays(block.repeatDays),
              ),
              if (block.room.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: block.room,
                ),
              ],
              if (block.professor.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Instructor',
                  value: block.professor,
                ),
              ],
              if (block.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: block.notes,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: OptivusColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);

    return setupAsync.when(
      loading: _buildLoadingSkeletonView,
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
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_stage == ClassesSetupStage.currentSetup) {
              widget.onBack();
            } else {
              _handleCancelWorkingSetup(setup);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildStageContent(setup),
          ),
        );
      },
    );
  }

  Widget _buildStageContent(BaseTimelineSetup setup) {
    switch (_stage) {
      case ClassesSetupStage.uploading:
        return const SafeArea(
          child: BaseTimelineAiThinkingView(
            initialMessage: 'Uploading timetable photo...',
            progressMessages: [
              'Encrypting and uploading to private storage...',
              'Preparing document for analysis...',
            ],
          ),
        );

      case ClassesSetupStage.extracting:
        return const SafeArea(
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
        );

      case ClassesSetupStage.chooseSource:
        return _buildChooseSourceView(setup);

      case ClassesSetupStage.error:
        return _buildErrorView(setup);

      case ClassesSetupStage.saveSuccess:
        return _buildSaveSuccessView();

      case ClassesSetupStage.review:
      case ClassesSetupStage.saving:
        return _buildReviewView(setup);

      case ClassesSetupStage.currentSetup:
        return _buildCurrentSetupView(setup);
    }
  }

  Widget _buildCurrentSetupView(BaseTimelineSetup setup) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.classes);
    final routineBlocks = setup.classBlocks.map(_draftToRoutineBlock).toList();
    _currentSelectedDay ??= computeInitialClassWeekday(routineBlocks);

    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: false,
    );
    final entries = routineBlocks.expand((b) => adapter.toEntries(b)).toList();
    final blockMap = {for (final b in routineBlocks) b.id: b};

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calm Top Nav Header
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Classes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        routineBlocks.isNotEmpty
                            ? '${routineBlocks.length} weekly classes'
                            : snapshot.summary,
                        style: const TextStyle(
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

          // Source Photo Preview (Truthful Presigned R2)
          if (snapshot.sourceR2Key != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: snapshot.sourceR2Key,
                assetId: snapshot.sourceAssetId,
                title: 'Timetable Photo',
                height: 110,
              ),
            ),

          // Timeline View (Hero)
          Expanded(
            child: FullScreenTimelineScaffold(
              entries: entries,
              selectedDay: _currentSelectedDay ?? 1,
              onDayChanged: (day) => setState(() => _currentSelectedDay = day),
              styleBuilder: (entry) => adapter.styleForEntry(entry),
              blockBuilder: (context, positioned) {
                final block = blockMap[positioned.entry.sourceId];
                return _buildClassCard(
                  context: context,
                  positioned: positioned,
                  block: block,
                  isEditable: false,
                  accent: OptivusColors.blueAccent,
                  onTap: () {
                    if (block != null) {
                      _showClassDetailSheet(block);
                    }
                  },
                );
              },
              onEntryTapped: (entry) {
                final block = blockMap[entry.sourceId];
                if (block != null) {
                  _showClassDetailSheet(block);
                }
              },
              accent: OptivusColors.blueAccent,
              mode: TimelineMode.previewReadOnly,
              visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
              stretchPolicy: TimelineStretchPolicy.constraintBased,
              emptyDayMessage: 'No classes on this day.',
            ),
          ),

          // Dominant 52px Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                label: Text(
                  snapshot.isConfigured ? 'Change setup' : 'Set up Classes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: OptivusColors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _stage = ClassesSetupStage.chooseSource;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseSourceView(BaseTimelineSetup setup) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.classes);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: () => _handleCancelWorkingSetup(setup),
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
                        'Update Timetable',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Your current setup stays active until you save a new one.',
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (snapshot.sourceR2Key != null) ...[
                  const Text(
                    'CURRENT PHOTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BaseTimelinePhotoPreviewCard(
                    r2Key: snapshot.sourceR2Key,
                    assetId: snapshot.sourceAssetId,
                    title: 'Current Timetable Photo',
                    height: 120,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  snapshot.sourceR2Key != null
                      ? 'USE A NEW TIMETABLE PHOTO'
                      : 'USE A TIMETABLE PHOTO',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSourceActionCard(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take a Photo',
                  subtitle: 'Capture a printed timetable or screen',
                  accent: OptivusColors.blueAccent,
                  onTap: () => _pickAndUploadPhoto(ImageSource.camera, setup),
                ),
                const SizedBox(height: 12),
                _buildSourceActionCard(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from Gallery',
                  subtitle: 'Upload a photo or screenshot from your device',
                  accent: OptivusColors.aquaAccent,
                  onTap: () => _pickAndUploadPhoto(ImageSource.gallery, setup),
                ),
                const SizedBox(height: 16),
                const Text(
                  'OR SET UP MANUALLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSourceActionCard(
                  icon: Icons.edit_calendar_rounded,
                  title: 'Set up manually',
                  subtitle: 'Add or adjust classes day by day',
                  accent: OptivusColors.routineAccent,
                  onTap: () {
                    setState(() {
                      _workingBlocks = setup.classBlocks
                          .map(_draftToRoutineBlock)
                          .toList();
                      _workingAssetId = setup.classLogicalAssetId;
                      _workingR2Key = setup.classLogicalAssetR2Key;
                      _isDirty = false;
                      _errorMessage = null;
                      _workingSelectedDay = computeInitialClassWeekday(
                        _workingBlocks,
                      );
                      _stage = ClassesSetupStage.review;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: OptivusColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewView(BaseTimelineSetup setup) {
    const adapter = ClassTimelineAdapter(
      accent: OptivusColors.blueAccent,
      defaultEditable: true,
    );

    final entries = _workingBlocks.expand((b) => adapter.toEntries(b)).toList();
    final blockMap = {for (final b in _workingBlocks) b.id: b};
    _workingSelectedDay ??= computeInitialClassWeekday(_workingBlocks);
    final isSaving = _stage == ClassesSetupStage.saving;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: isSaving
                      ? null
                      : () => _handleCancelWorkingSetup(setup),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Timetable',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_workingBlocks.length} classes scheduled',
                        style: const TextStyle(
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

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: OptivusColors.blueAccent.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Scan Again'),
                    onPressed: isSaving
                        ? null
                        : () => _showScanAgainSheet(setup),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Class'),
                    onPressed: isSaving ? null : _addNewBlock,
                  ),
                ),
              ],
            ),
          ),

          // Working Scanned Photo Preview
          if (_workingR2Key != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: BaseTimelinePhotoPreviewCard(
                r2Key: _workingR2Key,
                assetId: _workingAssetId,
                title: 'Scanned Timetable Photo',
                height: 110,
              ),
            ),

          // Attention banner for dropped items from photo
          if (_droppedCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OptivusColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: OptivusColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: OptivusColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _droppedExamples.isNotEmpty
                          ? '$_droppedCount unparsed item(s) skipped (e.g. ${_droppedExamples.first}). Please verify your classes.'
                          : '$_droppedCount unparsed item(s) from photo were skipped. Please verify your classes.',
                      style: const TextStyle(
                        color: OptivusColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Inline Error Message Banner
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: OptivusColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: OptivusColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: OptivusColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: OptivusColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: OptivusColors.danger,
                    ),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),

          // Timeline View
          Expanded(
            child: FullScreenTimelineScaffold(
              entries: entries,
              selectedDay: _workingSelectedDay ?? 1,
              onDayChanged: (day) => setState(() => _workingSelectedDay = day),
              styleBuilder: (entry) => adapter.styleForEntry(entry),
              blockBuilder: (context, positioned) {
                final block = blockMap[positioned.entry.sourceId];
                return _buildClassCard(
                  context: context,
                  positioned: positioned,
                  block: block,
                  isEditable: true,
                  accent: OptivusColors.blueAccent,
                );
              },
              onEntryTapped: (entry) {
                final block = _workingBlocks
                    .where((b) => b.id == entry.sourceId)
                    .firstOrNull;
                if (block != null) {
                  ClassTimelineAdapter.showClassEditSheet(
                    context: context,
                    block: block,
                    accent: OptivusColors.blueAccent,
                    onSave: (updated) async {
                      setState(() {
                        _workingBlocks = _workingBlocks
                            .map((b) => b.id == block.id ? updated : b)
                            .toList();
                        _isDirty = true;
                      });
                      return true;
                    },
                  );
                }
              },
              accent: OptivusColors.blueAccent,
              mode: TimelineMode.fullScreenEditable,
              visibleRangePolicy: TimelineVisibleRangePolicy.contentAdaptive,
              stretchPolicy: TimelineStretchPolicy.constraintBased,
              emptyDayMessage: 'No classes on this day.',
            ),
          ),

          // Dominant 52px Bottom CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OptivusColors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isSaving ? null : () => _handleSave(setup),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Use this timetable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OptivusColors.borderStandard),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                        onPressed: () {
                          _retireCandidateUpload(setup);
                          setState(() {
                            _workingBlocks = setup.classBlocks
                                .map(_draftToRoutineBlock)
                                .toList();
                            _workingAssetId = setup.classLogicalAssetId;
                            _workingR2Key = setup.classLogicalAssetR2Key;
                            _isDirty = false;
                            _errorMessage = null;
                            _workingSelectedDay = computeInitialClassWeekday(
                              _workingBlocks,
                            );
                            _stage = ClassesSetupStage.review;
                          });
                        },
                        child: const Text('Add Manually'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _handleCancelWorkingSetup(setup),
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
