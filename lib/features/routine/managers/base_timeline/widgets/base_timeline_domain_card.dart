import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/work_timeline_card.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

enum BaseTimelineCardDomain { work, eating, fixed, skinCare }

class BaseTimelineRefreshPendingBanner extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const BaseTimelineRefreshPendingBanner({
    super.key,
    this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OptivusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OptivusColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: OptivusColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? 'Saved, but Routine needs to refresh.',
              style: const TextStyle(
                color: OptivusColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Rich, domain-aware renderer used by Base Timeline sections.
///
/// Geometry remains owned by the shared timeline engine. This widget only owns
/// presentation, so domain data never has to be flattened into generic
/// `title + subtitle` fields.
class BaseTimelineDomainCard extends StatelessWidget {
  final PositionedTimelineEntry positioned;
  final TimelineBlockDraft block;
  final BaseTimelineCardDomain domain;
  final Color accent;
  final bool isEditable;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const BaseTimelineDomainCard({
    super.key,
    required this.positioned,
    required this.block,
    required this.domain,
    required this.accent,
    required this.isEditable,
    this.onTap,
    this.onDelete,
  });

  static double minimumHeight(
    TimelineBlockDraft block,
    BaseTimelineCardDomain domain,
  ) {
    return switch (domain) {
      BaseTimelineCardDomain.work => WorkTimelineCard.minimumHeight(block),
      BaseTimelineCardDomain.eating => () {
        final validDishes = block.dishes
            .where((e) => e.trim().isNotEmpty)
            .length;
        final hasLabels =
            (block.mealSlot?.trim().isNotEmpty == true) ||
            (block.mealCategory?.trim().isNotEmpty == true);
        final hasMacros = block.calories != null || block.protein != null;
        return 90.0 +
            (hasLabels ? 20.0 : 0.0) +
            (hasMacros ? 20.0 : 0.0) +
            (validDishes > 0 ? 18.0 + validDishes * 22.0 : 0.0);
      }(),
      BaseTimelineCardDomain.fixed => () {
        final isOvernight = block.crossesMidnight || block.endsNextDay;
        final hasLoc = block.location?.trim().isNotEmpty == true;
        final notes = block.notes?.trim() ?? '';
        final notesExtra = notes.isEmpty
            ? 0.0
            : (notes.length > 50 ? 50.0 : 32.0);
        return 88.0 +
            (isOvernight ? 22.0 : 0.0) +
            (hasLoc ? 20.0 : 0.0) +
            notesExtra;
      }(),
      BaseTimelineCardDomain.skinCare => () {
        final hasSlot = block.skincareSlotLabel?.trim().isNotEmpty == true;
        final stepsCount = block.skincareSteps.length;
        final prodCount = block.skincareProducts.length;
        final missCount = block.skincareMissingItems.length;
        return 88.0 +
            (hasSlot ? 22.0 : 0.0) +
            (stepsCount > 0 ? 18.0 + stepsCount * 22.0 : 0.0) +
            (prodCount > 0 ? 18.0 + prodCount * 22.0 : 0.0) +
            (missCount > 0 ? 18.0 + missCount * 22.0 : 0.0);
      }(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (positioned.hasOverlap && !positioned.isFront) {
      return _shell(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 14, color: accent),
              const SizedBox(height: 3),
              Text(
                block.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              Text(
                TimelineUtils.formatMinuteShort(positioned.startMinute),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _shell(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 17, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    block.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                if (isEditable && onDelete != null)
                  IconButton(
                    key: ValueKey('base-timeline-delete-${block.id}'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    tooltip: 'Delete block',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: OptivusColors.danger,
                    ),
                  ),
                if (isEditable)
                  Icon(Icons.edit_rounded, size: 14, color: accent),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              TimelineUtils.formatTimeRange(
                positioned.startMinute,
                positioned.endMinute,
              ),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            ..._details(),
          ],
        ),
      ),
    );
  }

  Widget _shell({required Widget child}) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
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
            color: accent.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
    );
    return Semantics(
      button: onTap != null,
      label:
          '${block.title}, ${TimelineUtils.formatTimeRange(positioned.startMinute, positioned.endMinute)}${isEditable ? ', tap to edit' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      ),
    );
  }

  List<Widget> _details() {
    final details = <Widget>[];
    void line(String value, {IconData? icon, Color? color}) {
      if (value.trim().isEmpty) return;
      details.add(const SizedBox(height: 4));
      details.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color ?? OptivusColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: color ?? OptivusColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    void section(String label, List<String> values, {Color? color}) {
      final clean = values.map((e) => e.trim()).where((e) => e.isNotEmpty);
      if (clean.isEmpty) return;
      details.add(const SizedBox(height: 7));
      details.add(
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: .7,
            fontWeight: FontWeight.w900,
            color: color ?? accent,
          ),
        ),
      );
      for (final value in clean) {
        line(value, color: color);
      }
    }

    switch (domain) {
      case BaseTimelineCardDomain.work:
        line(block.location ?? '', icon: Icons.location_on_outlined);
        line(block.notes ?? '', icon: Icons.notes_rounded);
        if (block.sectionLabel?.trim().isNotEmpty == true) {
          line(block.sectionLabel!, icon: Icons.business_center_outlined);
        }
        break;
      case BaseTimelineCardDomain.eating:
        final labels = <String>[
          if (block.mealSlot?.trim().isNotEmpty == true) block.mealSlot!,
          if (block.mealCategory?.trim().isNotEmpty == true &&
              block.mealCategory != block.mealSlot)
            block.mealCategory!,
        ];
        if (labels.isNotEmpty) line(labels.join(' · '));
        final macros = <String>[
          if (block.calories != null) '${block.calories!.round()} kcal',
          if (block.protein != null) '${block.protein!.round()} g protein',
        ];
        if (macros.isNotEmpty) line(macros.join(' · '), color: accent);
        section('DISHES', block.dishes);
        break;
      case BaseTimelineCardDomain.fixed:
        if (block.crossesMidnight || block.endsNextDay) {
          line('Continues overnight', icon: Icons.nights_stay_outlined);
        }
        line(block.location ?? '', icon: Icons.location_on_outlined);
        line(block.notes ?? '', icon: Icons.notes_rounded);
        break;
      case BaseTimelineCardDomain.skinCare:
        if (block.skincareSlotLabel?.trim().isNotEmpty == true) {
          line(block.skincareSlotLabel!, icon: Icons.schedule_rounded);
        }
        section('STEPS', [
          for (var i = 0; i < block.skincareSteps.length; i++)
            '${i + 1}. ${block.skincareSteps[i]}',
        ]);
        section('PRODUCTS', block.skincareProducts);
        section(
          'MISSING',
          block.skincareMissingItems,
          color: OptivusColors.warning,
        );
        break;
    }
    return details;
  }

  IconData get _icon => switch (domain) {
    BaseTimelineCardDomain.work => Icons.work_rounded,
    BaseTimelineCardDomain.eating => Icons.restaurant_rounded,
    BaseTimelineCardDomain.fixed =>
      block.title.toLowerCase().contains('sleep')
          ? Icons.bedtime_rounded
          : block.title.toLowerCase().contains('bath')
          ? Icons.bathtub_rounded
          : Icons.event_rounded,
    BaseTimelineCardDomain.skinCare => Icons.spa_rounded,
  };
}
