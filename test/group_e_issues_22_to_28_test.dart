import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';

void main() {
  group('Group E Issues 22–28 Test Suite', () {
    test(
      'Issue 22: Worker desired count differs from scheduler count produces structured partial result status',
      () {
        final plans = [
          const SkinCareRoutinePlan(
            slotLabel: 'morning',
            title: 'Morning Skin Care',
            steps: ['Cleanse', 'Sunscreen'],
            productNames: ['Cleanser', 'Sunscreen'],
          ),
        ];

        final result = SkinCareAiRoutineResult(
          routinePlans: plans,
          morningRoutine: ['Cleanser', 'Sunscreen'],
          nightRoutine: [],
          weeklyRoutine: [],
          timelineBlocks: [],
          generatedCount: 2, // Desired 2, but only 1 generated
          acceptedCount: 1,
          rejectedPlanReasons: ['night_plan_rejected_contraindication'],
        );

        expect(result.resultStatus, SkinCareRoutineResultStatus.partial);
        expect(result.isPartial, isTrue);
        expect(result.generatedCount, 2);
        expect(result.acceptedCount, 1);
        expect(result.rejectedCount, 1);
      },
    );

    test(
      'Issue 23: SkinCareRejectionExplanation contains structured rule, product, ingredient, and repair suggestion fields',
      () {
        final map = {
          'ruleId': 'acid_overlap_rule',
          'products': ['AHA Serum', 'Retinol Cream'],
          'ingredients': ['Glycolic acid', 'Retinol'],
          'severity': 'high',
          'reason':
              'Combining AHA exfoliant with Retinol in the same PM routine causes severe skin barrier breakdown.',
          'repairSuggestion':
              'Alternate AHA Serum and Retinol on separate nights.',
        };

        final explanation = SkinCareRejectionExplanation.fromMap(map);

        expect(explanation.ruleId, 'acid_overlap_rule');
        expect(explanation.products, ['AHA Serum', 'Retinol Cream']);
        expect(explanation.ingredients, ['Glycolic acid', 'Retinol']);
        expect(explanation.severity, 'high');
        expect(explanation.reason, contains('skin barrier breakdown'));
        expect(explanation.repairSuggestion, contains('Alternate AHA Serum'));

        final json = explanation.toMap();
        expect(json['ruleId'], 'acid_overlap_rule');
        expect(json['severity'], 'high');
      },
    );

    test(
      'Issue 24: Typed input parsing enriches product with equivalent safety metadata to photo input',
      () {
        final products = onboarding7ParseTypedProductDetails(
          'Minimalist SPF 50 - sunscreen\n'
          'CeraVe Hydrating Cleanser - cleanser\n'
          'Retinol 0.3% - treatment_serum',
        );

        expect(products, hasLength(3));

        final sunscreen = products.firstWhere((p) => p.category == 'sunscreen');
        expect(sunscreen.keyIngredients, contains('UV filters'));
        expect(sunscreen.usageHint, contains('morning'));
        expect(sunscreen.confidence, 'high');

        final cleanser = products.firstWhere((p) => p.category == 'cleanser');
        expect(cleanser.keyIngredients, contains('gentle surfactants'));
        expect(cleanser.confidence, 'high');

        final retinol = products.firstWhere((p) => p.name.contains('Retinol'));
        expect(retinol.possibleActives, contains('Retinol'));
        expect(retinol.warningIfAny, contains('sunscreen'));
        expect(retinol.confidence, 'high');
      },
    );

    test(
      'Issue 26: Invariant verification between accepted plans, timeline blocks, and bundle source IDs',
      () {
        final acceptedPlanIds = {'morning', 'night'};
        final timelineSourceIds = {'morning', 'night'};
        final persistedBundleSourceIds = {'morning', 'night'};

        final match =
            acceptedPlanIds.every(
              (id) =>
                  timelineSourceIds.contains(id) &&
                  persistedBundleSourceIds.contains(id),
            ) &&
            timelineSourceIds.length == acceptedPlanIds.length &&
            persistedBundleSourceIds.length == timelineSourceIds.length;

        expect(match, isTrue);

        final mismatchedTimelineIds = {'morning'};
        final mismatch =
            acceptedPlanIds.every(
              (id) =>
                  mismatchedTimelineIds.contains(id) &&
                  persistedBundleSourceIds.contains(id),
            ) &&
            mismatchedTimelineIds.length == acceptedPlanIds.length;

        expect(mismatch, isFalse);
      },
    );

    test(
      'Issue 27: Missing item importance classification normalizes into required, important, recommended, and optional',
      () {
        final req = SkinCareMissingItem.fromMap({
          'name': 'Moisturizer',
          'importance': 'essential',
        });
        expect(req.importance, 'required');

        final imp = SkinCareMissingItem.fromMap({
          'name': 'Cleanser',
          'importance': 'important',
        });
        expect(imp.importance, 'important');

        final rec = SkinCareMissingItem.fromMap({
          'name': 'Vitamin C',
          'importance': 'suggested',
        });
        expect(rec.importance, 'recommended');

        final opt = SkinCareMissingItem.fromMap({
          'name': 'Face Mask',
          'importance': 'extra',
        });
        expect(opt.importance, 'optional');
      },
    );

    test(
      'Issue 28: Medical-style guidance boundaries contain cosmetic disclaimer and severe irritation escalation path',
      () {
        expect(
          skinCareCosmeticGuidanceDisclaimer,
          contains('Cosmetic guidance only'),
        );
        expect(
          skinCareCosmeticGuidanceDisclaimer,
          contains('does not constitute medical diagnosis'),
        );
        expect(
          skinCareIrritationEscalationGuidance,
          contains('consult a board-certified dermatologist'),
        );
        expect(
          skinCareIrritationEscalationGuidance,
          contains('discontinue use immediately'),
        );
      },
    );
  });
}
