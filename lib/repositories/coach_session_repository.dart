import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/coach_models.dart';

abstract class CoachSessionRepository {
  Future<List<CoachSession>> fetchSessions(String uid);
  Future<void> saveSession(String uid, CoachSession session);
  Future<void> deleteSession(String uid, String sessionId);
}

abstract class CoachAiRepository {
  Future<CoachMessage> generateReply({
    required String uid,
    required String sessionId,
    required String userMessage,
    required Map<String, dynamic> allowedContext,
  });
}

class FakeCoachSessionRepository implements CoachSessionRepository {
  final Map<String, List<CoachSession>> _sessions = {};

  @override
  Future<List<CoachSession>> fetchSessions(String uid) async {
    return _sessions[uid] ?? const [];
  }

  @override
  Future<void> saveSession(String uid, CoachSession session) async {
    final current = [...await fetchSessions(uid)];
    current.removeWhere((item) => item.id == session.id);
    current.add(session);
    _sessions[uid] = current;
  }

  @override
  Future<void> deleteSession(String uid, String sessionId) async {
    _sessions[uid] = (await fetchSessions(
      uid,
    )).where((session) => session.id != sessionId).toList(growable: false);
  }
}

class FakeCoachAiRepository implements CoachAiRepository {
  @override
  Future<CoachMessage> generateReply({
    required String uid,
    required String sessionId,
    required String userMessage,
    required Map<String, dynamic> allowedContext,
  }) async {
    return CoachMessage(
      id: 'coach-ai-${DateTime.now().microsecondsSinceEpoch}',
      isFromCoach: true,
      content:
          'Backend connection pending. Coach AI will use allowed context through a Cloudflare Worker.',
      timestamp: 'Just now',
    );
  }
}

final coachSessionRepositoryProvider = Provider<CoachSessionRepository>((ref) {
  return FakeCoachSessionRepository();
});

final coachAiRepositoryProvider = Provider<CoachAiRepository>((ref) {
  return FakeCoachAiRepository();
});
