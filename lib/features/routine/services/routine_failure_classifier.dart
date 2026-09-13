import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/features/routine/models/routine_write_result.dart';

RoutineFailureCategory classifyRoutineWriteFailure(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
        return RoutineFailureCategory.offlineOrUnavailable;
      case 'deadline-exceeded':
        return RoutineFailureCategory.deadlineExceeded;
      case 'permission-denied':
        return RoutineFailureCategory.permissionDenied;
    }
  }
  if (error is FormatException || error is ArgumentError) {
    return RoutineFailureCategory.validation;
  }
  return RoutineFailureCategory.unknown;
}
