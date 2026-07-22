import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/routine_import_ai_config.dart';

void main() {
  test('real AI worker endpoints are configured by default', () {
    expect(
      OptivusRoutineImportAiConfig.workerBaseUrl,
      OptivusAiWorkersConfig.routineImportWorkerUrl,
    );
    expect(OptivusAiWorkersConfig.routineImportWorkerUrl, isNotEmpty);
    expect(OptivusAiWorkersConfig.nutritionWorkerUrl, isNotEmpty);
    expect(OptivusAiWorkersConfig.coachWorkerUrl, isNotEmpty);
    expect(OptivusAiWorkersConfig.skinCareWorkerUrl, isNotEmpty);
  });
}
