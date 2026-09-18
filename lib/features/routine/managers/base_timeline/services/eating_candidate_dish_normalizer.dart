import 'package:optivus/models/routine_import_review.dart';

/// Pure candidate dish normalizer used across Base Timeline and Onboarding.
///
/// Normalizes and filters candidate text into clean dish names.
/// Preserves legitimate dishes (e.g. 'Dal Tadka', 'Chicken 65', 'PB&J',
/// 'Greek Yogurt', 'Aloo Posto', 'Paneer Butter Masala') while filtering out
/// metadata noise (e.g. 'Monday', 'Breakfast', 'Part 1', '8:00 AM', 'Meal').
class EatingCandidateDishNormalizer {
  const EatingCandidateDishNormalizer._();

  static const Set<String> _genericMealTokens = {
    'breakfast',
    'lunch',
    'brunch',
    'supper',
    'snack',
    'snacks',
    'dinner',
    'extra snack',
    'extra-snack',
    'meal',
    'meals',
    'menu',
    'mess menu',
    'mess item',
    'food',
    'item',
    'items',
    'routine',
  };

  static const Set<String> _dayTokens = {
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
    'mon',
    'tue',
    'tues',
    'wed',
    'thu',
    'thur',
    'thurs',
    'fri',
    'sat',
    'sun',
    'weekday',
    'weekdays',
    'weekend',
    'weekends',
    'daily',
  };

  static bool looksLikeNonDishMealToken(String value) {
    final lower = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s/-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (lower.isEmpty || !RegExp(r'[a-z]').hasMatch(lower)) return true;

    // Reject "Part 1", "Part 2", etc.
    if (RegExp(r'\bpart\s*\d+\b', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // Reject time tokens (e.g. "8:00 AM", "12 PM")
    if (RegExp(
      r'^\d{1,2}([:.]\d{2})?\s*(am|pm)?$',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    // Reject calorie/macro tokens (e.g. "500 kcal", "25g protein", "high protein")
    if (RegExp(
          r'^\d+\s*(kcal|cal|calories|g|gm|grams?)\b',
          caseSensitive: false,
        ).hasMatch(lower) ||
        RegExp(
          r'^(high|low|zero)\s*(protein|carb|carbs|fat|calorie|calories)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
      return true;
    }

    // Reject "Meal 1", "Meal 2", "Option 1", etc.
    if (RegExp(
      r'\b(meal|option|dish)\s*\d+\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    if (_genericMealTokens.contains(lower)) return true;
    if (_dayTokens.contains(lower)) return true;

    return false;
  }

  static bool candidateTitleCanBeDishHint(String title) {
    final value = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.length < 2) return false;
    if (looksLikeNonDishMealToken(value)) return false;

    final withoutMealWords = value
        .replaceAll(
          RegExp(
            r'\b(Breakfast|Lunch|Brunch|Supper|Snacks?|Dinner|Meal)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (withoutMealWords.isEmpty) return false;
    return !looksLikeNonDishMealToken(withoutMealWords);
  }

  /// Extracts clean dishes from a candidate block.
  static List<String> extractDishes(RoutineImportCandidateBlock candidate) {
    final dishes = <String>{};

    void addDish(String text) {
      final dish = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (dish.length < 2 || looksLikeNonDishMealToken(dish)) return;
      dishes.add(dish);
    }

    for (final step in candidate.steps) {
      addDish(step);
    }

    void extractFromRawText(String? text, {bool stripMealWords = true}) {
      if (text == null || text.trim().isEmpty) return;
      final cleaned = text
          .replaceAll(RegExp(r'[–—]'), '-')
          .replaceAll(
            stripMealWords
                ? RegExp(
                    r'\b(Breakfast|Lunch|Brunch|Supper|Snacks?|Dinner)\b',
                    caseSensitive: false,
                  )
                : RegExp(r'(?!)'),
            ' ',
          )
          .replaceAll(
            RegExp(
              r'\b(Mon|Tue|Tues|Wed|Thu|Thur|Fri|Sat|Sun)(day)?\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(
            RegExp(r'\d{1,2}[:.]\d{2}\s*(AM|PM)?', caseSensitive: false),
            ' ',
          )
          .replaceAll(RegExp(r'\d{1,2}\s*(AM|PM)', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+-\s+'), ' ');

      final items = cleaned
          .split(RegExp(r'[,;\n|•·]+'))
          .map((item) => item.trim())
          .where((item) => item.length >= 2);

      for (final item in items) {
        addDish(item);
      }
    }

    extractFromRawText(candidate.sourceTextSnippet);
    extractFromRawText(candidate.notes);
    extractFromRawText(candidate.sourceColumnLabel);
    if (candidateTitleCanBeDishHint(candidate.title)) {
      extractFromRawText(candidate.title, stripMealWords: false);
    }

    return dishes.toList(growable: false);
  }
}
