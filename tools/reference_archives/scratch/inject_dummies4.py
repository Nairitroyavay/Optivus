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
  Future<dynamic> previewRoutineImport({dynamic routineType, dynamic mode, dynamic sourceText, dynamic imageMetadata}) async { return null; } 
  Future<void> saveFixedScheduleTemplates(dynamic x) async {} 
}
final routineProvider = StateProvider<RoutineState>((ref) => RoutineState());

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
  Future<dynamic> deleteUploadedMetadata() async { return null; }
  Future<dynamic> pickCompressAndUpload() async { return null; }
}
Future<void> runRoutineAcceptWithTimeout(dynamic fn) async { await fn(); }
class RoutineAcceptTimeoutException implements Exception {}
List<dynamic> fallbackSkinCareTemplatesFromText(String t) => [];
dynamic normalizeRoutineTimeOrNull(dynamic x, {dynamic isEndOfDay}) => null;
dynamic canonicalRelativeTimingRule(dynamic x, {dynamic isEndOfDay}) => null;
dynamic resolveRelativeTimingForTemplate({dynamic template, dynamic date, dynamic anchors}) => null;
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
    
    # Prepend dummy defs after the first import or package import
    content = re.sub(r"(import 'package:optivus/core/liquid_ui/liquid_ui.dart';)", r"\1\n" + DUMMY_DEFS, content, count=1)
    
    with open(dst, 'w') as f:
        f.write(content)


prepare_file(
    'reference_copied_old_frontend/onboarding_base_timeline/classes/class_setup_screen.dart', 
    'lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart'
)
prepare_file(
    'reference_copied_old_frontend/onboarding_base_timeline/eating/eating_setup_screen.dart', 
    'lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart'
)
prepare_file(
    'reference_copied_old_frontend/onboarding_base_timeline/skin_care/skin_care_setup_screen.dart', 
    'lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart'
)
prepare_file(
    'reference_copied_old_frontend/onboarding_base_timeline/fixed/fixed_schedule_setup_screen.dart', 
    'lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart'
)

