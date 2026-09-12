import 'package:flutter/material.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/models/onboarding_draft.dart';

/// Canonical mapper between [ClassRoutineBlock] and persistent [TimelineBlockDraft].
///
/// Ensures lossless conversion for all rich class metadata:
/// - subject <-> title
/// - room <-> location
/// - professor <-> professor
/// - courseCode <-> courseCode
/// - classType <-> classType
/// - section <-> sectionLabel
/// - notes <-> notes
/// - startMinute, endMinute, repeatDays
///
/// Strictly rejects or excludes invalid days instead of fabricating schedule truth.
class ClassScheduleDraftMapper {
  const ClassScheduleDraftMapper._();

  /// Converts a [ClassRoutineBlock] into a durable [TimelineBlockDraft].
  ///
  /// Returns null if the block has no subject, invalid time ordering, or no valid
  /// repeat weekdays (1-7). Does not fabricate weekdays.
  static TimelineBlockDraft? toTimelineDraft(
    ClassRoutineBlock block, {
    required String section,
    List<String> provenanceSourceIds = const [],
    String source = 'ai_import',
  }) {
    final title = block.subject.trim();
    if (title.isEmpty) return null;
    if (block.startMinute >= block.endMinute) return null;

    final repeatDays =
        block.repeatDays.where((day) => day >= 1 && day <= 7).toSet().toList()
          ..sort();
    if (repeatDays.isEmpty) return null;

    final room = block.room.trim();
    final professor = block.professor.trim();
    final courseCode = block.courseCode.trim();
    final classType = block.classType.trim();
    final sectionLabel = block.section.trim();
    final notes = block.notes.trim();

    return TimelineBlockDraft(
      id: block.id,
      section: section,
      title: title,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      repeatDays: repeatDays,
      location: room.isEmpty ? null : room,
      blockType: TimelineBlockDraft.hardBlockKey,
      source: source,
      provenanceSourceIds: provenanceSourceIds,
      professor: professor.isEmpty ? null : professor,
      courseCode: courseCode.isEmpty ? null : courseCode,
      classType: classType.isEmpty ? null : classType,
      sectionLabel: sectionLabel.isEmpty ? null : sectionLabel,
      notes: notes.isEmpty ? null : notes,
    );
  }

  /// Converts a [TimelineBlockDraft] back into a [ClassRoutineBlock].
  ///
  /// Restores all rich metadata fields losslessly. Does NOT fabricate weekdays.
  static ClassRoutineBlock toClassRoutineBlock(
    TimelineBlockDraft draft, {
    IconData? icon,
    Color? color,
    bool hasTopTape = true,
    bool hasBottomTape = true,
  }) {
    final repeatDays =
        draft.repeatDays.where((day) => day >= 1 && day <= 7).toSet().toList()
          ..sort();

    return ClassRoutineBlock(
      id: draft.id,
      subject: draft.title,
      room: draft.location ?? '',
      professor: draft.professor ?? '',
      courseCode: draft.courseCode ?? '',
      classType: draft.classType ?? '',
      section: draft.sectionLabel ?? '',
      notes: draft.notes ?? '',
      startMinute: draft.startMinute,
      endMinute: draft.endMinute,
      repeatDays: repeatDays,
      icon: icon,
      color: color,
      hasTopTape: hasTopTape,
      hasBottomTape: hasBottomTape,
    );
  }

  /// Converts a collection of [ClassRoutineBlock]s into durable [TimelineBlockDraft]s.
  static List<TimelineBlockDraft> toTimelineDrafts(
    List<ClassRoutineBlock> blocks, {
    required String section,
    String? provenanceAssetId,
    String? provenanceR2Key,
    String source = 'ai_import',
  }) {
    final provenance = <String>[
      if (provenanceAssetId != null && provenanceAssetId.trim().isNotEmpty)
        provenanceAssetId.trim(),
      if (provenanceR2Key != null && provenanceR2Key.trim().isNotEmpty)
        provenanceR2Key.trim(),
    ];
    return blocks
        .map(
          (b) => toTimelineDraft(
            b,
            section: section,
            provenanceSourceIds: provenance,
            source: source,
          ),
        )
        .whereType<TimelineBlockDraft>()
        .toList(growable: false);
  }

  /// Restores a list of [ClassRoutineBlock]s from [TimelineBlockDraft]s,
  /// preserving rich fields, applying color cycling, and filtering out invalid entries.
  static List<ClassRoutineBlock> toClassRoutineBlocks(
    List<TimelineBlockDraft> drafts, {
    ScheduleSetupConfig? config,
  }) {
    final restored = drafts
        .asMap()
        .entries
        .map((entry) {
          final color = config != null
              ? config.colorCycle[entry.key % config.colorCycle.length]
              : null;
          final icon = config?.icon;
          return toClassRoutineBlock(entry.value, color: color, icon: icon);
        })
        .where((b) => b.subject.trim().isNotEmpty)
        .where((b) => b.startMinute < b.endMinute)
        .where((b) => b.repeatDays.isNotEmpty)
        .toList(growable: false);

    final sorted = List<ClassRoutineBlock>.from(restored);
    sorted.sort((a, b) {
      final dayCompare = (a.weekday ?? 1).compareTo(b.weekday ?? 1);
      return dayCompare != 0
          ? dayCompare
          : a.startMinute.compareTo(b.startMinute);
    });

    if (config != null) {
      return normalizeScheduleBlockColors(sorted, config);
    }
    return List<ClassRoutineBlock>.unmodifiable(sorted);
  }
}
