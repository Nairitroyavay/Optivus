import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/tracker_session_link.dart';
import 'package:optivus/state/app_state.dart';

/// Selected day for the routine timeline.
final selectedDayProvider = StateProvider<DateTime>((ref) {
  return TimelineUtils.dateOnly(DateTime.now());
});

/// Monday of the currently selected week.
final selectedWeekStartProvider = StateProvider<DateTime>((ref) {
  return TimelineUtils.weekStart(DateTime.now());
});

/// Active primary filter.
final selectedPrimaryFilterProvider = StateProvider<String>((ref) => 'all');

/// Backward-compatible name used by older Routine widgets.
final routineFilterProvider = selectedPrimaryFilterProvider;

/// Active category filter.
final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'all');

/// Whether to show the full 24-hour timeline.
final showFullDayProvider = StateProvider<bool>((ref) => false);

/// Whether to show minute ticks on the ruler.
final showMinuteTicksProvider = StateProvider<bool>((ref) => true);

/// Whether to show the current-time indicator.
final showCurrentTimeLineProvider = StateProvider<bool>((ref) => true);

/// Whether to use compact card mode.
final compactModeProvider = StateProvider<bool>((ref) => false);

/// Whether move/edit controls snap to 1 minute instead of 5 minutes.
final precisionModeProvider = StateProvider<bool>((ref) => false);

final aiRoutineSuggestionsEnabledProvider = StateProvider<bool>((ref) => true);
final conflictResolverEnabledProvider = StateProvider<bool>((ref) => true);
final routineNotificationsEnabledProvider = StateProvider<bool>((ref) => false);

/// Primary filter options with labels and emojis.
class RoutineFilterOption {
  final String key;
  final String label;
  final String emoji;

  const RoutineFilterOption(this.key, this.label, this.emoji);
}

const List<RoutineFilterOption> primaryFilters = [
  RoutineFilterOption('all', 'All', 'All'),
  RoutineFilterOption('base_timeline', 'Base Timeline', 'Base'),
  RoutineFilterOption('flexible_tasks', 'Flexible Tasks', 'Flex'),
  RoutineFilterOption('tracker_tasks', 'Tracker Tasks', 'Track'),
  RoutineFilterOption('check_ins', 'Check-ins', 'Check'),
  RoutineFilterOption('conflicts', 'Conflicts', 'Warn'),
  RoutineFilterOption('completed', 'Completed', 'Done'),
  RoutineFilterOption('missed', 'Missed', 'Miss'),
];

const List<RoutineFilterOption> categoryFilters = [
  RoutineFilterOption('all', 'All Categories', 'All'),
  RoutineFilterOption('classes', 'Classes', 'Class'),
  RoutineFilterOption('job', 'Job / Work', 'Work'),
  RoutineFilterOption('eating', 'Eating', 'Food'),
  RoutineFilterOption('fixed', 'Fixed', 'Fixed'),
  RoutineFilterOption('skin_care', 'Skin Care', 'Skin'),
  RoutineFilterOption('good_habits', 'Good Habits', 'Good'),
  RoutineFilterOption('bad_habits', 'Bad Habits', 'Bad'),
  RoutineFilterOption('money', 'Money System', 'Money'),
  RoutineFilterOption('meditation', 'Meditation', 'Mind'),
  RoutineFilterOption('hydration', 'Hydration', 'Water'),
  RoutineFilterOption('screen_time', 'Screen Time', 'Screen'),
];

class TrackerLaunchIntent {
  final TrackerType trackerType;
  final String routineTaskId;
  final String sessionId;
  final DateTime startedAt;

  const TrackerLaunchIntent({
    required this.trackerType,
    required this.routineTaskId,
    required this.sessionId,
    required this.startedAt,
  });
}

final trackerLaunchIntentProvider = StateProvider<TrackerLaunchIntent?>(
  (ref) => null,
);

class RoutineTrackerLinksNotifier
    extends StateNotifier<List<TrackerSessionLink>> {
  RoutineTrackerLinksNotifier() : super(const []);

  void upsert(TrackerSessionLink link) {
    state = [
      for (final existing in state)
        if (existing.routineTaskId == link.routineTaskId) link else existing,
      if (!state.any(
        (existing) => existing.routineTaskId == link.routineTaskId,
      ))
        link,
    ];
  }

  void clearForRoutine(String routineTaskId) {
    state = state
        .where((link) => link.routineTaskId != routineTaskId)
        .toList(growable: false);
  }

  void reset() => state = const [];
}

final trackerSessionLinksProvider =
    StateNotifierProvider<
      RoutineTrackerLinksNotifier,
      List<TrackerSessionLink>
    >((ref) {
      return RoutineTrackerLinksNotifier();
    });

enum RoutineConflictType {
  timeOverlap,
  noFreeSlot,
  taskTooLong,
  hardBlockConflict,
  duplicateTask,
  tooManyTasks,
  sleepConflict,
  trackerTaskNotCompleted,
}

class RoutineConflict {
  final String id;
  final RoutineConflictType type;
  final String itemId;
  final String? otherItemId;
  final String title;
  final String message;
  final int startMinute;
  final int endMinute;
  final bool blocking;
  final bool canKeepBoth;

  const RoutineConflict({
    required this.id,
    required this.type,
    required this.itemId,
    this.otherItemId,
    required this.title,
    required this.message,
    required this.startMinute,
    required this.endMinute,
    required this.blocking,
    required this.canKeepBoth,
  });
}

class RoutineCompletionSummary {
  final int total;
  final int completed;
  final int skipped;
  final int missed;

  const RoutineCompletionSummary({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.missed,
  });

  double get ratio => total == 0 ? 0 : completed / total;
}

class RoutineConflictSummary {
  final int total;
  final int blocking;

  const RoutineConflictSummary({required this.total, required this.blocking});
}

final routineControllerProvider = Provider<RoutineController>((ref) {
  return RoutineController(ref);
});

final routineItemsProvider = Provider<List<RoutineItem>>((ref) {
  return ref.watch(mockRoutineProvider);
});

final selectedDayRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final day = ref.watch(selectedDayProvider);
  final items = ref.watch(routineItemsProvider);
  final materialized = RoutineMaterializer.itemsForDay(items, day);
  final conflicts = RoutineConflictEngine.detect(materialized, day: day);
  final conflictItemIds = conflicts
      .expand((conflict) => [conflict.itemId, conflict.otherItemId])
      .whereType<String>()
      .toSet();

  return materialized
      .map(
        (item) => item.copyWith(
          hasConflict: conflictItemIds.contains(item.id),
          conflictMessage: _firstConflictMessage(item.id, conflicts),
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
});

final routineConflictsProvider = Provider<List<RoutineConflict>>((ref) {
  final day = ref.watch(selectedDayProvider);
  final items = ref.watch(routineItemsProvider);
  return RoutineConflictEngine.detect(
    RoutineMaterializer.itemsForDay(items, day),
    day: day,
  );
});

final filteredRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final items = ref.watch(selectedDayRoutineItemsProvider);
  final primaryFilter = ref.watch(selectedPrimaryFilterProvider);
  final categoryFilter = ref.watch(selectedCategoryFilterProvider);
  final primary = TimelineUtils.filterItems(items, primaryFilter);
  return RoutineFilters.applyCategory(primary, categoryFilter);
});

final todayRoutineItemsProvider = Provider<List<RoutineItem>>((ref) {
  final items = ref.watch(routineItemsProvider);
  return RoutineMaterializer.itemsForDay(
    items,
    TimelineUtils.dateOnly(DateTime.now()),
  );
});

final currentRoutineItemProvider = Provider<RoutineItem?>((ref) {
  final now = DateTime.now();
  final minute = now.hour * 60 + now.minute;
  final todayItems = ref.watch(todayRoutineItemsProvider);
  for (final item in todayItems) {
    if (TimelineUtils.isMinuteInsideItem(item, minute) &&
        item.status != RoutineStatus.completed &&
        item.status != RoutineStatus.skipped) {
      return item;
    }
  }
  return null;
});

final nextRoutineItemProvider = Provider<RoutineItem?>((ref) {
  final now = DateTime.now();
  final minute = now.hour * 60 + now.minute;
  final candidates =
      ref
          .watch(todayRoutineItemsProvider)
          .where(
            (item) =>
                item.startMinute >= minute &&
                item.status != RoutineStatus.completed &&
                item.status != RoutineStatus.skipped,
          )
          .toList()
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return candidates.isEmpty ? null : candidates.first;
});

final routineCompletionSummaryProvider = Provider<RoutineCompletionSummary>((
  ref,
) {
  final items = ref.watch(todayRoutineItemsProvider);
  final actionable = items
      .where((item) {
        return item.blockType != RoutineBlockType.hardBlock;
      })
      .toList(growable: false);
  return RoutineCompletionSummary(
    total: actionable.length,
    completed: actionable
        .where(
          (item) => item.isCompleted || item.status == RoutineStatus.completed,
        )
        .length,
    skipped: actionable
        .where((item) => item.status == RoutineStatus.skipped)
        .length,
    missed: actionable
        .where((item) => item.isMissed || item.status == RoutineStatus.missed)
        .length,
  );
});

final routineConflictSummaryProvider = Provider<RoutineConflictSummary>((ref) {
  final conflicts = RoutineConflictEngine.detect(
    ref.watch(todayRoutineItemsProvider),
  );
  return RoutineConflictSummary(
    total: conflicts.length,
    blocking: conflicts.where((conflict) => conflict.blocking).length,
  );
});

String? _firstConflictMessage(String itemId, List<RoutineConflict> conflicts) {
  for (final conflict in conflicts) {
    if (conflict.itemId == itemId || conflict.otherItemId == itemId) {
      return conflict.message;
    }
  }
  return null;
}

class RoutineController {
  final Ref _ref;

  RoutineController(this._ref);

  List<RoutineItem> get _items => _ref.read(mockRoutineProvider);

  MockRoutineNotifier get _notifier => _ref.read(mockRoutineProvider.notifier);

  void addItem(RoutineItem item) => _notifier.addRoutineItem(item);

  void updateItem(RoutineItem item) => _notifier.updateRoutineItem(item);

  void deleteItem(String itemId) {
    _notifier.deleteRoutineItem(itemId);
    _ref.read(trackerSessionLinksProvider.notifier).clearForRoutine(itemId);
  }

  void startFlexibleTask(String itemId) {
    _updateById(
      itemId,
      (item) => item.copyWith(
        status: RoutineStatus.active,
        isCompleted: false,
        isMissed: false,
      ),
    );
  }

  void markCompleted(String itemId) {
    _updateById(
      itemId,
      (item) => item.copyWith(
        status: RoutineStatus.completed,
        isCompleted: true,
        isMissed: false,
      ),
    );
  }

  void markSkipped(String itemId) {
    _updateById(
      itemId,
      (item) => item.copyWith(
        status: RoutineStatus.skipped,
        isCompleted: false,
        isMissed: false,
      ),
    );
  }

  void markMissed(String itemId) {
    _updateById(
      itemId,
      (item) => item.copyWith(
        status: RoutineStatus.missed,
        isCompleted: false,
        isMissed: true,
      ),
    );
  }

  void markFlexible(String itemId) {
    _updateById(
      itemId,
      (item) => item.copyWith(
        blockType: RoutineBlockType.flexibleTask,
        hardBlock: false,
        allowOverlap: false,
      ),
    );
  }

  void checkIn(String itemId, String response) {
    final normalized = response.toLowerCase();
    final status = normalized == 'relapsed'
        ? RoutineStatus.missed
        : RoutineStatus.completed;
    _updateById(
      itemId,
      (item) => item.copyWith(
        status: status,
        isCompleted: status == RoutineStatus.completed,
        isMissed: status == RoutineStatus.missed,
        notes: _appendNote(item.notes, 'Check-in: $response'),
      ),
    );
  }

  void alreadySaved(String itemId, {double amount = 10}) {
    _ref
        .read(mockTrackerProvider.notifier)
        .logSaving(amount, 'Routine Money System task', isConfirmed: true);
    markCompleted(itemId);
  }

  void startTrackerTask(RoutineItem item) {
    final now = DateTime.now();
    final sessionId = 'tracker-${item.id}-${now.millisecondsSinceEpoch}';
    final trackerType = item.trackerType == TrackerType.none
        ? _inferTrackerType(item)
        : item.trackerType;
    final link = TrackerSessionLink(
      routineTaskId: item.id,
      trackerType: trackerType.name,
      sessionId: sessionId,
      startedAt: now,
      status: 'active',
    );

    _ref.read(trackerSessionLinksProvider.notifier).upsert(link);
    _ref.read(trackerLaunchIntentProvider.notifier).state = TrackerLaunchIntent(
      trackerType: trackerType,
      routineTaskId: item.id,
      sessionId: sessionId,
      startedAt: now,
    );
    _updateById(
      item.id,
      (current) => current.copyWith(
        status: RoutineStatus.inTracker,
        isTrackerLinked: true,
        trackerType: trackerType,
        isCompleted: false,
        isMissed: false,
      ),
    );
    _ref.read(appNavigationProvider.notifier).goToTracker();
  }

  void completeTrackerSession(String routineTaskId) {
    final links = _ref.read(trackerSessionLinksProvider);
    TrackerSessionLink? link;
    for (final candidate in links) {
      if (candidate.routineTaskId == routineTaskId) {
        link = candidate;
        break;
      }
    }
    final now = DateTime.now();
    if (link != null) {
      _ref
          .read(trackerSessionLinksProvider.notifier)
          .upsert(
            link.copyWith(
              completedAt: now,
              duration: link.startedAt == null
                  ? null
                  : now.difference(link.startedAt!),
              status: 'completed',
            ),
          );
    }
    markCompleted(routineTaskId);
    final intent = _ref.read(trackerLaunchIntentProvider);
    if (intent?.routineTaskId == routineTaskId) {
      _ref.read(trackerLaunchIntentProvider.notifier).state = null;
    }
  }

  void moveItem({
    required String itemId,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
  }) {
    final boundedStart = startMinute.clamp(0, 1439);
    final boundedDuration = durationMinutes.clamp(1, 1440);
    final endMinute = (boundedStart + boundedDuration).clamp(1, 1440);
    _updateById(
      itemId,
      (item) => item.copyWith(
        date: TimelineUtils.dateOnly(date),
        startMinute: boundedStart,
        endMinute: endMinute,
        crossesMidnight: false,
        endsNextDay: false,
        repeatDays: const [],
        status: RoutineStatus.moved,
        clearConflict: true,
      ),
    );
  }

  void moveToTomorrow(RoutineItem item) {
    moveItem(
      itemId: item.id,
      date: TimelineUtils.dateOnly(DateTime.now()).add(const Duration(days: 1)),
      startMinute: item.startMinute,
      durationMinutes: item.durationMinutes,
    );
  }

  void makeTinyVersion(RoutineItem item) {
    final tinyDuration = item.durationMinutes.clamp(5, 10);
    _updateById(
      item.id,
      (current) => current.copyWith(
        title: current.title.startsWith('[Tiny]')
            ? current.title
            : '[Tiny] ${current.title}',
        endMinute: (current.startMinute + tinyDuration).clamp(1, 1440),
        status: RoutineStatus.moved,
        clearConflict: true,
      ),
    );
  }

  int? findFreeSlot({
    required RoutineItem item,
    required DateTime date,
    int? durationMinutes,
  }) {
    final duration = durationMinutes ?? item.durationMinutes;
    final dayItems = RoutineMaterializer.itemsForDay(
      _items,
      date,
    ).where((candidate) => candidate.id != item.id).toList(growable: false);
    final snap = _ref.read(precisionModeProvider) ? 1 : 5;
    for (int start = 6 * 60; start + duration <= 23 * 60; start += snap) {
      final candidate = item.copyWith(
        startMinute: start,
        endMinute: start + duration,
        date: TimelineUtils.dateOnly(date),
        repeatDays: const [],
        clearConflict: true,
      );
      final conflicts = RoutineConflictEngine.detect([...dayItems, candidate]);
      final blocking = conflicts.any(
        (conflict) =>
            conflict.itemId == candidate.id ||
            conflict.otherItemId == candidate.id,
      );
      if (!blocking) return start;
    }
    return null;
  }

  List<RoutineConflict> previewMove({
    required RoutineItem item,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
  }) {
    final dayItems = RoutineMaterializer.itemsForDay(
      _items,
      date,
    ).where((candidate) => candidate.id != item.id).toList(growable: false);
    final candidate = item.copyWith(
      date: TimelineUtils.dateOnly(date),
      startMinute: startMinute,
      endMinute: startMinute + durationMinutes,
      repeatDays: const [],
      clearConflict: true,
    );
    return RoutineConflictEngine.detect([...dayItems, candidate], day: date)
        .where(
          (conflict) =>
              conflict.itemId == item.id || conflict.otherItemId == item.id,
        )
        .toList(growable: false);
  }

  void keepConflictPair(RoutineConflict conflict) {
    _updateById(
      conflict.itemId,
      (item) => item.copyWith(allowOverlap: true, clearConflict: true),
    );
    final other = conflict.otherItemId;
    if (other != null) {
      _updateById(
        other,
        (item) => item.copyWith(allowOverlap: true, clearConflict: true),
      );
    }
  }

  void _updateById(String itemId, RoutineItem Function(RoutineItem) update) {
    for (final item in _items) {
      if (item.id == itemId) {
        _notifier.updateRoutineItem(update(item));
        return;
      }
    }
  }

  TrackerType _inferTrackerType(RoutineItem item) {
    final lower = item.title.toLowerCase();
    if (lower.contains('meditat')) return TrackerType.meditation;
    if (lower.contains('workout') || lower.contains('gym')) {
      return TrackerType.workout;
    }
    if (lower.contains('focus')) return TrackerType.focus;
    if (lower.contains('hydrat') || lower.contains('water')) {
      return TrackerType.hydration;
    }
    if (lower.contains('smok')) return TrackerType.smoking;
    if (lower.contains('money') || lower.contains('save')) {
      return TrackerType.money;
    }
    return TrackerType.none;
  }

  String _appendNote(String? notes, String addition) {
    if (notes == null || notes.trim().isEmpty) return addition;
    return '$notes\n$addition';
  }
}

class RoutineMaterializer {
  RoutineMaterializer._();

  static List<RoutineItem> itemsForDay(List<RoutineItem> items, DateTime day) {
    final selected = TimelineUtils.dateOnly(day);
    final previous = selected.subtract(const Duration(days: 1));
    final result = <RoutineItem>[];

    for (final item in items) {
      if (_startsOnDay(item, selected)) {
        result.add(item);
      }
      if (_isOvernight(item) && _startsOnDay(item, previous)) {
        result.add(
          item.copyWith(
            date: selected,
            startMinute: 0,
            endMinute: item.endMinute,
            crossesMidnight: false,
            endsNextDay: false,
          ),
        );
      }
    }

    return result;
  }

  static bool occursOnDay(RoutineItem item, DateTime day) {
    final selected = TimelineUtils.dateOnly(day);
    return _startsOnDay(item, selected) ||
        (_isOvernight(item) &&
            _startsOnDay(item, selected.subtract(const Duration(days: 1))));
  }

  static bool _startsOnDay(RoutineItem item, DateTime day) {
    final date = item.date;
    if (date != null && _isOneTimeDatedItem(item)) {
      return DateUtils.isSameDay(date, day);
    }
    if (date != null && DateUtils.isSameDay(date, day)) {
      return true;
    }
    if (item.repeatDays.contains(day.weekday)) {
      return true;
    }
    return _repeatRuleMatches(item.repeatRule, day);
  }

  static bool _isOneTimeDatedItem(RoutineItem item) {
    final rule = item.repeatRule?.trim().toLowerCase();
    return rule == null || rule.isEmpty || rule == 'once' || rule == 'none';
  }

  static bool _isOvernight(RoutineItem item) {
    return item.crossesMidnight ||
        item.endsNextDay ||
        item.endMinute <= item.startMinute;
  }

  static bool _repeatRuleMatches(String? repeatRule, DateTime day) {
    final rule = repeatRule?.trim().toLowerCase();
    if (rule == null || rule.isEmpty || rule == 'once' || rule == 'none') {
      return false;
    }
    if (rule == 'daily' || rule == 'everyday') {
      return true;
    }
    if (rule == 'weekly') return false;
    if (rule == 'weekdays') return day.weekday <= DateTime.friday;
    if (rule == 'weekends') return day.weekday >= DateTime.saturday;

    const names = {
      DateTime.monday: ['mon', 'monday'],
      DateTime.tuesday: ['tue', 'tuesday'],
      DateTime.wednesday: ['wed', 'wednesday'],
      DateTime.thursday: ['thu', 'thursday'],
      DateTime.friday: ['fri', 'friday'],
      DateTime.saturday: ['sat', 'saturday'],
      DateTime.sunday: ['sun', 'sunday'],
    };
    return names[day.weekday]!.any(rule.contains);
  }
}

class RoutineFilters {
  RoutineFilters._();

  static List<RoutineItem> applyCategory(
    List<RoutineItem> items,
    String filter,
  ) {
    if (filter == 'all') return items;
    return items.where((item) => _matchesCategory(item, filter)).toList();
  }

  static bool _matchesCategory(RoutineItem item, String filter) {
    final title = item.title.toLowerCase();
    return switch (filter) {
      'classes' => item.category == RoutineCategory.classBlock,
      'job' => item.category == RoutineCategory.job,
      'eating' => item.category == RoutineCategory.eating,
      'fixed' => item.category == RoutineCategory.fixed,
      'skin_care' => item.category == RoutineCategory.skinCare,
      'good_habits' =>
        item.category == RoutineCategory.habit ||
            item.category == RoutineCategory.identity,
      'bad_habits' =>
        item.category == RoutineCategory.badHabit ||
            title.contains('smok') ||
            title.contains('alcohol') ||
            title.contains('junk'),
      'money' =>
        item.category == RoutineCategory.finance ||
            item.blockType == RoutineBlockType.moneyTask,
      'meditation' =>
        item.category == RoutineCategory.meditation ||
            item.trackerType == TrackerType.meditation ||
            title.contains('meditat'),
      'hydration' =>
        item.category == RoutineCategory.hydration ||
            item.trackerType == TrackerType.hydration ||
            title.contains('water'),
      'screen_time' => item.category == RoutineCategory.screenTime,
      _ => true,
    };
  }
}

class RoutineConflictEngine {
  RoutineConflictEngine._();

  static List<RoutineConflict> detect(
    List<RoutineItem> items, {
    DateTime? day,
  }) {
    final conflicts = <RoutineConflict>[];
    final meaningful =
        items.where((item) => item.durationMinutes > 0).toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    for (int i = 0; i < meaningful.length; i++) {
      final a = meaningful[i];
      final aEnd = TimelineUtils.normalizedEndMinute(a);
      for (int j = i + 1; j < meaningful.length; j++) {
        final b = meaningful[j];
        final bEnd = TimelineUtils.normalizedEndMinute(b);
        if (!_overlaps(a.startMinute, aEnd, b.startMinute, bEnd)) continue;

        final involvesHard = a.isHardBlock || b.isHardBlock;
        final isSleep = _isSleep(a) || _isSleep(b);
        final canKeep = a.allowOverlap || b.allowOverlap;
        final flexibleVsHard =
            involvesHard &&
            (a.blockType == RoutineBlockType.flexibleTask ||
                b.blockType == RoutineBlockType.flexibleTask ||
                a.blockType == RoutineBlockType.trackerTask ||
                b.blockType == RoutineBlockType.trackerTask);

        conflicts.add(
          RoutineConflict(
            id: 'overlap-${a.id}-${b.id}',
            type: isSleep
                ? RoutineConflictType.sleepConflict
                : involvesHard
                ? RoutineConflictType.hardBlockConflict
                : RoutineConflictType.timeOverlap,
            itemId: a.id,
            otherItemId: b.id,
            title: '${a.title} overlaps ${b.title}',
            message:
                '${a.title} overlaps with ${b.title}\n${TimelineUtils.formatTimeRange(_maxInt(a.startMinute, b.startMinute), _minInt(aEnd, bEnd))}',
            startMinute: _maxInt(a.startMinute, b.startMinute),
            endMinute: _minInt(aEnd, bEnd),
            blocking: flexibleVsHard || (!canKeep && involvesHard),
            canKeepBoth: canKeep || !flexibleVsHard,
          ),
        );
      }
    }

    conflicts.addAll(_duplicateConflicts(meaningful));
    if (meaningful.length > 14) {
      conflicts.add(
        RoutineConflict(
          id: 'too-many-${day?.toIso8601String() ?? 'today'}',
          type: RoutineConflictType.tooManyTasks,
          itemId: meaningful.first.id,
          title: 'Too many tasks in one day',
          message: '${meaningful.length} scheduled items may be too dense.',
          startMinute: meaningful.first.startMinute,
          endMinute: meaningful.last.endMinute,
          blocking: false,
          canKeepBoth: true,
        ),
      );
    }

    final now = DateTime.now();
    if (day == null || DateUtils.isSameDay(day, now)) {
      final currentMinute = now.hour * 60 + now.minute;
      for (final item in meaningful) {
        final overdueTracker =
            item.blockType == RoutineBlockType.trackerTask &&
            item.endMinute < currentMinute &&
            item.status != RoutineStatus.completed &&
            item.status != RoutineStatus.inTracker &&
            !item.isCompleted;
        if (overdueTracker) {
          conflicts.add(
            RoutineConflict(
              id: 'tracker-incomplete-${item.id}',
              type: RoutineConflictType.trackerTaskNotCompleted,
              itemId: item.id,
              title: '${item.title} not completed',
              message:
                  '${item.title} was scheduled but not completed in Tracker.',
              startMinute: item.startMinute,
              endMinute: item.endMinute,
              blocking: false,
              canKeepBoth: true,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  static List<RoutineConflict> _duplicateConflicts(List<RoutineItem> items) {
    final conflicts = <RoutineConflict>[];
    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];
        if (a.title.trim().toLowerCase() != b.title.trim().toLowerCase()) {
          continue;
        }
        if ((a.startMinute - b.startMinute).abs() > 30) continue;
        conflicts.add(
          RoutineConflict(
            id: 'duplicate-${a.id}-${b.id}',
            type: RoutineConflictType.duplicateTask,
            itemId: a.id,
            otherItemId: b.id,
            title: 'Duplicate task',
            message: '${a.title} appears more than once close together.',
            startMinute: _minInt(a.startMinute, b.startMinute),
            endMinute: _maxInt(a.endMinute, b.endMinute),
            blocking: false,
            canKeepBoth: true,
          ),
        );
      }
    }
    return conflicts;
  }

  static bool _overlaps(int aStart, int aEnd, int bStart, int bEnd) {
    return aStart < bEnd && aEnd > bStart;
  }

  static bool _isSleep(RoutineItem item) {
    return item.title.toLowerCase().contains('sleep');
  }

  static int _minInt(int a, int b) => a < b ? a : b;
  static int _maxInt(int a, int b) => a > b ? a : b;
}
