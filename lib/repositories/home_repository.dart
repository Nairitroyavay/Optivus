import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/models/mind_note.dart';

abstract class HomeDashboardRepository {
  Future<HomeDashboardState?> fetchDashboard(String uid);
  Future<void> saveDashboard(String uid, HomeDashboardState dashboard);
}

abstract class MindNoteRepository {
  Future<List<MindNote>> fetchMindNotes(String uid);
  Future<void> saveMindNote(String uid, MindNote note);
  Future<void> deleteMindNote(String uid, String noteId);
}

class FakeHomeDashboardRepository implements HomeDashboardRepository {
  final Map<String, HomeDashboardState> _dashboards = {};

  @override
  Future<HomeDashboardState?> fetchDashboard(String uid) async {
    return _dashboards[uid];
  }

  @override
  Future<void> saveDashboard(String uid, HomeDashboardState dashboard) async {
    _dashboards[uid] = dashboard;
  }
}

class FakeMindNoteRepository implements MindNoteRepository {
  final Map<String, List<MindNote>> _notes = {};

  @override
  Future<List<MindNote>> fetchMindNotes(String uid) async {
    return _notes[uid] ?? const [];
  }

  @override
  Future<void> saveMindNote(String uid, MindNote note) async {
    final current = [...await fetchMindNotes(uid)];
    current.removeWhere((item) => item.id == note.id);
    current.add(note);
    _notes[uid] = current;
  }

  @override
  Future<void> deleteMindNote(String uid, String noteId) async {
    _notes[uid] = (await fetchMindNotes(
      uid,
    )).where((item) => item.id != noteId).toList(growable: false);
  }
}

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepository>((
  ref,
) {
  return FakeHomeDashboardRepository();
});

final mindNoteRepositoryProvider = Provider<MindNoteRepository>((ref) {
  return FakeMindNoteRepository();
});
