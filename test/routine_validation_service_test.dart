import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/models/routine_item.dart';

void main() {
  group('RoutineValidationService', () {
    test('Validates empty owner UID', () {
      final item = RoutineItem(
        id: 'test',
        title: 'Title',
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        userId: '   ',
        blockType: RoutineBlockType.flexibleTask,
      );
      final context = RoutineValidationContext(
        candidate: item,
        existingTemplates: [],
        occurrences: [],
        evaluationDate: DateTime.utc(2026, 1, 1),
        operation: RoutineValidationOperation.create,
        authenticatedOwnerUid: '   ',
      );
      final result = RoutineValidationService.validate(context);
      expect(result.isValid, isFalse);
      expect(result.errorType, RoutineValidationErrorType.missingData);
      expect(result.userSafeMessage, contains('Owner UID'));
    });

    test('Validates date component', () {
      final item = RoutineItem(
        id: 'test',
        title: 'Title',
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        date: DateTime.now(), // has time component and maybe local
        blockType: RoutineBlockType.flexibleTask,
      );
      final context = RoutineValidationContext(
        candidate: item,
        existingTemplates: [],
        occurrences: [],
        evaluationDate: DateTime.utc(2026, 1, 1),
        operation: RoutineValidationOperation.create,
        authenticatedOwnerUid: 'test-uid',
      );
      final result = RoutineValidationService.validate(context);
      expect(result.isValid, isFalse);
      expect(result.errorType, RoutineValidationErrorType.invalidTime);
      expect(result.userSafeMessage, contains('zero time component'));
    });
  });
}
