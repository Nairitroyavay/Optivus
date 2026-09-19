import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_presentation_utils.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Responsive card renderer for Eating schedule items on the Base Timeline.
///
/// Supports:
/// - Front card: full rich display (title, slot/category badges, time range,
///   all dishes rendered without truncation, calories/protein macros, location, notes).
/// - Overlap/back card: compact promotion banner allowing tap-to-front.
/// - Adaptive content-based minimum height calculation measuring actual text wrapping.
class EatingTimelineCard extends StatelessWidget {
  final PositionedTimelineEntry positioned;
  final TimelineBlockDraft? block;
  final bool isEditable;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const EatingTimelineCard({
    super.key,
    required this.positioned,
    required this.block,
    required this.isEditable,
    this.accent = OptivusColors.roseAccent,
    this.onTap,
    this.onDelete,
  });

  static double minimumHeight(
    TimelineBlockDraft block, {
    double contentWidth = 220.0,
    double textScale = 1.0,
    bool isEditable = true,
  }) {
    final title = block.title.trim().isNotEmpty
        ? block.title.trim()
        : EatingPresentationUtils.formatSlotName(
            block.mealSlot,
            block.mealCategory,
          );
    final slotLabel = () {
      final s = block.mealSlot?.trim();
      final c = block.mealCategory?.trim();
      if (s != null &&
          s.isNotEmpty &&
          c != null &&
          c.isNotEmpty &&
          s.toLowerCase() != c.toLowerCase()) {
        final formattedS = EatingPresentationUtils.formatSlotName(s);
        final formattedC = EatingPresentationUtils.formatSlotName(c);
        return '$formattedS · $formattedC';
      }
      return EatingPresentationUtils.formatSlotName(s, c);
    }();
    final location = block.location?.trim() ?? '';
    final notes = block.notes?.trim() ?? '';
    final dishes = block.dishes.where((d) => d.trim().isNotEmpty).toList();
    final hasMacros = block.calories != null || block.protein != null;

    final isNarrow = contentWidth < 120.0;
    final horizontalPadding = isNarrow ? 16.0 : 24.0;
    final innerWidth = (contentWidth - horizontalPadding).clamp(
      30.0,
      double.infinity,
    );

    double totalHeight = 14.0; // vertical padding

    // 1. Header row: icon (20px) + spacing (6px) + edit allowance
    final editAllowance = isEditable ? 18.0 : 0.0;
    final titleWidth = (innerWidth - 26.0 - editAllowance).clamp(
      30.0,
      double.infinity,
    );
    final titleHeight = _measureTextHeight(
      text: title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      maxWidth: titleWidth,
      textScale: textScale,
    );
    totalHeight += math.max(20.0, titleHeight);

    // 2. Slot badge & time
    totalHeight += 4.0;
    final badgeHeight = _measureTextHeight(
      text: slotLabel,
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      maxWidth: innerWidth,
      textScale: textScale,
    );
    totalHeight += badgeHeight + 4.0;

    // 3. Dishes
    if (dishes.isNotEmpty) {
      totalHeight += 4.0;
      for (final dish in dishes) {
        final dishHeight = _measureTextHeight(
          text: '• $dish',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
          maxWidth: innerWidth,
          textScale: textScale,
        );
        totalHeight += math.max(20.0, dishHeight + 6.0);
      }
    }

    // 4. Macros
    if (hasMacros) {
      totalHeight += 6.0;
      final macroParts = <String>[];
      if (block.calories != null) {
        macroParts.add('${block.calories!.round()} kcal');
      }
      if (block.protein != null) {
        macroParts.add('${block.protein!.round()} g protein');
      }
      final macroHeight = _measureTextHeight(
        text: macroParts.join(' · '),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        maxWidth: innerWidth,
        textScale: textScale,
      );
      totalHeight += macroHeight + 6.0;
    }

    // 5. Location (matches maxLines: 2 in card preview)
    if (location.isNotEmpty) {
      totalHeight += 3.0;
      final locHeight = _measureTextHeight(
        text: location,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        maxWidth: (innerWidth - 14.0).clamp(30.0, double.infinity),
        textScale: textScale,
        maxLines: 2,
      );
      totalHeight += math.max(12.0, locHeight);
    }

    // 6. Notes (matches maxLines: 3 in card preview)
    if (notes.isNotEmpty) {
      totalHeight += 3.0;
      final notesHeight = _measureTextHeight(
        text: notes,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.25,
          fontStyle: FontStyle.italic,
        ),
        maxWidth: (innerWidth - 14.0).clamp(30.0, double.infinity),
        textScale: textScale,
        maxLines: 3,
      );
      totalHeight += math.max(12.0, notesHeight);
    }

    // Bottom safety buffer
    totalHeight += (12.0 * textScale).clamp(12.0, 28.0);

    return totalHeight < 96.0 ? 96.0 : totalHeight.ceilToDouble();
  }

  static double _measureTextHeight({
    required String text,
    required TextStyle style,
    required double maxWidth,
    double textScale = 1.0,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final h = painter.size.height;
    painter.dispose();
    return h;
  }

  @override
  Widget build(BuildContext context) {
    if (positioned.hasOverlap && !positioned.isFront) {
      return _buildExposedBackCard(context);
    }

    final entry = positioned.entry;
    final b = block;
    final title = b?.title.trim().isNotEmpty == true
        ? b!.title.trim()
        : (entry.title.isNotEmpty ? entry.title : 'Meal');
    final slot = () {
      final s = b?.mealSlot?.trim();
      final c = b?.mealCategory?.trim();
      if (s != null &&
          s.isNotEmpty &&
          c != null &&
          c.isNotEmpty &&
          s.toLowerCase() != c.toLowerCase()) {
        final formattedS = EatingPresentationUtils.formatSlotName(s);
        final formattedC = EatingPresentationUtils.formatSlotName(c);
        return '$formattedS · $formattedC';
      }
      return EatingPresentationUtils.formatSlotName(s, c);
    }();
    final dishes =
        b?.dishes.where((d) => d.trim().isNotEmpty).toList() ??
        (entry.subtitle != null && entry.subtitle!.isNotEmpty
            ? [entry.subtitle!]
            : const <String>[]);
    final calories = b?.calories;
    final protein = b?.protein;
    final location = b?.location?.trim() ?? '';
    final notes = b?.notes?.trim() ?? '';
    final timeLabel = TimelineUtils.formatTimeRange(
      entry.startMinute,
      entry.endMinute,
    );

    final isNarrow = positioned.width < 140;

    final height = positioned.height;
    final isCompact = height < 90;
    final verticalPad = isCompact ? 4.0 : 8.0;

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.14),
                accent.withValues(alpha: 0.03),
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
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 8 : 12,
            vertical: verticalPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    _iconForMeal(title, b?.mealSlot),
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isEditable)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: accent.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Slot badge and time
              Row(
                children: [
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    flex: 2,
                    child: Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Dishes
              if (dishes.isNotEmpty) ...[
                const SizedBox(height: 5),
                ...dishes.map(
                  (dish) => Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            dish,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: OptivusColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Macros
              if (calories != null || protein != null) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (calories != null && protein != null)
                      _buildMacroPill(
                        '${calories.round()} kcal · ${protein.round()} g protein',
                        accent,
                      )
                    else if (calories != null)
                      _buildMacroPill('${calories.round()} kcal', accent)
                    else if (protein != null)
                      _buildMacroPill(
                        '${protein.round()} g protein',
                        OptivusColors.blueAccent,
                      ),
                  ],
                ),
              ],

              // Location
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 11,
                      color: OptivusColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: OptivusColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Notes
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 11,
                      color: OptivusColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                          color: OptivusColors.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return card;
  }

  Widget _buildMacroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildExposedBackCard(BuildContext context) {
    final entry = positioned.entry;
    final b = block;
    final title = b?.title.trim().isNotEmpty == true
        ? b!.title.trim()
        : (entry.title.isNotEmpty ? entry.title : 'Meal');
    final timeShort = TimelineUtils.formatMinuteShort(entry.startMinute);

    final isNarrow = positioned.width < 140;

    return Semantics(
      button: true,
      label: 'Show $title in front',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.88),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.14),
                  accent.withValues(alpha: 0.04),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 6 : 10,
              vertical: isNarrow ? 4 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  _iconForMeal(title, b?.mealSlot),
                  size: isNarrow ? 12 : 14,
                  color: accent,
                ),
                SizedBox(width: isNarrow ? 3 : 5),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isNarrow ? 10.5 : 11.5,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  timeShort,
                  style: TextStyle(
                    fontSize: isNarrow ? 9.5 : 10,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                SizedBox(width: isNarrow ? 2 : 4),
                Icon(
                  Icons.flip_to_front_rounded,
                  size: isNarrow ? 10 : 12,
                  color: accent.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconForMeal(String title, String? slot) {
    final lower = '$title ${slot ?? ''}'.toLowerCase();
    if (lower.contains('breakfast')) return Icons.wb_sunny_rounded;
    if (lower.contains('lunch')) return Icons.lunch_dining_rounded;
    if (lower.contains('dinner')) return Icons.dinner_dining_rounded;
    if (lower.contains('snack')) return Icons.cookie_rounded;
    return Icons.restaurant_rounded;
  }
}
