part of '../onboarding_step_7_skin_care_setup.dart';

class _SkinCareTimelineSection extends ConsumerWidget {
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final ValueChanged<int> onDayChanged;
  final String emptyLabel;
  final Color accent;
  final List<String> specialCareNotes;

  const _SkinCareTimelineSection({
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
    required this.emptyLabel,
    required this.accent,
    this.specialCareNotes = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = SkinTimelineAdapter(accent: accent);
    final entries = [for (final block in blocks) ...adapter.toEntries(block)];
    return Expanded(
      child: FullScreenTimelineScaffold(
        key: const ValueKey('onboarding-step7-full-timeline'),
        entries: entries,
        selectedDay: selectedDay,
        onDayChanged: onDayChanged,
        emptyDayMessage: emptyLabel,
        accent: accent,
        styleBuilder: adapter.styleForEntry,
        blockBuilder: (context, positioned) {
          final block = blocks
              .where((candidate) => candidate.id == positioned.entry.sourceId)
              .first;
          return _SkinCareBlockCard(
            item: block,
            baseColor: accent,
            onEditRequested: () =>
                _showSkinCareBlockEditSheet(context, ref, block, accent),
          );
        },
        headerBanner: specialCareNotes.isEmpty
            ? null
            : Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your Routine',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey(
                      'onboarding-step7-special-care-notes-button',
                    ),
                    onPressed: () => _showSkinCareSpecialCareNotesSheet(
                      context,
                      specialCareNotes,
                      accent,
                    ),
                    icon: Icon(Icons.info_outline_rounded, color: accent),
                  ),
                ],
              ),
        onEntryTapped: (entry) {
          final block = blocks
              .where((candidate) => candidate.id == entry.sourceId)
              .firstOrNull;
          if (block == null) return;
          _showSkinCareBlockEditSheet(context, ref, block, accent);
        },
      ),
    );
  }
}

// ignore: unused_element
Future<void> _showSkinCareBlockEditSheet(
  BuildContext context,
  WidgetRef ref,
  TimelineBlockDraft block,
  Color accent,
) async {
  final titleCtrl = TextEditingController(text: block.title);
  final startTimeCtrl = TextEditingController(
    text: onboardingTimeLabel(block.startMinute),
  );
  final productsCtrl = TextEditingController(
    text: block.skincareProducts.join('\n'),
  );
  final stepsCtrl = TextEditingController(text: block.skincareSteps.join('\n'));
  final selectedDays = <int>{
    ...block.repeatDays.where((day) => day >= 1 && day <= 7),
  };
  if (selectedDays.isEmpty) selectedDays.addAll(onboardingEveryDay());
  final formKey = GlobalKey<FormState>();
  String? sheetError;

  try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setError(String? value) {
              setSheetState(() => sheetError = value);
            }

            TimelineBlockDraft? candidateFromInputs() {
              final parsedStart = _parseClockMinute(startTimeCtrl.text);
              final title = titleCtrl.text.trim();
              final repeatDays = selectedDays.toList()..sort();
              final parsedProducts = productsCtrl.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final parsedSteps = stepsCtrl.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (title.isEmpty) {
                setError('Routine title is required.');
                return null;
              }
              if (parsedStart == null) {
                setError('Use a valid start time like 7:45 AM.');
                return null;
              }
              if (parsedStart + onboarding7SkinCareDurationMinutes > 24 * 60) {
                setError('Choose a time before midnight.');
                return null;
              }
              if (repeatDays.isEmpty) {
                setError('Select at least one repeat day.');
                return null;
              }
              if (parsedProducts.isEmpty && parsedSteps.isEmpty) {
                setError('Add at least one product or routine step.');
                return null;
              }
              return block.copyWith(
                title: title,
                startMinute: parsedStart,
                endMinute: parsedStart + onboarding7SkinCareDurationMinutes,
                repeatDays: repeatDays,
                skincareProducts: parsedProducts,
                skincareSteps: parsedSteps,
              );
            }

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
                            const Text(
                              'Edit skin-care block',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F111A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Duration stays fixed at 15 minutes.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textSecondary.withValues(
                                  alpha: 0.86,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (sheetError != null) ...[
                              Container(
                                key: const ValueKey(
                                  'onboarding-step7-edit-error',
                                ),
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
                                    key: ValueKey(
                                      'onboarding-step7-edit-day-$day',
                                    ),
                                    behavior: HitTestBehavior.opaque,
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
                                            ? accent
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? accent
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
                              key: const ValueKey(
                                'onboarding-step7-edit-title-field',
                              ),
                              controller: titleCtrl,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-start-time-field',
                              ),
                              controller: startTimeCtrl,
                              decoration: InputDecoration(
                                labelText: 'Start time',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-products-field',
                              ),
                              controller: productsCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Products (one per line)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-steps-field',
                              ),
                              controller: stepsCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Steps (one per line)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'onboarding-step7-find-free-time-button',
                                  ),
                                  onPressed: () {
                                    final candidate = candidateFromInputs();
                                    if (candidate == null) return;
                                    final base = ref
                                        .read(mockOnboardingProvider)
                                        .draft
                                        .baseTimeline;
                                    final freeStart =
                                        onboarding7FindFreeStartForSkinCareEdit(
                                          baseTimeline: base,
                                          block: candidate,
                                          preferredStartMinute:
                                              candidate.startMinute,
                                        );
                                    if (freeStart == null) {
                                      setError(
                                        'No free 15-minute skin-care slot was found.',
                                      );
                                      return;
                                    }
                                    setSheetState(() {
                                      sheetError = null;
                                      startTimeCtrl.text = onboardingTimeLabel(
                                        freeStart,
                                      );
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.manage_search_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Find free time'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: accent,
                                    side: BorderSide(
                                      color: accent.withValues(alpha: 0.55),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  key: const ValueKey(
                                    'onboarding-step7-edit-save-button',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final candidate = candidateFromInputs();
                                    if (candidate == null) return;
                                    final base = ref
                                        .read(mockOnboardingProvider)
                                        .draft
                                        .baseTimeline;
                                    final conflicts =
                                        onboarding7SkinCareCandidateConflicts(
                                          baseTimeline: base,
                                          candidate: candidate,
                                          excludingBlockId: block.id,
                                        );
                                    if (conflicts) {
                                      setError(
                                        'That time overlaps another onboarding block. Choose a free 15-minute slot.',
                                      );
                                      return;
                                    }

                                    updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) => base.copyWith(
                                        blocks: [
                                          for (final item in base.blocks)
                                            if (item.id == block.id)
                                              candidate
                                            else
                                              item,
                                        ],
                                      ),
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text(
                                    'Save',
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
  } finally {
    titleCtrl.dispose();
    startTimeCtrl.dispose();
    productsCtrl.dispose();
    stepsCtrl.dispose();
  }
}

int? _parseClockMinute(String value) {
  final text = value.trim().toLowerCase();
  final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(text);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0');
  final period = match.group(3);
  if (hour == null || minute == null || minute < 0 || minute > 59) {
    return null;
  }
  if (period != null) {
    if (hour < 1 || hour > 12) return null;
    if (period == 'am') {
      hour = hour == 12 ? 0 : hour;
    } else {
      hour = hour == 12 ? 12 : hour + 12;
    }
  } else if (hour > 23) {
    return null;
  }
  return hour * 60 + minute;
}

// ignore: unused_element
double _calculateRequiredSkinCareBlockHeight({
  required BuildContext context,
  required TimelineBlockDraft block,
  required String timeLabel,
  required double blockWidth,
}) {
  final steps = _skinCareInstructionLines(block);
  final products = block.skincareProducts
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final missingItems = block.skincareMissingItems
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final contentWidth = math.max(80.0, blockWidth - 34.0);
  var height = 20.0;
  height += _measureTextHeight(
    context: context,
    text: block.title,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
    width: contentWidth,
    maxLines: 2,
  );
  height += 5.0;
  height += _measureTextHeight(
    context: context,
    text: timeLabel,
    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
    width: contentWidth,
    maxLines: 1,
  );
  if (steps.isNotEmpty) {
    height += 7.0;
    for (var i = 0; i < steps.length; i += 1) {
      height += _measureTextHeight(
        context: context,
        text: '${i + 1}. ${steps[i]}',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        width: contentWidth,
        maxLines: 3,
      );
      if (i != steps.length - 1) height += 4.0;
    }
  }
  if (products.isNotEmpty) {
    height += 8.0;
    height += _measureTextHeight(
      context: context,
      text: products.join(', '),
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
      width: contentWidth,
      maxLines: 3,
    );
  }
  if (missingItems.isNotEmpty) {
    height += products.isNotEmpty ? 5.0 : 8.0;
    for (var i = 0; i < missingItems.length; i += 1) {
      height += _measureTextHeight(
        context: context,
        text: missingItems[i],
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        width: contentWidth - 18.0,
        maxLines: 2,
      );
      height += 10.0;
      if (i != missingItems.length - 1) height += 4.0;
    }
  }
  height += 40.0;
  return math.min(430.0, math.max(110.0, height));
}

double _measureTextHeight({
  required BuildContext context,
  required String text,
  required TextStyle style,
  required double width,
  int? maxLines,
}) {
  if (text.trim().isEmpty) return 0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
  )..layout(maxWidth: width);
  return painter.height;
}

List<String> _skinCareInstructionLines(TimelineBlockDraft block) {
  final source = block.skincareSteps.isNotEmpty
      ? block.skincareSteps
      : block.skincareProducts;
  return source
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

// ignore: unused_element
class _SkinCareBlockCard extends StatelessWidget {
  final TimelineBlockDraft item;
  final Color baseColor;
  final VoidCallback? onEditRequested;

  const _SkinCareBlockCard({
    required this.item,
    required this.baseColor,
    // ignore: unused_element_parameter
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final instructionLines = [
      if (item.skincareSteps.isNotEmpty)
        ...item.skincareSteps.map((i) => i.trim()).where((i) => i.isNotEmpty)
      else
        ...item.skincareProducts
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty),
    ];
    final productNames = item.skincareProducts
        .map((product) => product.trim())
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
    final missingItems = item.skincareMissingItems
        .map((product) => product.trim())
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
    final timeLabel = TimelineUtils.formatTimeRange(
      item.startMinute,
      item.endMinute,
    );

    return Container(
      key: ValueKey('onboarding-step7-block-${item.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.72),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.26),
            baseColor.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.96),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        color: baseColor,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F111A),
                          ),
                        ),
                      ),
                      if (onEditRequested != null) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            key: ValueKey('onboarding-step7-edit-${item.id}'),
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            onPressed: onEditRequested,
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: baseColor.withValues(alpha: 0.82),
                    ),
                  ),
                  if (instructionLines.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    for (var i = 0; i < instructionLines.length; i += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == instructionLines.length - 1 ? 0 : 4,
                        ),
                        child: Text(
                          '${i + 1}. ${instructionLines[i]}',
                          key: ValueKey('onboarding-step7-step-${item.id}-$i'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary.withValues(
                              alpha: 0.86,
                            ),
                            height: 1.24,
                          ),
                        ),
                      ),
                  ],
                  if (productNames.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      productNames.join(', '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (missingItems.isNotEmpty) ...[
                    SizedBox(height: productNames.isNotEmpty ? 5 : 7),
                    for (var i = 0; i < missingItems.length; i += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == missingItems.length - 1 ? 0 : 4,
                        ),
                        child: Container(
                          key: ValueKey(
                            'onboarding-step7-missing-item-${item.id}-$i',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: OptivusColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: OptivusColors.danger.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Text(
                            missingItems[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.danger.withValues(
                                alpha: 0.92,
                              ),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
