import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineImportConversionService {
  const RoutineImportConversionService();

  List<RoutineItem> convertAcceptedCandidates({
    required List<RoutineImportCandidateBlock> candidates,
  }) {
    final items = <RoutineItem>[];
    for (final candidate in candidates) {
      if (!candidate.selected) continue;
      if (!_hasConvertibleTime(candidate)) continue;
      if (candidate.title.trim().isEmpty) continue;
      if (candidate.repeatDays.isEmpty) continue;
      if (candidate.candidateType == RoutineImportCandidateType.unknown) {
        continue;
      }

      items.add(_routineItemFromCandidate(candidate));
    }
    return items;
  }

  bool _hasConvertibleTime(RoutineImportCandidateBlock candidate) {
    return candidate.startMinute >= 0 &&
        candidate.startMinute < 24 * 60 &&
        candidate.endMinute > 0 &&
        candidate.endMinute <= 24 * 60 &&
        candidate.startMinute < candidate.endMinute;
  }

  RoutineItem _routineItemFromCandidate(RoutineImportCandidateBlock candidate) {
    final blockType = _routineBlockType(candidate);
    return RoutineItem(
      id: candidate.id,
      title: candidate.title.trim(),
      startMinute: candidate.startMinute,
      endMinute: candidate.endMinute,
      repeatDays: candidate.repeatDays,
      location: candidate.location,
      blockType: blockType,
      category: _routineCategory(candidate.category),
      source: RoutineSource.imported,
      priority: candidate.hardBlock
          ? RoutinePriority.mustDo
          : RoutinePriority.goodToDo,
      notes: _notesForCandidate(candidate),
      steps: candidate.steps,
      mealCategory: candidate.mealCategory,
      hardBlock: candidate.hardBlock || blockType == RoutineBlockType.hardBlock,
    );
  }

  String _notesForCandidate(RoutineImportCandidateBlock candidate) {
    final parts = <String>[
      if (candidate.notes != null && candidate.notes!.trim().isNotEmpty)
        candidate.notes!.trim(),
      'Imported from review.',
      if (candidate.needsManualReview) 'Imported from review; verify details.',
      if (candidate.sourceAssetId != null)
        'Source asset: ${candidate.sourceAssetId}',
      if (candidate.sourceTextSnippet != null &&
          candidate.sourceTextSnippet!.trim().isNotEmpty)
        'Source text: ${candidate.sourceTextSnippet!.trim()}',
      if (candidate.steps.isNotEmpty) 'Steps: ${candidate.steps.join(', ')}',
    ];
    return parts.join('\n');
  }

  RoutineBlockType _routineBlockType(RoutineImportCandidateBlock candidate) {
    if (candidate.candidateType == RoutineImportCandidateType.flexibleTask ||
        candidate.blockType == TimelineBlockDraft.flexibleTaskKey) {
      return RoutineBlockType.flexibleTask;
    }
    if (candidate.candidateType == RoutineImportCandidateType.checklistStep) {
      return RoutineBlockType.flexibleTask;
    }
    return switch (candidate.blockType) {
      TimelineBlockDraft.hardBlockKey ||
      'hardBlock' => RoutineBlockType.hardBlock,
      TimelineBlockDraft.checkInKey || 'checkIn' => RoutineBlockType.checkIn,
      'trackerTask' || 'tracker_task' => RoutineBlockType.trackerTask,
      'moneyTask' || 'money_task' => RoutineBlockType.moneyTask,
      _ => RoutineBlockType.softBlock,
    };
  }

  RoutineCategory _routineCategory(String category) {
    return switch (category) {
      'classBlock' || 'class_block' || 'classes' => RoutineCategory.classBlock,
      'job' || 'job_work_business' || 'work' => RoutineCategory.job,
      'eating' => RoutineCategory.eating,
      'skinCare' || 'skin_care' => RoutineCategory.skinCare,
      'habit' => RoutineCategory.habit,
      'health' => RoutineCategory.health,
      _ => RoutineCategory.fixed,
    };
  }
}
