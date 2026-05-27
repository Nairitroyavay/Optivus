import re
import os
import glob

# Ensure mock_dependencies.dart has everything needed perfectly
MOCK_DEPS = """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_editors/legacy_models/copied_routine_provider_subset.dart';

final appFeatureFlagsProvider = Provider((ref) => DummyFlags());
class DummyFlags {
  bool get classTimetableImageImportReady => false;
  bool get textParseImportReady => false;
  bool get eatingMenuImageImportReady => false;
  bool get skincareImageImportReady => false;
  bool get routineImportWorkerReady => false;
  bool get skinProductImageImportReady => false;
  bool get hostelMessImageImportReady => false;
}

final eatingDisorderFlagProvider = Provider((ref) => false);

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
  static const routineTemplateCreated = 0;
  static const routineTemplateUpdated = 0;
  static const routineTemplateDeleted = 0;
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
dynamic normalizeFixedScheduleRepeatRule(dynamic rule) => rule;
dynamic normalizeFixedScheduleTemplateMap(dynamic map) => map;
dynamic canonicalizeFixedScheduleTemplates(dynamic t) => t;
dynamic validateFixedScheduleTemplateDraft(dynamic t, {dynamic title, dynamic startTime, dynamic endTime, dynamic existingTemplates, dynamic currentTemplateId, dynamic allowOverlap}) => null;

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
  void setFixedScheduleTemplates(dynamic t) {}
  Future<void> setRoutineTemplates(String type, List<Map<String, dynamic>> t, {dynamic importMetadata}) async {}
}
class FixedScheduleTemplate {
  String id;
  String title;
  String startTime;
  String endTime;
  String repeatRule;
  String get templateId => id;
  DateTime get createdAt => DateTime.now();
  DateTime get updatedAt => DateTime.now();
  bool get isActive => true;
  int get reminderOffsetMinutes => 0;
  String get category => '';
  String get notes => '';
  bool get reminderEnabled => false;
  FixedScheduleTemplate({required this.id, required this.title, required this.startTime, required this.endTime, required this.repeatRule});
  factory FixedScheduleTemplate.fromMap(Map<String, dynamic> m) => FixedScheduleTemplate(id: '', title: '', startTime: '', endTime: '', repeatRule: '');
  Map<String, dynamic> toMap() => {};
  FixedScheduleTemplate copyWith({String? id, String? title, String? startTime, String? endTime, String? repeatRule, String? notes, bool? reminderEnabled, String? status, DateTime? updatedAt, int? index, bool? touchUpdatedAt}) => FixedScheduleTemplate(id: id ?? this.id, title: title ?? this.title, startTime: startTime ?? this.startTime, endTime: endTime ?? this.endTime, repeatRule: repeatRule ?? this.repeatRule);
}
"""

with open('lib/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart', 'w') as f:
    f.write(MOCK_DEPS)

# Now, strip inline DUMMY_DEFS from all 5 files, and insert the import at the top
files = glob.glob('lib/features/onboarding/steps/base_timeline_editors/*.dart')
for filepath in files:
    if filepath.endswith('mock_dependencies.dart'): continue
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Strip old DUMMY_DEFS block if present
    content = re.sub(r"// --- DUMMY DEFS FOR PORTING ---.*?// ------------------------------", "", content, flags=re.DOTALL)
    
    # Prepend import
    header = "import 'package:optivus/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart';\n"
    if 'mock_dependencies.dart' not in content:
        content = header + content
        
    # Ensure fixed_timeline_editor imports fixed_schedule_editor
    if filepath.endswith('fixed_timeline_editor.dart'):
        if 'fixed_schedule_editor.dart' not in content:
            content = "import 'package:optivus/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart';\n" + content
            
    # Fix validateFixedScheduleTemplateDraft call missing positional arg in fixed_schedule_editor
    if filepath.endswith('fixed_schedule_editor.dart'):
        content = content.replace("validateFixedScheduleTemplateDraft(", "validateFixedScheduleTemplateDraft(null, ")
        content = content.replace("validateFixedScheduleTemplateDraft(null, t)", "validateFixedScheduleTemplateDraft(t)")

    with open(filepath, 'w') as f:
        f.write(content)

