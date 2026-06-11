import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/services/nutrition_ai_client.dart';

void main() {
  group('Onboarding 5 No Fake Fallback', () {
    test('WorkerNutritionAiClient returns missing URL warning when baseUrl is empty instead of using fake data', () async {
      final client = WorkerNutritionAiClient(baseUrl: '');

      expect(
        () => client.generateEatingRoutine(
          uid: 'test-user',
          idToken: 'test-token',
          params: {},
        ),
        throwsA(isA<MissingConfigException>()),
      );
    });
  });
}
