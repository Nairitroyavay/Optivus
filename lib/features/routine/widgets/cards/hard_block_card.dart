import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/widgets/cards/routine_rich_timeline_card.dart';
import 'package:optivus/models/routine_item.dart';

/// Card for hard blocks: Class, Job, Work, Sleep, Travel, Exam, Shift.
class HardBlockCard extends ConsumerWidget {
  final RoutineItem item;
  final bool isNow;
  final double? railHeight;
  final bool isFront;
  final bool hasOverlap;
  final VoidCallback? onTap;

  const HardBlockCard({
    super.key,
    required this.item,
    this.isNow = false,
    this.railHeight,
    this.isFront = true,
    this.hasOverlap = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoutineRichTimelineCard(
      item: item,
      isNow: isNow,
      railHeight: railHeight,
      isFront: isFront,
      hasOverlap: hasOverlap,
      onTap: onTap,
    );
  }
}
