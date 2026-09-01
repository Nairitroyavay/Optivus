import 'package:flutter/material.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_style.dart';

/// Abstract adapter interface translating feature-specific domain items
/// into neutral TimelineEntry presentation models and handling editing.
abstract class TimelineFeatureAdapter<T> {
  const TimelineFeatureAdapter();

  /// Converts domain object [domain] into one or more neutral [TimelineEntry]s.
  /// (Multiple entries occur when cross-midnight splitting produces day-bounded segments).
  List<TimelineEntry> toEntries(T domain);

  /// Builds visual presentation styling for a timeline entry.
  TimelineEntryStyle styleForEntry(TimelineEntry entry);

  /// Optional edit handler called when user taps on an editable block.
  Future<void> onEditRequested(
    BuildContext context,
    TimelineEntry entry,
    VoidCallback onUpdated,
  );
}
