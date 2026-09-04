import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/onboarding_resume_validator.dart';
import 'package:optivus/services/onboarding_upload_source_reconciler.dart';
import 'package:optivus/services/session_destination_resolver.dart';
import 'package:optivus/services/server_reconstructor.dart';
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

  group(
    'Onboarding Foundation Final Pass - Fail-Closed Domain Validation (Step 4 & Step 5)',
    () {
      const assetClassA = 'class_A';
      const assetClassB = 'class_B';
      const assetWorkA = 'work_A';
      const assetWorkB = 'work_B';
      const assetMenuA = 'menu_A';
      const assetMenuB = 'menu_B';

      test(
        '16. required Class AI blocks with valid current logical source but empty provenance -> FAILS',
        () {
          final base = BaseTimelineDraft(
            classLogicalAssetId: assetClassA,
            classLogicalAssetR2Key:
                'users/uid/onboarding/class_timetable/$assetClassA.jpg',
            blocks: [
              TimelineBlockDraft(
                id: 'c1',
                section: 'classes',
                title: 'Math',
                startMinute: 540,
                endMinute: 600,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: const [], // Empty provenance
              ),
            ],
          );

          final error = base.validateClassesAndWorkForRole(
            LifeRoleDraft.studentKey,
          );
          expect(error, contains('generated from a previous photo'));
        },
      );

      test('17. required Work AI blocks with empty provenance -> FAILS', () {
        final base = BaseTimelineDraft(
          workLogicalAssetId: assetWorkA,
          workLogicalAssetR2Key:
              'users/uid/onboarding/work_schedule/$assetWorkA.jpg',
          blocks: [
            TimelineBlockDraft(
              id: 'w1',
              section: 'job_work_business',
              title: 'Shift',
              startMinute: 540,
              endMinute: 1000,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [],
            ),
          ],
        );

        final error = base.validateClassesAndWorkForRole(
          LifeRoleDraft.workingKey,
        );
        expect(error, contains('generated from a previous photo'));
      });

      test('18. correct Class provenance -> PASSES', () {
        final base = BaseTimelineDraft(
          classLogicalAssetId: assetClassA,
          classLogicalAssetR2Key:
              'users/uid/onboarding/class_timetable/$assetClassA.jpg',
          blocks: [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Math',
              startMinute: 540,
              endMinute: 600,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetClassA],
            ),
          ],
        );

        final error = base.validateClassesAndWorkForRole(
          LifeRoleDraft.studentKey,
        );
        expect(error, isNull);
      });

      test('19. correct Work provenance -> PASSES', () {
        final base = BaseTimelineDraft(
          workLogicalAssetId: assetWorkA,
          workLogicalAssetR2Key:
              'users/uid/onboarding/work_schedule/$assetWorkA.jpg',
          blocks: [
            TimelineBlockDraft(
              id: 'w1',
              section: 'job_work_business',
              title: 'Shift',
              startMinute: 540,
              endMinute: 1000,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetWorkA],
            ),
          ],
        );

        final error = base.validateClassesAndWorkForRole(
          LifeRoleDraft.workingKey,
        );
        expect(error, isNull);
      });

      test('20. wrong Class provenance -> FAILS', () {
        final base = BaseTimelineDraft(
          classLogicalAssetId: assetClassB,
          classLogicalAssetR2Key:
              'users/uid/onboarding/class_timetable/$assetClassB.jpg',
          blocks: [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Math',
              startMinute: 540,
              endMinute: 600,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetClassA], // Has A, expects B
            ),
          ],
        );

        final error = base.validateClassesAndWorkForRole(
          LifeRoleDraft.studentKey,
        );
        expect(error, contains('generated from a previous photo'));
      });

      test('21. wrong Work provenance -> FAILS', () {
        final base = BaseTimelineDraft(
          workLogicalAssetId: assetWorkB,
          workLogicalAssetR2Key:
              'users/uid/onboarding/work_schedule/$assetWorkB.jpg',
          blocks: [
            TimelineBlockDraft(
              id: 'w1',
              section: 'job_work_business',
              title: 'Shift',
              startMinute: 540,
              endMinute: 1000,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetWorkA],
            ),
          ],
        );

        final error = base.validateClassesAndWorkForRole(
          LifeRoleDraft.workingKey,
        );
        expect(error, contains('generated from a previous photo'));
      });

      test('22. studentWorking one valid / one stale -> FAILS', () {
        final base = BaseTimelineDraft(
          classLogicalAssetId: assetClassA,
          classLogicalAssetR2Key:
              'users/uid/onboarding/class_timetable/$assetClassA.jpg',
          workLogicalAssetId: assetWorkB,
          workLogicalAssetR2Key:
              'users/uid/onboarding/work_schedule/$assetWorkB.jpg',
          blocks: [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Math',
              startMinute: 540,
              endMinute: 600,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetClassA], // Valid Class
            ),
            TimelineBlockDraft(
              id: 'w1',
              section: 'job_work_business',
              title: 'Shift',
              startMinute: 720,
              endMinute: 1000,
              repeatDays: const [2],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [
                assetWorkA,
              ], // Stale Work provenance (expects B)
            ),
          ],
        );

        final error = base.validateClassesAndWorkForRole(
          LifeRoleDraft.studentWorkingKey,
        );
        expect(
          error,
          contains('work timeline was generated from a previous photo'),
        );
      });

      test(
        '23. legitimate persisted Class/Work swap with correct provenance -> PASSES',
        () {
          final base = BaseTimelineDraft(
            classLogicalAssetId: assetWorkA, // Swapped to work asset
            classLogicalAssetR2Key:
                'users/uid/onboarding/work_schedule/$assetWorkA.jpg',
            workLogicalAssetId: assetClassA, // Swapped to class asset
            workLogicalAssetR2Key:
                'users/uid/onboarding/class_timetable/$assetClassA.jpg',
            blocks: [
              TimelineBlockDraft(
                id: 'c1',
                section: 'classes',
                title: 'Class',
                startMinute: 540,
                endMinute: 600,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: const [assetWorkA],
              ),
              TimelineBlockDraft(
                id: 'w1',
                section: 'job_work_business',
                title: 'Work',
                startMinute: 720,
                endMinute: 1000,
                repeatDays: const [2],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: const [assetClassA],
              ),
            ],
          );

          final error = base.validateClassesAndWorkForRole(
            LifeRoleDraft.studentWorkingKey,
          );
          expect(error, isNull);
        },
      );

      test(
        '24. has_routine + confirmed Eating blocks + NO PendingFutureImportDraft -> FAILS',
        () {
          final base = BaseTimelineDraft(
            eatingSetupPath: 'has_routine',
            pendingFutureImports: const [], // Missing import
            blocks: [
              TimelineBlockDraft(
                id: 'm1',
                section: 'eating',
                title: 'Lunch',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds: const [assetMenuA],
              ),
            ],
          );

          final error = base.validateEatingSetup();
          expect(error, contains('generated from a previous menu'));
        },
      );

      test('25. has_routine + import but missing uploadedAssetId -> FAILS', () {
        final base = BaseTimelineDraft(
          eatingSetupPath: 'has_routine',
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'e1',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: null, // Missing asset ID
              uploadedAssetR2Key: 'users/uid/onboarding/eating_menu/menu.jpg',
            ),
          ],
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 780,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.softBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetMenuA],
            ),
          ],
        );

        final error = base.validateEatingSetup();
        expect(error, contains('generated from a previous menu'));
      });

      test(
        '26. has_routine + import but missing uploadedAssetR2Key -> FAILS',
        () {
          final base = BaseTimelineDraft(
            eatingSetupPath: 'has_routine',
            pendingFutureImports: [
              PendingFutureImportDraft(
                id: 'e1',
                section: 'Eating',
                mode: 'Photo AI',
                createdAt: DateTime.now(),
                uploadedAssetId: assetMenuA,
                uploadedAssetR2Key: null, // Missing R2 key
              ),
            ],
            blocks: [
              TimelineBlockDraft(
                id: 'm1',
                section: 'eating',
                title: 'Lunch',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds: const [assetMenuA],
              ),
            ],
          );

          final error = base.validateEatingSetup();
          expect(error, contains('generated from a previous menu'));
        },
      );

      test('27. has_routine + AI block provenance empty -> FAILS', () {
        final base = BaseTimelineDraft(
          eatingSetupPath: 'has_routine',
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'e1',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: assetMenuA,
              uploadedAssetR2Key:
                  'users/uid/onboarding/eating_menu/$assetMenuA.jpg',
            ),
          ],
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 780,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.softBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [], // Empty provenance
            ),
          ],
        );

        final error = base.validateEatingSetup();
        expect(error, contains('generated from a previous menu'));
      });

      test('28. has_routine + import A + block provenance B -> FAILS', () {
        final base = BaseTimelineDraft(
          eatingSetupPath: 'has_routine',
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'e1',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: assetMenuA,
              uploadedAssetR2Key:
                  'users/uid/onboarding/eating_menu/$assetMenuA.jpg',
            ),
          ],
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 780,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.softBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetMenuB], // Has B, expects A
            ),
          ],
        );

        final error = base.validateEatingSetup();
        expect(error, contains('generated from a previous menu'));
      });

      test('29. has_routine + import A + block provenance A -> PASSES', () {
        final base = BaseTimelineDraft(
          eatingSetupPath: 'has_routine',
          pendingFutureImports: [
            PendingFutureImportDraft(
              id: 'e1',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: assetMenuA,
              uploadedAssetR2Key:
                  'users/uid/onboarding/eating_menu/$assetMenuA.jpg',
              uploadedAssetStatus: 'uploaded',
            ),
          ],
          blocks: [
            TimelineBlockDraft(
              id: 'm1',
              section: 'eating',
              title: 'Lunch',
              startMinute: 720,
              endMinute: 780,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.softBlockKey,
              source: 'ai_import',
              provenanceSourceIds: const [assetMenuA],
            ),
          ],
        );

        final error = base.validateEatingSetup();
        expect(error, isNull);
      });

      test(
        '30. create path + valid generated Eating blocks + no upload provenance -> PASSES',
        () {
          final base = BaseTimelineDraft(
            eatingSetupPath: 'create',
            blocks: [
              TimelineBlockDraft(
                id: 'm1',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 480,
                endMinute: 510,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds:
                    const [], // Photo provenance not required for Create path
              ),
            ],
          );

          final error = base.validateEatingSetup();
          expect(error, isNull);
        },
      );
    },
  );

  group(
    'Onboarding Foundation Final Pass - Auth / Reconstruction Integration & Crash Window',
    () {
      const ownerUid = 'user_crash_test';

      UploadedAsset makeAsset(String id, UploadedAssetPurpose purpose) {
        final p = purpose.wireName;
        return UploadedAsset(
          assetId: id,
          ownerUid: ownerUid,
          sourceFeature: OnboardingDraft.sourceOnboarding,
          purpose: purpose,
          fileName: '$id.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 2048,
          r2Key: 'users/$ownerUid/onboarding/$p/$id.jpg',
          status: UploadedAssetStatus.uploaded,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
      }

      test(
        '31 & 32. ReconstructionIncomplete with stale photo source resumes at affected step',
        () {
          final classA = makeAsset(
            'class_A',
            UploadedAssetPurpose.classTimetable,
          );
          final classB = makeAsset(
            'class_B',
            UploadedAssetPurpose.classTimetable,
          );

          final draft = OnboardingDraft(
            uid: ownerUid,
            currentStep: 8,
            patiencePledgeAccepted: true,
            bodyBasics: const BodyBasicsDraft(
              ageRange: '25-34',
              gender: 'male',
              heightCm: 175,
              weightKg: 70,
            ),
            stepCompleted: const [
              true,
              true,
              true,
              true,
              true,
              true,
              true,
              true,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
            lifeRole: const LifeRoleDraft(
              lifeRole: LifeRoleDraft.studentKey,
              exerciseLevel: 'light',
              waterIntake: '2_liters',
              stressLevel: 'moderate',
              sleepQuality: 'good',
            ),
            baseTimeline: BaseTimelineDraft(
              classLogicalAssetId: classA.assetId,
              classLogicalAssetR2Key: classA.r2Key,
              blocks: [
                TimelineBlockDraft(
                  id: 'c1',
                  section: 'classes',
                  title: 'Physics',
                  startMinute: 540,
                  endMinute: 600,
                  repeatDays: const [1],
                  blockType: TimelineBlockDraft.hardBlockKey,
                  source: 'ai_import',
                  provenanceSourceIds: [classA.assetId, classA.r2Key],
                ),
              ],
            ),
          );

          final restoredWithB = RestoredUploadsState(
            uid: ownerUid,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: classB,
              ),
            },
          );

          final recon = OnboardingUploadSourceReconciler.reconcile(
            ownerUid: ownerUid,
            draft: draft,
            restoredUploads: restoredWithB,
          );

          final effectiveStep = validateOnboardingResume(
            recon.reconciledDraft,
          ).resumeStep;
          expect(effectiveStep, equals(4));

          final dest = resolveReconstructionDestination(
            ReconstructionIncomplete(
              ownerUid: ownerUid,
              profile: UserProfile.empty(uid: ownerUid),
              step: effectiveStep,
              draft: recon.reconciledDraft,
            ),
          );

          expect(dest.kind, equals(SessionDestinationKind.resumeOnboarding));
          expect(dest.resumeStep, equals(4));
        },
      );

      test(
        '33 & 34. ReconstructionIncomplete with matching photo source preserves destination',
        () {
          final classA = makeAsset(
            'class_A',
            UploadedAssetPurpose.classTimetable,
          );

          final draft = OnboardingDraft(
            uid: ownerUid,
            currentStep: 8,
            patiencePledgeAccepted: true,
            bodyBasics: const BodyBasicsDraft(
              ageRange: '25-34',
              gender: 'male',
              heightCm: 175,
              weightKg: 70,
            ),
            stepCompleted: const [
              true,
              true,
              true,
              true,
              true,
              true,
              true,
              true,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
            lifeRole: const LifeRoleDraft(
              lifeRole: LifeRoleDraft.studentKey,
              exerciseLevel: 'light',
              waterIntake: '2_liters',
              stressLevel: 'moderate',
              sleepQuality: 'good',
            ),
            baseTimeline: BaseTimelineDraft(
              classLogicalAssetId: classA.assetId,
              classLogicalAssetR2Key: classA.r2Key,
              eatingSetupPath: 'create',
              skinCareSkipped: true,
              blocks: [
                TimelineBlockDraft(
                  id: 'c1',
                  section: 'classes',
                  title: 'Physics',
                  startMinute: 540,
                  endMinute: 600,
                  repeatDays: const [1],
                  blockType: TimelineBlockDraft.hardBlockKey,
                  source: 'ai_import',
                  provenanceSourceIds: [classA.assetId, classA.r2Key],
                ),
                TimelineBlockDraft(
                  id: 'm1',
                  section: 'eating',
                  title: 'Lunch',
                  startMinute: 720,
                  endMinute: 780,
                  repeatDays: const [1],
                  blockType: TimelineBlockDraft.softBlockKey,
                  source: 'ai_import',
                ),
                BaseTimelineDraft.defaultSleepBlock(),
                BaseTimelineDraft.defaultBathBlock(),
              ],
            ),
          );

          final restoredWithA = RestoredUploadsState(
            uid: ownerUid,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: classA,
              ),
            },
          );

          final recon = OnboardingUploadSourceReconciler.reconcile(
            ownerUid: ownerUid,
            draft: draft,
            restoredUploads: restoredWithA,
          );

          final effectiveStep = validateOnboardingResume(
            recon.reconciledDraft,
          ).resumeStep;
          expect(effectiveStep, equals(8));
        },
      );

      test('36. upload hydration failure is non-destructive', () {
        final draft = OnboardingDraft(
          uid: ownerUid,
          currentStep: 6,
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
          baseTimeline: const BaseTimelineDraft(classLogicalAssetId: 'asset_A'),
        );

        final restoredError = const RestoredUploadsState(
          uid: ownerUid,
          errorMessage: 'Network error',
        );

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: ownerUid,
          draft: draft,
          restoredUploads: restoredError,
        );

        expect(result.integrityFailure, isTrue);
        // Draft must NOT be mutated or wiped
        expect(result.reconciledDraft, equals(draft));
      });

      test(
        'MANDATORY RELEASE-BLOCKER CRASH WINDOW TEST (Step 5 Menu Replacement Crash)',
        () {
          final menuA = makeAsset('menu_A', UploadedAssetPurpose.eatingMenu);
          final menuB = makeAsset('menu_B', UploadedAssetPurpose.eatingMenu);

          // Saved draft state before app crash: Menu A
          final draftBeforeCrash = OnboardingDraft(
            uid: ownerUid,
            currentStep: 8,
            patiencePledgeAccepted: true,
            bodyBasics: const BodyBasicsDraft(
              ageRange: '25-34',
              gender: 'male',
              heightCm: 175,
              weightKg: 70,
            ),
            stepCompleted: const [
              true,
              true,
              true,
              true,
              true,
              true, // Step 5 completed
              true,
              true,
              false,
              false,
              false,
              false,
              false,
              false,
              false,
            ],
            lifeRole: const LifeRoleDraft(
              lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
              exerciseLevel: 'light',
              waterIntake: '2_liters',
              stressLevel: 'moderate',
              sleepQuality: 'good',
            ),
            baseTimeline: BaseTimelineDraft(
              eatingSetupPath: 'has_routine',
              pendingFutureImports: [
                PendingFutureImportDraft(
                  id: 'e1',
                  section: 'Eating',
                  mode: 'Photo AI',
                  createdAt: DateTime.now(),
                  uploadedAssetId: menuA.assetId,
                  uploadedAssetR2Key: menuA.r2Key,
                ),
              ],
              blocks: [
                TimelineBlockDraft(
                  id: 'm1',
                  section: 'eating',
                  title: 'Lunch derived from Menu A',
                  startMinute: 720,
                  endMinute: 780,
                  repeatDays: const [1, 2, 3, 4, 5, 6, 7],
                  blockType: TimelineBlockDraft.softBlockKey,
                  source: 'ai_import',
                  provenanceSourceIds: [menuA.assetId, menuA.r2Key],
                ),
              ],
            ),
          );

          // Restored durable uploads after crash: Menu B is current
          final restoredAfterCrash = RestoredUploadsState(
            uid: ownerUid,
            assetsByPurpose: {
              UploadedAssetPurpose.eatingMenu: RestoredUploadedAsset(
                asset: menuB,
              ),
            },
          );

          // Reconcile reconstructed draft against restored uploads
          final reconciliation = OnboardingUploadSourceReconciler.reconcile(
            ownerUid: ownerUid,
            draft: draftBeforeCrash,
            restoredUploads: restoredAfterCrash,
          );

          expect(reconciliation.changed, isTrue);
          expect(reconciliation.earliestAffectedStep, equals(5));

          final reconciledDraft = reconciliation.reconciledDraft;

          // Assertions:
          // 1. Menu B remains current durable upload
          expect(
            restoredAfterCrash
                .forPurpose(UploadedAssetPurpose.eatingMenu)
                ?.asset
                .assetId,
            equals(menuB.assetId),
          );

          // 2. Old Menu A AI blocks are NOT authoritative (removed)
          expect(
            reconciledDraft.baseTimeline.blocks.any(
              (b) => b.section == 'eating',
            ),
            isFalse,
          );

          // 3. Stale Pending import A replaced by Menu B
          final currentImport = reconciledDraft.baseTimeline
              .latestImportForSection('Eating');
          expect(currentImport, isNotNull);
          expect(currentImport!.uploadedAssetId, equals(menuB.assetId));

          // 4. Step 5 no longer completed, marked dirty
          expect(reconciledDraft.stepCompleted[5], isFalse);
          expect(reconciledDraft.stepDirty[5], isTrue);

          // 5. Destination reopens Step 5
          final effectiveStep = validateOnboardingResume(
            reconciledDraft,
          ).resumeStep;
          expect(effectiveStep, equals(5));

          final dest = resolveReconstructionDestination(
            ReconstructionIncomplete(
              ownerUid: ownerUid,
              profile: UserProfile.empty(uid: ownerUid),
              step: effectiveStep,
              draft: reconciledDraft,
            ),
          );
          expect(dest.kind, equals(SessionDestinationKind.resumeOnboarding));
          expect(dest.resumeStep, equals(5));

          // 6. No provenance is fabricated for B
          expect(reconciledDraft.baseTimeline.blocks, isEmpty);
        },
      );
    },
  );
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
