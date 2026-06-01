import re
import os

DUMMY_DEFS = """
// --- DUMMY DEFS FOR PORTING ---
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/onboarding_draft.dart';

final appFeatureFlagsProvider = Provider((ref) => DummyFlags());
class DummyFlags {
  bool get classTimetableImageImportReady => false;
  bool get textParseImportReady => false;
  bool get eatingMenuImageImportReady => false;
  bool get skincareImageImportReady => false;
}
final eventServiceProvider = Provider((ref) => DummyEvent());
class DummyEvent { Future<void> emit({dynamic eventName, dynamic source, dynamic payload}) async {} }
final firestoreServiceProvider = Provider((ref) => DummyFirestore());
class DummyFirestore { Future<void> saveSuggestion(dynamic x, dynamic y) async {} }
final routineRepositoryProvider = Provider((ref) => DummyRepo());
class DummyRepo { Future<void> previewRoutineImport(dynamic a, dynamic b, dynamic c) async {} }
class ImageSource { static const gallery = 0; static const camera = 1; }
class EventNames { 
  static const timetableSuggestAI = 0; 
  static const classScheduleImported = 0; 
  static const classScheduleUpdated = 0; 
  static const fixedScheduleUpdated = 0;
  static const fixedScheduleImported = 0;
  static const eatingScheduleUpdated = 0;
  static const skincareScheduleUpdated = 0;
}
class ImageUploadService {
  Future<dynamic> pickImage(dynamic x) async { return null; }
  Future<dynamic> uploadImage(dynamic x, dynamic y) async { return null; }
}
Future<void> runRoutineAcceptWithTimeout(dynamic fn) async { await fn(); }
class RoutineAcceptTimeoutException implements Exception {}
// ------------------------------
"""

def reset_file(src, dst):
    os.system(f"cp {src} {dst}")
    os.system(f"sed -i '' 's/package:optivus2\\//package:optivus\\//g' {dst}")

def apply_fixes(filepath, init_state_repl, save_repl):
    with open(filepath, 'r') as f:
        content = f.read()

    # Remove legacy imports to avoid conflicts
    content = re.sub(r"import 'package:image_picker/image_picker.dart';", "", content)
    content = re.sub(r"import 'package:optivus/core/constants/event_names.dart';", "", content)
    content = re.sub(r"import 'package:optivus/core/providers.dart';", "", content)
    content = re.sub(r"import 'package:optivus/providers/routine_provider.dart';", "", content)
    content = re.sub(r"import 'package:optivus/services/image_upload_service.dart';", "", content)
    content = re.sub(r"import 'package:optivus/services/routine_acceptance_guard.dart';", "", content)
    
    # Inject dummy definitions after the remaining imports
    content = re.sub(r"(import 'package:optivus/core/liquid_ui/liquid_ui.dart';)", r"\1\n" + DUMMY_DEFS, content, count=1)

    # Replace initState
    content = re.sub(
        r"WidgetsBinding\.instance\.addPostFrameCallback\(\(_\) \{.*?setState\(\(\) => (weeklyRoutines = next|weeklyMeals = next|weeklySkinSteps = next|_currentTemplates = ref\.read\(routineProvider\)\.fixedScheduleTemplates);\n      \}?\)?;\n    \}\);",
        init_state_repl,
        content,
        flags=re.DOTALL
    )

    # Replace _save or save logic
    content = re.sub(
        r"Future<bool> _save\(.*?\).*?finally \{\n      if \(mounted\) setState\(\(\) => _isSaving = false\);\n    \}\n  \}",
        save_repl,
        content,
        flags=re.DOTALL
    )

    # Overwrite `_showRoutineReviewDialog` to just save and pop
    review_repl = """
  void _showRoutineReviewDialog() {
    _save().then((success) {
      if (success && mounted) {
        widget.onComplete();
      }
    });
  }
"""
    content = re.sub(r"void _showRoutineReviewDialog\(\) \{.*?(?=  Widget _buildDroplet|  Widget _buildMealCard|  Widget _buildSkinCard|  Widget _buildStepDroplet|  Widget build)", review_repl, content, flags=re.DOTALL)

    # We need to adapt `_save(ref)` if they take arguments, let's just make it `_save()` and inside we use `ref`. 
    # Since `ref` is available in ConsumerState, `_save()` is fine.
    content = content.replace("Future<bool> _save(WidgetRef ref) async {", "Future<bool> _save() async {")
    content = content.replace("_save(ref)", "_save()")

    with open(filepath, 'w') as f:
        f.write(content)


# --- 1. CLASSES ---
reset_file(
    'reference_copied_old_frontend/onboarding_base_timeline/classes/class_setup_screen.dart', 
    'lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart'
)

init_class = """
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final baseTimeline = ref.read(mockOnboardingProvider).draft.baseTimeline;
      final savedClasses = baseTimeline.blocks.where((b) => b.section == 'classes').toList();
      if (!mounted) return;

      final next = <int, List<ClassRoutineBlock>>{
        for (int i = 0; i < 7; i++) i: <ClassRoutineBlock>[],
      };

      for (final item in savedClasses) {
        for (final day in item.repeatDays) {
          final dayIndex = (day - 1).clamp(0, 6);
          final start = item.startMinute / 60.0 - 6.0;
          final duration = (item.endMinute - item.startMinute) / 60.0;
          next[dayIndex]!.add(
            ClassRoutineBlock(
              id: 'class_${dayIndex}_${item.id}',
              subject: item.title,
              room: item.location ?? '',
              professor: '',
              start: start < 0 ? start + 24 : start,
              duration: duration <= 0 ? 1.0 : duration,
              icon: Icons.school_rounded,
              color: Color(0xFF378ADD),
              hasTopTape: true,
              hasBottomTape: true,
            ),
          );
        }
      }

      for (int i = 0; i < 7; i++) {
        next[i]!.sort((a, b) => a.start.compareTo(b.start));
        next[i]!.add(ClassRoutineBlock(
          id: 'add_saved_$i',
          subject: '',
          start: 7.0,
          isAdd: true,
        ));
      }

      setState(() => weeklyRoutines = next);
    });
"""

save_class = """
  Future<bool> _save() async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);

    try {
      final List<TimelineBlockDraft> newBlocks = [];
      for (int day = 0; day < 7; day++) {
        for (final block in weeklyRoutines[day]!) {
          if (block.isAdd || block.subject.trim().isEmpty) continue;
          
          int startMin = ((block.start + 6.0) * 60).round();
          int endMin = ((block.start + block.duration + 6.0) * 60).round();
          if (startMin < 0) startMin += 24 * 60;
          if (endMin < 0) endMin += 24 * 60;
          
          newBlocks.add(TimelineBlockDraft(
            id: 'class_${day}_${DateTime.now().millisecondsSinceEpoch}_${block.subject.replaceAll(" ", "")}',
            section: 'classes',
            title: block.subject,
            startMinute: startMin,
            endMinute: endMin,
            crossesMidnight: endMin < startMin,
            blockType: TimelineBlockDraft.hardBlockKey,
            repeatDays: [day + 1],
            location: block.room.isNotEmpty ? block.room : null,
          ));
        }
      }

      ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
        final filteredBlocks = draft.baseTimeline.blocks.where((b) => b.section != 'classes').toList();
        return draft.copyWith(
          baseTimeline: draft.baseTimeline.copyWith(blocks: [...filteredBlocks, ...newBlocks]),
          clearFinalPreview: true,
        );
      });
      ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
"""

apply_fixes('lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart', init_class, save_class)

