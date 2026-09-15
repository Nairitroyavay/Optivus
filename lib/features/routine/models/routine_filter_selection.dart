import 'package:flutter/foundation.dart';
import 'package:optivus/features/routine/models/routine_day_entry.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';

/// Immutable specification of the user's active routine filters across View,
/// Status, and Category axes.
@immutable
class RoutineFilterSelection {
  final String view;
  final String status;
  final String category;

  const RoutineFilterSelection({
    this.view = 'all',
    this.status = 'any',
    this.category = 'all',
  });

  /// The number of non-default filters actively constraining the timeline.
  int get activeCount {
    var count = 0;
    if (view != 'all') count++;
    if (status != 'any') count++;
    if (category != 'all') count++;
    return count;
  }

  /// Convenience aliases matching filter semantics
  String get selectedPrimaryFilter => view;
  String get selectedStatusFilter => status;
  String get selectedCategoryFilter => category;

  /// Returns a normalized filter selection where an unavailable category filter
  /// is reset to 'all' if no matching entry exists on the evaluated day.
  RoutineFilterSelection normalizedFor(List<RoutineDayEntry> entries) {
    if (category == 'all') return this;
    final hasCategory = entries.any(
      (entry) => RoutineEntryFilter.matchesCategory(entry.item, category),
    );
    if (hasCategory) return this;
    return copyWith(category: 'all');
  }

  RoutineFilterSelection copyWith({
    String? view,
    String? status,
    String? category,
  }) {
    return RoutineFilterSelection(
      view: view ?? this.view,
      status: status ?? this.status,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineFilterSelection &&
          runtimeType == other.runtimeType &&
          view == other.view &&
          status == other.status &&
          category == other.category;

  @override
  int get hashCode => Object.hash(view, status, category);

  @override
  String toString() =>
      'RoutineFilterSelection(view: $view, status: $status, category: $category)';
}
