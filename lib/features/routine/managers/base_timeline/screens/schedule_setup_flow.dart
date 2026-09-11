import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_candidate_mapping.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/class_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/adapters/work_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

class ScheduleSetupFlow extends ConsumerStatefulWidget {
  final ScheduleSetupConfig config;
  final List<TimelineBlockDraft> initialBlocks;
  final String? initialAssetId;
  final String? initialR2Key;
  final Future<void> Function(
    List<TimelineBlockDraft> blocks,
    String? assetId,
    String? r2Key,
  )
  onSave;
  final VoidCallback onCancel;

  const ScheduleSetupFlow({
    super.key,
    required this.config,
    required this.initialBlocks,
    this.initialAssetId,
    this.initialR2Key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  ConsumerState<ScheduleSetupFlow> createState() => _ScheduleSetupFlowState();
}

class _ScheduleSetupFlowState extends ConsumerState<ScheduleSetupFlow> {
  late List<ClassRoutineBlock> _blocks;
  String? _assetId;
  String? _r2Key;
  int _selectedDay = 1;
  bool _isExtracting = false;
  bool _isSaving = false;
  bool _isDirty = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _blocks = widget.initialBlocks.map((b) {
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
    }).toList();
    _assetId = widget.initialAssetId;
    _r2Key = widget.initialR2Key;
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
          'Any unsaved setup edits will be lost.',
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

  void _handleCancel() async {
    if (_isSaving || _isExtracting) return;
    if (await _confirmDiscard()) {
      if (_assetId != null && _assetId != widget.initialAssetId) {
        try {
          final uid = ref.read(userProfileProvider).uid;
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: _assetId,
            objectKey: _r2Key,
          );
        } catch (_) {}
      }
      widget.onCancel();
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

    // Retire any previously uncommitted upload before starting new one
    if (_assetId != null && _assetId != widget.initialAssetId) {
      try {
        final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
        await helper.retireUncommittedUpload(
          uid: uid,
          assetId: _assetId,
          objectKey: _r2Key,
        );
      } catch (_) {}
    }

    final uploadNotifier = ref.read(uploadControllerProvider.notifier);
    final purpose = widget.config.source == RoutineImportReviewSource.classes
        ? UploadedAssetPurpose.classTimetable
        : UploadedAssetPurpose.workSchedule;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final asset = await uploadNotifier.startUpload(
        uid: uid,
        purpose: purpose,
        sourceFeature: UploadSourceFeature.routineBaseTimeline,
        source: source,
      );

      if (asset == null) {
        if (mounted) {
          setState(() {
            _isExtracting = false;
          });
        }
        return;
      }

      _assetId = asset.assetId;
      _r2Key = asset.r2Key;

      // Run AI Extraction
      final reviewDraft = RoutineImportReviewDraft(
        id: 'rev_${asset.assetId}',
        uid: uid,
        source: widget.config.source,
        status: RoutineImportReviewStatus.draft,
        sourceLabel: widget.config.sectionLabel,
        uploadedAssetId: asset.assetId,
        uploadedAssetR2Key: asset.r2Key,
        uploadedAssetStatus: 'uploaded',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final result = await aiController.runExtraction(reviewDraft);

      if (result != null && result.candidates.isNotEmpty) {
        final mappingResult = mapOnboarding4Candidates(
          candidates: result.candidates,
          config: widget.config,
        );

        if (mappingResult.blocks.isNotEmpty) {
          if (mounted) {
            setState(() {
              _blocks = mappingResult.blocks;
              _isDirty = true;
              _isExtracting = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isExtracting = false;
              _errorMessage =
                  result.warnings.firstOrNull ??
                  'No valid blocks found in schedule. You can add blocks manually.';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isExtracting = false;
            _errorMessage =
                result?.warnings.firstOrNull ??
                'No blocks detected. You can add blocks manually.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = 'Upload failed. Please try again or add manually.';
        });
      }
    }
  }

  void _showImageSourceSheet() {
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
              Text(
                widget.config.uploadTitle,
                style: const TextStyle(
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
                  _pickAndUploadPhoto(ImageSource.gallery);
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
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewBlock() {
    final defaultBlock = ClassRoutineBlock(
      id: 'blk_${DateTime.now().millisecondsSinceEpoch}',
      subject: '',
      room: '',
      professor: '',
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      repeatDays: [_selectedDay],
    );

    ClassTimelineAdapter.showClassEditSheet(
      context: context,
      block: defaultBlock,
      accent: widget.config.accent,
      onSave: (updated) async {
        setState(() {
          _blocks = [..._blocks, updated];
          _isDirty = true;
        });
        return true;
      },
    );
  }

  void _editBlock(ClassRoutineBlock block) {
    ClassTimelineAdapter.showClassEditSheet(
      context: context,
      block: block,
      accent: widget.config.accent,
      onSave: (updated) async {
        setState(() {
          _blocks = _blocks.map((b) => b.id == block.id ? updated : b).toList();
          _isDirty = true;
        });
        return true;
      },
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isExtracting) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final drafts = _blocks.map((b) {
      return TimelineBlockDraft(
        id: b.id,
        title: b.subject,
        location: b.room,
        startMinute: b.startMinute,
        endMinute: b.endMinute,
        repeatDays: b.repeatDays,
        section: widget.config.timelineSection,
        blockType: TimelineBlockDraft.hardBlockKey,
        professor: b.professor,
        courseCode: b.courseCode,
        classType: b.classType,
        sectionLabel: b.section,
        notes: b.notes,
      );
    }).toList();

    try {
      await widget.onSave(drafts, _assetId, _r2Key);
      if (widget.initialAssetId != null && _assetId != widget.initialAssetId) {
        try {
          final uid = ref.read(userProfileProvider).uid;
          final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: widget.initialAssetId!,
            oldObjectKey: widget.initialR2Key,
          );
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save schedule. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClasses = widget.config.source == RoutineImportReviewSource.classes;
    final adapter = isClasses
        ? ClassTimelineAdapter(accent: widget.config.accent)
        : WorkTimelineAdapter(accent: widget.config.accent);

    final entries = _blocks.expand((b) {
      return adapter.toEntries(b);
    }).toList();

    return PopScope(
      canPop: !_isDirty && !_isSaving && !_isExtracting,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          if (await _confirmDiscard()) {
            widget.onCancel();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Bar ──
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
                          : _handleCancel,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.config.mainTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_blocks.length} blocks scheduled',
                            style: const TextStyle(
                              fontSize: 12,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.config.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (_isSaving || _isExtracting)
                          ? null
                          : _handleSave,
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

              // ── Action Buttons ──
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
                            color: widget.config.accent.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Scan Photo'),
                        onPressed: (_isExtracting || _isSaving)
                            ? null
                            : _showImageSourceSheet,
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
                        label: const Text('Add Block'),
                        onPressed: (_isExtracting || _isSaving)
                            ? null
                            : _addNewBlock,
                      ),
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

              // ── Main Timeline View ──
              Expanded(
                child: (_isExtracting || _isSaving)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            Text(
                              _isSaving
                                  ? 'Saving ${widget.config.sectionLabel.toLowerCase()}...'
                                  : 'Analyzing ${widget.config.sectionLabel.toLowerCase()} photo...',
                              style: const TextStyle(
                                color: OptivusColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FullScreenTimelineScaffold(
                        entries: entries,
                        selectedDay: _selectedDay,
                        onDayChanged: (day) =>
                            setState(() => _selectedDay = day),
                        styleBuilder: (entry) => adapter.styleForEntry(entry),
                        onEntryTapped: (entry) {
                          final block = _blocks
                              .where((b) => b.id == entry.sourceId)
                              .firstOrNull;
                          if (block != null) {
                            _editBlock(block);
                          }
                        },
                        accent: widget.config.accent,
                        emptyDayMessage:
                            'No ${widget.config.sectionLabel.toLowerCase()} on this day.',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
