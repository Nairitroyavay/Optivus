import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/optivus_colors.dart';
import '../../../models/onboarding_draft.dart';
import '../../routine/utils/timeline_utils.dart';
import '../../../state/app_state.dart' show mockOnboardingProvider;
import 'onboarding_base_timeline_helpers.dart' show onboardingFixedStepIndex;
import 'onboarding_class_setup_timeline.dart' show ClassRoutineBlock;

class OnboardingStep6 extends ConsumerStatefulWidget {
  const OnboardingStep6({super.key});

  @override
  ConsumerState<OnboardingStep6> createState() => _OnboardingStep6State();
}

class _OnboardingStep6State extends ConsumerState<OnboardingStep6> {
  static const double _kHourHeight = 84.0;
  static const double _kPixelsPerMinute = _kHourHeight / 60.0;
  static const double _kLeftOffset = 64.0;
  static const double _kTimelineBottomPadding = 420.0;

  final ScrollController _scrollController = ScrollController();
  String? _frontBlockId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureDefaults();
    });
  }

  void _ensureDefaults() {
    final draft = ref.read(mockOnboardingProvider).draft;
    final base = draft.baseTimeline.withRequiredFixedBlocks();
    if (draft.baseTimeline != base) {
      ref
          .read(mockOnboardingProvider.notifier)
          .updateDraft((d) => d.copyWith(baseTimeline: base));
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepDirty(onboardingFixedStepIndex, true);
    }
  }

  List<ClassRoutineBlock> _getBlocks(BaseTimelineDraft baseTimeline) {
    final timelineBlocks = baseTimeline.blocks
        .where((b) => b.section == 'fixed')
        .toList();

    return timelineBlocks.map((entry) {
      return ClassRoutineBlock(
        id: entry.id,
        subject: entry.title,
        room: entry.location ?? '',
        startMinute: entry.startMinute,
        endMinute: entry.endMinute,
        repeatDays: entry.repeatDays,
        icon: Icons.event_rounded,
        color: OptivusColors.purpleAccent,
        hasTopTape: true,
        hasBottomTape: true,
      );
    }).toList();
  }

  void _setBlocks(List<ClassRoutineBlock> blocks) {
    ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
      final base = draft.baseTimeline;
      final existingBlocks = base.blocks
          .where((b) => b.section != 'fixed')
          .toList();

      final fixedBlocks = blocks.map((b) {
        if (b.id == BaseTimelineDraft.fixedSleepId) {
          return TimelineBlockDraft(
            id: b.id,
            section: 'fixed',
            title: 'Sleep',
            startMinute: b.startMinute,
            endMinute: b.endMinute,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
            source: OnboardingDraft.sourceOnboarding,
            crossesMidnight: b.endMinute < b.startMinute,
          );
        } else if (b.id == BaseTimelineDraft.fixedBathId) {
          return TimelineBlockDraft(
            id: b.id,
            section: 'fixed',
            title: 'Bath',
            startMinute: b.startMinute,
            endMinute: b.endMinute,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
            source: OnboardingDraft.sourceOnboarding,
            crossesMidnight: false,
          );
        }
        return TimelineBlockDraft(
          id: b.id,
          section: 'fixed',
          title: b.subject,
          startMinute: b.startMinute,
          endMinute: b.endMinute,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          location: b.room,
          blockType: TimelineBlockDraft.hardBlockKey,
          source: OnboardingDraft.sourceOnboarding,
          crossesMidnight: false,
        );
      }).toList();

      existingBlocks.addAll(fixedBlocks);

      return draft.copyWith(
        baseTimeline: base.copyWith(blocks: existingBlocks),
      );
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepDirty(onboardingFixedStepIndex, true);
    _validate();
  }

  void _validate() {
    final draft = ref.read(mockOnboardingProvider).draft;
    final blocks = _getBlocks(draft.baseTimeline);
    final sleep = blocks
        .where((b) => b.id == BaseTimelineDraft.fixedSleepId)
        .toList();
    final bath = blocks
        .where((b) => b.id == BaseTimelineDraft.fixedBathId)
        .toList();

    if (sleep.isEmpty || bath.isEmpty) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setValidationMessage('Missing required Sleep or Bath block.');
      return;
    }

    ref.read(mockOnboardingProvider.notifier).setValidationMessage(null);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final blocks = _getBlocks(draft.baseTimeline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed Header
        Padding(
          key: const Key('onboarding-step6-header'),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fixed Schedule',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manual-only non-negotiable blocks.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('onboarding-step6-add-button'),
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: OptivusColors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Timeline Area
        Expanded(child: _buildTimeline(blocks)),
      ],
    );
  }

  Widget _buildTimeline(List<ClassRoutineBlock> allBlocks) {
    const topPadding = 18.0;

    // Expand overnight blocks visually
    final visualBlocks = <ClassRoutineBlock>[];
    for (final block in allBlocks) {
      if (block.startMinute > block.endMinute) {
        // Crosses midnight, split into two visual blocks
        visualBlocks.add(
          block.copyWith(id: '${block.id}-part1', endMinute: 1440),
        );
        visualBlocks.add(
          block.copyWith(id: '${block.id}-part2', startMinute: 0),
        );
      } else {
        visualBlocks.add(block);
      }
    }
    visualBlocks.sort((a, b) => a.startMinute.compareTo(b.startMinute));

    int startMinute = 24 * 60;
    int endMinute = 0;
    if (visualBlocks.isEmpty) {
      startMinute = 8 * 60;
      endMinute = 18 * 60;
    } else {
      for (final b in visualBlocks) {
        if (b.startMinute < startMinute) startMinute = b.startMinute;
        if (b.endMinute > endMinute) endMinute = b.endMinute;
      }
      startMinute = (startMinute ~/ 60) * 60;
      endMinute = ((endMinute ~/ 60) + 1) * 60;
      if (endMinute - startMinute < 10 * 60) {
        endMinute = math.min(24 * 60, startMinute + 10 * 60);
      }
    }

    final hourCount = (endMinute - startMinute) ~/ 60;

    double yFor(int minute) {
      return topPadding + (minute - startMinute) * _kPixelsPerMinute;
    }

    double hFor(int start, int end) {
      return (end - start) * _kPixelsPerMinute;
    }

    final maxCardBottom = visualBlocks.fold<double>(0, (max, item) {
      final bottom =
          yFor(item.startMinute) + hFor(item.startMinute, item.endMinute);
      return bottom > max ? bottom : max;
    });

    final timelineHeight = math.max(
      yFor(endMinute) + _kTimelineBottomPadding,
      maxCardBottom + _kTimelineBottomPadding,
    );

    return Container(
      key: const Key('onboarding-step6-timeline'),
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
          key: const Key('onboarding-step6-timeline-scroll'),
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _kTimelineBottomPadding),
          child: SizedBox(
            height: timelineHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Vertical rail
                Positioned(
                  key: const Key('onboarding-step6-rail'),
                  top: 0,
                  bottom: 0,
                  left: 48,
                  width: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: OptivusColors.purpleAccent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: OptivusColors.purpleAccent.withValues(
                          alpha: 0.40,
                        ),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: OptivusColors.purpleAccent.withValues(
                            alpha: 0.18,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hour labels and minute ticks
                ...List.generate(hourCount + 1, (i) {
                  final minute = startMinute + i * 60;
                  final hour = (minute ~/ 60) % 24;
                  final ampm = hour < 12 ? 'AM' : 'PM';
                  final displayHour = hour == 0
                      ? 12
                      : (hour > 12 ? hour - 12 : hour);
                  final label = '$displayHour $ampm';
                  final y = yFor(minute);

                  return Positioned(
                    top: y - 10,
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
                              color: OptivusColors.purpleAccent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Blocks
                ...visualBlocks.map((block) {
                  final y = yFor(block.startMinute);
                  final h = hFor(block.startMinute, block.endMinute);
                  final isFront = _frontBlockId == block.id;

                  // For rendering split blocks, map back to original for editing
                  final originalBlock = allBlocks.firstWhere(
                    (b) => block.id.startsWith(b.id),
                    orElse: () => block,
                  );

                  return Positioned(
                    top: y,
                    left: _kLeftOffset,
                    right: 16,
                    height: h,
                    child: GestureDetector(
                      key: Key('onboarding-step6-block-${originalBlock.id}'),
                      onTap: () {
                        setState(() => _frontBlockId = block.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(
                            alpha: isFront ? 0.72 : 0.58,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              OptivusColors.purpleAccent.withValues(
                                alpha: isFront ? 0.26 : 0.18,
                              ),
                              OptivusColors.purpleAccent.withValues(
                                alpha: isFront ? 0.08 : 0.04,
                              ),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: isFront ? 0.96 : 0.82,
                            ),
                            width: isFront ? 1.6 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: OptivusColors.purpleAccent.withValues(
                                alpha: isFront ? 0.18 : 0.09,
                              ),
                              blurRadius: isFront ? 14 : 10,
                              offset: Offset(0, isFront ? 5 : 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              originalBlock.icon ?? Icons.event_rounded,
                              color: OptivusColors.purpleAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      originalBlock.subject,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F111A),
                                      ),
                                    ),
                                    if (h >= 56) ...[
                                      const SizedBox(height: 6),
                                      _buildBlockInfoChip(
                                        '${TimelineUtils.formatMinute(block.startMinute)} - ${TimelineUtils.formatMinute(block.endMinute)}',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            _buildBlockMenuButton(originalBlock),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBlockMenuButton(ClassRoutineBlock item) {
    return PopupMenuButton<String>(
      key: ValueKey('onboarding-step6-menu-${item.id}'),
      tooltip: 'Block actions',
      padding: EdgeInsets.zero,
      iconSize: 18,
      splashRadius: 18,
      child: const SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: Icon(
            Icons.more_vert_rounded,
            color: OptivusColors.textSecondary,
            size: 18,
          ),
        ),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditDialog(item);
        } else if (value == 'delete') {
          _deleteBlock(item);
        }
      },
      itemBuilder: (context) {
        final isMandatory =
            item.id == BaseTimelineDraft.fixedSleepId ||
            item.id == BaseTimelineDraft.fixedBathId;
        return [
          const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
          if (!isMandatory)
            const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
        ];
      },
    );
  }

  void _deleteBlock(ClassRoutineBlock item) {
    final draft = ref.read(mockOnboardingProvider).draft;
    final blocks = _getBlocks(draft.baseTimeline).toList();
    blocks.removeWhere((b) => b.id == item.id);
    _setBlocks(blocks);
  }

  void _showAddDialog() {
    _showEditDialog(
      ClassRoutineBlock(
        id: 'fixed_${DateTime.now().millisecondsSinceEpoch}',
        subject: 'Fixed Block',
        startMinute: 20 * 60,
        endMinute: 20 * 60 + 30,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      ),
      isNew: true,
    );
  }

  Future<void> _showEditDialog(
    ClassRoutineBlock item, {
    bool isNew = false,
  }) async {
    final isSleep = item.id == BaseTimelineDraft.fixedSleepId;
    final isBath = item.id == BaseTimelineDraft.fixedBathId;
    final isMandatory = isSleep || isBath;

    final subjectCtrl = TextEditingController(text: item.subject);
    final startTimeCtrl = TextEditingController(text: item.displayStartTime);
    final endTimeCtrl = TextEditingController(text: item.displayEndTime);

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
                              isNew
                                  ? 'Add fixed block'
                                  : (isSleep
                                        ? 'Edit Sleep'
                                        : (isBath
                                              ? 'Edit Bath'
                                              : 'Edit fixed block')),
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
                            TextFormField(
                              key: const ValueKey('block_name_input'),
                              controller: subjectCtrl,
                              enabled: !isMandatory,
                              decoration: InputDecoration(
                                labelText: 'Fixed block name',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Fixed block name is required.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: const ValueKey('start_time_input'),
                                    controller: startTimeCtrl,
                                    decoration: InputDecoration(
                                      labelText: isSleep
                                          ? 'Sleep time'
                                          : (isBath
                                                ? 'Bath start'
                                                : 'Start time'),
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
                                    key: const ValueKey('end_time_input'),
                                    controller: endTimeCtrl,
                                    decoration: InputDecoration(
                                      labelText: isSleep
                                          ? 'Wake time'
                                          : (isBath ? 'Bath end' : 'End time'),
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
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Spacer(),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: OptivusColors.purpleAccent,
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
                                    if (!formKey.currentState!.validate())
                                      return;

                                    final subject = subjectCtrl.text.trim();
                                    final parsedStart = _parseClockMinute(
                                      startTimeCtrl.text,
                                    );
                                    final parsedEnd = _parseClockMinute(
                                      endTimeCtrl.text,
                                    );

                                    String? error;
                                    if (subject.isEmpty) {
                                      error = 'Fixed block name is required.';
                                    } else if (parsedStart == null) {
                                      error = 'Invalid start time.';
                                    } else if (parsedEnd == null) {
                                      error = 'Invalid end time.';
                                    } else if (isSleep &&
                                        parsedStart == parsedEnd) {
                                      error =
                                          'Sleep and wake time cannot be the same.';
                                    } else if (isBath &&
                                        parsedEnd <= parsedStart) {
                                      error =
                                          'Bath end time must be after bath start time.';
                                    } else if (!isSleep &&
                                        parsedEnd <= parsedStart) {
                                      error =
                                          'End time must be after start time.';
                                    } else if (!isSleep &&
                                        parsedEnd - parsedStart > 12 * 60) {
                                      error = 'Block duration is too long.';
                                    }

                                    if (error != null) {
                                      setSheetState(() => sheetError = error);
                                      return;
                                    }

                                    final updated = item.copyWith(
                                      subject: isSleep
                                          ? 'Sleep'
                                          : (isBath ? 'Bath' : subject),
                                      startMinute: parsedStart,
                                      endMinute: parsedEnd,
                                      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
                                    );

                                    final draft = ref
                                        .read(mockOnboardingProvider)
                                        .draft;
                                    final blocks = _getBlocks(
                                      draft.baseTimeline,
                                    ).toList();
                                    if (isNew) {
                                      blocks.add(updated);
                                    } else {
                                      final index = blocks.indexWhere(
                                        (b) => b.id == item.id,
                                      );
                                      if (index >= 0) blocks[index] = updated;
                                    }
                                    _setBlocks(blocks);

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

  static int? _parseClockMinute(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM|am|pm)?\s*$',
    ).firstMatch(value);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0');
    final period = match.group(3)?.toUpperCase();
    if (hour == null || minute == null || minute < 0 || minute > 59)
      return null;

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
}
