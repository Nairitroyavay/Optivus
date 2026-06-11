import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Onboarding 5 No Fake Fallback', () {
    test('WorkerNutritionAiClient returns missing URL warning when baseUrl is empty instead of using fake data', () async {
      final client = WorkerNutritionAiClient(baseUrl: '');

      final result = await client.generateEatingRoutine(
        uid: 'test-user',
        idToken: 'test-token',
        params: {},
      );

      expect(result.candidates.isEmpty, true);
      expect(result.warnings.contains('Nutrition AI worker is not configured.'), true);
      expect(result.id, 'worker-gen-missing-url');
    });
  });
}
