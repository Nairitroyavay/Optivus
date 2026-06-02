import 'package:optivus/models/routine_import_review.dart';

class RoutineImportTimeWindow {
  final int startMinute;
  final int endMinute;

  const RoutineImportTimeWindow({
    required this.startMinute,
    required this.endMinute,
  });
}

class RoutineImportTimelineEditService {
  const RoutineImportTimelineEditService._();

  static int snappedDeltaMinutes({
    required double verticalDelta,
    required double pixelsPerMinute,
    int snapMinutes = 5,
  }) {
    if (pixelsPerMinute <= 0) return 0;
    final rawMinutes = verticalDelta / pixelsPerMinute;
    final snap = snapMinutes <= 0 ? 5 : snapMinutes;
    return (rawMinutes / snap).round() * snap;
  }

  static RoutineImportTimeWindow moveWindow({
    required int startMinute,
    required int endMinute,
    required int deltaMinutes,
    int minDurationMinutes = 10,
  }) {
    final duration = (endMinute - startMinute)
        .clamp(minDurationMinutes, 24 * 60)
        .toInt();
    final maxStart = (24 * 60 - duration).clamp(0, 24 * 60).toInt();
    final nextStart = (startMinute + deltaMinutes).clamp(0, maxStart).toInt();
    return RoutineImportTimeWindow(
      startMinute: nextStart,
      endMinute: nextStart + duration,
    );
  }

  static RoutineImportTimeWindow resizeStart({
    required int startMinute,
    required int endMinute,
    required int deltaMinutes,
    int minDurationMinutes = 10,
  }) {
    final safeEnd = endMinute.clamp(minDurationMinutes, 24 * 60).toInt();
    final maxStart = (safeEnd - minDurationMinutes).clamp(0, 24 * 60).toInt();
    final nextStart = (startMinute + deltaMinutes).clamp(0, maxStart).toInt();
    return RoutineImportTimeWindow(startMinute: nextStart, endMinute: safeEnd);
  }

  static RoutineImportTimeWindow resizeEnd({
    required int startMinute,
    required int endMinute,
    required int deltaMinutes,
    int minDurationMinutes = 10,
  }) {
    final safeStart = startMinute
        .clamp(0, 24 * 60 - minDurationMinutes)
        .toInt();
    final minEnd = (safeStart + minDurationMinutes).clamp(0, 24 * 60).toInt();
    final nextEnd = (endMinute + deltaMinutes).clamp(minEnd, 24 * 60).toInt();
    return RoutineImportTimeWindow(startMinute: safeStart, endMinute: nextEnd);
  }

  static RoutineImportCandidateBlock moveCandidate({
    required RoutineImportCandidateBlock candidate,
    required int deltaMinutes,
    int minDurationMinutes = 10,
  }) {
    final window = moveWindow(
      startMinute: candidate.startMinute,
      endMinute: candidate.endMinute,
      deltaMinutes: deltaMinutes,
      minDurationMinutes: minDurationMinutes,
    );
    return candidate.copyWith(
      startMinute: window.startMinute,
      endMinute: window.endMinute,
      hasFixedTime: true,
    );
  }

  static RoutineImportCandidateBlock resizeCandidateStart({
    required RoutineImportCandidateBlock candidate,
    required int deltaMinutes,
    int minDurationMinutes = 10,
  }) {
    final window = resizeStart(
      startMinute: candidate.startMinute,
      endMinute: candidate.endMinute,
      deltaMinutes: deltaMinutes,
      minDurationMinutes: minDurationMinutes,
    );
    return candidate.copyWith(
      startMinute: window.startMinute,
      endMinute: window.endMinute,
      hasFixedTime: true,
    );
  }

  static RoutineImportCandidateBlock resizeCandidateEnd({
    required RoutineImportCandidateBlock candidate,
    required int deltaMinutes,
    int minDurationMinutes = 10,
  }) {
    final window = resizeEnd(
      startMinute: candidate.startMinute,
      endMinute: candidate.endMinute,
      deltaMinutes: deltaMinutes,
      minDurationMinutes: minDurationMinutes,
    );
    return candidate.copyWith(
      startMinute: window.startMinute,
      endMinute: window.endMinute,
      hasFixedTime: true,
    );
  }
}
