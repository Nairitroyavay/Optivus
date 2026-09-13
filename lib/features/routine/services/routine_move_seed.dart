import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_action_context.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

@immutable
class RoutineMoveSeed {
  final int startMinute;
  final int durationMinutes;

  const RoutineMoveSeed({
    required this.startMinute,
    required this.durationMinutes,
  });
}

class RoutineMoveSeedResolver {
  const RoutineMoveSeedResolver._();

  static RoutineMoveSeed resolve({
    required RoutineActionContext actionContext,
    required RoutineItem visibleItem,
    required List<RoutineItem> templates,
    required List<RoutineOccurrenceRecord> occurrences,
  }) {
    final occurrence = occurrences
        .where(
          (candidate) =>
              candidate.routineItemId == actionContext.templateId &&
              candidate.occurrenceDateKey == actionContext.occurrenceDateKey,
        )
        .firstOrNull;
    final template = templates
        .where((candidate) => candidate.id == actionContext.templateId)
        .firstOrNull;
    final start =
        occurrence?.movedStartMinute ??
        template?.startMinute ??
        visibleItem.startMinute;
    final end =
        occurrence?.movedEndMinute ??
        template?.endMinute ??
        visibleItem.endMinute;
    final duration = end > start ? end - start : 1440 - start + end;
    return RoutineMoveSeed(
      startMinute: start,
      durationMinutes: duration.clamp(1, 1440),
    );
  }
}
