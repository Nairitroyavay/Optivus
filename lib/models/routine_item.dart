enum RoutineBlockType {
  hardBlock, // Non-negotiable: Class, Shift work, Travel, sleep
  softBlock, // Movable/soft: Eating, Skincare, Family task, walk
  flexibleTask, // Movable habits: Reading, Language, Study
  trackerTask, // Timed tracker items: Workout, Meditation, Focus session
  checkIn, // Manual loggers: Smoking check, alcohol avoid, Hydration logs
  moneyTask // UPI target save ₹10 task
}

class RoutineItem {
  final String id;
  final String title;
  final int startMinute; // Minutes since midnight
  final int endMinute; // Minutes since midnight
  final List<int> repeatDays; // 1 = Monday, 7 = Sunday
  final String? location;
  final RoutineBlockType blockType;
  final String? notes;
  
  // Custom metadata based on types
  final List<String>? subtasks;
  final List<bool>? subtasksCompleted;
  
  // Eating Meal specific lists
  final String? mealCategory; // Breakfast, Lunch, Snacks, Dinner
  final List<String>? dishes;
  final double? calories;
  final double? protein;

  // Skincare specific details
  final List<String>? skincareProducts;
  
  // Status attributes
  final bool isCompleted;
  final bool isMissed;
  final bool hasConflict;
  final String? conflictMessage;

  RoutineItem({
    required this.id,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    required this.blockType,
    List<int>? repeatDays,
    this.location,
    this.notes,
    this.subtasks,
    this.subtasksCompleted,
    this.mealCategory,
    this.dishes,
    this.calories,
    this.protein,
    this.skincareProducts,
    this.isCompleted = false,
    this.isMissed = false,
    this.hasConflict = false,
    this.conflictMessage,
  }) : repeatDays = repeatDays ?? const [1, 2, 3, 4, 5, 6, 7];

  int get durationMinutes => endMinute - startMinute;

  RoutineItem copyWith({
    String? id,
    String? title,
    int? startMinute,
    int? endMinute,
    List<int>? repeatDays,
    String? location,
    RoutineBlockType? blockType,
    String? notes,
    List<String>? subtasks,
    List<bool>? subtasksCompleted,
    String? mealCategory,
    List<String>? dishes,
    double? calories,
    double? protein,
    List<String>? skincareProducts,
    bool? isCompleted,
    bool? isMissed,
    bool? hasConflict,
    String? conflictMessage,
    bool clearConflict = false,
  }) {
    return RoutineItem(
      id: id ?? this.id,
      title: title ?? this.title,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      repeatDays: repeatDays ?? this.repeatDays,
      location: location ?? this.location,
      blockType: blockType ?? this.blockType,
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      subtasksCompleted: subtasksCompleted ?? this.subtasksCompleted,
      mealCategory: mealCategory ?? this.mealCategory,
      dishes: dishes ?? this.dishes,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      skincareProducts: skincareProducts ?? this.skincareProducts,
      isCompleted: isCompleted ?? this.isCompleted,
      isMissed: isMissed ?? this.isMissed,
      hasConflict: clearConflict ? false : (hasConflict ?? this.hasConflict),
      conflictMessage: clearConflict ? null : (conflictMessage ?? this.conflictMessage),
    );
  }
}
