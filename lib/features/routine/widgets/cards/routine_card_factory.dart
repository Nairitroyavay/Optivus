import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/widgets/cards/hard_block_card.dart';
import 'package:optivus/features/routine/widgets/cards/soft_block_card.dart';
import 'package:optivus/features/routine/widgets/cards/flexible_task_card.dart';
import 'package:optivus/features/routine/widgets/cards/tracker_task_card.dart';
import 'package:optivus/features/routine/widgets/cards/check_in_card.dart';
import 'package:optivus/features/routine/widgets/cards/money_task_card.dart';

/// Factory that builds the correct card widget based on RoutineBlockType.
class RoutineCardFactory {
  RoutineCardFactory._();

  /// Build the card widget, passing isNow for current-time highlighting.
  static Widget buildCard({
    required RoutineItem item,
    bool isNow = false,
    VoidCallback? onTap,
  }) {
    return switch (item.blockType) {
      RoutineBlockType.hardBlock =>
        HardBlockCard(item: item, isNow: isNow, onTap: onTap),
      RoutineBlockType.softBlock =>
        SoftBlockCard(item: item, isNow: isNow, onTap: onTap),
      RoutineBlockType.flexibleTask =>
        FlexibleTaskCard(item: item, isNow: isNow, onTap: onTap),
      RoutineBlockType.trackerTask =>
        TrackerTaskCard(item: item, isNow: isNow, onTap: onTap),
      RoutineBlockType.checkIn =>
        CheckInCard(item: item, isNow: isNow, onTap: onTap),
      RoutineBlockType.moneyTask =>
        MoneyTaskCard(item: item, isNow: isNow, onTap: onTap),
    };
  }

  /// Backward-compat entry point (old API).
  static Widget build(RoutineItem item, {VoidCallback? onTap}) {
    return buildCard(item: item, onTap: onTap);
  }

  /// Color for each block type — uses OptivusColors tokens, no raw hex.
  static Color colorForType(RoutineBlockType type) {
    return switch (type) {
      RoutineBlockType.hardBlock => OptivusColors.blockHard,
      RoutineBlockType.softBlock => OptivusColors.blockSoft,
      RoutineBlockType.flexibleTask => OptivusColors.blockFlex,
      RoutineBlockType.trackerTask => OptivusColors.blockTracker,
      RoutineBlockType.checkIn => OptivusColors.blockCheckIn,
      RoutineBlockType.moneyTask => OptivusColors.blockMoney,
    };
  }
}
