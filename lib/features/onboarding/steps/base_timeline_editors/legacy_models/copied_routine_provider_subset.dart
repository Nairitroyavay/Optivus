// ignore_for_file: unused_field, unused_element, unused_local_variable, dead_code, dead_null_aware_expression
// REFERENCE COPY ONLY — not imported into app yet.
// This contains a clean subset of models and helper functions extracted from the 
// legacy routine_provider.dart so that reference timeline setup screens can parse
// their internal structures (like skincare steps, meals, fixed templates, and classes)
// without depending on the entire legacy state provider.

import 'routine_template_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GENERAL UTILS / HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _cleanRoutineString(Object? value) => value?.toString().trim() ?? '';

String _normalizeRoutineTime(Object? value, {required String fallback}) {
  final match =
      RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_cleanRoutineString(value));
  if (match == null) return fallback;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<int> _routineIntList(Object? value) {
  if (value is! List) return const [5, 10];
  final values = value
      .whereType<Object>()
      .map((item) {
        if (item is int) return item;
        if (item is num) return item.round();
        return int.tryParse(item.toString()) ?? 0;
      })
      .where((item) => item > 0)
      .toSet()
      .toList()
    ..sort();
  return values.isEmpty ? const [5] : values;
}

int _routineMinutesFromTime(String value) {
  final normalized = _normalizeRoutineTime(value, fallback: '00:00');
  final parts = normalized.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _routineTimeFromMinutes(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _routineTimeLabel(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
}

String _emojiForRoutineTitle(String title) {
  final key = title.toLowerCase();
  if (key.contains('sleep')) return '🛏️';
  if (key.contains('class') || key.contains('study')) return '🎓';
  if (key.contains('work')) return '💼';
  if (key.contains('gym') || key.contains('workout')) return '💪';
  if (key.contains('meal') || key.contains('dinner') || key.contains('food')) {
    return '🍽️';
  }
  return '📌';
}

// ─────────────────────────────────────────────────────────────────────────────
// SKIN CARE TIMELINE MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// One skin-care step
class SkinStep {
  final String emoji;
  final String name;
  final String tag;
  const SkinStep({required this.emoji, required this.name, required this.tag});

  Map<String, dynamic> toMap() => {'emoji': emoji, 'name': name, 'tag': tag};

  factory SkinStep.fromMap(Map<String, dynamic> m) => SkinStep(
        emoji: m['emoji'] ?? '',
        name: m['name'] ?? '',
        tag: m['tag'] ?? '',
      );
}

/// Skin care plan for one day: three time slots
class DaySkinPlan {
  final List<SkinStep> morning;
  final List<SkinStep> afternoon;
  final List<SkinStep> night;
  const DaySkinPlan({
    this.morning = const [],
    this.afternoon = const [],
    this.night = const [],
  });

  bool get isEmpty => morning.isEmpty && afternoon.isEmpty && night.isEmpty;

  DaySkinPlan copyWith({
    List<SkinStep>? morning,
    List<SkinStep>? afternoon,
    List<SkinStep>? night,
  }) =>
      DaySkinPlan(
        morning: morning ?? this.morning,
        afternoon: afternoon ?? this.afternoon,
        night: night ?? this.night,
      );

  Map<String, dynamic> toMap() => {
        'morning': morning.map((e) => e.toMap()).toList(),
        'afternoon': afternoon.map((e) => e.toMap()).toList(),
        'night': night.map((e) => e.toMap()).toList(),
      };

  factory DaySkinPlan.fromMap(Map<String, dynamic> m) => DaySkinPlan(
        morning: (m['morning'] as List? ?? [])
            .map((e) => SkinStep.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        afternoon: (m['afternoon'] as List? ?? [])
            .map((e) => SkinStep.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        night: (m['night'] as List? ?? [])
            .map((e) => SkinStep.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EATING / MEAL TIMELINE MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// One meal slot
class MealItem {
  final String emoji;
  final String name;
  final String time; // "08:00 AM"
  const MealItem({required this.emoji, required this.name, required this.time});

  Map<String, dynamic> toMap() => {'emoji': emoji, 'name': name, 'time': time};

  factory MealItem.fromMap(Map<String, dynamic> m) => MealItem(
        emoji: m['emoji'] ?? '',
        name: m['name'] ?? '',
        time: m['time'] ?? '',
      );
}

/// Eating plan for one day
class DayMealPlan {
  final List<MealItem> meals;
  const DayMealPlan({this.meals = const []});

  bool get isEmpty => meals.isEmpty;

  List<MealItem> get all => meals;

  DayMealPlan copyWith({
    List<MealItem>? meals,
  }) =>
      DayMealPlan(
        meals: meals ?? this.meals,
      );

  Map<String, dynamic> toMap() => {
        'meals': meals.map((e) => e.toMap()).toList(),
      };

  factory DayMealPlan.fromMap(Map<String, dynamic> m) => DayMealPlan(
        meals: (m['meals'] as List? ?? [])
            .map((e) => MealItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMETABLE / CLASSES MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// One class in the weekly timetable
class ClassItem {
  final String subject;
  final String room;
  final String professor;
  final String startTime; // "09:00"
  final String endTime; // "10:00"
  final int weekday; // 1=Mon … 7=Sun
  final String colorHex;
  const ClassItem({
    required this.subject,
    required this.room,
    required this.professor,
    required this.startTime,
    required this.endTime,
    required this.weekday,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'room': room,
        'professor': professor,
        'startTime': startTime,
        'endTime': endTime,
        'weekday': weekday,
        'colorHex': colorHex,
      };

  factory ClassItem.fromMap(Map<String, dynamic> m) => ClassItem(
        subject: m['subject'] ?? '',
        room: m['room'] ?? '',
        professor: m['professor'] ?? '',
        startTime: m['startTime'] ?? '',
        endTime: m['endTime'] ?? '',
        weekday: m['weekday'] ?? 1,
        colorHex: m['colorHex'] ?? '#FFFFFF',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// FIXED TIMELINE MODELS
// ─────────────────────────────────────────────────────────────────────────────

const _fixedScheduleKnownKeys = {
  'templateId',
  'title',
  'routineType',
  'startTime',
  'endTime',
  'repeatRule',
  'category',
  'notes',
  'reminderEnabled',
  'reminderOffsetMinutes',
  'isActive',
  'createdAt',
  'updatedAt',
};

const _fixedBlockKnownKeys = {
  'id',
  'title',
  'emoji',
  'startMinute',
  'endMinute',
  'colorHex',
  'repeatRule',
  'category',
  'notes',
  'reminderEnabled',
  'reminderOffsetMinutes',
  'createdAt',
  'updatedAt',
};

bool _fixedTemplateIsActive(Map<String, dynamic> map) {
  if (map['isActive'] is bool) return map['isActive'] as bool;
  final lifecycle =
      _cleanRoutineString(map['state'] ?? map['status']).toLowerCase();
  return lifecycle != 'inactive' &&
      lifecycle != 'archived' &&
      lifecycle != 'deleted';
}

Map<String, dynamic> _fixedTemplateExtra(Map<String, dynamic> map) => {
      for (final entry in map.entries)
        if (!_fixedScheduleKnownKeys.contains(entry.key))
          entry.key.toString(): entry.value,
    };

Map<String, dynamic> _fixedBlockExtra(Map<String, dynamic> map) => {
      for (final entry in map.entries)
        if (!_fixedBlockKnownKeys.contains(entry.key))
          entry.key.toString(): entry.value,
    };

String _fixedTemplateId(Map<String, dynamic> map) {
  final explicit = _cleanRoutineString(map['templateId'] ?? map['id']);
  if (explicit.isNotEmpty) return explicit;
  return RoutineTemplateModel.forSave(
    map,
    fallbackRoutineType: 'fixed_schedule',
  ).templateId;
}

/// A fixed block template on the 24-hour schedule (from onboarding "Set Your Fixed Schedule")
class FixedScheduleTemplate {
  final String templateId;
  final String title;
  final String routineType;
  final String startTime; // "HH:mm" in 24h format
  final String endTime; // "HH:mm" in 24h format
  final String repeatRule;
  final String category;
  final String notes;
  final bool reminderEnabled;
  final int reminderOffsetMinutes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> extra;

  const FixedScheduleTemplate({
    required this.templateId,
    required this.title,
    this.routineType = 'fixed_schedule',
    required this.startTime,
    required this.endTime,
    this.repeatRule = 'daily',
    this.category = '',
    this.notes = '',
    this.reminderEnabled = false,
    this.reminderOffsetMinutes = 5,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.extra = const {},
  });

  FixedScheduleTemplate copyWith({
    String? title,
    String? startTime,
    String? endTime,
    String? category,
    String? notes,
    String? repeatRule,
    bool? reminderEnabled,
    int? reminderOffsetMinutes,
    bool? isActive,
    String? updatedAt,
    Map<String, dynamic>? extra,
  }) =>
      FixedScheduleTemplate(
        templateId: templateId,
        title: title ?? this.title,
        routineType: routineType,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        repeatRule: repeatRule ?? this.repeatRule,
        category: category ?? this.category,
        notes: notes ?? this.notes,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderOffsetMinutes:
            reminderOffsetMinutes ?? this.reminderOffsetMinutes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toMap() => {
        ...extra,
        'templateId': templateId,
        'title': title,
        'routineType': routineType,
        'startTime': startTime,
        'endTime': endTime,
        'repeatRule': repeatRule,
        'category': category,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FixedScheduleTemplate.fromMap(Map<String, dynamic> m) =>
      FixedScheduleTemplate(
        templateId: _fixedTemplateId(m),
        title: _cleanRoutineString(m['title'] ?? m['name']),
        routineType: 'fixed_schedule',
        startTime: _normalizeRoutineTime(
          m['startTime'] ?? m['time'],
          fallback: '09:00',
        ),
        endTime: _normalizeRoutineTime(m['endTime'], fallback: '10:00'),
        repeatRule:
            _cleanRoutineString(m['repeatRule'] ?? m['weekdayRule']).isNotEmpty
                ? _cleanRoutineString(m['repeatRule'] ?? m['weekdayRule'])
                : 'daily',
        category: _cleanRoutineString(m['category']),
        notes: _cleanRoutineString(m['notes']),
        reminderEnabled: m['reminderEnabled'] == true,
        reminderOffsetMinutes:
            ((m['reminderOffsetMinutes'] as num?)?.toInt() ?? 5).clamp(0, 180),
        isActive: _fixedTemplateIsActive(m),
        createdAt: _cleanRoutineString(m['createdAt']).isNotEmpty
            ? _cleanRoutineString(m['createdAt'])
            : DateTime.now().toIso8601String(),
        updatedAt: _cleanRoutineString(m['updatedAt']).isNotEmpty
            ? _cleanRoutineString(m['updatedAt'])
            : DateTime.now().toIso8601String(),
        extra: _fixedTemplateExtra(m),
      );
}

/// Legacy UI adapter for screens that still edit/display minute-based blocks.
class FixedBlock {
  final String id;
  final String title;
  final String emoji;
  final int startMinute;
  final int endMinute;
  final String colorHex;
  final String repeatRule;
  final String category;
  final String notes;
  final bool reminderEnabled;
  final int reminderOffsetMinutes;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> extra;

  const FixedBlock({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startMinute,
    required this.endMinute,
    required this.colorHex,
    this.repeatRule = 'daily',
    this.category = '',
    this.notes = '',
    this.reminderEnabled = false,
    this.reminderOffsetMinutes = 5,
    this.createdAt = '',
    this.updatedAt = '',
    this.extra = const {},
  });

  String get startLabel => _routineTimeLabel(startMinute);
  String get endLabel => _routineTimeLabel(endMinute);

  Map<String, dynamic> toMap() => {
        ...extra,
        'id': id,
        'title': title,
        'emoji': emoji,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'colorHex': colorHex,
        'repeatRule': repeatRule,
        'category': category,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  FixedScheduleTemplate toTemplate() {
    final now = DateTime.now().toIso8601String();
    return FixedScheduleTemplate(
      templateId: id,
      title: title,
      startTime: _routineTimeFromMinutes(startMinute),
      endTime: _routineTimeFromMinutes(endMinute),
      repeatRule: repeatRule,
      category: category,
      notes: notes,
      reminderEnabled: reminderEnabled,
      reminderOffsetMinutes: reminderOffsetMinutes,
      isActive: true,
      createdAt: createdAt.isNotEmpty ? createdAt : now,
      updatedAt: updatedAt.isNotEmpty ? updatedAt : now,
      extra: extra,
    );
  }

  factory FixedBlock.fromTemplate(FixedScheduleTemplate template) => FixedBlock(
        id: template.templateId,
        title: template.title,
        emoji: _emojiForRoutineTitle(template.title),
        startMinute: _routineMinutesFromTime(template.startTime),
        endMinute: _routineMinutesFromTime(template.endTime),
        colorHex: '#CBD5E1',
        repeatRule: template.repeatRule,
        category: template.category,
        notes: template.notes,
        reminderEnabled: template.reminderEnabled,
        reminderOffsetMinutes: template.reminderOffsetMinutes,
        createdAt: template.createdAt,
        updatedAt: template.updatedAt,
        extra: template.extra,
      );

  factory FixedBlock.fromMap(Map<String, dynamic> m) => FixedBlock(
        id: _cleanRoutineString(m['id']),
        title: _cleanRoutineString(m['title']),
        emoji: _cleanRoutineString(m['emoji']).isNotEmpty
            ? _cleanRoutineString(m['emoji'])
            : _emojiForRoutineTitle(_cleanRoutineString(m['title'])),
        startMinute: ((m['startMinute'] as num?)?.toInt() ?? 0).clamp(0, 1439),
        endMinute: ((m['endMinute'] as num?)?.toInt() ?? 0).clamp(0, 1439),
        colorHex: _cleanRoutineString(m['colorHex']).isNotEmpty
            ? _cleanRoutineString(m['colorHex'])
            : '#CBD5E1',
        repeatRule: _cleanRoutineString(m['repeatRule']).isNotEmpty
            ? _cleanRoutineString(m['repeatRule'])
            : 'daily',
        category: _cleanRoutineString(m['category']),
        notes: _cleanRoutineString(m['notes']),
        reminderEnabled: m['reminderEnabled'] == true,
        reminderOffsetMinutes:
            ((m['reminderOffsetMinutes'] as num?)?.toInt() ?? 5).clamp(0, 180),
        createdAt: _cleanRoutineString(m['createdAt']),
        updatedAt: _cleanRoutineString(m['updatedAt']),
        extra: _fixedBlockExtra(m),
      );
}
