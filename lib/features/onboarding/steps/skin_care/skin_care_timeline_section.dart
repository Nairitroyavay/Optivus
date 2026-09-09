part of '../onboarding_step_7_skin_care_setup.dart';

class _SkinCareTimelineSection extends ConsumerStatefulWidget {
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
  ConsumerState<_SkinCareTimelineSection> createState() =>
      _SkinCareTimelineSectionState();
}

class _SkinCareTimelineSectionState
    extends ConsumerState<_SkinCareTimelineSection> {
  bool _isOpeningSheet = false;

  Future<void> _openEditSheet(TimelineBlockDraft block) async {
    if (_isOpeningSheet) return;
    _isOpeningSheet = true;
    try {
      await SkinTimelineAdapter.showSkinEditSheet(
        context: context,
        block: block,
        accent: widget.accent,
        findFreeStart: (candidate) {
          final base = ref.read(onboardingStateProvider).draft.baseTimeline;
          return onboarding7FindFreeStartForSkinCareEdit(
            baseTimeline: base,
            block: candidate,
            preferredStartMinute: candidate.startMinute,
          );
        },
        hasConflict: (candidate) {
          final base = ref.read(onboardingStateProvider).draft.baseTimeline;
          return onboarding7SkinCareCandidateConflicts(
            baseTimeline: base,
            candidate: candidate,
            excludingBlockId: block.id,
          );
        },
        validateBlock: (candidate) {
          final base = ref.read(onboardingStateProvider).draft.baseTimeline;
          return onboarding7ValidateEditedSkinCareBlock(base, candidate);
        },
        onSave: (candidate) async {
          final base = ref.read(onboardingStateProvider).draft.baseTimeline;
          final validationError = onboarding7ValidateEditedSkinCareBlock(
            base,
            candidate,
          );
          if (validationError != null) {
            throw Exception(validationError);
          }
          updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (b) => b.copyWith(
              blocks: [
                for (final item in b.blocks)
                  if (item.id == block.id) candidate else item,
              ],
            ),
          );
          return true;
        },
      );
    } finally {
      if (mounted) {
        _isOpeningSheet = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adapter = SkinTimelineAdapter(accent: widget.accent);
    final initialEntries = [
      for (final block in widget.blocks) ...adapter.toEntries(block),
    ];
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final footerInset =
              OnboardingFooterMetrics.resolve(context).requiredContentInset +
              16.0;
          final geometryConfig = const TimelineGeometryConfig().copyWith(
            bottomPadding: footerInset,
          );
          final provisionalLayout = TimelineOverlapEngine.computeLayout(
            entries: initialEntries,
            availableWidth: constraints.maxWidth,
            selectedDay: widget.selectedDay,
            config: geometryConfig,
          );
          final widthsBySourceId = {
            for (final positioned in provisionalLayout.entries)
              positioned.entry.sourceId: positioned.width,
          };
          final blocksById = {
            for (final block in widget.blocks) block.id: block,
          };
          final measuredEntries = [
            for (final entry in initialEntries)
              entry.copyWith(
                minHeight: _calculateRequiredSkinCareBlockHeight(
                  context: context,
                  block: blocksById[entry.sourceId]!,
                  timeLabel: TimelineUtils.formatTimeRange(
                    entry.startMinute,
                    entry.endMinute,
                  ),
                  blockWidth:
                      widthsBySourceId[entry.sourceId] ??
                      math.max(120.0, constraints.maxWidth - 78.0),
                ),
              ),
          ];
          return FullScreenTimelineScaffold(
            key: const ValueKey('onboarding-step7-full-timeline'),
            entries: measuredEntries,
            selectedDay: widget.selectedDay,
            onDayChanged: widget.onDayChanged,
            emptyDayMessage: widget.emptyLabel,
            accent: widget.accent,
            geometryConfig: geometryConfig,
            styleBuilder: adapter.styleForEntry,
            blockBuilder: (context, positioned) {
              final block = widget.blocks
                  .where(
                    (candidate) => candidate.id == positioned.entry.sourceId,
                  )
                  .first;
              return _SkinCareBlockCard(
                item: block,
                baseColor: widget.accent,
                onEditRequested: () => _openEditSheet(block),
              );
            },
            headerBanner: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your Routine',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (widget.specialCareNotes.isNotEmpty)
                  IconButton(
                    key: const ValueKey(
                      'onboarding-step7-special-care-notes-button',
                    ),
                    onPressed: () => _showSkinCareSpecialCareNotesSheet(
                      context,
                      widget.specialCareNotes,
                      widget.accent,
                    ),
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: widget.accent,
                    ),
                  ),
              ],
            ),
            onEntryTapped: (entry) {
              final block = widget.blocks
                  .where((candidate) => candidate.id == entry.sourceId)
                  .firstOrNull;
              if (block == null) return;
              _openEditSheet(block);
            },
          );
        },
      ),
    );
  }
}

// ignore: unused_element
double _calculateRequiredSkinCareBlockHeight({
  required BuildContext context,
  required TimelineBlockDraft block,
  required String timeLabel,
  required double blockWidth,
}) {
  final showFullDetails = _skinCareBlockNeedsFullDetailsAffordance(block);
  final allSteps = _skinCareInstructionLines(block);
  final steps = showFullDetails
      ? allSteps.take(2).toList(growable: false)
      : allSteps;

  final allProducts = block.skincareProducts
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final products = showFullDetails
      ? allProducts.take(2).toList(growable: false)
      : allProducts;
  final productsText = showFullDetails && allProducts.length > 2
      ? '${products.join(', ')} +${allProducts.length - 2} more'
      : products.join(', ');

  final allMissingItems = block.skincareMissingItems
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final missingItems = showFullDetails
      ? allMissingItems.take(1).toList(growable: false)
      : allMissingItems;

  final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
  final contentWidth = math.max(60.0, blockWidth - 34.0);
  final titleWidth = math.max(60.0, contentWidth - 56.0);
  var height =
      30.0 +
      24.0 *
          scaleFactor; // container padding (20) + border (3.2) + scaled text buffer

  final measuredTitle = _measureTextHeight(
    context: context,
    text: block.title,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
    width: titleWidth,
  );
  height += math.max(28.0, measuredTitle);
  height += 4.0;
  height += _measureTextHeight(
    context: context,
    text: timeLabel,
    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
    width: contentWidth,
  );
  if (steps.isNotEmpty) {
    height += 7.0;
    for (var i = 0; i < steps.length; i += 1) {
      height += _measureTextHeight(
        context: context,
        text: '${i + 1}. ${steps[i]}',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          height: 1.24,
        ),
        width: contentWidth,
      );
      if (i != steps.length - 1) height += 4.0;
    }
  }
  if (productsText.isNotEmpty) {
    height += 7.0;
    height += _measureTextHeight(
      context: context,
      text: productsText,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      width: contentWidth,
    );
  }
  if (missingItems.isNotEmpty) {
    height += productsText.isNotEmpty ? 5.0 : 7.0;
    for (var i = 0; i < missingItems.length; i += 1) {
      height += _measureTextHeight(
        context: context,
        text: missingItems[i],
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        width: math.max(40.0, contentWidth - 18.0),
      );
      height += 12.0; // padding 10 + border 2
      if (i != missingItems.length - 1) height += 4.0;
    }
  }
  if (showFullDetails) {
    height += 6.0;
    height += 28.0;
  }
  return math.max(105.0, height.ceilToDouble());
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
    final showFullDetails = _skinCareBlockNeedsFullDetailsAffordance(item);
    final allInstructionLines = [
      if (item.skincareSteps.isNotEmpty)
        ...item.skincareSteps.map((i) => i.trim()).where((i) => i.isNotEmpty)
      else
        ...item.skincareProducts
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty),
    ];
    final instructionLines = showFullDetails
        ? allInstructionLines.take(2).toList(growable: false)
        : allInstructionLines;

    final allProductNames = item.skincareProducts
        .map((product) => product.trim())
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
    final productNames = showFullDetails
        ? allProductNames.take(2).toList(growable: false)
        : allProductNames;
    final productsText = showFullDetails && allProductNames.length > 2
        ? '${productNames.join(', ')} +${allProductNames.length - 2} more'
        : productNames.join(', ');

    final allMissingItems = item.skincareMissingItems
        .map((product) => product.trim())
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
    final missingItems = showFullDetails
        ? allMissingItems.take(1).toList(growable: false)
        : allMissingItems;

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
                if (productsText.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    productsText,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
                if (missingItems.isNotEmpty) ...[
                  SizedBox(height: productsText.isNotEmpty ? 5 : 7),
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
                            color: OptivusColors.danger.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          missingItems[i],
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.danger.withValues(alpha: 0.92),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
                if (showFullDetails) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    key: ValueKey('onboarding-step7-full-details-${item.id}'),
                    style: TextButton.styleFrom(
                      foregroundColor: baseColor,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showSkinCareBlockDetailsSheet(
                      context,
                      item,
                      baseColor,
                    ),
                    child: const Text(
                      'View full details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _skinCareBlockNeedsFullDetailsAffordance(TimelineBlockDraft item) {
  final productsLength = item.skincareProducts.join(' ').trim().length;
  final stepsLength = item.skincareSteps.join(' ').trim().length;
  final missingLength = item.skincareMissingItems.join(' ').trim().length;
  return item.title.trim().length > 70 ||
      productsLength > 180 ||
      stepsLength > 260 ||
      missingLength > 120 ||
      item.skincareSteps.length > 5 ||
      item.skincareProducts.length > 5;
}

void _showSkinCareBlockDetailsSheet(
  BuildContext context,
  TimelineBlockDraft item,
  Color accent,
) {
  final timeLabel = TimelineUtils.formatTimeRange(
    item.startMinute,
    item.endMinute,
  );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              if (item.skincareSteps.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SkinCareDetailsHeading('Steps'),
                for (var i = 0; i < item.skincareSteps.length; i += 1)
                  _SkinCareDetailsLine('${i + 1}. ${item.skincareSteps[i]}'),
              ],
              if (item.skincareProducts.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SkinCareDetailsHeading('Products'),
                for (final product in item.skincareProducts)
                  _SkinCareDetailsLine(product),
              ],
              if (item.skincareMissingItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SkinCareDetailsHeading('Missing Items'),
                for (final product in item.skincareMissingItems)
                  _SkinCareDetailsLine(product),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _SkinCareDetailsHeading extends StatelessWidget {
  final String text;

  const _SkinCareDetailsHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: OptivusColors.textPrimary,
      ),
    );
  }
}

class _SkinCareDetailsLine extends StatelessWidget {
  final String text;

  const _SkinCareDetailsLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: OptivusColors.textSecondary,
        ),
      ),
    );
  }
}
