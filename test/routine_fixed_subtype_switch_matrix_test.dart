import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/models/add_routine_draft.dart';
import 'package:optivus/features/routine/services/add_routine_mapper.dart';
import 'package:optivus/models/routine_item.dart';

void main() {
  group('Gate D: Fixed Subtype Switch Matrix (4x4 + Sleep/Travel/Bath/Other)', () {
    test(
      'Class -> Work -> Eating -> Skin Care -> Class complete zero-leakage cycle',
      () {
        // Start with Class
        var fixed = const AddRoutineFixedState(
          kind: 'Class',
          hardBlock: true,
          professor: 'Dr. Smith',
          courseCode: 'CS101',
          classType: 'Lecture',
          sectionLabel: 'Section A',
          classLocation: 'Hall B',
        );

        expect(fixed.classDetails.professor, 'Dr. Smith');
        expect(fixed.classDetails.courseCode, 'CS101');
        expect(fixed.classDetails.classType, 'Lecture');
        expect(fixed.classDetails.sectionLabel, 'Section A');
        expect(fixed.classDetails.location, 'Hall B');

        // 1. Switch to Work
        fixed = fixed.copyWith(
          kind: 'Work',
          workContextType: 'Full-time',
          workRole: 'Software Engineer',
          workOrganization: 'Acme Corp',
          workDepartmentOrProject: 'Infra',
          workMode: 'Remote',
          workBlockKind: 'Coding',
          workLocation: 'Home Office',
        );

        // Class fields MUST be cleared
        expect(fixed.professor, isNull);
        expect(fixed.courseCode, isNull);
        expect(fixed.classType, isNull);
        expect(fixed.sectionLabel, isNull);
        expect(fixed.classLocation, isNull);

        // Work fields populated
        expect(fixed.workRole, 'Software Engineer');
        expect(fixed.workOrganization, 'Acme Corp');
        expect(fixed.workLocation, 'Home Office');

        // 2. Switch to Eating
        fixed = fixed.copyWith(
          kind: 'Eating',
          mealCategory: 'Lunch',
          mealSlot: 'midday',
          dishes: ['Salad', 'Grilled Chicken'],
          caloriesEstimate: 650.0,
          proteinEstimate: 45.0,
        );

        // Work fields MUST be cleared
        expect(fixed.workRole, isNull);
        expect(fixed.workOrganization, isNull);
        expect(fixed.workLocation, isNull);

        // Eating fields populated
        expect(fixed.mealCategory, 'Lunch');
        expect(fixed.mealSlot, 'midday');
        expect(fixed.dishes, ['Salad', 'Grilled Chicken']);
        expect(fixed.caloriesEstimate, 650.0);
        expect(fixed.proteinEstimate, 45.0);

        // 3. Switch to Skin Care
        fixed = fixed.copyWith(
          kind: 'Skin Care',
          skincareSlotLabel: 'Evening Routine',
          steps: ['Cleanser', 'Moisturizer', 'Sunscreen'],
          skincareProducts: ['CeraVe Hydrating Cleanser'],
          skincareMissingItems: ['Retinol'],
        );

        // Eating fields MUST be cleared
        expect(fixed.mealCategory, isNull);
        expect(fixed.dishes, isEmpty);
        expect(fixed.caloriesEstimate, isNull);
        expect(fixed.proteinEstimate, isNull);

        // Skin Care fields populated
        expect(fixed.skincareSlotLabel, 'Evening Routine');
        expect(fixed.steps, ['Cleanser', 'Moisturizer', 'Sunscreen']);
        expect(fixed.skincareProducts, ['CeraVe Hydrating Cleanser']);

        // 4. Switch back to Class
        fixed = fixed.copyWith(
          kind: 'Class',
          professor: 'Dr. Jones',
          courseCode: 'MATH201',
        );

        // Skin Care fields MUST be cleared
        expect(fixed.skincareSlotLabel, isNull);
        expect(fixed.steps, isEmpty);
        expect(fixed.skincareProducts, isEmpty);

        // Class fields populated
        expect(fixed.professor, 'Dr. Jones');
        expect(fixed.courseCode, 'MATH201');
      },
    );

    test('All 4x4 pairwise transitions guarantee zero cross-leakage', () {
      final kinds = ['Class', 'Work', 'Eating', 'Skin Care'];

      for (final fromKind in kinds) {
        for (final toKind in kinds) {
          if (fromKind == toKind) continue;

          // Populate fromKind
          var state = const AddRoutineFixedState().copyWith(
            kind: fromKind,
            professor: fromKind == 'Class' ? 'Prof' : null,
            workRole: fromKind == 'Work' ? 'Role' : null,
            mealCategory: fromKind == 'Eating' ? 'Dinner' : null,
            skincareSlotLabel: fromKind == 'Skin Care' ? 'Night' : null,
          );

          // Transition to toKind
          state = state.copyWith(kind: toKind);

          if (toKind != 'Class') expect(state.professor, isNull);
          if (toKind != 'Work') expect(state.workRole, isNull);
          if (toKind != 'Eating') expect(state.mealCategory, isNull);
          if (toKind != 'Skin Care') expect(state.skincareSlotLabel, isNull);
        }
      }
    });

    test(
      'Transitions to and from Sleep, Travel, Bath, Other clear all specific subtype state',
      () {
        const nonSubtypeKinds = ['Sleep', 'Travel', 'Bath', 'Other'];

        for (final nonSubtype in nonSubtypeKinds) {
          // Start from a fully loaded Class
          var state = const AddRoutineFixedState(
            kind: 'Class',
            professor: 'Dr. Smith',
            courseCode: 'CS101',
            classType: 'Lecture',
            sectionLabel: 'A',
            classLocation: 'Room 1',
          );

          // Switch to non-subtype
          state = state.copyWith(kind: nonSubtype);
          expect(state.kind, nonSubtype);
          expect(state.professor, isNull);
          expect(state.courseCode, isNull);
          expect(state.classType, isNull);
          expect(state.sectionLabel, isNull);
          expect(state.classLocation, isNull);
          expect(state.workRole, isNull);
          expect(state.mealCategory, isNull);
          expect(state.skincareSlotLabel, isNull);

          // Map to routine item
          final draft = AddRoutineDraft.initial(
            id: 'item-$nonSubtype',
            initialType: AddRoutineType.fixed,
          ).copyWith(title: '$nonSubtype block', fixedState: state);
          final item = AddRoutineMapper.toRoutineItem(draft);
          expect(item.blockType, RoutineBlockType.hardBlock);
          expect(
            item.category,
            AddRoutineMapper.categoryForFixedKind(nonSubtype),
          );
          expect(item.professor, isNull);
          expect(item.courseCode, isNull);
          expect(item.workRole, isNull);
          expect(item.dishes, isNull);
          expect(item.steps, isNull);
        }
      },
    );

    test(
      'AddRoutineMapper correctly translates subtype fields to RoutineItem',
      () {
        // Test Eating translation
        final eatingDraft =
            AddRoutineDraft.initial(
              id: 'eat-1',
              initialType: AddRoutineType.fixed,
            ).copyWith(
              title: 'Nutritious Dinner',
              fixedState: const AddRoutineFixedState(
                kind: 'Eating',
                mealCategory: 'Dinner',
                mealSlot: 'evening',
                dishes: ['Salmon', 'Asparagus', 'Brown Rice'],
                caloriesEstimate: 720.0,
                proteinEstimate: 52.0,
              ),
            );
        final eatingItem = AddRoutineMapper.toRoutineItem(eatingDraft);
        expect(eatingItem.dishes, ['Salmon', 'Asparagus', 'Brown Rice']);
        expect(eatingItem.caloriesEstimate, 720.0);
        expect(eatingItem.proteinEstimate, 52.0);

        // Test Skin Care translation
        final skinDraft =
            AddRoutineDraft.initial(
              id: 'skin-1',
              initialType: AddRoutineType.fixed,
            ).copyWith(
              title: 'Morning Skincare',
              fixedState: const AddRoutineFixedState(
                kind: 'Skin Care',
                skincareSlotLabel: 'AM Routine',
                steps: [
                  'Wash face',
                  'Apply Vitamin C',
                  'Moisturize',
                  'Sunscreen',
                ],
                skincareProducts: ['Cleanser', 'Serum', 'SPF 50'],
              ),
            );
        final skinItem = AddRoutineMapper.toRoutineItem(skinDraft);
        expect(skinItem.steps, [
          'Wash face',
          'Apply Vitamin C',
          'Moisturize',
          'Sunscreen',
        ]);
        expect(skinItem.skincareProducts, ['Cleanser', 'Serum', 'SPF 50']);
      },
    );
  });
}
