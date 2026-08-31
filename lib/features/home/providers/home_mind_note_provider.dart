import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';

class HomeMindNoteNotifier extends StateNotifier<List<HomeMindNote>> {
  HomeMindNoteNotifier({bool fakeDataAllowed = false})
    : super(
        fakeDataAllowed
            ? [
                HomeMindNote(
                  id: 'mock1',
                  type: MindNoteType.overthinking,
                  intensity: MindNoteIntensity.medium,
                  visibility: MindNoteVisibility.private,
                  content:
                      'I keep thinking about whether I should rewrite the backend in Go or stick to Node.js.',
                  createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
                ),
              ]
            : const [],
      );

  void addNote(String content, MindNoteType type, MindNoteIntensity intensity) {
    final note = HomeMindNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      intensity: intensity,
      visibility: MindNoteVisibility.private,
      content: content,
      createdAt: DateTime.now(),
    );
    state = [note, ...state];
  }

  void toggleShareWithCoach(String id) {
    state = state.map((note) {
      if (note.id == id) {
        final newVisibility = note.visibility == MindNoteVisibility.private
            ? MindNoteVisibility.sharedWithCoach
            : MindNoteVisibility.private;
        return note.copyWith(visibility: newVisibility);
      }
      return note;
    }).toList();
  }

  void deleteNote(String id) {
    state = state.where((note) => note.id != id).toList();
  }

  void resetForSignedOut() {
    state = const [];
  }
}

final homeMindNoteProvider =
    StateNotifierProvider<HomeMindNoteNotifier, List<HomeMindNote>>((ref) {
      return HomeMindNoteNotifier(
        fakeDataAllowed: ref.watch(fakeDataAllowedProvider),
      );
    });
