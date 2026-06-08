import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

// ---------------------------------------------------------------------------
// Photo slot model — tracks one uploaded photo with its label & section.
// ---------------------------------------------------------------------------
class _PhotoSlot {
  final UploadedAsset asset;
  final String label;
  final RoutineImportReviewSource source;

  const _PhotoSlot({
    required this.asset,
    required this.label,
    required this.source,
  });
}

// ---------------------------------------------------------------------------
// Timeline range helper (duplicated from the old widget since it's private)
// ---------------------------------------------------------------------------
class _TimelineRange {
  final int startHour;
  final int endHour;

  const _TimelineRange({required this.startHour, required this.endHour});

  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
  int get hourCount => (endHour - startHour).clamp(1, 24);
}

// ---------------------------------------------------------------------------
//  OnboardingStep4Unified — the single-screen Classes & Job widget
// ---------------------------------------------------------------------------
class OnboardingStep4Unified extends ConsumerStatefulWidget {
  const OnboardingStep4Unified({super.key});

  @override
  ConsumerState<OnboardingStep4Unified> createState() =>
      _OnboardingStep4UnifiedState();
}

class _OnboardingStep4UnifiedState
    extends ConsumerState<OnboardingStep4Unified> {
  static const _kHourHeight = 84.0;
  static const _kPixelsPerMinute = _kHourHeight / 60.0;
  static const _kLeftOffset = 64.0;
  static const _kMinTimelineAreaHeight = 320.0;
  static const _kTimelineBottomPadding = 240.0;

  final List<_PhotoSlot> _photos = [];
  bool _isUploading = false;
  bool _isGenerating = false;
  String? _generationError;
  String? _timelineError;
  int _day = 0; // 0=Mon … 6=Sun
  bool _didInitFromDraft = false;

  // ---- Role helpers ----
  String? get _role => ref.read(mockOnboardingProvider).draft.lifeRole.lifeRole;

  bool get _classesRequired =>
      _role == LifeRoleDraft.studentKey ||
      _role == LifeRoleDraft.studentWorkingKey;

  bool get _workRequired =>
      _role == LifeRoleDraft.workingKey ||
      _role == LifeRoleDraft.studentWorkingKey ||
      _role == LifeRoleDraft.businessKey;

  bool get _needsBothPhotos => _classesRequired && _workRequired;
  int get _maxPhotos => _needsBothPhotos ? 2 : 1;
  bool get _hasClassPhoto =>
      _photos.any((photo) => photo.source == RoutineImportReviewSource.classes);
  bool get _hasWorkPhoto =>
      _photos.any((photo) => photo.source == RoutineImportReviewSource.work);
  bool get _hasAnyPhoto => _photos.isNotEmpty;
  bool get _hasAllPhotos {
    if (_needsBothPhotos) return _hasClassPhoto && _hasWorkPhoto;
    return _photos.isNotEmpty;
  }

  bool get _canTapGenerate => _hasAnyPhoto && !_isUploading && !_isGenerating;

  // ---- Upload text config ----
  String get _uploadTitle {
    if (_needsBothPhotos) return 'Upload your class and work timetable';
    if (_classesRequired) return 'Upload your class timetable';
    return 'Upload your work schedule';
  }

  String get _uploadSubtitle {
    if (_needsBothPhotos) {
      return 'Upload both class and work schedule photos before '
          'generating your timeline.';
    }
    if (_classesRequired) {
      return 'Use a clear photo of your weekly class schedule.';
    }
    if (_role == LifeRoleDraft.businessKey) {
      return 'Use a clear photo of your business/work schedule.';
    }
    return 'Use a clear photo of your weekly work schedule.';
  }

  // ---- Accent for the combined view (class-primary) ----
  Color get _accent => OptivusColors.aquaAccent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initFromDraft();
    });
  }

  // ---- Init from draft ----
  void _initFromDraft() {
    if (_didInitFromDraft) return;
    _didInitFromDraft = true;

    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;

    // Restore confirmed class blocks
    if (_classesRequired) {
      final classBlocks = base.confirmedBlocksForSection('classes');
      if (classBlocks.isNotEmpty) {
        ref
            .read(onboardingClassTimelineProvider.notifier)
            .state = _classBlocksFromTimelineDrafts(
          classBlocks,
          ScheduleSetupConfig.classSetup,
        );
      }
    }

    // Restore confirmed work blocks
    if (_workRequired) {
      final workBlocks = base.confirmedBlocksForSection('job_work_business');
      if (workBlocks.isNotEmpty) {
        ref
            .read(onboardingWorkTimelineProvider.notifier)
            .state = _classBlocksFromTimelineDrafts(
          workBlocks,
          ScheduleSetupConfig.workSetup,
        );
      }
    }
  }

  // ---- Helpers ----
  List<ClassRoutineBlock> _classBlocksFromTimelineDrafts(
    List<TimelineBlockDraft> blocks,
    ScheduleSetupConfig config,
  ) {
    return blocks
        .asMap()
        .entries
        .map(
          (entry) => ClassRoutineBlock(
            id: entry.value.id,
            subject: entry.value.title,
            room: entry.value.location ?? '',
            startMinute: entry.value.startMinute.clamp(0, 24 * 60 - 1),
            endMinute: entry.value.endMinute.clamp(1, 24 * 60),
            repeatDays: _safeRepeatDays(entry.value.repeatDays),
            icon: config.icon,
            color: config.colorCycle[entry.key % config.colorCycle.length],
            hasTopTape: true,
            hasBottomTape: true,
          ),
        )
        .where((b) => b.subject.trim().isNotEmpty)
        .where((b) => b.startMinute < b.endMinute)
        .toList(growable: false)
      ..sort((a, b) {
        final dayCompare = (a.weekday ?? 1).compareTo(b.weekday ?? 1);
        return dayCompare != 0
            ? dayCompare
            : a.startMinute.compareTo(b.startMinute);
      });
  }

  List<int> _safeRepeatDays(List<int> days) {
    final safe = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
    return safe.isEmpty ? const [1] : safe;
  }

  _TimelineRange _rangeFor(List<ClassRoutineBlock> blocks) {
    var startHour = 6;
    var endHour = 23;
    if (blocks.isNotEmpty) {
      final minStart = blocks
          .map((b) => b.startMinute)
          .reduce((a, b) => a < b ? a : b);
      final maxEnd = blocks
          .map((b) => b.endMinute)
          .reduce((a, b) => a > b ? a : b);
      if (minStart < 6 * 60) {
        startHour = (minStart ~/ 60).clamp(0, 23);
      }
      if (maxEnd > 23 * 60) {
        endHour = ((maxEnd + 59) ~/ 60).clamp(startHour + 1, 24);
      }
    }
    return _TimelineRange(startHour: startHour, endHour: endHour);
  }

  double _timelineY({
    required int minuteOfDay,
    required int visibleStartMinute,
    required double topPadding,
  }) {
    return topPadding + (minuteOfDay - visibleStartMinute) * _kPixelsPerMinute;
  }

  // ---- Upload ----
  Future<void> _pickAndUpload() async {
    if (_isUploading || _isGenerating) return;
    if (_photos.length >= _maxPhotos || _hasAllPhotos) {
      setState(() => _generationError = _photoLimitMessage());
      return;
    }

    // Determine which section this upload is for
    UploadedAssetPurpose purpose;
    String label;
    RoutineImportReviewSource source;

    if (_needsBothPhotos) {
      if (!_hasClassPhoto) {
        purpose = UploadedAssetPurpose.classTimetable;
        label = 'Class';
        source = RoutineImportReviewSource.classes;
      } else if (!_hasWorkPhoto) {
        purpose = UploadedAssetPurpose.workSchedule;
        label = 'Work';
        source = RoutineImportReviewSource.work;
      } else {
        setState(() {
          _generationError = 'Only class and work timetable photos are needed.';
        });
        return;
      }
    } else if (_classesRequired) {
      purpose = UploadedAssetPurpose.classTimetable;
      label = 'Class';
      source = RoutineImportReviewSource.classes;
    } else {
      purpose = UploadedAssetPurpose.workSchedule;
      label = 'Work';
      source = RoutineImportReviewSource.work;
    }

    setState(() {
      _isUploading = true;
      _generationError = null;
      _timelineError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;

    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: purpose,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );

    if (!mounted) return;
    final uploadState = ref.read(uploadControllerProvider);
    setState(() => _isUploading = false);

    if (asset == null) {
      if (uploadState.status == UploadFlowStatus.failed) {
        setState(() {
          _generationError =
              uploadState.errorMessage ?? 'Photo upload failed. Try again.';
        });
      }
      return;
    }

    setState(() {
      _photos.add(_PhotoSlot(asset: asset, label: label, source: source));
      _photos.sort(_comparePhotoSlots);
      _generationError = null;
      _timelineError = null;
    });
    _markClassJobDirty();
  }

  void _removePhoto(int index) {
    if (_isUploading || _isGenerating) return;
    final removed = _photos[index];
    setState(() {
      _photos.removeAt(index);
      _generationError = null;
      _timelineError = null;
    });

    // Clear generated blocks for the removed section
    if (removed.source == RoutineImportReviewSource.classes) {
      ref.read(onboardingClassTimelineProvider.notifier).state = const [];
    } else {
      ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
    }
    _markClassJobDirty();
  }

  int _comparePhotoSlots(_PhotoSlot a, _PhotoSlot b) {
    int rank(_PhotoSlot photo) =>
        photo.source == RoutineImportReviewSource.classes ? 0 : 1;
    return rank(a).compareTo(rank(b));
  }

  String _photoLimitMessage() {
    if (_needsBothPhotos) {
      return 'Only class and work timetable photos are needed.';
    }
    if (_classesRequired) return 'Only one class timetable photo is allowed.';
    return 'Only one work schedule photo is allowed.';
  }

  void _markClassJobDirty() {
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepDirty(onboardingClassJobStepIndex, true);
  }

  // ---- Generation ----
  Future<void> _runGeneration() async {
    if (!_canTapGenerate) return;
    if (_needsBothPhotos && !_hasAllPhotos) {
      setState(() {
        _generationError = 'Missing one timetable photo';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _timelineError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingClassJobStepIndex, true);

    final draft = ref.read(mockOnboardingProvider).draft;
    final aiController = ref.read(routineImportAiControllerProvider.notifier);

    bool anySuccess = false;

    try {
      for (final photo in _photos) {
        if (!mounted) return;
        if (photo.source == RoutineImportReviewSource.classes) {
          ref.read(onboardingClassTimelineProvider.notifier).state = const [];
        } else {
          ref.read(onboardingWorkTimelineProvider.notifier).state = const [];
        }

        final now = DateTime.now();
        final reviewDraft = RoutineImportReviewDraft(
          id: 'onboarding_${photo.source.name}_import_review',
          uid: draft.uid,
          source: photo.source,
          status: RoutineImportReviewStatus.needsReview,
          sourceLabel: photo.label,
          uploadedAssetId: photo.asset.assetId,
          uploadedAssetR2Key: photo.asset.r2Key,
          uploadedAssetStatus: 'uploaded',
          createdAt: now,
          updatedAt: now,
        );

        final result = await aiController.runExtraction(reviewDraft);
        if (!mounted) return;

        final candidateCount = result?.candidates.length ?? 0;
        if (result != null && result.candidates.isNotEmpty) {
          final config = photo.source == RoutineImportReviewSource.classes
              ? ScheduleSetupConfig.classSetup
              : ScheduleSetupConfig.workSetup;

          final blocks = result.candidates
              .where((c) => c.title.trim().isNotEmpty)
              .where((c) => c.startMinute < c.endMinute)
              .toList(growable: false);

          final classBlocks = blocks
              .asMap()
              .entries
              .map(
                (entry) => ClassRoutineBlock(
                  id: entry.value.id,
                  subject: entry.value.title,
                  room: entry.value.location ?? '',
                  startMinute: entry.value.startMinute.clamp(0, 24 * 60 - 1),
                  endMinute: entry.value.endMinute.clamp(1, 24 * 60),
                  repeatDays: _safeRepeatDays(entry.value.repeatDays),
                  icon: config.icon,
                  color:
                      config.colorCycle[entry.key % config.colorCycle.length],
                  hasTopTape: true,
                  hasBottomTape: true,
                ),
              )
              .toList(growable: false);

          debugPrint(
            '[Onboarding4] ${photo.source.name} AI candidate count: '
            '$candidateCount; visible blocks: ${classBlocks.length}',
          );

          if (classBlocks.isNotEmpty) {
            anySuccess = true;
            if (photo.source == RoutineImportReviewSource.classes) {
              ref.read(onboardingClassTimelineProvider.notifier).state =
                  classBlocks;
            } else {
              ref.read(onboardingWorkTimelineProvider.notifier).state =
                  classBlocks;
            }
          }
        } else {
          debugPrint(
            '[Onboarding4] ${photo.source.name} AI candidate count: 0; '
            'visible blocks: 0',
          );
        }
      }
    } finally {
      if (mounted) {
        ref
            .read(mockOnboardingProvider.notifier)
            .setStepLoading(onboardingClassJobStepIndex, false);
      }
    }

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      if (!anySuccess) {
        _timelineError = 'AI could not detect timetable blocks clearly.';
      }
    });
    if (anySuccess) _markClassJobDirty();
  }

  // ---- Sync local blocks back to provider (for edits) ----
  List<ClassRoutineBlock> _currentBlocks(ScheduleSetupConfig config) {
    return config.source == RoutineImportReviewSource.classes
        ? ref.read(onboardingClassTimelineProvider)
        : ref.read(onboardingWorkTimelineProvider);
  }

  AutoDisposeStateProvider<List<ClassRoutineBlock>> _providerFor(
    ScheduleSetupConfig config,
  ) {
    return config.source == RoutineImportReviewSource.classes
        ? onboardingClassTimelineProvider
        : onboardingWorkTimelineProvider;
  }

  ScheduleSetupConfig _configForBlock(ClassRoutineBlock block) {
    // If the block's icon matches class config, it's a class block
    if (block.icon == ScheduleSetupConfig.classSetup.icon) {
      return ScheduleSetupConfig.classSetup;
    }
    return ScheduleSetupConfig.workSetup;
  }

  // ---- Edit sheet ----
  Future<void> _showEditDialog(ClassRoutineBlock item) async {
    final config = _configForBlock(item);
    final subjectCtrl = TextEditingController(text: item.subject);
    final startTimeCtrl = TextEditingController(text: item.displayStartTime);
    final endTimeCtrl = TextEditingController(text: item.displayEndTime);
    final roomCtrl = TextEditingController(text: item.room);
    final selectedDays = <int>{
      ..._safeRepeatDays(
        item.repeatDays.isEmpty ? <int>[_day + 1] : item.repeatDays,
      ),
    };
    final formKey = GlobalKey<FormState>();
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.editTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F111A),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (sheetError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: OptivusColors.danger.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: OptivusColors.danger.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  sheetError!,
                                  style: const TextStyle(
                                    color: OptivusColors.danger,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            // Day chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final dayName = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ][index];
                                  final day = index + 1;
                                  final isSelected = selectedDays.contains(day);
                                  return GestureDetector(
                                    onTap: () => setSheetState(() {
                                      if (selectedDays.contains(day)) {
                                        selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
                                      }
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? config.accent
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? config.accent
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        dayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: subjectCtrl,
                              decoration: InputDecoration(
                                labelText: config.subjectLabel,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: startTimeCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Start (e.g. 9:00 AM)',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: endTimeCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'End (e.g. 10:00 AM)',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: roomCtrl,
                              decoration: InputDecoration(
                                labelText: 'Location / Room (Optional)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    // Delete block
                                    final provider = _providerFor(config);
                                    ref
                                        .read(provider.notifier)
                                        .state = _currentBlocks(config)
                                        .where((b) => b.id != item.id)
                                        .toList(growable: false);
                                    _markClassJobDirty();
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: OptivusColors.danger,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: OptivusColors.danger,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: config.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final subject = subjectCtrl.text.trim();
                                    final parsedStart = _parseClockMinute(
                                      startTimeCtrl.text,
                                    );
                                    final parsedEnd = _parseClockMinute(
                                      endTimeCtrl.text,
                                    );
                                    String? error;
                                    if (subject.isEmpty) {
                                      error = config.subjectRequiredText;
                                    } else if (parsedStart == null) {
                                      error =
                                          'Use a valid start time like 9:00 AM.';
                                    } else if (parsedEnd == null) {
                                      error =
                                          'Use a valid end time like 10:00 AM.';
                                    } else if (parsedEnd <= parsedStart) {
                                      error = config.endAfterStartText;
                                    } else if (parsedEnd - parsedStart >
                                        8 * 60) {
                                      error = config.durationTooLongText;
                                    } else if (selectedDays.isEmpty) {
                                      error = 'Select at least one repeat day.';
                                    }

                                    if (error != null) {
                                      setSheetState(() => sheetError = error);
                                      return;
                                    }

                                    final repeatDays = selectedDays.toList()
                                      ..sort();
                                    final updated = item.copyWith(
                                      subject: subject,
                                      room: roomCtrl.text.trim(),
                                      startMinute: parsedStart,
                                      endMinute: parsedEnd,
                                      repeatDays: repeatDays,
                                    );

                                    final provider = _providerFor(config);
                                    ref.read(provider.notifier).state = [
                                      for (final block in _currentBlocks(
                                        config,
                                      ))
                                        if (block.id == item.id)
                                          updated
                                        else
                                          block,
                                    ];
                                    _markClassJobDirty();

                                    Navigator.pop(ctx);
                                  },
                                  child: const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- Parse clock time (same as existing) ----
  static int? _parseClockMinute(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\s*$',
    ).firstMatch(value);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0');
    final period = match.group(3)?.toUpperCase();
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }

    var h = hour;
    if (period != null) {
      if (h < 1 || h > 12) return null;
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
    } else if (h < 0 || h > 23) {
      return null;
    }

    return h * 60 + minute;
  }

  static String _formatRange(int startMinute, int endMinute) {
    return '${TimelineUtils.formatMinute(startMinute)} - '
        '${TimelineUtils.formatMinute(endMinute)}';
  }

  // ======================================================================
  //  BUILD
  // ======================================================================
  @override
  Widget build(BuildContext context) {
    // Watch providers so we re-build when blocks change
    final classBlocks = ref.watch(onboardingClassTimelineProvider);
    final workBlocks = ref.watch(onboardingWorkTimelineProvider);
    final allBlocks = [...classBlocks, ...workBlocks];
    final hasBlocks = allBlocks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Upload card ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: _buildUploadCard(),
        ),

        const SizedBox(height: 20),

        // ── Schedule header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Set Your Weekly Schedule',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _accent,
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Day chips ──
        _buildDayChips(),

        // ── Timeline ──
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height =
                  constraints.maxHeight.isFinite && constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : _kMinTimelineAreaHeight;
              return SizedBox(
                height: height,
                child: _buildTimelineArea(allBlocks, hasBlocks),
              );
            },
          ),
        ),
      ],
    );
  }

  // ======================================================================
  //  Upload Card
  // ======================================================================
  Widget _buildUploadCard() {
    return OnboardingGlassCard(
      tint: _accent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _uploadTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _uploadSubtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Thumbnail row + arrow button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Thumbnails
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Existing photo thumbnails
                    for (var i = 0; i < _photos.length; i++)
                      _buildPhotoThumbnail(i),

                    // "Add photo" tap target
                    if (!_hasAllPhotos && !_isUploading && !_isGenerating)
                      _buildAddPhotoButton(),

                    // Uploading indicator
                    if (_isUploading) _buildUploadingIndicator(),
                  ],
                ),
              ),

              // Arrow generate button
              _buildArrowButton(),
            ],
          ),

          // Generation error
          if (_generationError != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: OptivusColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _generationError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.warning,
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

  Widget _buildPhotoThumbnail(int index) {
    final photo = _photos[index];
    final previewPath = photo.asset.localPreviewPath;
    final hasPreview = previewPath != null && File(previewPath).existsSync();

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: hasPreview
                  ? Image.file(File(previewPath), fit: BoxFit.cover)
                  : Container(
                      color: _accent.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.image_rounded,
                        color: _accent,
                        size: 28,
                      ),
                    ),
            ),
          ),
          // Label
          Positioned(
            bottom: -6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  photo.label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // X close button
          if (!_isUploading && !_isGenerating)
            Positioned(
              top: -6,
              right: -6,
              width: 24,
              height: 24,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _removePhoto(index),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return SizedBox(
      width: 64,
      height: 64,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pickAndUpload,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(
              color: _accent.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: _accent, size: 24),
              const SizedBox(height: 2),
              Text(
                'Upload',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Container(
      width: 148,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.5),
        border: Border.all(color: _accent.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
          const SizedBox(width: 8),
          const Text(
            'Uploading photo...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton() {
    final bool spinning = _isGenerating;
    final bool enabled = _canTapGenerate;
    final bool active = enabled || spinning;

    return SizedBox(
      width: 54,
      height: 54,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !spinning ? _runGeneration : null,
        child: Opacity(
          opacity: active ? 1 : 0.48,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? _accent.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.36),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.64),
                width: 1.4,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.62),
                        blurRadius: 10,
                        offset: const Offset(-3, -3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 5,
                      left: 13,
                      right: 13,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withValues(alpha: 0.34),
                        ),
                      ),
                    ),
                    if (spinning)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: active ? Colors.white : OptivusColors.textMuted,
                        size: 26,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  Day Chips
  // ======================================================================
  Widget _buildDayChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final dayName = [
              'MON',
              'TUE',
              'WED',
              'THU',
              'FRI',
              'SAT',
              'SUN',
            ][index];
            final isSelected = _day == index;
            return SizedBox(
              width: 56,
              height: 52,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _day = index),
                child: _buildDayChip(dayName, isSelected),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, bool selected) {
    final size = selected ? 46.0 : 38.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (selected ? _accent : Colors.black).withValues(
                  alpha: selected ? 0.12 : 0.05,
                ),
                blurRadius: selected ? 8 : 7,
                spreadRadius: 0,
                offset: Offset(0, selected ? 2 : 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: selected ? 0.56 : 0.70),
                blurRadius: selected ? 7 : 10,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? _accent.withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.38),
                  border: Border.all(
                    color: selected
                        ? _accent.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.72),
                    width: selected ? 1.8 : 1.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 4,
                      left: 9,
                      right: 9,
                      height: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withValues(alpha: 0.46),
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: selected ? 12 : 10,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Colors.white
                            : OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================================
  //  Timeline Area
  // ======================================================================
  Widget _buildTimelineArea(List<ClassRoutineBlock> allBlocks, bool hasBlocks) {
    // Generating state: show AI reading message
    if (_isGenerating) {
      return SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: OnboardingGlassCard(
                tint: _accent.withValues(alpha: 0.07),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI is reading your timetable...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'AI is generating your timeline.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
          ),
        ),
      );
    }

    if (!hasBlocks && _timelineError != null) {
      return SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: OnboardingGlassCard(
                tint: _accent.withValues(alpha: 0.08),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: _accent.withValues(alpha: 0.85),
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _timelineError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.textSecondary,
                        height: 1.45,
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

    // Has blocks: show the timeline
    if (hasBlocks) {
      return _buildTimeline(allBlocks);
    }

    // Empty: show placeholder
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: OnboardingGlassCard(
              tint: Colors.white.withValues(alpha: 0.30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: _accent.withValues(alpha: 0.75),
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Upload your timetable photo and tap the arrow '
                    'to generate your weekly schedule.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                      height: 1.5,
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

  // ======================================================================
  //  Timeline Rendering (faithfully replicating existing UI)
  // ======================================================================
  Widget _buildTimeline(List<ClassRoutineBlock> allBlocks) {
    final dayItems =
        allBlocks
            .where((b) => b.repeatDays.contains(_day + 1))
            .toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    final range = _rangeFor(allBlocks);
    const topPadding = 18.0;
    const bottomPadding = _kTimelineBottomPadding;

    final maxCardBottom = dayItems.fold<double>(0, (maxBottom, item) {
      final bottom = _timelineY(
        minuteOfDay: item.endMinute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      return bottom > maxBottom ? bottom : maxBottom;
    });

    final timelineHeight = [
      _timelineY(
            minuteOfDay: range.endMinute,
            visibleStartMinute: range.startMinute,
            topPadding: topPadding,
          ) +
          bottomPadding,
      maxCardBottom + bottomPadding,
    ].reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _kTimelineBottomPadding),
          child: SizedBox(
            height: timelineHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Vertical rail
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 48,
                  width: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.16),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Minute tick indicators
                ..._buildMinuteIndicators(
                  range: range,
                  dayItems: dayItems,
                  topPadding: topPadding,
                ),

                // Hour labels
                ...List.generate(range.hourCount + 1, (i) {
                  final hour = (range.startHour + i) % 24;
                  final minute = range.startMinute + i * 60;
                  final ampm = hour < 12 ? 'AM' : 'PM';
                  final displayHour = hour == 0
                      ? 12
                      : (hour > 12 ? hour - 12 : hour);
                  final label = '$displayHour $ampm';
                  return Positioned(
                    top:
                        _timelineY(
                          minuteOfDay: minute,
                          visibleStartMinute: range.startMinute,
                          topPadding: topPadding,
                        ) -
                        10,
                    left: 0,
                    width: 56,
                    height: 20,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          width: 42,
                          child: Text(
                            label,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 48,
                          top: 9,
                          width: 4,
                          height: 1.5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (dayItems.isEmpty)
                  Positioned(
                    top: topPadding + 28,
                    left: _kLeftOffset,
                    right: 16,
                    child: OnboardingGlassCard(
                      tint: Colors.white.withValues(alpha: 0.30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: const Text(
                        'No fixed blocks on this day.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ),
                  ),

                // Block cards
                ...dayItems.map(
                  (item) => _buildColoredBlock(
                    item,
                    visibleStartMinute: range.startMinute,
                    topPadding: topPadding,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Minute indicators ----
  List<Widget> _buildMinuteIndicators({
    required _TimelineRange range,
    required List<ClassRoutineBlock> dayItems,
    required double topPadding,
  }) {
    final widgets = <Widget>[];
    final boundaryMinutes =
        (<int>{
            for (final item in dayItems) ...[item.startMinute, item.endMinute],
          }.where((minute) {
            return minute % 60 != 0 &&
                minute > range.startMinute &&
                minute < range.endMinute;
          }).toList())
          ..sort();

    for (final minute in boundaryMinutes) {
      final y = _timelineY(
        minuteOfDay: minute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      widgets.addAll([
        Positioned(
          top: y - 8,
          left: 0,
          width: 38,
          height: 16,
          child: Text(
            TimelineUtils.formatMinuteShort(minute),
            textAlign: TextAlign.right,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _accent.withValues(alpha: 0.68),
            ),
          ),
        ),
        Positioned(
          top: y,
          left: 44,
          width: 18,
          height: 1.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ]);
    }

    return widgets;
  }

  // ---- Colored block card (exact copy from existing) ----
  Widget _buildColoredBlock(
    ClassRoutineBlock item, {
    required int visibleStartMinute,
    required double topPadding,
  }) {
    final top = _timelineY(
      minuteOfDay: item.startMinute,
      visibleStartMinute: visibleStartMinute,
      topPadding: topPadding,
    );
    final bottom = _timelineY(
      minuteOfDay: item.endMinute,
      visibleStartMinute: visibleStartMinute,
      topPadding: topPadding,
    );
    final height = (bottom - top).clamp(1.0, double.infinity).toDouble();

    final config = _configForBlock(item);
    final baseColor = item.color ?? config.accent;

    return Positioned(
      top: top,
      left: _kLeftOffset,
      right: 16,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showEditDialog(item),
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: 0.3),
                  baseColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.icon ?? config.icon,
                            color: baseColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F111A),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.more_vert_rounded,
                            color: OptivusColors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatRange(item.startMinute, item.endMinute),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textBody,
                              ),
                            ),
                          ),
                          if (item.room.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.room,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: OptivusColors.textBody,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
