import 'package:optivus/models/habit_system_operation.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/repositories/firebase_habit_systems_repository.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';


abstract class HabitSystemsRepository {
  Future<List<HabitSystemRecord>> fetchHabitSystems(String uid);
  Future<HabitSystemWriteResult> createSystem({
    required HabitSystemRecord system,
    required String operationId,
  });
  Future<HabitSystemWriteResult> updateSystem({
    required HabitSystemRecord system,
    required int expectedVersion,
    required String operationId,
  });
  Future<HabitSystemWriteResult> archiveSystem(String uid, String systemId, int expectedVersion, String operationId);
  Future<HabitSystemWriteResult> restoreSystem(String uid, String systemId, int expectedVersion, String operationId);
  Future<HabitSystemWriteResult> reconcileProjectedSystem(HabitSystemRecord system);
  Future<void> deleteHabitSystem(String uid, String systemId);
  Stream<List<HabitSystemRecord>> watchHabitSystems(String uid);
}



final habitSystemsRepositoryProvider = Provider<HabitSystemsRepository>((ref) {
  return FirestoreHabitSystemsRepository();
});
