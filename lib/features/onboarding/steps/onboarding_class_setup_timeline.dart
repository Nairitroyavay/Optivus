import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/services/routine_import_extraction_service.dart';

import 'package:optivus/features/onboarding/steps/base_timeline_step.dart';
import 'package:optivus/models/uploaded_asset.dart';

// Provider to hold the local drafts for the inline timeline
final onboardingClassTimelineProvider =
    StateProvider.autoDispose<List<ClassRoutineBlock>>((ref) => []);

class ClassRoutineBlock {
  final String id;
  String subject;
  String room;
  String professor;
  double start; // Hours from 6 AM
  double duration; // Hours length
  IconData? icon;
  Color? color;
  bool isAdd;
  bool hasTopTape;
  bool hasBottomTape;
  bool reminderEnabled;
  int? weekday;
  String? suggestionId;

  String get displayStartTime => _formatTimeFromStart(start);
  String get displayEndTime => _formatTimeFromStart(start + duration);

  ClassRoutineBlock({
    required this.id,
    required this.subject,
    this.room = '',
    this.professor = '',
    required this.start,
    this.duration = 1.0,
    this.icon,
    this.color,
    this.isAdd = false,
    this.hasTopTape = false,
    this.hasBottomTape = false,
    this.reminderEnabled = false,
    this.weekday,
    this.suggestionId,
  });

  ClassRoutineBlock clone() {
    return ClassRoutineBlock(
      id: id,
      subject: subject,
      room: room,
      professor: professor,
      start: start,
      duration: duration,
      icon: icon,
      color: color,
      isAdd: isAdd,
      hasTopTape: hasTopTape,
      hasBottomTape: hasBottomTape,
      reminderEnabled: reminderEnabled,
      weekday: weekday,
      suggestionId: suggestionId,
    );
  }
}

String _formatTimeFromStart(double hoursFrom6AM) {
  int totalMinutes = ((hoursFrom6AM + 6) * 60).round();
  int h = (totalMinutes ~/ 60) % 24;
  int m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

double _parseHoursFrom6AM(String timeStr) {
  try {
    timeStr = timeStr.trim().toUpperCase();
    bool isPM = timeStr.contains('PM');
    String cleaned = timeStr.replaceAll('AM', '').replaceAll('PM', '').trim();
    List<String> parts = cleaned.split(':');
    if (parts.isEmpty) return 0.0;
    int h = int.parse(parts[0]);
    int m = parts.length > 1 ? int.parse(parts[1]) : 0;

    if (isPM && h != 12) h += 12;
    if (!isPM && h == 12) h = 0;

    double hoursFromMidnight = h + (m / 60.0);
    double from6AM = hoursFromMidnight - 6;
    if (from6AM < 0) from6AM += 24;
    return from6AM;
  } catch (e) {
    return 0.0;
  }
}

class OnboardingClassSetupWidget extends ConsumerStatefulWidget {
  final int stepIndex;

  const OnboardingClassSetupWidget({super.key, required this.stepIndex});

  @override
  ConsumerState<OnboardingClassSetupWidget> createState() =>
      _OnboardingClassSetupWidgetState();
}

class _OnboardingClassSetupWidgetState
    extends ConsumerState<OnboardingClassSetupWidget> {
  final RoutineImportExtractionService _extractionService =
      const RoutineImportExtractionService();

  int _day = 0; // 0 for Mon, 6 for Sun
  final double kHourHeight = 84.0;
  final double kLeftOffset = 64.0;

  final List<Color> _cycleColors = [
    const Color(0xFF378ADD), // Blue
    const Color(0xFFF59E0B), // Orange/Gold
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF43F5E), // Rose
  ];
  int _colorIndex = 0;
  bool _localExtractionTriggered = false;

  @override
  void initState() {
    super.initState();
  }

  void _checkAndRunExtraction(BuildContext context) async {
    if (_localExtractionTriggered) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    final uploadState = ref.read(uploadControllerProvider);
    final purpose = onboardingUploadPurposeForBaseTimelineSection(onboardingSectionClasses);
    final applies = purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;

    // Wait until upload finishes
    if (applies && uploadState.isBusy) return;

    if (pending != null &&
        pending.hasUploadedAssetReference &&
        pending.parsedBlocks.isEmpty) {
      _localExtractionTriggered = true;

      // Extract
      final aiController = ref.read(routineImportAiControllerProvider.notifier);
      final reviewDraft = _extractionService.buildReviewDraft(
        uid: draft.uid,
        source: RoutineImportReviewSource.classes,
        onboardingDraft: draft,
      );

      final result = await aiController.runExtraction(reviewDraft);

      if (!mounted) return;

      if (result != null && result.candidates.isNotEmpty) {
        _populateTimelineFromCandidates(result.candidates);
        _updatePendingBlocks(result.candidates);
      } else {
        // Zero blocks or error
        _updatePendingBlocks([]);
      }
      _localExtractionTriggered = false;
    } else if (pending != null && pending.parsedBlocks.isNotEmpty) {
       // If returning to screen and blocks exist, ensure we populate if empty
       final localBlocks = ref.read(onboardingClassTimelineProvider);
       if (localBlocks.isEmpty && !_localExtractionTriggered) {
          final reviewDraft = _extractionService.buildReviewDraft(
            uid: draft.uid,
            source: RoutineImportReviewSource.classes,
            onboardingDraft: draft,
          );
          _populateTimelineFromCandidates(reviewDraft.candidateBlocks);
       }
    }
  }

  void _updatePendingBlocks(List<RoutineImportCandidateBlock> candidates) {
    final draft = ref.read(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    if (pending == null) return;

    final blocks = candidates.map((c) => TimelineBlockDraft(
      id: c.id,
      section: 'classes',
      title: c.title,
      startMinute: c.startMinute,
      endMinute: c.endMinute,
      repeatDays: c.repeatDays,
      blockType: c.blockType,
      source: 'ai_import',
    )).toList();

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(pending.copyWith(parsedBlocks: blocks)),
    );
  }

  void _populateTimelineFromCandidates(List<RoutineImportCandidateBlock> candidates) {
    final Map<int, List<ClassRoutineBlock>> weekly = {
      for (int i = 0; i < 7; i++) i: <ClassRoutineBlock>[],
    };

    for (final candidate in candidates) {
      for (final day in candidate.repeatDays) {
        final dayIndex = (day - 1).clamp(0, 6);
        final startHours = ((candidate.startMinute / 60.0) - 6).clamp(0.0, 18.0).toDouble();
        final endHours = ((candidate.endMinute / 60.0) - 6).clamp(0.0, 18.0).toDouble();
        final duration = (endHours - startHours).clamp(0.5, 18.0).toDouble();

        weekly[dayIndex]!.add(
          ClassRoutineBlock(
            id: 'class_${dayIndex}_${candidate.id}',
            subject: candidate.title,
            room: candidate.location ?? '',
            start: startHours,
            duration: duration,
            icon: Icons.school_rounded,
            color: _cycleColors[_colorIndex % _cycleColors.length],
            hasTopTape: true,
            hasBottomTape: true,
            weekday: day,
          ),
        );
        _colorIndex++;
      }
    }

    final flatList = <ClassRoutineBlock>[];
    for (int i = 0; i < 7; i++) {
      weekly[i]!.sort((a, b) => a.start.compareTo(b.start));
      flatList.addAll(weekly[i]!);
    }

    ref.read(onboardingClassTimelineProvider.notifier).state = flatList;
  }

  Future<void> _startUpload(BuildContext context) async {
    final purpose = onboardingUploadPurposeForBaseTimelineSection(onboardingSectionClasses);
    if (purpose == null) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = ref.read(authProvider).user?.uid ?? draft.uid;
    final now = DateTime.now();
    final existing = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    
    final seed = PendingFutureImportDraft(
      id: onboardingImportId(onboardingSectionClasses, 'photo_upload'),
      section: onboardingSectionClasses,
      mode: 'Photo Upload',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: existing?.uploadedAssetId,
      uploadedAssetR2Key: existing?.uploadedAssetR2Key,
      uploadedAssetStatus: existing?.uploadedAssetStatus,
      parsedBlocks: const [], // Clear parsed blocks for new upload
    );

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(seed),
    );

    final asset = await ref.read(uploadControllerProvider.notifier).startUpload(
      uid: uid,
      purpose: purpose,
      sourceFeature: OnboardingDraft.sourceOnboarding,
    );

    if (!mounted) return;
    final state = ref.read(uploadControllerProvider);
    final next = seed.copyWith(
      updatedAt: DateTime.now(),
      status: asset == null && state.status == UploadFlowStatus.failed
          ? PendingFutureImportDraft.errorStatus
          : PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: asset?.assetId ?? state.asset?.assetId,
      uploadedAssetR2Key: asset?.r2Key ?? state.asset?.r2Key,
      uploadedAssetStatus: asset?.status.name ??
          state.asset?.status.name ??
          (state.status == UploadFlowStatus.failed
              ? UploadedAssetStatus.failed.name
              : UploadedAssetStatus.uploaded.name),
      errorMessage: state.status == UploadFlowStatus.failed ? state.errorMessage : null,
      clearErrorMessage: state.status != UploadFlowStatus.failed,
    );

    updateBaseTimelineDraft(
      ref,
      widget.stepIndex,
      (base) => base.upsertPendingImport(next),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(uploadControllerProvider, (previous, next) {
      _checkAndRunExtraction(context);
    });

    final draft = ref.watch(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(onboardingSectionClasses);
    final uploadState = ref.watch(uploadControllerProvider);
    final aiState = ref.watch(routineImportAiControllerProvider);

    final purpose = onboardingUploadPurposeForBaseTimelineSection(onboardingSectionClasses);
    final applies = purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;
    final busy = applies && uploadState.isBusy;
    final extracting = aiState.isExtracting;

    if (busy || extracting) {
      return _buildLoadingState(busy ? 'Uploading photo...' : 'AI is reading your timetable…');
    }

    if (pending?.hasUploadedAssetReference == true && pending!.parsedBlocks.isNotEmpty) {
       return _buildTimelineState();
    }

    if (pending?.hasUploadedAssetReference == true && pending!.parsedBlocks.isEmpty && !extracting && !busy) {
        // Zero blocks handled here
        return _buildZeroBlocksState();
    }

    return _buildUploadState();
  }

  Widget _buildLoadingState(String message) {
    return OnboardingGlassCard(
      tint: OptivusColors.aquaAccent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: OptivusColors.aquaAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZeroBlocksState() {
     return OnboardingGlassCard(
      tint: OptivusColors.warning.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: OptivusColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'We couldn’t detect classes clearly.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OnboardingActionPill(
            label: 'Upload again',
            icon: Icons.upload_rounded,
            accent: OptivusColors.warning,
            selected: true,
            onTap: () => _startUpload(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadState() {
    return OnboardingGlassCard(
      tint: OptivusColors.aquaAccent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: OptivusColors.aquaAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload your class timetable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a clear photo of your weekly class schedule.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OnboardingActionPill(
            label: 'Upload photo',
            icon: Icons.upload_rounded,
            accent: OptivusColors.aquaAccent,
            selected: true,
            compact: true,
            onTap: () => _startUpload(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineState() {
    final allBlocks = ref.watch(onboardingClassTimelineProvider);
    final dayItems = allBlocks.where((b) => b.weekday == _day + 1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.glassFill,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8), // soft cream/yellow background
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                 ),
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text(
                          'CLASS SETUP',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFD97706), letterSpacing: 1),
                       ),
                       const SizedBox(height: 12),
                       const Text(
                          'Your Fixed Classes.',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F111A)),
                       ),
                       const SizedBox(height: 4),
                       const Text(
                          'Stay on top of your semester with a clear timetable.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                       ),
                    ],
                 ),
              ),
              // Day Chips
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 color: Colors.white.withValues(alpha: 0.1),
                 child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                       children: List.generate(7, (index) {
                          final dayName = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][index];
                          final isSelected = _day == index;
                          return Padding(
                             padding: const EdgeInsets.only(right: 8),
                             child: GestureDetector(
                                onTap: () => setState(() => _day = index),
                                child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                   decoration: BoxDecoration(
                                      color: isSelected ? OptivusColors.aquaAccent : Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                   ),
                                   child: Text(
                                      dayName,
                                      style: TextStyle(
                                         fontSize: 12,
                                         fontWeight: FontWeight.w800,
                                         color: isSelected ? Colors.white : OptivusColors.textSecondary,
                                      ),
                                   ),
                                ),
                             ),
                          );
                       }),
                    ),
                 ),
              ),
              // Timeline View
              SizedBox(
                 height: 400,
                 child: Stack(
                    children: [
                       // Background lines
                       Positioned.fill(
                          child: CustomPaint(
                             painter: _TimelineBackgroundPainter(kHourHeight, kLeftOffset),
                          ),
                       ),
                       // Hour Labels
                       Positioned.fill(
                          child: ListView.builder(
                             physics: const NeverScrollableScrollPhysics(),
                             itemCount: 19,
                             itemBuilder: (ctx, index) {
                                return SizedBox(
                                   height: kHourHeight,
                                   child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                         padding: const EdgeInsets.only(left: 12, top: 4),
                                         child: Text(
                                            _formatTimeFromStart(index.toDouble()),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                         ),
                                      ),
                                   ),
                                );
                             },
                          ),
                       ),
                       // Blocks
                       Positioned.fill(
                          child: SingleChildScrollView(
                             child: SizedBox(
                                height: 19 * kHourHeight,
                                child: Stack(
                                   clipBehavior: Clip.none,
                                   children: dayItems.map((item) {
                                      return _buildColoredBlock(item);
                                   }).toList(),
                                ),
                             ),
                          ),
                       ),
                    ],
                 ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColoredBlock(ClassRoutineBlock item) {
    final top = item.start * kHourHeight;
    final height = item.duration * kHourHeight;

    return Positioned(
      top: top,
      left: kLeftOffset,
      right: 16,
      height: height,
      child: GestureDetector(
        onTap: () => _showEditDialog(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: item.color?.withValues(alpha: 0.15) ?? OptivusColors.aquaAccent.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
          ),
          child: ClipRRect(
             borderRadius: BorderRadius.circular(16),
             child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                   padding: const EdgeInsets.all(10),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                            children: [
                               Icon(Icons.school_rounded, color: item.color, size: 16),
                               const SizedBox(width: 6),
                               Expanded(
                                  child: Text(
                                     item.subject,
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F111A)),
                                  ),
                               ),
                               const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 16),
                            ],
                         ),
                         const SizedBox(height: 4),
                         Text(
                            '${item.displayStartTime} - ${item.displayEndTime}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
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

  Future<void> _showEditDialog(ClassRoutineBlock item) async {
    TextEditingController subjectCtrl = TextEditingController(text: item.subject);
    TextEditingController startTimeCtrl = TextEditingController(text: item.displayStartTime);
    TextEditingController endTimeCtrl = TextEditingController(text: item.displayEndTime);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
           padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
           child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                 key: formKey,
                 child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text('Edit Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                       const SizedBox(height: 16),
                       TextFormField(
                          controller: subjectCtrl,
                          decoration: InputDecoration(
                             labelText: 'Subject',
                             filled: true,
                             fillColor: const Color(0xFFF1F5F9),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                       ),
                       const SizedBox(height: 12),
                       Row(
                          children: [
                             Expanded(
                                child: TextFormField(
                                   controller: startTimeCtrl,
                                   decoration: InputDecoration(
                                      labelText: 'Start (HH:mm)',
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                   ),
                                ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                                child: TextFormField(
                                   controller: endTimeCtrl,
                                   decoration: InputDecoration(
                                      labelText: 'End (HH:mm)',
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                   ),
                                ),
                             ),
                          ],
                       ),
                       const SizedBox(height: 24),
                       Row(
                          children: [
                             TextButton(
                                onPressed: () {
                                   final currentList = ref.read(onboardingClassTimelineProvider);
                                   ref.read(onboardingClassTimelineProvider.notifier).state = currentList.where((b) => b.id != item.id).toList();
                                   Navigator.pop(ctx);
                                },
                                child: const Text('Delete', style: TextStyle(color: OptivusColors.danger, fontWeight: FontWeight.w700)),
                             ),
                             const Spacer(),
                             ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                   backgroundColor: OptivusColors.aquaAccent,
                                   foregroundColor: Colors.white,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                   if (!formKey.currentState!.validate()) return;
                                   item.subject = subjectCtrl.text.trim();
                                   double parsedStart = _parseHoursFrom6AM(startTimeCtrl.text);
                                   double parsedEnd = _parseHoursFrom6AM(endTimeCtrl.text);
                                   if (parsedEnd <= parsedStart && parsedEnd != 0.0) parsedEnd += 24;
                                   item.start = parsedStart;
                                   item.duration = parsedEnd - parsedStart > 0.5 ? parsedEnd - parsedStart : 0.5;

                                   // Trigger rebuild
                                   final currentList = ref.read(onboardingClassTimelineProvider);
                                   ref.read(onboardingClassTimelineProvider.notifier).state = [...currentList];
                                   Navigator.pop(ctx);
                                },
                                child: const Text('Save Changes'),
                             ),
                          ],
                       ),
                    ],
                 ),
              ),
           ),
        );
      }
    );
  }
}

class _TimelineBackgroundPainter extends CustomPainter {
  final double hourHeight;
  final double leftOffset;

  _TimelineBackgroundPainter(this.hourHeight, this.leftOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 18; i++) {
      final y = i * hourHeight;
      canvas.drawLine(Offset(leftOffset, y), Offset(size.width, y), paint);
    }
    canvas.drawLine(Offset(leftOffset, 0), Offset(leftOffset, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
