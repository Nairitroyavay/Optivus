import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/upload_source_identity.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/onboarding_upload_source_reconciler.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  const uid = 'user_123';

  UploadedAsset createAsset({
    required String id,
    required UploadedAssetPurpose purpose,
    String owner = uid,
  }) {
    final purposeWire = purpose.wireName;
    return UploadedAsset(
      assetId: id,
      ownerUid: owner,
      sourceFeature: OnboardingDraft.sourceOnboarding,
      purpose: purpose,
      fileName: '$id.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 1024,
      r2Key: 'users/$owner/onboarding/$purposeWire/$id.jpg',
      status: UploadedAssetStatus.uploaded,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  RestoredUploadsState createRestoredUploads({
    String owner = uid,
    UploadedAsset? classAsset,
    UploadedAsset? workAsset,
    UploadedAsset? eatingAsset,
    String? errorMessage,
  }) {
    return RestoredUploadsState(
      uid: owner,
      errorMessage: errorMessage,
      assetsByPurpose: {
        if (classAsset != null)
          UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
            asset: classAsset,
          ),
        if (workAsset != null)
          UploadedAssetPurpose.workSchedule: RestoredUploadedAsset(
            asset: workAsset,
          ),
        if (eatingAsset != null)
          UploadedAssetPurpose.eatingMenu: RestoredUploadedAsset(
            asset: eatingAsset,
          ),
      },
    );
  }

  group('OnboardingUploadSourceReconciler - Pure Unit Tests', () {
    test('1. no Step 4/5 upload-backed data -> unchanged', () {
      final draft = OnboardingDraft(
        uid: uid,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: const BaseTimelineDraft(),
      );
      final restored = createRestoredUploads();

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isFalse);
      expect(result.earliestAffectedStep, isNull);
      expect(result.integrityFailure, isFalse);
      expect(result.reconciledDraft, equals(draft));
    });

    test('2. valid Step4 Class draft A + current Class A -> unchanged', () {
      final classA = createAsset(
        id: 'class_A',
        purpose: UploadedAssetPurpose.classTimetable,
      );
      final draft = OnboardingDraft(
        uid: uid,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: BaseTimelineDraft(
          classLogicalAssetId: classA.assetId,
          classLogicalAssetR2Key: classA.r2Key,
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
              provenanceSourceIds: [classA.assetId, classA.r2Key],
            ),
          ],
        ),
      );
      final restored = createRestoredUploads(classAsset: classA);

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isFalse);
      expect(result.earliestAffectedStep, isNull);
    });

    test('3. valid Step4 Work draft A + current Work A -> unchanged', () {
      final workA = createAsset(
        id: 'work_A',
        purpose: UploadedAssetPurpose.workSchedule,
      );
      final draft = OnboardingDraft(
        uid: uid,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey),
        baseTimeline: BaseTimelineDraft(
          workLogicalAssetId: workA.assetId,
          workLogicalAssetR2Key: workA.r2Key,
          blocks: [
            TimelineBlockDraft(
              id: 'w1',
              section: 'job_work_business',
              title: 'Work Shift',
              startMinute: 540,
              endMinute: 1020,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: [workA.assetId, workA.r2Key],
            ),
          ],
        ),
      );
      final restored = createRestoredUploads(workAsset: workA);

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isFalse);
      expect(result.earliestAffectedStep, isNull);
    });

    test('4. valid studentWorking swapped mapping -> unchanged', () {
      // Physical: classAsset = C, workAsset = W
      final physClass = createAsset(
        id: 'phys_C',
        purpose: UploadedAssetPurpose.classTimetable,
      );
      final physWork = createAsset(
        id: 'phys_W',
        purpose: UploadedAssetPurpose.workSchedule,
      );

      // Logical Classes = phys_W, Logical Work = phys_C
      final draft = OnboardingDraft(
        uid: uid,
        lifeRole: const LifeRoleDraft(
          lifeRole: LifeRoleDraft.studentWorkingKey,
        ),
        baseTimeline: BaseTimelineDraft(
          classLogicalAssetId: physWork.assetId,
          classLogicalAssetR2Key: physWork.r2Key,
          workLogicalAssetId: physClass.assetId,
          workLogicalAssetR2Key: physClass.r2Key,
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
              provenanceSourceIds: [physWork.assetId, physWork.r2Key],
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
              provenanceSourceIds: [physClass.assetId, physClass.r2Key],
            ),
          ],
        ),
      );

      final restored = createRestoredUploads(
        classAsset: physClass,
        workAsset: physWork,
      );

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isFalse);
      expect(result.earliestAffectedStep, isNull);
    });

    test(
      '5. Step4 Class draft A + current replacement B -> Class stale, Work preserved',
      () {
        final classA = createAsset(
          id: 'class_A',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final classB = createAsset(
          id: 'class_B',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final workW = createAsset(
          id: 'work_W',
          purpose: UploadedAssetPurpose.workSchedule,
        );

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 8,
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
            lifeRole: LifeRoleDraft.studentWorkingKey,
          ),
          baseTimeline: BaseTimelineDraft(
            classLogicalAssetId: classA.assetId,
            classLogicalAssetR2Key: classA.r2Key,
            workLogicalAssetId: workW.assetId,
            workLogicalAssetR2Key: workW.r2Key,
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
                id: 'w1',
                section: 'job_work_business',
                title: 'Shift',
                startMinute: 800,
                endMinute: 1000,
                repeatDays: const [2],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [workW.assetId, workW.r2Key],
              ),
            ],
          ),
        );

        final restored = createRestoredUploads(
          classAsset: classB,
          workAsset: workW,
        );

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: draft,
          restoredUploads: restored,
        );

        expect(result.changed, isTrue);
        expect(result.earliestAffectedStep, equals(4));
        expect(result.reasonCodes, contains('step4_class_source_stale'));

        final reconciled = result.reconciledDraft;
        expect(reconciled.currentStep, equals(4));
        expect(reconciled.stepCompleted[4], isFalse);
        expect(reconciled.stepDirty[4], isTrue);

        // Class AI blocks removed
        expect(
          reconciled.baseTimeline.blocks.any((b) => b.section == 'classes'),
          isFalse,
        );
        // Work AI blocks preserved
        expect(
          reconciled.baseTimeline.blocks.any(
            (b) => b.section == 'job_work_business',
          ),
          isTrue,
        );
        // Logical Class asset updated to classB
        expect(
          reconciled.baseTimeline.classLogicalAssetId,
          equals(classB.assetId),
        );
        expect(
          reconciled.baseTimeline.workLogicalAssetId,
          equals(workW.assetId),
        );
      },
    );

    test(
      '6. Step4 Work draft A + current replacement B -> Work stale, Class preserved',
      () {
        final classC = createAsset(
          id: 'class_C',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final workA = createAsset(
          id: 'work_A',
          purpose: UploadedAssetPurpose.workSchedule,
        );
        final workB = createAsset(
          id: 'work_B',
          purpose: UploadedAssetPurpose.workSchedule,
        );

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 6,
          stepCompleted: const [
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
            false,
            false,
          ],
          lifeRole: const LifeRoleDraft(
            lifeRole: LifeRoleDraft.studentWorkingKey,
          ),
          baseTimeline: BaseTimelineDraft(
            classLogicalAssetId: classC.assetId,
            classLogicalAssetR2Key: classC.r2Key,
            workLogicalAssetId: workA.assetId,
            workLogicalAssetR2Key: workA.r2Key,
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
                provenanceSourceIds: [classC.assetId, classC.r2Key],
              ),
              TimelineBlockDraft(
                id: 'w1',
                section: 'job_work_business',
                title: 'Shift 1',
                startMinute: 800,
                endMinute: 1000,
                repeatDays: const [2],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [workA.assetId, workA.r2Key],
              ),
            ],
          ),
        );

        final restored = createRestoredUploads(
          classAsset: classC,
          workAsset: workB,
        );

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: draft,
          restoredUploads: restored,
        );

        expect(result.changed, isTrue);
        expect(result.earliestAffectedStep, equals(4));
        expect(result.reasonCodes, contains('step4_work_source_stale'));

        final reconciled = result.reconciledDraft;
        expect(
          reconciled.baseTimeline.blocks.any((b) => b.section == 'classes'),
          isTrue,
        );
        expect(
          reconciled.baseTimeline.blocks.any(
            (b) => b.section == 'job_work_business',
          ),
          isFalse,
        );
      },
    );

    test(
      '7. swapped: logical Classes = old work W1, current physical work = W2 -> update to W2, invalidate Class AI',
      () {
        final workW1 = createAsset(
          id: 'work_W1',
          purpose: UploadedAssetPurpose.workSchedule,
        );
        final workW2 = createAsset(
          id: 'work_W2',
          purpose: UploadedAssetPurpose.workSchedule,
        );

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 6,
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
          baseTimeline: BaseTimelineDraft(
            classLogicalAssetId: workW1.assetId,
            classLogicalAssetR2Key: workW1.r2Key,
            blocks: [
              TimelineBlockDraft(
                id: 'c1',
                section: 'classes',
                title: 'Class from W1',
                startMinute: 540,
                endMinute: 600,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [workW1.assetId, workW1.r2Key],
              ),
            ],
          ),
        );

        final restored = createRestoredUploads(workAsset: workW2);

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: draft,
          restoredUploads: restored,
        );

        expect(result.changed, isTrue);
        expect(result.earliestAffectedStep, equals(4));

        final reconciled = result.reconciledDraft;
        expect(
          reconciled.baseTimeline.classLogicalAssetId,
          equals(workW2.assetId),
        );
        expect(reconciled.baseTimeline.blocks, isEmpty);
      },
    );

    test('8. missing Class current asset -> Class stale', () {
      final classA = createAsset(
        id: 'class_A',
        purpose: UploadedAssetPurpose.classTimetable,
      );
      final draft = OnboardingDraft(
        uid: uid,
        currentStep: 5,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: BaseTimelineDraft(
          classLogicalAssetId: classA.assetId,
          classLogicalAssetR2Key: classA.r2Key,
          blocks: [
            TimelineBlockDraft(
              id: 'c1',
              section: 'classes',
              title: 'Class A',
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

      final restored = createRestoredUploads(); // No assets uploaded

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isTrue);
      expect(result.earliestAffectedStep, equals(4));
      expect(result.reconciledDraft.baseTimeline.classLogicalAssetId, isNull);
    });

    test('9. missing Work current asset -> Work stale', () {
      final workA = createAsset(
        id: 'work_A',
        purpose: UploadedAssetPurpose.workSchedule,
      );
      final draft = OnboardingDraft(
        uid: uid,
        currentStep: 5,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey),
        baseTimeline: BaseTimelineDraft(
          workLogicalAssetId: workA.assetId,
          workLogicalAssetR2Key: workA.r2Key,
          blocks: [
            TimelineBlockDraft(
              id: 'w1',
              section: 'job_work_business',
              title: 'Work A',
              startMinute: 540,
              endMinute: 1000,
              repeatDays: const [1],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_import',
              provenanceSourceIds: [workA.assetId, workA.r2Key],
            ),
          ],
        ),
      );

      final restored = createRestoredUploads(); // No assets uploaded

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isTrue);
      expect(result.earliestAffectedStep, equals(4));
      expect(result.reconciledDraft.baseTimeline.workLogicalAssetId, isNull);
    });

    test(
      '10. Step5 has_routine: draft Menu A + current Menu A -> unchanged',
      () {
        final menuA = createAsset(
          id: 'menu_A',
          purpose: UploadedAssetPurpose.eatingMenu,
        );
        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 6,
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
                title: 'Lunch',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [menuA.assetId, menuA.r2Key],
              ),
            ],
          ),
        );

        final restored = createRestoredUploads(eatingAsset: menuA);

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: draft,
          restoredUploads: restored,
        );

        expect(result.changed, isFalse);
        expect(result.earliestAffectedStep, isNull);
      },
    );

    test(
      '11. Step5 has_routine: draft Menu A + current Menu B -> Eating AI invalidated',
      () {
        final menuA = createAsset(
          id: 'menu_A',
          purpose: UploadedAssetPurpose.eatingMenu,
        );
        final menuB = createAsset(
          id: 'menu_B',
          purpose: UploadedAssetPurpose.eatingMenu,
        );

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 8,
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
                title: 'Lunch',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [menuA.assetId, menuA.r2Key],
              ),
            ],
          ),
        );

        final restored = createRestoredUploads(eatingAsset: menuB);

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: draft,
          restoredUploads: restored,
        );

        expect(result.changed, isTrue);
        expect(result.earliestAffectedStep, equals(5));
        expect(result.reasonCodes, contains('step5_eating_source_stale'));

        final reconciled = result.reconciledDraft;
        expect(reconciled.currentStep, equals(5));
        expect(reconciled.stepCompleted[5], isFalse);
        expect(reconciled.stepDirty[5], isTrue);

        // Old Eating AI block removed
        expect(
          reconciled.baseTimeline.blocks.any((b) => b.section == 'eating'),
          isFalse,
        );

        // No applied import is fabricated before Menu B is analyzed.
        final importB = reconciled.baseTimeline.latestImportForSection(
          'Eating',
        );
        expect(importB, isNull);
        expect(reconciled.baseTimeline.eatingSetupPath, 'has_routine');
        expect(reconciled.stepCompleted[14], isFalse);
        expect(reconciled.stepDirty[14], isTrue);
        expect(reconciled.baseTimeline.validateEatingSetup(), isNotNull);

        final second = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: reconciled,
          restoredUploads: restored,
        );
        expect(second.changed, isFalse);
        expect(second.reconciledDraft, reconciled);
      },
    );

    test(
      '12. Step5 has_routine: draft Menu A + no current Eating upload -> Step5 affected',
      () {
        final menuA = createAsset(
          id: 'menu_A',
          purpose: UploadedAssetPurpose.eatingMenu,
        );
        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 6,
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
                title: 'Lunch',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [menuA.assetId, menuA.r2Key],
              ),
            ],
          ),
        );

        final restored = createRestoredUploads(); // No eating upload

        final result = OnboardingUploadSourceReconciler.reconcile(
          ownerUid: uid,
          draft: draft,
          restoredUploads: restored,
        );

        expect(result.changed, isTrue);
        expect(result.earliestAffectedStep, equals(5));
        expect(result.reconciledDraft.baseTimeline.blocks, isEmpty);
        expect(
          result.reconciledDraft.baseTimeline.latestImportForSection('Eating'),
          isNull,
        );
      },
    );

    test('13. Step5 create path: no Eating upload -> unaffected', () {
      final draft = OnboardingDraft(
        uid: uid,
        currentStep: 6,
        baseTimeline: BaseTimelineDraft(
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
              provenanceSourceIds: const [],
            ),
          ],
        ),
      );

      final restored = createRestoredUploads();

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.changed, isFalse);
      expect(result.earliestAffectedStep, isNull);
    });

    test('14. reconciler idempotency', () {
      final classA = createAsset(
        id: 'class_A',
        purpose: UploadedAssetPurpose.classTimetable,
      );
      final classB = createAsset(
        id: 'class_B',
        purpose: UploadedAssetPurpose.classTimetable,
      );

      final draft = OnboardingDraft(
        uid: uid,
        currentStep: 8,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: BaseTimelineDraft(
          classLogicalAssetId: classA.assetId,
          classLogicalAssetR2Key: classA.r2Key,
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
              provenanceSourceIds: [classA.assetId, classA.r2Key],
            ),
          ],
        ),
      );

      final restored = createRestoredUploads(classAsset: classB);

      // First run
      final firstResult = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );
      expect(firstResult.changed, isTrue);

      // Second run on already reconciled draft
      final secondResult = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: firstResult.reconciledDraft,
        restoredUploads: restored,
      );
      expect(secondResult.changed, isFalse);
      expect(secondResult.reconciledDraft, equals(firstResult.reconciledDraft));
    });

    test('15. RestoredUploads uid mismatch -> integrity failure', () {
      final draft = OnboardingDraft(
        uid: uid,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      );

      final restored = createRestoredUploads(owner: 'other_user');

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.integrityFailure, isTrue);
      expect(result.reasonCodes, contains('restored_uploads_owner_mismatch'));
      expect(result.reconciledDraft, equals(draft));
    });

    test('RestoredUploads error state -> integrity failure', () {
      final draft = OnboardingDraft(
        uid: uid,
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        baseTimeline: const BaseTimelineDraft(classLogicalAssetId: 'class_A'),
      );

      final restored = createRestoredUploads(
        errorMessage: 'Network timeout loading uploads',
      );

      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: draft,
        restoredUploads: restored,
      );

      expect(result.integrityFailure, isTrue);
      expect(result.reasonCodes, contains('restored_uploads_error'));
      expect(result.reconciledDraft, equals(draft));
    });

    test('exact source helper requires both identifiers for every purpose', () {
      for (final purpose in [
        UploadedAssetPurpose.classTimetable,
        UploadedAssetPurpose.workSchedule,
        UploadedAssetPurpose.eatingMenu,
      ]) {
        final asset = createAsset(
          id: '${purpose.wireName}_A',
          purpose: purpose,
        );
        expect(
          uploadedSourceIdentityMatches(
            assetId: asset.assetId,
            r2Key: asset.r2Key,
            asset: asset,
          ),
          isTrue,
        );
        expect(
          uploadedSourceIdentityMatches(
            assetId: asset.assetId,
            r2Key: 'users/$uid/onboarding/${purpose.wireName}/wrong.jpg',
            asset: asset,
          ),
          isFalse,
        );
        expect(
          uploadedSourceIdentityMatches(
            assetId: 'wrong',
            r2Key: asset.r2Key,
            asset: asset,
          ),
          isFalse,
        );
        expect(
          provenanceContainsExactUploadIdentity(
            [asset.assetId],
            asset.assetId,
            asset.r2Key,
          ),
          isFalse,
        );
        expect(
          provenanceContainsExactUploadIdentity(
            [asset.r2Key],
            asset.assetId,
            asset.r2Key,
          ),
          isFalse,
        );
        expect(
          provenanceContainsExactUploadIdentity(
            [asset.assetId, asset.r2Key],
            asset.assetId,
            asset.r2Key,
          ),
          isTrue,
        );
      }
    });

    test('corrupt Class ID/key pair is stale even when ID matches', () {
      final classA = createAsset(
        id: 'class_A',
        purpose: UploadedAssetPurpose.classTimetable,
      );
      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: OnboardingDraft(
          uid: uid,
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
          baseTimeline: BaseTimelineDraft(
            classLogicalAssetId: classA.assetId,
            classLogicalAssetR2Key:
                'users/$uid/onboarding/class_timetable/wrong.jpg',
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
                provenanceSourceIds: [classA.assetId, classA.r2Key],
              ),
            ],
          ),
        ),
        restoredUploads: createRestoredUploads(classAsset: classA),
      );
      expect(result.changed, isTrue);
      expect(result.reasonCodes, contains('step4_class_source_stale'));
    });

    test('Work block with only one provenance token is stale', () {
      final workA = createAsset(
        id: 'work_A',
        purpose: UploadedAssetPurpose.workSchedule,
      );
      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: OnboardingDraft(
          uid: uid,
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey),
          baseTimeline: BaseTimelineDraft(
            workLogicalAssetId: workA.assetId,
            workLogicalAssetR2Key: workA.r2Key,
            blocks: [
              TimelineBlockDraft(
                id: 'w1',
                section: 'job_work_business',
                title: 'Work',
                startMinute: 540,
                endMinute: 600,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.hardBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [workA.assetId],
              ),
            ],
          ),
        ),
        restoredUploads: createRestoredUploads(workAsset: workA),
      );
      expect(result.changed, isTrue);
      expect(result.reasonCodes, contains('step4_work_source_stale'));
    });

    test('Eating import with matching key but wrong ID is removed', () {
      final menuA = createAsset(
        id: 'menu_A',
        purpose: UploadedAssetPurpose.eatingMenu,
      );
      final result = OnboardingUploadSourceReconciler.reconcile(
        ownerUid: uid,
        draft: OnboardingDraft(
          uid: uid,
          baseTimeline: BaseTimelineDraft(
            eatingSetupPath: 'has_routine',
            pendingFutureImports: [
              PendingFutureImportDraft(
                id: 'e1',
                section: 'Eating',
                mode: 'Photo AI',
                createdAt: DateTime.utc(2026),
                uploadedAssetId: 'wrong',
                uploadedAssetR2Key: menuA.r2Key,
              ),
            ],
            blocks: [
              TimelineBlockDraft(
                id: 'm1',
                section: 'eating',
                title: 'Meal',
                startMinute: 720,
                endMinute: 780,
                repeatDays: const [1],
                blockType: TimelineBlockDraft.softBlockKey,
                source: 'ai_import',
                provenanceSourceIds: [menuA.assetId, menuA.r2Key],
              ),
            ],
          ),
        ),
        restoredUploads: createRestoredUploads(eatingAsset: menuA),
      );
      expect(result.changed, isTrue);
      expect(result.reconciledDraft.baseTimeline.pendingFutureImports, isEmpty);
      expect(result.reconciledDraft.baseTimeline.blocks, isEmpty);
    });
  });
}
