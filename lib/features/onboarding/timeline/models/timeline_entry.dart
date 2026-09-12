import 'package:flutter/foundation.dart';
import 'package:optivus/core/timeline/timeline_visual_models.dart';

/// Semantic category for timeline items.
enum TimelineCategory { classes, work, meal, fixed, skinCare, other }

/// Neutral timeline presentation model.
///
/// Decoupled from concrete feature domain objects.
@immutable
class TimelineEntry implements TimelineInterval {
  /// Unique identifier for this visual timeline entry.
  @override
  final String id;

  /// Underlying domain object identifier (e.g. routine ID or draft block ID).
  final String sourceId;

  /// Start minute of the event (0..1440).
  @override
  final int startMinute;

  /// End minute of the event (0..1440). Must be >= startMinute.
  @override
  final int endMinute;

  /// Active days of the week (1..7, where Monday = 1 and Sunday = 7).
  final List<int> repeatDays;

  /// Primary event title.
  final String title;

  /// Optional secondary subtitle / room / location.
  final String? subtitle;

  /// Category identifying the feature domain.
  final TimelineCategory category;

  /// Whether the user can tap to edit this entry.
  final bool isEditable;

  /// Optional adapter key for routing edit operations.
  final String? adapterKey;

  /// Optional day index for day-bounded split segments (1..7).
  final int? specificDay;

  /// Optional minimum height in pixels required by content (dishes, steps).
  final double minHeight;

  const TimelineEntry({
    required this.id,
    required this.sourceId,
    required this.startMinute,
    required this.endMinute,
    required this.repeatDays,
    required this.title,
    this.subtitle,
    required this.category,
    this.isEditable = true,
    this.adapterKey,
    this.specificDay,
    this.minHeight = 0.0,
  }) : assert(
         startMinute <= endMinute,
         'startMinute must be <= endMinute ($startMinute > $endMinute)',
       );

  /// Duration in minutes.
  int get durationMinutes => endMinute - startMinute;

  /// Whether this entry repeats on the specified day (1..7).
  bool isActiveOnDay(int day) {
    if (specificDay != null) {
      return specificDay == day;
    }
    return repeatDays.contains(day);
  }

  TimelineEntry copyWith({
    String? id,
    String? sourceId,
    int? startMinute,
    int? endMinute,
    List<int>? repeatDays,
    String? title,
    String? subtitle,
    TimelineCategory? category,
    bool? isEditable,
    String? adapterKey,
    int? specificDay,
    double? minHeight,
  }) {
    return TimelineEntry(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      repeatDays: repeatDays ?? this.repeatDays,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      isEditable: isEditable ?? this.isEditable,
      adapterKey: adapterKey ?? this.adapterKey,
      specificDay: specificDay ?? this.specificDay,
      minHeight: minHeight ?? this.minHeight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sourceId == other.sourceId &&
          startMinute == other.startMinute &&
          endMinute == other.endMinute &&
          listEquals(repeatDays, other.repeatDays) &&
          title == other.title &&
          subtitle == other.subtitle &&
          category == other.category &&
          isEditable == other.isEditable &&
          adapterKey == other.adapterKey &&
          specificDay == other.specificDay &&
          minHeight == other.minHeight;

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    startMinute,
    endMinute,
    Object.hashAll(repeatDays),
    title,
    subtitle,
    category,
    isEditable,
    adapterKey,
    specificDay,
    minHeight,
  );

  @override
  String toString() =>
      'TimelineEntry(id: $id, sourceId: $sourceId, $startMinute..$endMinute, title: "$title", cat: $category)';
}
