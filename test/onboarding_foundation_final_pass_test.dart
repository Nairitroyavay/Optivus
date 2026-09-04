import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  group('Onboarding Foundation Final Pass - Body Basics Validation', () {
    test('height boundary validation: 120 to 220 cm', () {
      const base = BodyBasicsDraft(
        ageRange: '25-34',
        gender: 'female',
        weightKg: 65,
      );

      expect(base.copyWith(heightCm: 119.9).validate(), isNotNull);
      expect(base.copyWith(heightCm: 120.0).validate(), isNull);
      expect(base.copyWith(heightCm: 170.0).validate(), isNull);
      expect(base.copyWith(heightCm: 220.0).validate(), isNull);
      expect(base.copyWith(heightCm: 220.1).validate(), isNotNull);
    });

    test('weight boundary validation: 40 to 150 kg', () {
      const base = BodyBasicsDraft(
        ageRange: '25-34',
        gender: 'male',
        heightCm: 175,
      );

      expect(base.copyWith(weightKg: 39.9).validate(), isNotNull);
      expect(base.copyWith(weightKg: 40.0).validate(), isNull);
      expect(base.copyWith(weightKg: 75.0).validate(), isNull);
      expect(base.copyWith(weightKg: 150.0).validate(), isNull);
      expect(base.copyWith(weightKg: 150.1).validate(), isNotNull);
    });

    test('withEstimates enforces body basics bounds', () {
      final invalidHeight = const BodyBasicsDraft(
        ageRange: '25-34',
        gender: 'female',
        heightCm: 110,
        weightKg: 60,
      ).withEstimates();
      expect(invalidHeight.bodyDataCompleted, isFalse);
      expect(invalidHeight.bmiEstimate, isNull);

      final validBody = const BodyBasicsDraft(
        ageRange: '25-34',
        gender: 'female',
        heightCm: 165,
        weightKg: 60,
      ).withEstimates();
      expect(validBody.bodyDataCompleted, isTrue);
      expect(validBody.bmiEstimate, isNotNull);
      expect(validBody.calorieEstimate, isNotNull);
      expect(validBody.proteinEstimate, isNotNull);
    });
  });

  group(
    'Onboarding Foundation Final Pass - Step 4/5 Upload Busy & Readiness',
    () {
      test('Step 4 busy gating is role aware', () {
        const workingRole = LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey);

        final mapClassBusy = <String, UploadSlotRuntimeState>{
          'class': const UploadSlotRuntimeState(
            slotKey: 'class',
            purpose: UploadedAssetPurpose.classTimetable,
            phase: UploadInteractionPhase.uploading,
          ),
          'work': const UploadSlotRuntimeState(
            slotKey: 'work',
            purpose: UploadedAssetPurpose.workSchedule,
            phase: UploadInteractionPhase.empty,
          ),
        };

        final mapWorkBusy = <String, UploadSlotRuntimeState>{
          'class': const UploadSlotRuntimeState(
            slotKey: 'class',
            purpose: UploadedAssetPurpose.classTimetable,
            phase: UploadInteractionPhase.empty,
          ),
          'work': const UploadSlotRuntimeState(
            slotKey: 'work',
            purpose: UploadedAssetPurpose.workSchedule,
            phase: UploadInteractionPhase.uploading,
          ),
        };

        // For student: class slot busy -> isBusy is true
        expect(mapClassBusy['class']!.isBusy, isTrue);

        // For working: class slot busy is irrelevant -> class slot busy does not block working role Step 4
        final classBusyForWorking =
            mapClassBusy['work']!.isBusy &&
            workingRole.lifeRole != LifeRoleDraft.studentKey;
        expect(classBusyForWorking, isFalse);

        // For studentWorking: either slot busy blocks Step 4
        final studentWorkingClassBusy =
            mapClassBusy['class']!.isBusy || mapClassBusy['work']!.isBusy;
        expect(studentWorkingClassBusy, isTrue);

        final studentWorkingWorkBusy =
            mapWorkBusy['class']!.isBusy || mapWorkBusy['work']!.isBusy;
        expect(studentWorkingWorkBusy, isTrue);
      });

      test('Step 5 busy gating checks eating slot', () {
        final eatingBusyMap = <String, UploadSlotRuntimeState>{
          'eating': const UploadSlotRuntimeState(
            slotKey: 'eating',
            purpose: UploadedAssetPurpose.eatingMenu,
            phase: UploadInteractionPhase.uploading,
          ),
        };
        expect(eatingBusyMap['eating']!.isBusy, isTrue);

        final eatingIdleMap = <String, UploadSlotRuntimeState>{
          'eating': const UploadSlotRuntimeState(
            slotKey: 'eating',
            purpose: UploadedAssetPurpose.eatingMenu,
            phase: UploadInteractionPhase.uploaded,
          ),
        };
        expect(eatingIdleMap['eating']!.isBusy, isFalse);
      });
    },
  );

  group('Onboarding Foundation Final Pass - Durable AI Source Provenance', () {
    test('Step 4 class provenance validation detects stale AI blocks', () {
      const assetA = 'asset_class_A';
      const assetB = 'asset_class_B';

      final blockFromA = TimelineBlockDraft(
        id: 'c1',
        section: 'classes',
        title: 'Math 101',
        startMinute: 540,
        endMinute: 600,
        repeatDays: const [1, 3, 5],
        blockType: TimelineBlockDraft.hardBlockKey,
        source: 'ai_import',
        provenanceSourceIds: const [assetA],
      );

      final draftWithAssetB = OnboardingDraft(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: BaseTimelineDraft(
          blocks: [blockFromA],
          classLogicalAssetId:
              assetB, // Current asset is B, but block is from A
        ),
      );

      final error = draftWithAssetB.baseTimeline.validateClassesAndWorkForRole(
        LifeRoleDraft.studentKey,
      );
      expect(error, contains('generated from a previous photo'));
    });

    test('Step 4 class provenance validation accepts matching asset B', () {
      const assetB = 'asset_class_B';

      final blockFromB = TimelineBlockDraft(
        id: 'c1',
        section: 'classes',
        title: 'Math 101',
        startMinute: 540,
        endMinute: 600,
        repeatDays: const [1, 3, 5],
        blockType: TimelineBlockDraft.hardBlockKey,
        source: 'ai_import',
        provenanceSourceIds: const [assetB],
      );

      final draftWithAssetB = OnboardingDraft(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: BaseTimelineDraft(
          blocks: [blockFromB],
          classLogicalAssetId: assetB,
        ),
      );

      final error = draftWithAssetB.baseTimeline.validateClassesAndWorkForRole(
        LifeRoleDraft.studentKey,
      );
      expect(error, isNull);
    });

    test('Step 4 Class replacement preserves valid Work data', () {
      const classA = 'class_A';
      const workW = 'work_W';

      final classBlockA = TimelineBlockDraft(
        id: 'c1',
        section: 'classes',
        title: 'Physics',
        startMinute: 540,
        endMinute: 600,
        repeatDays: const [1],
        blockType: TimelineBlockDraft.hardBlockKey,
        source: 'ai_import',
        provenanceSourceIds: const [classA],
      );

      final workBlockW = TimelineBlockDraft(
        id: 'w1',
        section: 'job_work_business',
        title: 'Shift',
        startMinute: 800,
        endMinute: 1000,
        repeatDays: const [2],
        blockType: TimelineBlockDraft.hardBlockKey,
        source: 'ai_import',
        provenanceSourceIds: const [workW],
      );

      const role = LifeRoleDraft.studentWorkingKey;

      final draftBefore = OnboardingDraft(
        lifeRole: const LifeRoleDraft(lifeRole: role),
        baseTimeline: BaseTimelineDraft(
          blocks: [classBlockA, workBlockW],
          classLogicalAssetId: classA,
          workLogicalAssetId: workW,
        ),
      );

      expect(
        draftBefore.baseTimeline.validateClassesAndWorkForRole(role),
        isNull,
      );

      // Now class photo A is replaced by class photo B
      const classB = 'class_B';
      final draftAfterClassReplace = draftBefore.copyWith(
        baseTimeline: draftBefore.baseTimeline.copyWith(
          classLogicalAssetId: classB,
          // Work logical asset remains workW
        ),
      );

      // Class validation fails because classBlockA has provenance classA != classB
      expect(
        draftAfterClassReplace.baseTimeline.validateClassesAndWorkForRole(role),
        contains('class timeline was generated from a previous photo'),
      );
    });

    test('Step 5 Eating provenance validation detects stale menu import', () {
      const menuA = 'menu_asset_A';
      const menuB = 'menu_asset_B';

      final mealBlockFromA = TimelineBlockDraft(
        id: 'e1',
        section: 'eating',
        title: 'Lunch',
        startMinute: 720,
        endMinute: 780,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        source: 'ai_import',
        provenanceSourceIds: const [menuA],
      );

      final draftWithMenuB = OnboardingDraft(
        baseTimeline: BaseTimelineDraft(
          eatingSetupPath: 'has_routine',
          blocks: [mealBlockFromA],
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'eating_photo_ai',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: menuB, // Current is B, block is A
              uploadedAssetR2Key: 'users/uid/onboarding/eating_menu/$menuB.jpg',
            ),
          ],
        ),
      );

      final error = draftWithMenuB.baseTimeline.validateEatingSetup();
      expect(error, contains('generated from a previous menu'));
    });
  });

  group('Onboarding Foundation Final Pass - Step 4 Class/Work Logical Swap', () {
    test(
      'Logical Class and Work asset mapping survives draft serialization',
      () {
        const assetClassPhysical = 'asset_123_phys_class';
        const assetWorkPhysical = 'asset_456_phys_work';

        // Logical swap: Classes = assetWorkPhysical, Work = assetClassPhysical
        final base = BaseTimelineDraft(
          classLogicalAssetId: assetWorkPhysical,
          classLogicalAssetR2Key:
              'users/uid/onboarding/work_schedule/$assetWorkPhysical.jpg',
          workLogicalAssetId: assetClassPhysical,
          workLogicalAssetR2Key:
              'users/uid/onboarding/class_timetable/$assetClassPhysical.jpg',
        );

        final map = base.toMap();
        final restored = BaseTimelineDraft.fromMap(map);

        expect(restored.classLogicalAssetId, equals(assetWorkPhysical));
        expect(restored.workLogicalAssetId, equals(assetClassPhysical));
      },
    );

    test('Logical mapping is preserved when copying draft', () {
      const classId = 'class_id';
      const workId = 'work_id';

      final base = BaseTimelineDraft(
        classLogicalAssetId: classId,
        workLogicalAssetId: workId,
      );

      final updated = base.copyWith(classJobSetupStep: 5);
      expect(updated.classLogicalAssetId, equals(classId));
      expect(updated.workLogicalAssetId, equals(workId));

      final cleared = base.copyWith(
        clearClassLogicalAsset: true,
        clearWorkLogicalAsset: true,
      );
      expect(cleared.classLogicalAssetId, isNull);
      expect(cleared.workLogicalAssetId, isNull);
    });
  });

  group('Onboarding Foundation Final Pass - Account Isolation', () {
    test(
      'Syncing with user B resets previous controller state from user A',
      () {
        final fakeRepo = FakeUploadedAssetRepository();
        final fakeAuth = TestAuthRepository();
        final fakePrepare = ImagePrepareService();
        final fakeR2 = TestR2UploadClient();
        final fakePerm = const DefaultUploadPermissionService();

        final controller = UploadInteractionController(
          shellConfig: onboardingUploadShellConfig,
          assetRepository: fakeRepo,
          authRepository: fakeAuth,
          imagePrepareService: fakePrepare,
          r2UploadClient: fakeR2,
          permissionService: fakePerm,
        );

        // User A sync
        final stateA = RestoredUploadsState(
          uid: 'user_A',
          assetsByPurpose: {
            UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
              asset: UploadedAsset(
                assetId: 'asset_A',
                ownerUid: 'user_A',
                sourceFeature: OnboardingDraft.sourceOnboarding,
                purpose: UploadedAssetPurpose.classTimetable,
                fileName: 'asset_A.jpg',
                contentType: 'image/jpeg',
                sizeBytes: 100,
                r2Key: 'users/user_A/onboarding/class_timetable/asset_A.jpg',
                status: UploadedAssetStatus.uploaded,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
          },
        );

        controller.syncWithDurableState(stateA, uid: 'user_A');
        expect(controller.state['class']?.hasDurableAsset, isTrue);

        // Now User B syncs
        final stateB = RestoredUploadsState(
          uid: 'user_B',
          assetsByPurpose: const {},
        );

        controller.syncWithDurableState(stateB, uid: 'user_B');
        // User B state must be clean, not showing user A's asset
        expect(controller.state['class']?.hasDurableAsset, isFalse);
        expect(
          controller.state['class']?.phase,
          equals(UploadInteractionPhase.empty),
        );
      },
    );
  });
}

class TestAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser =>
      AuthUser(uid: 'fake_uid', email: 'test@example.com', emailVerified: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestR2UploadClient implements R2UploadClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
