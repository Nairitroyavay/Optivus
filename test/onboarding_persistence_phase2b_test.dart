import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/onboarding_completion_service.dart';

void main() {
  test('OnboardingDraft toMap/fromMap preserves currentStep', () {
    final draft = _draftWithUploadReferences().copyWith(currentStep: 4);

    final roundTrip = OnboardingDraft.fromMap(draft.toMap());

    expect(roundTrip.currentStep, 4);
  });

  test(
    'OnboardingDraft toMap/fromMap preserves stepCompleted and stepDirty',
    () {
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
      completed[0] = true;
      completed[1] = true;
      completed[4] = true;
      final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
      dirty[2] = true;
      dirty[5] = true;
      final draft = _draftWithUploadReferences().copyWith(
        stepCompleted: completed,
        stepDirty: dirty,
      );

      final roundTrip = OnboardingDraft.fromMap(draft.toMap());

      expect(roundTrip.stepCompleted, completed);
      expect(roundTrip.stepDirty, dirty);
    },
  );

  test(
    'OnboardingDraft toMap/fromMap preserves PendingFutureImportDraft uploaded asset references',
    () {
      final draft = _draftWithUploadReferences();

      final roundTrip = OnboardingDraft.fromMap(draft.toMap());
      final imports = roundTrip.baseTimeline.pendingFutureImports;

      expect(imports, hasLength(4));
      expect(imports[0].uploadedAssetId, 'class-asset');
      expect(imports[0].uploadedAssetR2Key, contains('class_timetable'));
      expect(imports[0].uploadedAssetStatus, 'uploaded');
      expect(imports[1].uploadedAssetId, 'menu-asset');
      expect(imports[1].uploadedAssetR2Key, contains('eating_menu'));
      expect(imports[1].uploadedAssetStatus, 'uploaded');
      expect(imports[2].uploadedAssetId, 'skin-asset');
      expect(imports[2].uploadedAssetR2Key, contains('skin_care'));
      expect(imports[2].uploadedAssetStatus, 'uploaded');
    },
  );

  test('OnboardingCompletionBundle.toMap includes uploadedAssetReferences', () {
    final bundle = OnboardingCompletionService.buildBundle(
      _draftWithUploadReferences(),
    );

    final map = bundle.toMap();
    final references = (map['uploadedAssetReferences'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    expect(references, hasLength(3));
    expect(references.map((item) => item['id']), contains('classes_photo'));
    expect(references.map((item) => item['id']), contains('eating_photo'));
    expect(references.map((item) => item['id']), contains('skin_photo'));
    expect(
      references.any((item) => item.containsKey('uploadPlaceholderPath')),
      isFalse,
    );
  });

  test('FakeOnboardingRepository saves and fetches draft', () async {
    final repository = FakeOnboardingRepository();
    final draft = _draftWithUploadReferences().copyWith(currentStep: 6);

    await repository.saveDraft(draft);

    final saved = await repository.fetchDraft(draft.uid);
    expect(saved, isNotNull);
    expect(saved!.currentStep, 6);
    expect(
      saved.baseTimeline.pendingFutureImports.first.uploadedAssetId,
      'class-asset',
    );
  });

  test('FakeOnboardingRepository updates saved currentStep', () async {
    final repository = FakeOnboardingRepository();
    final draft = _draftWithUploadReferences().copyWith(currentStep: 3);

    await repository.saveDraft(draft);
    await repository.saveDraft(draft.copyWith(currentStep: 4));

    final saved = await repository.fetchDraft(draft.uid);
    expect(saved, isNotNull);
    expect(saved!.currentStep, 4);
  });

  test(
    'FakeOnboardingRepository completeOnboarding saves final draft and completion bundle',
    () async {
      final repository = FakeOnboardingRepository();
      final finalDraft = _draftWithUploadReferences().copyWith(
        currentStep: OnboardingDraft.lastStepIndex,
        onboardingCompleted: true,
        stepCompleted: List<bool>.filled(OnboardingDraft.stepCount, true),
        stepDirty: List<bool>.filled(OnboardingDraft.stepCount, false),
      );
      final bundle = OnboardingCompletionService.buildBundle(finalDraft);

      await repository.completeOnboarding(
        finalDraft: finalDraft,
        bundle: bundle,
      );

      final savedDraft = await repository.fetchDraft(finalDraft.uid);
      final savedBundle = repository.savedCompletionBundle(finalDraft.uid);
      expect(savedDraft, isNotNull);
      expect(savedDraft!.onboardingCompleted, isTrue);
      expect(savedBundle, isNotNull);
      expect(savedBundle!.uploadedAssetReferences, hasLength(3));
    },
  );

  test('Firestore onboarding paths remain correct', () {
    expect(
      FirestoreUserPaths.onboardingDraft('abc'),
      'users/abc/onboarding/draft',
    );
    expect(
      FirestoreUserPaths.onboardingCompletionBundle('abc'),
      'users/abc/onboarding/completionBundle',
    );
  });
}

OnboardingDraft _draftWithUploadReferences() {
  final now = DateTime.utc(2026, 6, 2, 8);
  return OnboardingDraft(
    uid: 'phase2b-user',
    currentStep: 4,
    baseTimeline: BaseTimelineDraft(
      pendingFutureImports: [
        PendingFutureImportDraft(
          id: 'classes_photo',
          section: 'Classes',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'class-asset',
          uploadedAssetR2Key:
              'users/phase2b-user/onboarding/class_timetable/class-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'eating_photo',
          section: 'Eating',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'menu-asset',
          uploadedAssetR2Key:
              'users/phase2b-user/onboarding/eating_menu/menu-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'skin_photo',
          section: 'Skin Care',
          mode: 'Photo Upload',
          createdAt: now,
          uploadedAssetId: 'skin-asset',
          uploadedAssetR2Key:
              'users/phase2b-user/onboarding/skin_care/skin-asset.jpg',
          uploadedAssetStatus: 'uploaded',
        ),
        PendingFutureImportDraft(
          id: 'manual_text',
          section: 'Classes',
          mode: 'Pasted Text',
          createdAt: now,
          pastedText: 'Monday 9 AM class',
        ),
      ],
    ),
  );
}
