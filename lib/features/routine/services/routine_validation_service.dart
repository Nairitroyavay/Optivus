import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';

enum RoutineValidationErrorType { none, invalidTime, missingData, duplicateId }

enum RoutineValidationOperation { create, update, move, batch }

class RoutineValidationContext {
  final RoutineItem candidate;
  final List<RoutineItem> existingTemplates;
  final List<RoutineOccurrenceRecord> occurrences;
  final DateTime evaluationDate;
  final DateTime? explicitNow;
  final RoutineValidationOperation operation;
  final List<RoutineItem> batchCandidates;
  final String authenticatedOwnerUid;

  const RoutineValidationContext({
    required this.candidate,
    required this.existingTemplates,
    required this.occurrences,
    required this.evaluationDate,
    this.explicitNow,
    required this.operation,
    this.batchCandidates = const [],
    required this.authenticatedOwnerUid,
  });
}

class RoutineValidationResult {
  final bool isValid;
  final RoutineValidationErrorType errorType;
  final String? userSafeMessage;
  final List<String> affectedItemIds;

  const RoutineValidationResult.valid()
    : isValid = true,
      errorType = RoutineValidationErrorType.none,
      userSafeMessage = null,
      affectedItemIds = const [];

  const RoutineValidationResult.invalid({
    required this.errorType,
    required this.userSafeMessage,
    this.affectedItemIds = const [],
  }) : isValid = false;
}

class RoutineBatchValidationResult {
  final bool isValid;
  final List<RoutineValidationResult> itemFailures;
  final bool durableSaved;
  final bool retryRequired;
  final String? message;
  final String? operationId;

  const RoutineBatchValidationResult.valid({
    this.durableSaved = true,
    this.retryRequired = false,
    this.message,
    this.operationId,
  }) : isValid = true,
       itemFailures = const [];

  const RoutineBatchValidationResult.invalid(this.itemFailures, {this.message})
    : isValid = false,
      durableSaved = false,
      retryRequired = false,
      operationId = null;

  const RoutineBatchValidationResult.retryRequired({
    required this.message,
    required this.operationId,
  }) : isValid = true,
       itemFailures = const [],
       durableSaved = false,
       retryRequired = true;

  const RoutineBatchValidationResult.superseded({
    required this.operationId,
    this.message,
  }) : isValid = true,
       itemFailures = const [],
       durableSaved = false,
       retryRequired = false;
}

class RoutineValidationService {
  RoutineValidationService._();

  static RoutineValidationResult validate(RoutineValidationContext context) {
    final item = context.candidate;

    // A. Explicit validation invariants

    if (item.startMinute < 0 || item.startMinute > 1439) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.invalidTime,
        userSafeMessage: 'Start time must be between 0 and 1439.',
        affectedItemIds: [item.id],
      );
    }

    if (item.endMinute < 0 || item.endMinute > 1440) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.invalidTime,
        userSafeMessage: 'End time must be between 0 and 1440.',
        affectedItemIds: [item.id],
      );
    }

    if (item.startMinute == item.endMinute) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.invalidTime,
        userSafeMessage: 'Start and end time cannot be equal.',
        affectedItemIds: [item.id],
      );
    }

    final overnightFlag = item.crossesMidnight || item.endsNextDay;

    if (!overnightFlag) {
      if (item.endMinute <= item.startMinute) {
        return RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.invalidTime,
          userSafeMessage:
              'Non-overnight items require end time to be strictly after start time.',
          affectedItemIds: [item.id],
        );
      }
    } else {
      if (item.endMinute >= item.startMinute) {
        return RoutineValidationResult.invalid(
          errorType: RoutineValidationErrorType.invalidTime,
          userSafeMessage:
              'Overnight items require end time to be strictly before start time.',
          affectedItemIds: [item.id],
        );
      }
    }

    final expectedDuration = overnightFlag
        ? (1440 - item.startMinute) + item.endMinute
        : item.endMinute - item.startMinute;

    if (item.durationMinutes <= 0 || item.durationMinutes != expectedDuration) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.invalidTime,
        userSafeMessage:
            'Duration must be positive and match the normalized time range.',
        affectedItemIds: [item.id],
      );
    }

    // Validate explicit dates vs recurrence
    if (item.repeatRule == 'once' && item.date == null) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'One-time tasks require a date.',
        affectedItemIds: [item.id],
      );
    }

    if (item.id.isEmpty) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Item ID cannot be empty.',
        affectedItemIds: [item.id],
      );
    }

    // Validate document ID format (no slashes, reasonable length)
    if (item.id.contains('/') || item.id.length > 128) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Item ID format is invalid.',
        affectedItemIds: [item.id],
      );
    }

    if (item.userId != null && item.userId != context.authenticatedOwnerUid) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Item owner UID does not match authenticated user.',
        affectedItemIds: [item.id],
      );
    }

    if (item.userId != null && item.userId!.trim().isEmpty) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Owner UID cannot be empty if provided.',
        affectedItemIds: [item.id],
      );
    }

    bool hasTimeComponent(DateTime dt) {
      return dt.hour != 0 ||
          dt.minute != 0 ||
          dt.second != 0 ||
          dt.millisecond != 0 ||
          dt.microsecond != 0;
    }

    if ((item.date != null && hasTimeComponent(item.date!)) ||
        (item.endDate != null && hasTimeComponent(item.endDate!))) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.invalidTime,
        userSafeMessage: 'Dates must have zero time component.',
        affectedItemIds: [item.id],
      );
    }

    // Validate title is not blank
    if (item.title.trim().isEmpty) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Routine title cannot be empty.',
        affectedItemIds: [item.id],
      );
    }

    final uniqueDays = item.repeatDays.toSet();
    if (uniqueDays.length != item.repeatDays.length ||
        uniqueDays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      return RoutineValidationResult.invalid(
        errorType: RoutineValidationErrorType.missingData,
        userSafeMessage: 'Routine repeat days must be unique values 1-7.',
        affectedItemIds: [item.id],
      );
    }

    if (item.category == RoutineCategory.eating) {
      final allEatingPool = <RoutineItem>[
        ...context.existingTemplates.where(
          (t) => t.category == RoutineCategory.eating && t.id != item.id,
        ),
        ...context.batchCandidates.where(
          (b) => b.category == RoutineCategory.eating && b.id != item.id,
        ),
        item,
      ];
      for (int day = 1; day <= 7; day++) {
        final dayMeals = allEatingPool
            .where((m) => m.repeatDays.isEmpty || m.repeatDays.contains(day))
            .toList();

        if (dayMeals.length > 6) {
          return RoutineValidationResult.invalid(
            errorType: RoutineValidationErrorType.invalidTime,
            userSafeMessage: 'Maximum 6 meals allowed per day.',
            affectedItemIds: [item.id],
          );
        }
      }
    }

    return const RoutineValidationResult.valid();
  }

  static RoutineBatchValidationResult validateBatch({
    required List<RoutineItem> itemsToAdd,
    required List<RoutineItem> existingTemplates,
    required List<RoutineOccurrenceRecord> occurrences,
    required DateTime evaluationDate,
    DateTime? explicitNow,
    required String authenticatedOwnerUid,
  }) {
    if (itemsToAdd.isEmpty) {
      return const RoutineBatchValidationResult.valid();
    }

    final failures = <RoutineValidationResult>[];
    final idSet = <String>{};

    for (final item in itemsToAdd) {
      if (!idSet.add(item.id)) {
        failures.add(
          RoutineValidationResult.invalid(
            errorType: RoutineValidationErrorType.duplicateId,
            userSafeMessage: 'Duplicate item ID within batch.',
            affectedItemIds: [item.id],
          ),
        );
        continue;
      }

      final context = RoutineValidationContext(
        candidate: item,
        existingTemplates: existingTemplates,
        occurrences: occurrences,
        evaluationDate: item.date ?? evaluationDate,
        explicitNow: explicitNow,
        operation: RoutineValidationOperation.batch,
        batchCandidates: itemsToAdd,
        authenticatedOwnerUid: authenticatedOwnerUid,
      );

      final v = validate(context);
      if (!v.isValid) {
        failures.add(v);
      }
    }

    if (failures.isNotEmpty) {
      return RoutineBatchValidationResult.invalid(failures);
    }
    return const RoutineBatchValidationResult.valid();
  }
}
