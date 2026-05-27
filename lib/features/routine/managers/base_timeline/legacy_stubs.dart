import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventNames {
  static const String baseTimelineSet = 'base_timeline_set';
  static const String suggestionDismissed = 'suggestion_dismissed';
  static const String suggestionAccepted = 'suggestion_accepted';
  static const String routineTemplateCreated = 'routineTemplateCreated';
  static const String routineTemplateUpdated = 'routineTemplateUpdated';
  static const String routineTemplateDeleted = 'routineTemplateDeleted';
  static const String suggestionGenerated = 'suggestionGenerated';
}

class RoutineAnchor {
  static const String wakeUp = 'wakeUp';
  static const String sleep = 'sleep';
  RoutineAnchor({dynamic title, dynamic routineType, dynamic startTime, dynamic endTime, dynamic repeatRule});
  RoutineAnchor.fromMap(dynamic map);
}

class FixedScheduleTemplate {
  dynamic id;
  dynamic templateId;
  dynamic title;
  dynamic startTime;
  dynamic endTime;
  dynamic color;
  dynamic repeatRule;
  dynamic category;
  dynamic notes;
  bool reminderEnabled = false;
  bool isActive = true;
  int reminderOffsetMinutes = 0;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  FixedScheduleTemplate({
    this.id, 
    this.templateId, 
    this.title, 
    this.startTime, 
    this.endTime, 
    this.color, 
    this.repeatRule,
    this.category,
    this.notes,
    this.reminderEnabled = false,
    this.isActive = true,
    this.reminderOffsetMinutes = 0,
  });

  FixedScheduleTemplate copyWith({
    dynamic id,
    dynamic templateId,
    dynamic title,
    dynamic startTime,
    dynamic endTime,
    dynamic color,
    dynamic repeatRule,
    dynamic category,
    dynamic notes,
    bool? reminderEnabled,
    bool? isActive,
    int? reminderOffsetMinutes,
    dynamic createdAt,
    dynamic updatedAt,
  }) {
    return this;
  }

  factory FixedScheduleTemplate.fromMap(dynamic map) => FixedScheduleTemplate();
  Map<String, dynamic> toMap() => {};
}

class RoutineState {
  final Map<String, dynamic> templates = {};
  final List<FixedScheduleTemplate> fixedScheduleTemplates = [];
  final Map<String, dynamic> routineTemplates = {};
  bool hasLoadedRoutine = true;
  String? routineLoadError;
  List<dynamic> classesForDay(int day) => [];
  dynamic classes;
  List<dynamic> entries = [];
}

class SkinStep {
  final String? emoji;
  final String? name;
  final String? tag;
  SkinStep({this.emoji, this.name, this.tag});
}

class DaySkinPlan {
  final dynamic morning;
  final dynamic afternoon;
  final dynamic night;
  DaySkinPlan({this.morning, this.afternoon, this.night});
}

class ClassItem {
  dynamic id;
  dynamic subject;
  dynamic room;
  dynamic professor;
  dynamic startTime;
  dynamic endTime;
  dynamic colorHex;
  dynamic weekday;
  ClassItem({this.id, this.subject, this.room, this.professor, this.startTime, this.endTime, this.colorHex, this.weekday});
}

class MealItem {
  dynamic emoji;
  dynamic title;
  dynamic tag;
  dynamic name;
  dynamic time;
  MealItem({this.emoji, this.title, this.tag, this.name, this.time});
}

class DayMealPlan {
  dynamic morning;
  dynamic afternoon;
  dynamic night;
  dynamic meals;
  DayMealPlan({this.morning, this.afternoon, this.night, this.meals});
}

class RoutineTemplateModel {
  dynamic id;
  dynamic title;
  dynamic routineType;
  static RoutineTemplateModel fromMap(dynamic map) => RoutineTemplateModel();
  Map<String, dynamic> toMap() => {};
}

dynamic normalizeRoutineTimeOrNull(dynamic a, [dynamic b]) => null;
dynamic canonicalRelativeTimingRule(dynamic a) => null;
dynamic resolveRelativeTimingForTemplate({dynamic template, dynamic date, dynamic anchors}) => null;

Future<dynamic> runRoutineAcceptWithTimeout(dynamic action, {dynamic importMetadata}) async {
  if (action is Future Function()) {
    return await action();
  } else {
    return action();
  }
}

List<Map<String, dynamic>> fallbackSkinCareTemplatesFromText(String text) => [];
List<FixedScheduleTemplate> canonicalizeFixedScheduleTemplates(dynamic templates) => [];
Map<String, dynamic> normalizeFixedScheduleTemplateMap(Map<String, dynamic> map, {dynamic index, dynamic touchUpdatedAt}) => map;

String? validateFixedScheduleTemplateDraft({
  dynamic draft,
  dynamic title,
  dynamic startTime,
  dynamic endTime,
  dynamic existingTemplates,
  dynamic currentTemplateId,
  dynamic allowOverlap,
  dynamic extra1,
  dynamic extra2,
}) => null;

dynamic normalizeFixedScheduleRepeatRule(dynamic rule) => rule;

final routineProvider = StateNotifierProvider<DummyRoutineNotifier, RoutineState>((ref) => DummyRoutineNotifier());

class DummyRoutineNotifier extends StateNotifier<RoutineState> {
  DummyRoutineNotifier() : super(RoutineState());

  List<dynamic> classes = [];
  List<dynamic> eating = [];
  List<dynamic> fixedBlocks = [];
  List<dynamic> skinCare = [];
  void saveRoutineItem(dynamic item) {}
  void setRoutineTemplates([dynamic a, dynamic b, dynamic c, dynamic d, dynamic e]) {}
  void markSkinCareSetUp([dynamic a]) {}
  void setSkinCarePlan({dynamic morning, dynamic afternoon, dynamic night, dynamic dummyArg, dynamic meals}) {}
  void setClasses(dynamic classes, {dynamic importMetadata}) {}
  void setMealPlan([dynamic a, dynamic b, dynamic c]) {}
  void setFixedScheduleTemplates(dynamic templates) {}
}

final firestoreServiceProvider = Provider<dynamic>((ref) => _DummyService());
final routineRepositoryProvider = Provider<dynamic>((ref) => _DummyService());
final appFeatureFlagsProvider = Provider<dynamic>((ref) => _DummyService());
final eventServiceProvider = Provider<dynamic>((ref) => _DummyService());
final eatingDisorderFlagProvider = Provider<dynamic>((ref) => false);

class _DummyService {
  Future<void> saveUserRoutine(String uid, Map<String, dynamic> routineData) async {}
  Future<void> saveFixedScheduleTemplates(dynamic templates) async {}
  bool get suggestionGenerated => false;
}

class ImageUploadService {
  Future<dynamic> pickAndUploadImage({dynamic arg1, dynamic arg2, dynamic source, dynamic routineType}) async => null;
  Future<dynamic> analyzeTimetableImage(dynamic url) async => null;
  Future<dynamic> pickCompressAndUpload({dynamic arg1, dynamic arg2, dynamic arg3, dynamic source, dynamic routineType, String? folder}) async => null;
  Future<void> deleteUploadedMetadata(dynamic metadata) async {}
}

class RoutineAcceptTimeoutException implements Exception {}

class RoutineReviewScreen extends StatelessWidget {
  final dynamic importMetadata;
  final dynamic title;
  final dynamic routineType;
  final dynamic templates;
  final dynamic onRegenerate;
  final dynamic onAcceptAll;
  final dynamic fallbackRoutineType;
  
  const RoutineReviewScreen({
    super.key, 
    this.importMetadata,
    this.title,
    this.routineType,
    this.templates,
    this.onRegenerate,
    this.onAcceptAll,
    this.fallbackRoutineType,
  });

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Routine Review Screen")));
}
