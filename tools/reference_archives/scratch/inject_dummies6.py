import re
import os

DUMMY_DEFS = """
// --- DUMMY DEFS FOR PORTING ---
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_editors/legacy_models/copied_routine_provider_subset.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_editors/legacy_models/routine_template_model.dart';

final appFeatureFlagsProvider = Provider((ref) => DummyFlags());
class DummyFlags {
  bool get classTimetableImageImportReady => false;
  bool get textParseImportReady => false;
  bool get eatingMenuImageImportReady => false;
  bool get skincareImageImportReady => false;
  bool get routineImportWorkerReady => false;
  bool get skinProductImageImportReady => false;
}
final eventServiceProvider = Provider((ref) => DummyEvent());
class DummyEvent { Future<void> emit({dynamic eventName, dynamic source, dynamic payload}) async {} }
final firestoreServiceProvider = Provider((ref) => DummyFirestore());
class DummyFirestore { Future<void> saveSuggestion(dynamic x, dynamic y) async {} }
final routineRepositoryProvider = Provider((ref) => DummyRepo());
class DummyRepo { 
  Future<List<Map<String, dynamic>>> previewRoutineImport({dynamic routineType, dynamic mode, dynamic sourceText, dynamic imageMetadata}) async { return []; } 
  Future<void> saveFixedScheduleTemplates(dynamic x) async {} 
}
final routineProvider = StateProvider<RoutineState>((ref) => RoutineState());
class RoutineState { 
  final routineTemplates = const <String, List<dynamic>>{}; 
  final fixedScheduleTemplates = const []; 
  dynamic classesForDay(int day) => []; 
}

class ImageSource { static const gallery = 0; static const camera = 1; }
class EventNames { 
  static const timetableSuggestAI = 0; 
  static const classScheduleImported = 0; 
  static const classScheduleUpdated = 0; 
  static const fixedScheduleUpdated = 0;
  static const fixedScheduleImported = 0;
  static const eatingScheduleUpdated = 0;
  static const skincareScheduleUpdated = 0;
  static const suggestionGenerated = 0;
  static const suggestionDismissed = 0;
  static const suggestionAccepted = 0;
}
class ImageUploadService {
  Future<dynamic> pickImage(dynamic x) async { return null; }
  Future<dynamic> uploadImage(dynamic x, dynamic y) async { return null; }
  Future<dynamic> deleteUploadedMetadata(dynamic x) async { return null; }
  Future<dynamic> pickCompressAndUpload({dynamic source, dynamic routineType}) async { return null; }
}
Future<void> runRoutineAcceptWithTimeout(dynamic fn) async { await Future.value(fn()); }
class RoutineAcceptTimeoutException implements Exception {}

List<Map<String, dynamic>> fallbackSkinCareTemplatesFromText(String t) => [];
dynamic normalizeRoutineTimeOrNull(dynamic x, {dynamic isEndOfDay}) => null;
dynamic canonicalRelativeTimingRule(dynamic x, {dynamic isEndOfDay}) => null;
dynamic resolveRelativeTimingForTemplate({dynamic template, dynamic date, dynamic anchors}) => template;

class RoutineReviewScreen extends StatelessWidget {
  final dynamic mode;
  final dynamic title;
  final dynamic routineType;
  final dynamic originalBlocks;
  final dynamic modifiedBlocks;
  final dynamic originalTemplates;
  final dynamic modifiedTemplates;
  final dynamic templates;
  final dynamic onRegenerate;
  final dynamic onAcceptAll;
  final dynamic onSave;
  final dynamic onCancel;
  const RoutineReviewScreen({Key? key, this.title, this.routineType, this.templates, this.onRegenerate, this.onAcceptAll, this.mode, this.originalBlocks, this.modifiedBlocks, this.originalTemplates, this.modifiedTemplates, this.onSave, this.onCancel}) : super(key: key);
  Widget build(BuildContext context) => const SizedBox();
}
class RoutineAnchor {
  RoutineAnchor({dynamic title, dynamic routineType, dynamic startTime, dynamic endTime, dynamic repeatRule});
  static RoutineAnchor fromMap(dynamic m) => RoutineAnchor();
}
extension StateControllerSkinExt on StateController<RoutineState> {
  void setSkinCarePlan(int day, dynamic plan) {}
  void markSkinCareSetUp() {}
  Future<void> setRoutineTemplates(String type, List<Map<String, dynamic>> t, {dynamic importMetadata}) async {}
}
// ------------------------------
"""

def prepare_file(src, dst):
    os.system(f"cp {src} {dst}")
    os.system(f"sed -i '' 's/package:optivus2\\//package:optivus\\//g' {dst}")
    
    with open(dst, 'r') as f:
        content = f.read()

    # Remove legacy imports broadly
    content = re.sub(r"import 'package:image_picker/image_picker.dart';", "", content)
    content = re.sub(r"import 'package:optivus/providers/.*?\n", "", content)
    content = re.sub(r"import 'package:optivus/services/.*?\n", "", content)
    content = re.sub(r"import 'package:optivus/views/.*?\n", "", content)
    content = re.sub(r"import 'package:optivus/core/constants/.*?\n", "", content)
    content = re.sub(r"import 'package:optivus/core/providers.dart';\n", "", content)
    
    # Prepend dummy defs after the first liquid_ui import
    content = re.sub(r"(import 'package:optivus/core/liquid_ui/liquid_ui.dart';)", r"\1\n" + DUMMY_DEFS, content, count=1)
    
    with open(dst, 'w') as f:
        f.write(content)

prepare_file(
    'reference_copied_old_frontend/onboarding_base_timeline/skin_care/skin_care_setup_screen.dart', 
    'lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart'
)

# NOW overwrite initState and _save
with open('lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart', 'r') as f:
    content = f.read()

save_replacement = """
  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final List<TimelineBlockDraft> newBlocks = [];
      for (int d = 0; d < 7; d++) {
        final itemsForDay = weeklyRoutines[d] ?? [];
        for (final item in itemsForDay) {
          if (item.isAdd || item.title.trim().isEmpty) continue;
          
          int startMin = ((item.start + 6.0) * 60).round();
          int endMin = ((item.start + item.duration + 6.0) * 60).round();
          if (startMin < 0) startMin += 24 * 60;
          if (endMin < 0) endMin += 24 * 60;
          
          newBlocks.add(TimelineBlockDraft(
            id: 'skin_care_${d}_${DateTime.now().millisecondsSinceEpoch}_${item.title.replaceAll(" ", "")}',
            section: 'skin_care',
            title: item.title,
            startMinute: startMin,
            endMinute: endMin,
            crossesMidnight: endMin < startMin,
            blockType: TimelineBlockDraft.hardBlockKey,
            repeatDays: [d + 1],
          ));
        }
      }

      ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
        final filteredBlocks = draft.baseTimeline.blocks.where((b) => b.section != 'skin_care').toList();
        return draft.copyWith(
          baseTimeline: draft.baseTimeline.copyWith(blocks: [...filteredBlocks, ...newBlocks]),
          clearFinalPreview: true,
        );
      });
      ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);

      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
"""

content = re.sub(
    r"Future<void> _save\(WidgetRef ref\) async \{.*?finally \{\n      if \(mounted\) setState\(\(\) => _isSaving = false\);\n    \}\n  \}",
    save_replacement,
    content,
    flags=re.DOTALL
)

# Overwrite initState
init_replacement = """
  @override
  void initState() {
    super.initState();
    weeklyRoutines = {};
    for (int i = 0; i < 7; i++) {
      weeklyRoutines[i] = [];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final baseTimeline = ref.read(mockOnboardingProvider).draft.baseTimeline;
      final savedItems = baseTimeline.blocks.where((b) => b.section == 'skin_care').toList();

      final next = <int, List<SkinCareRoutineBlock>>{
        for (int i = 0; i < 7; i++) i: <SkinCareRoutineBlock>[],
      };

      for (final item in savedItems) {
        for (final day in item.repeatDays) {
          final dayIndex = (day - 1).clamp(0, 6);
          final start = item.startMinute / 60.0 - 6.0;
          final duration = (item.endMinute - item.startMinute) / 60.0;
          next[dayIndex]!.add(
            SkinCareRoutineBlock(
              id: 'skin_${dayIndex}_${item.id}',
              title: item.title,
              start: start < 0 ? start + 24 : start,
              duration: duration <= 0 ? 1.0 : duration,
              icon: Icons.water_drop_rounded,
              color: Color(0xFF0EA5E9),
              hasTopTape: true,
              hasBottomTape: true,
            ),
          );
        }
      }

      for (int i = 0; i < 7; i++) {
        next[i]!.sort((a, b) => a.start.compareTo(b.start));
        next[i]!.add(SkinCareRoutineBlock(
          id: 'add_saved_$i',
          title: '',
          start: 7.0,
          isAdd: true,
        ));
      }

      setState(() => weeklyRoutines = next);
    });
  }
"""

content = re.sub(
    r"@override\n  void initState\(\) \{.*?setState\(\(\) => weeklyRoutines = next\);\n    \}\);\n  \}",
    init_replacement,
    content,
    flags=re.DOTALL
)
content = re.sub(r"@override\n  void initState\(\) \{.*?\n  \}\n\n  @override\n  void dispose\(\)", init_replacement + "\n\n  @override\n  void dispose()", content, flags=re.DOTALL)


# The `_save(ref)` calls in build -> `_save()`
content = content.replace("onPressed: () => _save(ref),", "onPressed: () => _save(),")
content = content.replace("void _showRoutineReviewDialog() {\n    _save(ref)", "void _showRoutineReviewDialog() {\n    _save()")
content = content.replace("_save().then((success)", "_save().then((_)")


with open('lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart', 'w') as f:
    f.write(content)

