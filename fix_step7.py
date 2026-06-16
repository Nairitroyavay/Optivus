import re

with open("lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart", "r") as f:
    content = f.read()

# Replace _SkinCareVerticalTimeline instantiation
content = content.replace(
"""                : _SkinCareVerticalTimeline(
                    blocks: dayBlocks,
                    accent: accent,
                    onEditRequested: (block) => _showSkinCareBlockEditSheet(
                      context,
                      ref,
                      block,
                      accent,
                    ),
                  ),""",
"""                : OnboardingVerticalTimeline(
                    blocks: dayBlocks,
                    accent: accent,
                    requiredHeightBuilder: (context, block, blockWidth) =>
                        _calculateRequiredSkinCareBlockHeight(
                      context: context,
                      block: block,
                      timeLabel: TimelineUtils.formatTimeRange(
                        block.startMinute,
                        block.endMinute,
                      ),
                      blockWidth: blockWidth,
                    ),
                    blockBuilder: (ctx, block) {
                      return _SkinCareBlockCard(
                        item: block,
                        baseColor: accent,
                        onEditRequested: () => _showSkinCareBlockEditSheet(
                          context,
                          ref,
                          block,
                          accent,
                        ),
                      );
                    },
                  ),"""
)

# Replace all old classes with the new ones
start_marker = "class _TimelineRange {"
end_marker = "class _SkinCareChipGroup extends StatelessWidget {"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + """double _calculateRequiredSkinCareBlockHeight({
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

class _SkinCareBlockCard extends StatelessWidget {
  final TimelineBlockDraft item;
  final Color baseColor;
  final VoidCallback? onEditRequested;

  const _SkinCareBlockCard({
    required this.item,
    required this.baseColor,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final instructionLines = [
       if (item.skincareSteps.isNotEmpty)
         ...item.skincareSteps.map((i) => i.trim()).where((i) => i.isNotEmpty)
       else
         ...item.skincareProducts.map((i) => i.trim()).where((i) => i.isNotEmpty)
    ];
    final productNames = item.skincareProducts
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
                            color: OptivusColors.textPrimary.withValues(alpha: 0.86),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

""" + content[end_idx:]

with open("lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart", "w") as f:
    f.write(new_content)

print("done")
