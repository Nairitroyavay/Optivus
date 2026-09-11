import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/skin_care_ai_client.dart';

class SkinCareDomainEngine {
  final SkinCareAiClient _client;

  const SkinCareDomainEngine({required SkinCareAiClient client})
    : _client = client;

  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    return _client.analyzeProducts(
      uid: uid,
      idToken: idToken,
      productPhotos: productPhotos,
    );
  }

  Future<List<TimelineBlockDraft>> generateRoutineFromProducts({
    required String uid,
    required String idToken,
    required List<SkinCareDetectedProduct> products,
    required String skinType,
    required List<String> problems,
    required int desiredApplicationsPerDay,
    required BaseTimelineDraft baseTimeline,
  }) async {
    final routineParams = {
      'sourceFeature': 'routine_base_timeline',
      'productInputSource': 'typed',
      'typedProductDetails': products.map((p) => p.toMap()).toList(),
      'desiredApplicationsPerDay': desiredApplicationsPerDay,
      'skinType': skinType,
      'mainProblem': problems.isNotEmpty ? problems.first : 'none',
      'skinConcerns': problems,
      'budget': 'medium',
      'routinePreference': 'balanced',
    };

    var result = await _client.generateRoutine(
      uid: uid,
      idToken: idToken,
      params: routineParams,
    );

    if (result.hasError && result.errorCode == 'json_payload_too_large') {
      result = await _client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          ...routineParams,
          'typedProductDetails': products
              .map((p) => p.toCompactRoutinePayload())
              .toList(),
          'compact': true,
        },
      );
    }

    if (result.hasError || result.routinePlans.isEmpty) {
      throw StateError(
        result.errorMessage ?? 'AI returned no usable skin care routine.',
      );
    }

    final partitioned = onboarding7PartitionRoutinePlans(result.routinePlans);
    final scheduleResult = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: _ensureBathAndSleepInDraft(baseTimeline),
      routinePlans: partitioned.dailyPlans,
      desiredApplicationsPerDay: desiredApplicationsPerDay,
      ownedProductNames: products.map((p) => p.displayName).toList(),
      ownedProductDetails: products,
      forceEveryDay: true,
    );

    if (scheduleResult.hasError || scheduleResult.blocks.isEmpty) {
      throw StateError(
        scheduleResult.errorMessage ?? 'Could not schedule skin care routine.',
      );
    }

    return scheduleResult.blocks;
  }

  Future<List<TimelineBlockDraft>> generateBuildForMeRoutine({
    required String uid,
    required String idToken,
    required String skinType,
    required List<String> problems,
    required int desiredApplicationsPerDay,
    required BaseTimelineDraft baseTimeline,
    String? facePhotoR2Key,
  }) async {
    final routineParams = {
      'sourceFeature': 'routine_base_timeline',
      'skinType': skinType,
      'mainProblem': problems.isNotEmpty ? problems.first : 'none',
      'skinConcerns': problems,
      'budget': 'medium',
      'routinePreference': 'balanced',
      'desiredApplicationsPerDay': desiredApplicationsPerDay,
      'facePhotoR2Key': ?facePhotoR2Key,
    };

    var result = await _client.generateRoutine(
      uid: uid,
      idToken: idToken,
      params: routineParams,
    );

    if (!result.hasError &&
        result.routinePlans.isEmpty &&
        result.recommendedProducts.isNotEmpty) {
      final detected = result.recommendedProducts
          .map(
            (rec) => SkinCareDetectedProduct(
              name: rec.name,
              brand: rec.brand,
              category: rec.category,
            ),
          )
          .toList();

      result = await _client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          ...routineParams,
          'productInputSource': 'typed',
          'typedProductDetails': detected.map((p) => p.toMap()).toList(),
        },
      );
    }

    if (result.hasError || result.routinePlans.isEmpty) {
      throw StateError(
        result.errorMessage ?? 'AI returned no usable skin care routine.',
      );
    }

    final partitioned = onboarding7PartitionRoutinePlans(result.routinePlans);
    final allProductNames = partitioned.dailyPlans
        .expand((plan) => plan.productNames)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    final fallbackProductNames = result.recommendedProducts
        .map((p) => p.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    final scheduleResult = onboarding7ScheduleSkinCareRoutine(
      baseTimeline: _ensureBathAndSleepInDraft(baseTimeline),
      routinePlans: partitioned.dailyPlans,
      desiredApplicationsPerDay: desiredApplicationsPerDay,
      ownedProductNames: allProductNames.isNotEmpty
          ? allProductNames
          : fallbackProductNames,
      forceEveryDay: true,
    );

    if (scheduleResult.hasError || scheduleResult.blocks.isEmpty) {
      throw StateError(
        scheduleResult.errorMessage ?? 'Could not schedule skin care routine.',
      );
    }

    return scheduleResult.blocks;
  }

  BaseTimelineDraft _ensureBathAndSleepInDraft(BaseTimelineDraft draft) {
    var blocks = List<TimelineBlockDraft>.from(draft.blocks);
    final hasBath = blocks.any(
      (b) =>
          b.section == 'fixed' &&
          (b.id == BaseTimelineDraft.fixedBathId ||
              b.title.toLowerCase().contains('bath')),
    );
    if (!hasBath) {
      blocks.add(
        TimelineBlockDraft(
          id: BaseTimelineDraft.fixedBathId,
          section: 'fixed',
          title: 'Morning Bath',
          startMinute: 7 * 60 + 30,
          endMinute: 8 * 60,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      );
    }
    final hasSleep = blocks.any(
      (b) =>
          b.section == 'fixed' &&
          (b.id == BaseTimelineDraft.fixedSleepId ||
              b.title.toLowerCase().contains('sleep') ||
              b.title.toLowerCase().contains('bed')),
    );
    if (!hasSleep) {
      blocks.add(
        TimelineBlockDraft(
          id: BaseTimelineDraft.fixedSleepId,
          section: 'fixed',
          title: 'Sleep',
          startMinute: 23 * 60,
          endMinute: 7 * 60,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      );
    }
    return draft.copyWith(blocks: blocks);
  }
}

final skinCareDomainEngineProvider = Provider<SkinCareDomainEngine>((ref) {
  return SkinCareDomainEngine(client: ref.watch(skinCareAiClientProvider));
});
