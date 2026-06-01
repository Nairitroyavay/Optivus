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
  bool get routineImportWorkerReady => false;
}
final eventServiceProvider = Provider((ref) => DummyEvent());
class DummyEvent { Future<void> emit({dynamic eventName, dynamic source, dynamic payload}) async {} }
final firestoreServiceProvider = Provider((ref) => DummyFirestore());
class DummyFirestore { Future<void> saveSuggestion(dynamic x, dynamic y) async {} }
final routineRepositoryProvider = Provider((ref) => DummyRepo());
class DummyRepo { Future<void> previewRoutineImport({dynamic routineType, dynamic mode, dynamic sourceText, dynamic imageMetadata}) async {} Future<void> saveFixedScheduleTemplates(dynamic x) async {} }
final routineProvider = Provider((ref) => DummyRoutine());
class DummyRoutine {
  final classes = const [];
  final meals = const [];
  final fixedScheduleTemplates = const [];
  final skinSteps = const [];
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
  Future<dynamic> deleteUploadedMetadata() async { return null; }
  Future<dynamic> pickCompressAndUpload() async { return null; }
}
Future<void> runRoutineAcceptWithTimeout(dynamic fn) async { await fn(); }
class RoutineAcceptTimeoutException implements Exception {}
// ------------------------------
"""

def prepare_file(src, dst):
    os.system(f"cp {src} {dst}")
    os.system(f"sed -i '' 's/package:optivus2\\//package:optivus\\//g' {dst}")
    
    with open(dst, 'r') as f:
        content = f.read()

    # Remove legacy imports
    content = re.sub(r"import 'package:image_picker/image_picker.dart';", "", content)
    content = re.sub(r"import 'package:optivus/core/constants/event_names.dart';", "", content)
    content = re.sub(r"import 'package:optivus/core/providers.dart';", "", content)
    content = re.sub(r"import 'package:optivus/providers/routine_provider.dart';", "", content)
    content = re.sub(r"import 'package:optivus/services/image_upload_service.dart';", "", content)
    content = re.sub(r"import 'package:optivus/services/routine_acceptance_guard.dart';", "", content)
    
    # Prepend dummy defs
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

