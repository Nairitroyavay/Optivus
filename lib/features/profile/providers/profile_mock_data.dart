import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mock Data for Focus Areas
final mockFocusAreasProvider = Provider<List<String>>((ref) {
  return ['Health', 'Finance', 'Mind', 'Skill', 'Discipline'];
});

// Mock Data for Habits to Break
final mockHabitsToBreakProvider = Provider<List<String>>((ref) {
  return ['Cigarettes', 'Doom Scrolling', 'Junk Food'];
});

// Mock Identity Statement
final mockIdentityStatementProvider = Provider<String>((ref) {
  return 'Working toward Strong Body, Financial Freedom, and Discipline.';
});
