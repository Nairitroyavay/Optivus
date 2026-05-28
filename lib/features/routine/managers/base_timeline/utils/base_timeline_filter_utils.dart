import 'package:optivus/models/routine_item.dart';

class BaseTimelineFilterUtils {
  BaseTimelineFilterUtils._();

  static List<RoutineItem> getItemsByCategory(List<RoutineItem> items, RoutineCategory category) {
    return items.where((item) => item.category == category).toList();
  }

  static List<RoutineItem> getClasses(List<RoutineItem> items) =>
      getItemsByCategory(items, RoutineCategory.classBlock);

  static List<RoutineItem> getWorkItems(List<RoutineItem> items) =>
      getItemsByCategory(items, RoutineCategory.job);

  static List<RoutineItem> getEatingItems(List<RoutineItem> items) =>
      getItemsByCategory(items, RoutineCategory.eating);

  static List<RoutineItem> getFixedItems(List<RoutineItem> items) =>
      items.where((i) => i.category == RoutineCategory.fixed || i.category == RoutineCategory.sleep).toList();

  static List<RoutineItem> getSkinCareItems(List<RoutineItem> items) =>
      getItemsByCategory(items, RoutineCategory.skinCare);
}
