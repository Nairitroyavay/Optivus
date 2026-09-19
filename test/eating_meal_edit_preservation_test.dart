import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_meal_edit_sheet.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  testWidgets('meal title edit preserves hidden generated meal metadata', (
    tester,
  ) async {
    const original = TimelineBlockDraft(
      id: 'generated-meal-1',
      section: 'eating',
      title: 'Breakfast',
      startMinute: 480,
      endMinute: 510,
      repeatDays: [1, 3, 5],
      location: 'Home',
      blockType: TimelineBlockDraft.softBlockKey,
      source: 'ai_generated_meal_setup',
      mealCategory: 'breakfast',
      mealSlot: 'breakfast',
      dishes: ['Oats', 'Berries'],
      calories: 520,
      protein: 28,
      provenanceSourceIds: ['generation-1'],
      notes: 'Prep overnight',
    );
    TimelineBlockDraft? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => EatingMealEditSheet.show(
                context: context,
                block: original,
                isNew: false,
                onSave: (updated) async {
                  saved = updated;
                  return true;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('timeline-edit-meal-title-field')),
      'Updated breakfast',
    );
    await tester.ensureVisible(find.text('Apply changes'));
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, 'Updated breakfast');
    expect(saved!.id, original.id);
    expect(saved!.section, original.section);
    expect(saved!.blockType, original.blockType);
    expect(saved!.source, original.source);
    expect(saved!.mealSlot, original.mealSlot);
    expect(saved!.mealCategory, original.mealCategory);
    expect(saved!.repeatDays, original.repeatDays);
    expect(saved!.dishes, original.dishes);
    expect(saved!.startMinute, original.startMinute);
    expect(saved!.endMinute, original.endMinute);
    expect(saved!.provenanceSourceIds, original.provenanceSourceIds);
  });
}
