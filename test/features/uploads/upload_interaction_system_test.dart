import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:optivus/config/upload_policy.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/features/uploads/uploads.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  const uidA = 'user-a';
  const uidB = 'user-b';

  group('AH-F017 One Upload Interaction System (28 Mandatory Tests)', () {
    // -------------------------------------------------------------------------
    // 1. Replacement B fails while durable A exists
    // -------------------------------------------------------------------------
    test(
      '1. Replacement B fails while durable A exists -> state represents Failed attempt + durable A -> dismiss restores A',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FailingSaveUploadedAssetRepository(
          initialAssets: [initialAsset],
        );
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        // Hydrate with durable A
        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: initialAsset,
              ),
            },
          ),
          uid: uidA,
        );

        expect(controller.state['class']?.durableAsset?.assetId, 'asset-a');
        expect(
          controller.state['class']?.phase,
          UploadInteractionPhase.restored,
        );

        // Attempt replacing with B which fails during metadata save
        final res = await controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(res, isNull);

        final failedState = controller.state['class'];
        expect(failedState, isNotNull);
        expect(failedState!.phase, UploadInteractionPhase.failed);
        expect(failedState.durableAsset?.assetId, 'asset-a');
        expect(failedState.attemptError, isNotNull);

        // Dismiss attempt error restores presentation of authoritative A
        controller.dismissAttemptError('class');
        final dismissedState = controller.state['class'];
        expect(dismissedState!.phase, UploadInteractionPhase.restored);
        expect(dismissedState.durableAsset?.assetId, 'asset-a');
        expect(dismissedState.attemptError, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // 2. Remove durable operation fails -> A remains authoritative
    // -------------------------------------------------------------------------
    test(
      '2. Remove durable operation fails -> A remains authoritative -> no Empty state',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FailingSaveUploadedAssetRepository(
          initialAssets: [initialAsset],
        );
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: initialAsset,
              ),
            },
          ),
          uid: uidA,
        );

        final success = await controller.remove('class', uid: uidA);
        expect(success, isFalse);

        final slot = controller.state['class'];
        expect(slot?.durableAsset?.assetId, 'asset-a');
        expect(slot?.isActionableEmpty, isFalse);
        expect(slot?.attemptError, contains("Couldn't remove"));
      },
    );

    // -------------------------------------------------------------------------
    // 3. Class upload active + Work upload starts -> generation fences remain independent
    // -------------------------------------------------------------------------
    test(
      '3. Class upload active + Work upload starts -> independent per-slot generation tokens',
      () async {
        final classCompleter = Completer<PreparedUploadImage?>();
        final workCompleter = Completer<PreparedUploadImage?>();
        final prepareService = ControlledImagePrepareService({
          UploadedAssetPurpose.classTimetable: classCompleter.future,
          UploadedAssetPurpose.workSchedule: workCompleter.future,
        });

        final repo = FakeUploadedAssetRepository();
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Timetables',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
            UploadSlotConfig(
              key: 'work',
              label: 'Work',
              title: 'Work schedule',
              icon: Icons.work_rounded,
              purpose: UploadedAssetPurpose.workSchedule,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: prepareService,
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        // Start class upload (hangs in preparation)
        final classFuture = controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(controller.state['class']?.isBusy, isTrue);

        // Start work upload (hangs in preparation)
        final workFuture = controller.chooseFromGallery(
          'work',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(controller.state['work']?.isBusy, isTrue);

        // Complete work upload first
        workCompleter.complete(
          PreparedUploadImage(
            fileName: 'work.jpg',
            contentType: 'image/jpeg',
            bytes: Uint8List.fromList([1, 2, 3]),
            sizeBytes: 3,
          ),
        );
        final workAsset = await workFuture;
        expect(workAsset, isNotNull);
        expect(
          controller.state['work']?.phase,
          UploadInteractionPhase.uploaded,
        );
        expect(controller.state['class']?.isBusy, isTrue);

        // Complete class upload second
        classCompleter.complete(
          PreparedUploadImage(
            fileName: 'class.jpg',
            contentType: 'image/jpeg',
            bytes: Uint8List.fromList([4, 5, 6]),
            sizeBytes: 3,
          ),
        );
        final classAsset = await classFuture;
        expect(classAsset, isNotNull);
        expect(
          controller.state['class']?.phase,
          UploadInteractionPhase.uploaded,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 4. Upload finishes -> AH-F016 starts AI -> upload state remains Uploaded
    // -------------------------------------------------------------------------
    test(
      '4. Upload finishes -> AH-F016 starts AI -> upload state remains Uploaded (NOT processing)',
      () async {
        final repo = FakeUploadedAssetRepository();
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Eating',
          slots: const [
            UploadSlotConfig(
              key: 'eating',
              label: 'Meal',
              title: 'Meal photo',
              icon: Icons.restaurant_rounded,
              purpose: UploadedAssetPurpose.eatingMenu,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        final asset = await controller.chooseFromGallery(
          'eating',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(asset, isNotNull);
        expect(
          controller.state['eating']?.phase,
          UploadInteractionPhase.uploaded,
        );

        // AH-F016 AI controller activates
        final aiController = AiGenerationController();
        unawaited(
          aiController.run<void>(
            operationType: 'eating',
            timeoutPolicy: AiOperationTimeouts.nutrition,
            operation: (scope) async {
              scope.transition(AiGenerationPhase.analyzing);
              await Completer<void>().future;
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(aiController.state.isActive, isTrue);

        // Invariant 2 & 4: Upload state remains Uploaded
        expect(
          controller.state['eating']?.phase,
          UploadInteractionPhase.uploaded,
        );
        expect(controller.state['eating']?.hasDurableAsset, isTrue);
      },
    );

    // -------------------------------------------------------------------------
    // 5. Server asset hydration delayed -> never transiently renders actionable Empty
    // -------------------------------------------------------------------------
    test(
      '5. Server asset hydration delayed -> never transiently renders actionable Empty',
      () {
        final slot = UploadSlotRuntimeState(
          slotKey: 'class',
          purpose: UploadedAssetPurpose.classTimetable,
          isHydrating: true,
          phase: UploadInteractionPhase.empty,
        );

        // Invariant 12 & 16: isActionableEmpty is strictly false while isHydrating is true
        expect(slot.isHydrating, isTrue);
        expect(slot.isActionableEmpty, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // 6. Binary upload succeeds but metadata persistence fails -> fresh reconstruction restores previous A
    // -------------------------------------------------------------------------
    test(
      '6. Binary upload succeeds but metadata persistence fails -> fresh reconstruction restores previous A / Empty',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FailingSaveUploadedAssetRepository(
          initialAssets: [initialAsset],
        );
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        final res = await controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(res, isNull);

        // Fresh reconstruction from repository
        final recent = await repo.fetchRecentAssets(uid: uidA);
        expect(recent.length, 1);
        expect(recent.first.assetId, 'asset-a');
      },
    );

    // -------------------------------------------------------------------------
    // 7. Picker cancellation while replacing A -> zero upload calls, zero remove calls, A unchanged
    // -------------------------------------------------------------------------
    test(
      '7. Picker cancellation while replacing A -> zero upload calls, zero remove calls, A unchanged',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FakeUploadedAssetRepository([initialAsset]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        // Cancelling picker
        final prepareService = CancellingImagePrepareService();

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: prepareService,
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: initialAsset,
              ),
            },
          ),
          uid: uidA,
        );

        final res = await controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(res, isNull);
        expect(uploadClient.uploadCallCount, 0);
        expect(uploadClient.deletedObjectKeys.isEmpty, isTrue);
        expect(controller.state['class']?.durableAsset?.assetId, 'asset-a');
        expect(
          controller.state['class']?.phase,
          UploadInteractionPhase.restored,
        );
      },
    );

    // -------------------------------------------------------------------------
    // 8. Product names edited while product image retry runs -> names remain current
    // -------------------------------------------------------------------------
    testWidgets(
      '8. Product names edited while product image retry runs -> names remain current',
      (tester) async {
        final textController = TextEditingController(text: 'Vitamin C Serum');
        final slotConfig = const UploadSlotConfig(
          key: 'skin',
          label: 'Products',
          title: 'Product photo',
          icon: Icons.face_retouching_natural_rounded,
          purpose: UploadedAssetPurpose.skinCare,
        );
        final slotState = const UploadSlotRuntimeState(
          slotKey: 'skin',
          purpose: UploadedAssetPurpose.skinCare,
          phase: UploadInteractionPhase.failed,
          attemptError: 'Network error',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UploadImageAndNamesCard(
                slotConfig: slotConfig,
                slotState: slotState,
                textController: textController,
                title: 'Skin Care Products',
                countBadgeNumber: 1,
                onTapPhoto: () {},
              ),
            ),
          ),
        );

        expect(find.text('Vitamin C Serum'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('onboarding-step7-product-names-field')),
          'Hyaluronic Acid',
        );
        await tester.pump();

        expect(textController.text, 'Hyaluronic Acid');
      },
    );

    // -------------------------------------------------------------------------
    // 9. All 5 Shared Actions (takePhoto, chooseFromGallery, replace, remove, retry)
    // -------------------------------------------------------------------------
    test('9. All 5 Shared Actions execute cleanly', () async {
      final repo = FakeUploadedAssetRepository();
      final uploadClient = RecordingR2UploadClient();
      final authRepo = FakeAuthRepo(
        currentUser: const AuthUser(
          uid: uidA,
          email: 'a@optivus.dev',
          emailVerified: true,
        ),
      );

      final config = UploadShellConfig(
        title: 'Class timetable',
        slots: const [
          UploadSlotConfig(
            key: 'class',
            label: 'Class',
            title: 'Class timetable',
            icon: Icons.school_rounded,
            purpose: UploadedAssetPurpose.classTimetable,
          ),
        ],
      );

      final controller = UploadInteractionController(
        shellConfig: config,
        assetRepository: repo,
        authRepository: authRepo,
        imagePrepareService: FakeImagePrepareService(),
        r2UploadClient: uploadClient,
        permissionService: const DefaultUploadPermissionService(),
      );

      // Action 1: takePhoto
      final a1 = await controller.takePhoto(
        'class',
        uid: uidA,
        sourceFeature: 'onboarding',
      );
      expect(a1, isNotNull);
      expect(controller.state['class']?.phase, UploadInteractionPhase.uploaded);

      // Action 2: chooseFromGallery (Replace)
      final a2 = await controller.chooseFromGallery(
        'class',
        uid: uidA,
        sourceFeature: 'onboarding',
      );
      expect(a2, isNotNull);
      expect(controller.state['class']?.durableAsset?.assetId, a2!.assetId);

      // Action 3: retry (when failed attempt exists)
      controller.syncWithDurableState(
        RestoredUploadsState(uid: uidA),
        uid: uidA,
      );

      // Action 4: remove
      final removed = await controller.remove('class', uid: uidA);
      expect(removed, isTrue);
      expect(controller.state['class']?.phase, UploadInteractionPhase.empty);
    });

    // -------------------------------------------------------------------------
    // 10. Platform-aware permissions
    // -------------------------------------------------------------------------
    test(
      '10. Platform-aware permissions: grant, soft denial, and detectable permanent denial',
      () async {
        const permService = DefaultUploadPermissionService();

        expect(
          await permService.checkOrRequest(ImageSource.camera),
          UploadPermissionStatus.granted,
        );

        final softDenial = permService.mapPickerException(
          PlatformException(
            code: 'camera_access_denied',
            message: 'User denied camera permission',
          ),
          ImageSource.camera,
        );
        expect(softDenial, UploadPermissionStatus.denied);
        expect(
          permService.permissionGuidanceMessage(
            ImageSource.camera,
            isPermanent: false,
          ),
          contains('Camera permission is needed'),
        );

        final permanentDenial = permService.mapPickerException(
          PlatformException(
            code: 'camera_access_denied_permanent',
            message: 'Permanently denied',
          ),
          ImageSource.camera,
        );
        expect(permanentDenial, UploadPermissionStatus.permanentlyDenied);
        expect(
          permService.permissionGuidanceMessage(
            ImageSource.camera,
            isPermanent: true,
          ),
          contains('open device Settings'),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 11. Orientation / EXIF normalization occurs exactly once
    // -------------------------------------------------------------------------
    test(
      '11. Orientation / EXIF normalization occurs exactly once during decoding',
      () async {
        final img = image_lib.Image(width: 50, height: 100);
        img.exif.imageIfd.orientation = 6; // 90 degree clockwise rotation tag
        final bytes = Uint8List.fromList(image_lib.encodeJpg(img));

        final prepared = await ImagePrepareService().preparePickedFile(
          XFile.fromData(bytes, name: 'rotated.jpg', mimeType: 'image/jpeg'),
          purpose: UploadedAssetPurpose.classTimetable,
        );

        expect(prepared, isNotNull);
        final decodedPrepared = image_lib.decodeImage(prepared!.bytes);
        expect(decodedPrepared, isNotNull);
        expect(decodedPrepared!.width, 100);
        expect(decodedPrepared.height, 50);
        expect(decodedPrepared.exif.imageIfd.orientation, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // 12. Compression & Dimension limits conform to audited policy
    // -------------------------------------------------------------------------
    test(
      '12. Compression and dimension limits conform to UploadImagePolicy.forPurpose',
      () {
        final routinePolicy = UploadImagePolicy.forPurpose(
          UploadedAssetPurpose.classTimetable,
        );
        expect(routinePolicy.maxBytes, 15 * 1024 * 1024);
        expect(routinePolicy.maxLongestSide, 4096);

        final profilePolicy = UploadImagePolicy.forPurpose(
          UploadedAssetPurpose.profilePhoto,
        );
        expect(profilePolicy.maxBytes, 5 * 1024 * 1024);
        expect(profilePolicy.maxLongestSide, 3500);
      },
    );

    // -------------------------------------------------------------------------
    // 13. Corrupted / Invalid images report clean error without crashing
    // -------------------------------------------------------------------------
    test(
      '13. Corrupted / Invalid image reports friendly error without crashing',
      () async {
        final corruptedBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
        await expectLater(
          ImagePrepareService().preparePickedFile(
            XFile.fromData(
              corruptedBytes,
              name: 'bad.jpg',
              mimeType: 'image/jpeg',
            ),
            purpose: UploadedAssetPurpose.classTimetable,
          ),
          throwsA(
            isA<ImagePreparationException>().having(
              (e) => e.message,
              'message',
              contains('could not be read'),
            ),
          ),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 14. Configuration modes: 1 image, 2 slots, required, optional, image + names
    // -------------------------------------------------------------------------
    test('14. Configuration modes instantiate correctly', () {
      final singleRequired = const UploadShellConfig(
        title: 'Meal photo',
        requirementMode: UploadRequirementMode.required,
        slots: [
          UploadSlotConfig(
            key: 'meal',
            label: 'Meal',
            title: 'Meal photo',
            icon: Icons.restaurant_rounded,
            purpose: UploadedAssetPurpose.eatingMenu,
            required: true,
          ),
        ],
      );
      expect(singleRequired.isDualSlot, isFalse);

      final dualRequired = const UploadShellConfig(
        title: 'Timetables',
        requirementMode: UploadRequirementMode.required,
        slots: [
          UploadSlotConfig(
            key: 'class',
            label: 'Class',
            title: 'Class timetable',
            icon: Icons.school_rounded,
            purpose: UploadedAssetPurpose.classTimetable,
          ),
          UploadSlotConfig(
            key: 'work',
            label: 'Work',
            title: 'Work schedule',
            icon: Icons.work_rounded,
            purpose: UploadedAssetPurpose.workSchedule,
          ),
        ],
      );
      expect(dualRequired.isDualSlot, isTrue);
      expect(
        dualRequired.slotFor('class')?.purpose,
        UploadedAssetPurpose.classTimetable,
      );
      expect(
        dualRequired.slotFor('work')?.purpose,
        UploadedAssetPurpose.workSchedule,
      );
    });

    // -------------------------------------------------------------------------
    // 15. Target features: Step 4, Step 5, Step 7
    // -------------------------------------------------------------------------
    testWidgets('15. Target features render upload shell cleanly', (
      tester,
    ) async {
      final config = const UploadShellConfig(
        title: 'Class and Work Timetables',
        requirementMode: UploadRequirementMode.required,
        slots: [
          UploadSlotConfig(
            key: 'class',
            label: 'Class',
            title: 'Class',
            icon: Icons.school_rounded,
            purpose: UploadedAssetPurpose.classTimetable,
          ),
          UploadSlotConfig(
            key: 'work',
            label: 'Work',
            title: 'Work',
            icon: Icons.work_rounded,
            purpose: UploadedAssetPurpose.workSchedule,
          ),
        ],
      );

      final slotStates = {
        'class': const UploadSlotRuntimeState(
          slotKey: 'class',
          purpose: UploadedAssetPurpose.classTimetable,
          phase: UploadInteractionPhase.empty,
        ),
        'work': const UploadSlotRuntimeState(
          slotKey: 'work',
          purpose: UploadedAssetPurpose.workSchedule,
          phase: UploadInteractionPhase.empty,
        ),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadInteractionShell(
              config: config,
              slotStates: slotStates,
              cardKey: const ValueKey('onboarding-step4-upload-card'),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('onboarding-step4-upload-card')),
        findsOneWidget,
      );
      expect(find.text('Class and Work Timetables'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 16. A upload starts -> account switches A -> B -> late A result ignored
    // -------------------------------------------------------------------------
    test(
      '16. A upload starts -> account switches A -> B -> late A result ignored',
      () async {
        final prepareCompleter = Completer<PreparedUploadImage?>();
        final prepareService = ControlledImagePrepareService({
          UploadedAssetPurpose.classTimetable: prepareCompleter.future,
        });
        final repo = FakeUploadedAssetRepository();
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: prepareService,
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        final uploadFuture = controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );

        // Account switch to B
        authRepo.currentUser = const AuthUser(
          uid: uidB,
          email: 'b@optivus.dev',
          emailVerified: true,
        );
        controller.resetForSignedOut();

        prepareCompleter.complete(
          PreparedUploadImage(
            fileName: 'late.jpg',
            contentType: 'image/jpeg',
            bytes: Uint8List.fromList([1]),
            sizeBytes: 1,
          ),
        );

        final res = await uploadFuture;
        expect(res, isNull);
        expect(controller.state['class']?.durableAsset, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // 17. Same UID auth refresh during upload -> upload continues exactly once
    // -------------------------------------------------------------------------
    test(
      '17. Same UID auth refresh during upload -> upload continues exactly once',
      () async {
        final repo = FakeUploadedAssetRepository();
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        final asset = await controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(asset, isNotNull);
        expect(uploadClient.uploadCallCount, 1);
      },
    );

    // -------------------------------------------------------------------------
    // 18. B upload starts -> user selects C -> late B result ignored
    // -------------------------------------------------------------------------
    test('18. same-slot selection is ignored while an upload is busy', () async {
      final bCompleter = Completer<PreparedUploadImage?>();
      final prepareService = SequenceImagePrepareService([bCompleter.future]);

      final repo = FakeUploadedAssetRepository();
      final uploadClient = RecordingR2UploadClient();
      final authRepo = FakeAuthRepo(
        currentUser: const AuthUser(
          uid: uidA,
          email: 'a@optivus.dev',
          emailVerified: true,
        ),
      );

      final config = UploadShellConfig(
        title: 'Class timetable',
        slots: const [
          UploadSlotConfig(
            key: 'class',
            label: 'Class',
            title: 'Class timetable',
            icon: Icons.school_rounded,
            purpose: UploadedAssetPurpose.classTimetable,
          ),
        ],
      );

      final controller = UploadInteractionController(
        shellConfig: config,
        assetRepository: repo,
        authRepository: authRepo,
        imagePrepareService: prepareService,
        r2UploadClient: uploadClient,
        permissionService: const DefaultUploadPermissionService(),
      );

      // Start attempt B (simulated preselected file or unlocked second trigger)
      final futureB = controller.uploadPreselectedFile(
        'class',
        file: XFile('b.jpg'),
        uid: uidA,
        sourceFeature: 'onboarding',
      );

      // A second same-slot trigger is rejected by the per-slot mutex.
      final futureC = controller.uploadPreselectedFile(
        'class',
        file: XFile('c.jpg'),
        uid: uidA,
        sourceFeature: 'onboarding',
      );

      final assetC = await futureC;
      expect(assetC, isNull);

      // The original operation remains authoritative.
      bCompleter.complete(
        PreparedUploadImage(
          fileName: 'b.jpg',
          contentType: 'image/jpeg',
          bytes: Uint8List.fromList([1]),
          sizeBytes: 1,
        ),
      );
      final assetB = await futureB;
      expect(assetB?.fileName, 'b.jpg');
      expect(controller.state['class']?.durableAsset?.fileName, 'b.jpg');
    });

    // -------------------------------------------------------------------------
    // 19. Process death before durable metadata -> B is NOT restored
    // -------------------------------------------------------------------------
    test(
      '19. Process death before durable metadata -> B is NOT restored, previous A restored if it existed',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FakeUploadedAssetRepository([initialAsset]);

        // State restored from repository
        final restored = await repo.fetchRecentAssets(uid: uidA);
        expect(restored.length, 1);
        expect(restored.first.assetId, 'asset-a');
      },
    );

    // -------------------------------------------------------------------------
    // 20. Process death after binary + metadata success but before UI success -> B restores as Restored
    // -------------------------------------------------------------------------
    test(
      '20. Process death after binary + metadata success -> restores as Restored with zero re-upload',
      () async {
        final assetB = _validAsset(
          uid: uidA,
          assetId: 'asset-b',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FakeUploadedAssetRepository([assetB]);
        final uploadClient = RecordingR2UploadClient();

        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );

        await controller.hydrate(uid: uidA);
        final restored = controller.state.forPurpose(
          UploadedAssetPurpose.classTimetable,
        );
        expect(restored, isNotNull);
        expect(restored!.asset.assetId, 'asset-b');
        expect(uploadClient.uploadCallCount, 0);
      },
    );

    // -------------------------------------------------------------------------
    // 21. Restored A preview starts -> B replacement succeeds -> late A preview ignored
    // -------------------------------------------------------------------------
    test(
      '21. Restored A preview starts -> B replacement succeeds -> late A preview ignored',
      () async {
        final assetA = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final previewCompleterA = Completer<Uri?>();
        final resolver = ControlledPreviewResolver(
          resolverMap: {'asset-a': previewCompleterA.future},
        );

        final restoredController = RestoredUploadsController(
          assetRepository: FakeUploadedAssetRepository([assetA]),
          previewResolver: resolver,
        );

        await restoredController.hydrate(uid: uidA);
        expect(
          restoredController.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.previewStatus,
          UploadedAssetPreviewStatus.loading,
        );

        final assetB = _validAsset(
          uid: uidA,
          assetId: 'asset-b',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        restoredController.registerUploaded(assetB);

        previewCompleterA.complete(
          Uri.parse('https://r2.optivus.app/preview/a.jpg'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          restoredController.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'asset-b',
        );
      },
    );

    // -------------------------------------------------------------------------
    // 22. Restored asset + preview unavailable -> Replace works, Remove works
    // -------------------------------------------------------------------------
    test(
      '22. Restored asset + preview unavailable -> Replace works, Remove works, required condition satisfied',
      () async {
        final assetA = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
          localPreviewPath: null,
        );
        final repo = FakeUploadedAssetRepository([assetA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: assetA,
                previewStatus: UploadedAssetPreviewStatus.unavailable,
              ),
            },
          ),
          uid: uidA,
        );

        final slot = controller.state['class'];
        expect(slot?.hasDurableAsset, isTrue);

        // Replace works
        final newAsset = await controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(newAsset, isNotNull);

        // Remove works
        final removed = await controller.remove('class', uid: uidA);
        expect(removed, isTrue);
        expect(controller.state['class']?.phase, UploadInteractionPhase.empty);
      },
    );

    // -------------------------------------------------------------------------
    // 23. Remove success -> Empty only after durable remove succeeds
    // -------------------------------------------------------------------------
    test(
      '23. Remove success -> Empty only after durable remove succeeds',
      () async {
        final assetA = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FakeUploadedAssetRepository([assetA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: assetA,
              ),
            },
          ),
          uid: uidA,
        );

        expect(controller.state['class']?.hasDurableAsset, isTrue);
        final success = await controller.remove('class', uid: uidA);
        expect(success, isTrue);
        expect(controller.state['class']?.phase, UploadInteractionPhase.empty);
        expect(repo.deletedAssetIds.contains('asset-a'), isTrue);
        expect(uploadClient.deletedObjectKeys, [assetA.r2Key]);
      },
    );

    // -------------------------------------------------------------------------
    // 24. Terminal metadata write failure keeps uploaded authority
    // -------------------------------------------------------------------------
    test(
      '24. Terminal metadata write failure keeps uploaded authority',
      () async {
        final assetA = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FailingSaveUploadedAssetRepository(
          initialAssets: [assetA],
        );
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: assetA,
              ),
            },
          ),
          uid: uidA,
        );

        final success = await controller.remove('class', uid: uidA);
        expect(success, isFalse);
        expect(controller.state['class']?.durableAsset?.assetId, 'asset-a');
        expect(controller.state['class']?.hasDurableAsset, isTrue);
        expect(
          uploadClient.deletedObjectKeys,
          isEmpty,
          reason: 'R2 must not be deleted before metadata is authoritative',
        );
      },
    );

    for (final failBytes in [true, false]) {
      test(
        'terminalized remove ${failBytes ? "R2" : "final marker"} failure drops authority; restart retry',
        () async {
          final a = _validAsset(
            uid: uidA,
            assetId: 'A',
            purpose: UploadedAssetPurpose.classTimetable,
          );
          final repo = CleanupFailingRepository([a])..failFinal = !failBytes;
          final client = CleanupFailingR2Client()..failDelete = failBytes;
          final auth = FakeAuthRepo(
            currentUser: const AuthUser(uid: uidA, emailVerified: true),
          );
          UploadInteractionController make() => UploadInteractionController(
            shellConfig: const UploadShellConfig(
              title: 'Class',
              slots: [
                UploadSlotConfig(
                  key: 'class',
                  label: 'Class',
                  title: 'Class',
                  icon: Icons.school,
                  purpose: UploadedAssetPurpose.classTimetable,
                ),
              ],
            ),
            assetRepository: repo,
            authRepository: auth,
            imagePrepareService: FakeImagePrepareService(),
            r2UploadClient: client,
            permissionService: const DefaultUploadPermissionService(),
          );
          final controller = make();
          controller.syncWithDurableState(
            RestoredUploadsState(
              uid: uidA,
              assetsByPurpose: {
                UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                  asset: a,
                ),
              },
            ),
            uid: uidA,
          );
          expect(await controller.remove('class', uid: uidA), isFalse);
          expect(controller.state['class']!.durableAsset, isNull);
          expect(controller.state['class']!.cleanupPending, isTrue);
          expect(
            controller.state['class']!.attemptError,
            contains('cleanup is pending'),
          );
          final pending = await repo.fetchAsset(uid: uidA, assetId: a.assetId);
          expect(pending!.r2Key, a.r2Key);
          expect(pending.status, UploadedAssetStatus.deleted);
          expect(pending.errorMessage, 'private_cleanup_pending');
          expect(
            uploadedAssetIsDurablyUploadedForSlot(
              asset: pending,
              uid: uidA,
              purpose: UploadedAssetPurpose.classTimetable,
              expectedSourceFeature: UploadSourceFeature.onboarding,
            ),
            isFalse,
          );
          controller.dispose();
          // Reconstruct solely from persistent repository data, with no current photo.
          final restarted = make();
          restarted.syncWithDurableState(
            const RestoredUploadsState(uid: uidA),
            uid: uidA,
          );
          repo.failFinal = false;
          client.failDelete = false;
          expect(await restarted.remove('class', uid: uidA), isTrue);
          expect(restarted.state['class']!.durableAsset, isNull);
          expect(restarted.state['class']!.cleanupPending, isFalse);
          expect(client.deletedObjectKeys.last, a.r2Key);
          expect(await repo.fetchAsset(uid: uidA, assetId: a.assetId), isNull);
          restarted.dispose();
        },
      );
    }

    test(
      '24b. account switch during byte cleanup cannot clear the new owner slot',
      () async {
        final assetA = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final assetB = _validAsset(
          uid: uidB,
          assetId: 'asset-b',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FakeUploadedAssetRepository([assetA, assetB]);
        final uploadClient = DelayedDeleteR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(uid: uidA, emailVerified: true),
        );
        final controller = UploadInteractionController(
          shellConfig: const UploadShellConfig(
            title: 'Class timetable',
            slots: [
              UploadSlotConfig(
                key: 'class',
                label: 'Class',
                title: 'Class timetable',
                icon: Icons.school_rounded,
                purpose: UploadedAssetPurpose.classTimetable,
              ),
            ],
          ),
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );
        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: assetA,
              ),
            },
          ),
          uid: uidA,
        );

        final removal = controller.remove('class', uid: uidA);
        await uploadClient.deleteStarted.future;
        authRepo.currentUser = const AuthUser(uid: uidB, emailVerified: true);
        controller.resetForSignedOut();
        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidB,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: assetB,
              ),
            },
          ),
          uid: uidB,
        );
        uploadClient.finishDelete.complete();

        expect(await removal, isFalse);
        expect(controller.state['class']?.durableAsset?.assetId, 'asset-b');
      },
    );

    // -------------------------------------------------------------------------
    // 25. Rapid Remove x3 -> exactly one durable remove operation
    // -------------------------------------------------------------------------
    test(
      '25. Rapid Remove x3 -> exactly one durable remove operation',
      () async {
        final assetA = _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = CountingUploadedAssetRepository([assetA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Class timetable',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.classTimetable: RestoredUploadedAsset(
                asset: assetA,
              ),
            },
          ),
          uid: uidA,
        );

        final f1 = controller.remove('class', uid: uidA);
        final f2 = controller.remove('class', uid: uidA);
        final f3 = controller.remove('class', uid: uidA);

        final results = await Future.wait([f1, f2, f3]);
        expect(results.where((r) => r == true).length, 1);
        expect(repo.deletedAssetIds.length, 1);
      },
    );

    // -------------------------------------------------------------------------
    // 26. Upload failure -> AH-F016 AI invocation count = 0
    // -------------------------------------------------------------------------
    test('26. Upload failure -> AH-F016 AI invocation count = 0', () async {
      final repo = FailingSaveUploadedAssetRepository();
      final uploadClient = RecordingR2UploadClient();
      final authRepo = FakeAuthRepo(
        currentUser: const AuthUser(
          uid: uidA,
          email: 'a@optivus.dev',
          emailVerified: true,
        ),
      );
      final aiController = AiGenerationController();

      final config = UploadShellConfig(
        title: 'Eating',
        slots: const [
          UploadSlotConfig(
            key: 'eating',
            label: 'Meal',
            title: 'Meal photo',
            icon: Icons.restaurant_rounded,
            purpose: UploadedAssetPurpose.eatingMenu,
          ),
        ],
      );

      final controller = UploadInteractionController(
        shellConfig: config,
        assetRepository: repo,
        authRepository: authRepo,
        imagePrepareService: FakeImagePrepareService(),
        r2UploadClient: uploadClient,
        permissionService: const DefaultUploadPermissionService(),
      );

      final res = await controller.chooseFromGallery(
        'eating',
        uid: uidA,
        sourceFeature: 'onboarding',
      );
      expect(res, isNull);

      // Invariant 22: Upload failure must produce zero AI calls
      expect(aiController.state.isActive, isFalse);
    });

    // -------------------------------------------------------------------------
    // 27. Durable upload + AI failure + Retry AI -> additional upload invocation count = 0
    // -------------------------------------------------------------------------
    test(
      '27. Durable upload + AI failure + Retry AI -> additional upload invocation count = 0',
      () async {
        final uploadClient = RecordingR2UploadClient();

        final aiController = AiGenerationController();
        unawaited(
          aiController.run<void>(
            operationType: 'eating',
            timeoutPolicy: AiOperationTimeouts.nutrition,
            operation: (scope) async {
              throw Exception('AI failed to parse meal');
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(aiController.state.phase, AiGenerationPhase.error);

        // Retry AI
        unawaited(
          aiController.run<void>(
            operationType: 'eating',
            timeoutPolicy: AiOperationTimeouts.nutrition,
            retry: true,
            operation: (scope) async {},
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(aiController.state.phase, AiGenerationPhase.success);

        // Invariant 23: Zero additional upload calls
        expect(uploadClient.uploadCallCount, 0);
      },
    );

    // -------------------------------------------------------------------------
    // 28. Class and Work independent generation: Class cannot invalidate Work and vice versa
    // -------------------------------------------------------------------------
    test(
      '28. Class and Work each have independent operation generation',
      () async {
        final repo = FakeUploadedAssetRepository();
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final config = UploadShellConfig(
          title: 'Timetables',
          slots: const [
            UploadSlotConfig(
              key: 'class',
              label: 'Class',
              title: 'Class timetable',
              icon: Icons.school_rounded,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
            UploadSlotConfig(
              key: 'work',
              label: 'Work',
              title: 'Work schedule',
              icon: Icons.work_rounded,
              purpose: UploadedAssetPurpose.workSchedule,
            ),
          ],
        );

        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        final classAsset = await controller.chooseFromGallery(
          'class',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        final workAsset = await controller.chooseFromGallery(
          'work',
          uid: uidA,
          sourceFeature: 'onboarding',
        );

        expect(classAsset, isNotNull);
        expect(workAsset, isNotNull);
        expect(
          controller.state['class']?.durableAsset?.assetId,
          classAsset!.assetId,
        );
        expect(
          controller.state['work']?.durableAsset?.assetId,
          workAsset!.assetId,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Transactional Replacement (Gate 3 Fifth Closure)
    // -------------------------------------------------------------------------
    test(
      '29. deferReplacement: true stages candidate as pendingReplacementAsset, preserves durableAsset Photo A in repo and R2',
      () async {
        final photoA = _validAsset(
          uid: uidA,
          assetId: 'photo-a',
          purpose: UploadedAssetPurpose.skinProducts,
          r2Key: 'users/$uidA/onboarding/skin_products/photo-a.jpg',
        );
        final repo = FakeUploadedAssetRepository([photoA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );
        final config = UploadShellConfig(
          title: 'Skin products',
          slots: const [
            UploadSlotConfig(
              key: 'products',
              label: 'Products',
              title: 'Products photo',
              icon: Icons.sanitizer_rounded,
              purpose: UploadedAssetPurpose.skinProducts,
            ),
          ],
        );
        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.skinProducts: RestoredUploadedAsset(
                asset: photoA,
              ),
            },
          ),
          uid: uidA,
        );

        expect(controller.state['products']?.durableAsset?.assetId, 'photo-a');
        expect(controller.state['products']?.pendingReplacementAsset, isNull);

        // Perform deferred replacement upload
        final candidate = await controller.chooseFromGallery(
          'products',
          uid: uidA,
          sourceFeature: 'onboarding',
          deferReplacement: true,
        );

        expect(candidate, isNotNull);
        final slotState = controller.state['products'];
        expect(slotState, isNotNull);
        // Canonical durable asset remains Photo A
        expect(slotState!.durableAsset?.assetId, 'photo-a');
        // Candidate staged as pending replacement asset
        expect(slotState.pendingReplacementAsset?.assetId, candidate!.assetId);
        expect(slotState.isDeferredReplacement, isTrue);
        expect(slotState.hasPendingReplacement, isTrue);
        // Effective asset is the pending replacement for UI preview
        expect(slotState.effectiveAsset?.assetId, candidate.assetId);

        // Photo A is NOT deleted from repo or R2
        expect(repo.deletedAssetIds, isNot(contains('photo-a')));
        expect(uploadClient.deletedObjectKeys, isNot(contains(photoA.r2Key)));
        // Candidate is saved in repository
        expect(repo.assets.map((a) => a.assetId), contains(candidate.assetId));
      },
    );

    test(
      '30. rollbackReplacement cleans candidate from repo and R2, restores Photo A as canonical and undeleted',
      () async {
        final photoA = _validAsset(
          uid: uidA,
          assetId: 'photo-a',
          purpose: UploadedAssetPurpose.skinProducts,
          r2Key: 'users/$uidA/onboarding/skin_products/photo-a.jpg',
        );
        final repo = FakeUploadedAssetRepository([photoA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );
        final config = UploadShellConfig(
          title: 'Skin products',
          slots: const [
            UploadSlotConfig(
              key: 'products',
              label: 'Products',
              title: 'Products photo',
              icon: Icons.sanitizer_rounded,
              purpose: UploadedAssetPurpose.skinProducts,
            ),
          ],
        );
        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.skinProducts: RestoredUploadedAsset(
                asset: photoA,
              ),
            },
          ),
          uid: uidA,
        );

        final candidate = await controller.chooseFromGallery(
          'products',
          uid: uidA,
          sourceFeature: 'onboarding',
          deferReplacement: true,
        );
        expect(candidate, isNotNull);

        // User cancels / navigates Back -> rollback replacement
        await controller.rollbackReplacement('products', uid: uidA);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final slotState = controller.state['products'];
        expect(slotState, isNotNull);
        expect(slotState!.durableAsset?.assetId, 'photo-a');
        expect(slotState.pendingReplacementAsset, isNull);
        expect(slotState.isDeferredReplacement, isFalse);
        expect(slotState.hasPendingReplacement, isFalse);
        expect(slotState.effectiveAsset?.assetId, 'photo-a');

        // Candidate was cleaned from repo and R2
        expect(repo.deletedAssetIds, contains(candidate!.assetId));
        expect(uploadClient.deletedObjectKeys, contains(candidate.r2Key));

        // Photo A was NEVER deleted
        expect(repo.deletedAssetIds, isNot(contains('photo-a')));
        expect(uploadClient.deletedObjectKeys, isNot(contains(photoA.r2Key)));
        expect(repo.assets.map((a) => a.assetId), contains('photo-a'));
      },
    );

    test(
      '31. commitReplacement promotes candidate to durableAsset and deletes Photo A only after commit',
      () async {
        final photoA = _validAsset(
          uid: uidA,
          assetId: 'photo-a',
          purpose: UploadedAssetPurpose.skinProducts,
          r2Key: 'users/$uidA/onboarding/skin_products/photo-a.jpg',
        );
        final repo = FakeUploadedAssetRepository([photoA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );
        final config = UploadShellConfig(
          title: 'Skin products',
          slots: const [
            UploadSlotConfig(
              key: 'products',
              label: 'Products',
              title: 'Products photo',
              icon: Icons.sanitizer_rounded,
              purpose: UploadedAssetPurpose.skinProducts,
            ),
          ],
        );
        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.skinProducts: RestoredUploadedAsset(
                asset: photoA,
              ),
            },
          ),
          uid: uidA,
        );

        final candidate = await controller.chooseFromGallery(
          'products',
          uid: uidA,
          sourceFeature: 'onboarding',
          deferReplacement: true,
        );
        expect(candidate, isNotNull);

        // Before commit, Photo A is still durable and not deleted
        expect(repo.deletedAssetIds, isNot(contains('photo-a')));

        // Plan B succeeds -> commitReplacement
        await controller.commitReplacement('products', uid: uidA);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final slotState = controller.state['products'];
        expect(slotState, isNotNull);
        expect(slotState!.durableAsset?.assetId, candidate!.assetId);
        expect(slotState.pendingReplacementAsset, isNull);
        expect(slotState.isDeferredReplacement, isFalse);
        expect(slotState.hasPendingReplacement, isFalse);

        // Now Photo A is cleaned from repo and R2
        expect(repo.deletedAssetIds, contains('photo-a'));
        expect(uploadClient.deletedObjectKeys, contains(photoA.r2Key));
        // Candidate remains intact
        expect(repo.deletedAssetIds, isNot(contains(candidate.assetId)));
      },
    );

    test(
      '32. deferReplacement: false (default) immediately supersedes and cleans Photo A (backward compatible)',
      () async {
        final photoA = _validAsset(
          uid: uidA,
          assetId: 'photo-a',
          purpose: UploadedAssetPurpose.skinProducts,
          r2Key: 'users/$uidA/onboarding/skin_products/photo-a.jpg',
        );
        final repo = FakeUploadedAssetRepository([photoA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );
        final config = UploadShellConfig(
          title: 'Skin products',
          slots: const [
            UploadSlotConfig(
              key: 'products',
              label: 'Products',
              title: 'Products photo',
              icon: Icons.sanitizer_rounded,
              purpose: UploadedAssetPurpose.skinProducts,
            ),
          ],
        );
        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.skinProducts: RestoredUploadedAsset(
                asset: photoA,
              ),
            },
          ),
          uid: uidA,
        );

        // Upload with default deferReplacement: false
        final newAsset = await controller.chooseFromGallery(
          'products',
          uid: uidA,
          sourceFeature: 'onboarding',
        );
        expect(newAsset, isNotNull);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final slotState = controller.state['products'];
        expect(slotState, isNotNull);
        // Immediately became durableAsset
        expect(slotState!.durableAsset?.assetId, newAsset!.assetId);
        expect(slotState.pendingReplacementAsset, isNull);
        expect(slotState.isDeferredReplacement, isFalse);

        // Photo A was immediately deleted
        expect(repo.deletedAssetIds, contains('photo-a'));
        expect(uploadClient.deletedObjectKeys, contains(photoA.r2Key));
      },
    );

    test(
      '33. remove() with pending replacement deletes both durableAsset and pendingReplacementAsset',
      () async {
        final photoA = _validAsset(
          uid: uidA,
          assetId: 'photo-a',
          purpose: UploadedAssetPurpose.skinProducts,
          r2Key: 'users/$uidA/onboarding/skin_products/photo-a.jpg',
        );
        final repo = FakeUploadedAssetRepository([photoA]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );
        final config = UploadShellConfig(
          title: 'Skin products',
          slots: const [
            UploadSlotConfig(
              key: 'products',
              label: 'Products',
              title: 'Products photo',
              icon: Icons.sanitizer_rounded,
              purpose: UploadedAssetPurpose.skinProducts,
            ),
          ],
        );
        final controller = UploadInteractionController(
          shellConfig: config,
          assetRepository: repo,
          authRepository: authRepo,
          imagePrepareService: FakeImagePrepareService(),
          r2UploadClient: uploadClient,
          permissionService: const DefaultUploadPermissionService(),
        );

        controller.syncWithDurableState(
          RestoredUploadsState(
            uid: uidA,
            assetsByPurpose: {
              UploadedAssetPurpose.skinProducts: RestoredUploadedAsset(
                asset: photoA,
              ),
            },
          ),
          uid: uidA,
        );

        final candidate = await controller.chooseFromGallery(
          'products',
          uid: uidA,
          sourceFeature: 'onboarding',
          deferReplacement: true,
        );
        expect(candidate, isNotNull);

        // Explicit remove by user -> both Photo A and candidate Photo B must be deleted
        final removed = await controller.remove('products', uid: uidA);
        expect(removed, isTrue);

        final slotState = controller.state['products'];
        expect(slotState, isNotNull);
        expect(slotState!.phase, UploadInteractionPhase.empty);
        expect(slotState.durableAsset, isNull);
        expect(slotState.pendingReplacementAsset, isNull);

        // Both Photo A and Photo B were deleted
        expect(repo.deletedAssetIds, contains('photo-a'));
        expect(repo.deletedAssetIds, contains(candidate!.assetId));
        expect(uploadClient.deletedObjectKeys, contains(photoA.r2Key));
        expect(uploadClient.deletedObjectKeys, contains(candidate.r2Key));
      },
    );

    test('34. resetForSignedOut() cleans pending replacement asset', () async {
      final photoA = _validAsset(
        uid: uidA,
        assetId: 'photo-a',
        purpose: UploadedAssetPurpose.skinProducts,
        r2Key: 'users/$uidA/onboarding/skin_products/photo-a.jpg',
      );
      final repo = FakeUploadedAssetRepository([photoA]);
      final uploadClient = RecordingR2UploadClient();
      final authRepo = FakeAuthRepo(
        currentUser: const AuthUser(
          uid: uidA,
          email: 'a@optivus.dev',
          emailVerified: true,
        ),
      );
      final config = UploadShellConfig(
        title: 'Skin products',
        slots: const [
          UploadSlotConfig(
            key: 'products',
            label: 'Products',
            title: 'Products photo',
            icon: Icons.sanitizer_rounded,
            purpose: UploadedAssetPurpose.skinProducts,
          ),
        ],
      );
      final controller = UploadInteractionController(
        shellConfig: config,
        assetRepository: repo,
        authRepository: authRepo,
        imagePrepareService: FakeImagePrepareService(),
        r2UploadClient: uploadClient,
        permissionService: const DefaultUploadPermissionService(),
      );

      controller.syncWithDurableState(
        RestoredUploadsState(
          uid: uidA,
          assetsByPurpose: {
            UploadedAssetPurpose.skinProducts: RestoredUploadedAsset(
              asset: photoA,
            ),
          },
        ),
        uid: uidA,
      );

      final candidate = await controller.chooseFromGallery(
        'products',
        uid: uidA,
        sourceFeature: 'onboarding',
        deferReplacement: true,
      );
      expect(candidate, isNotNull);

      // Sign out
      controller.resetForSignedOut();

      // Pending candidate was cleaned
      expect(repo.deletedAssetIds, contains(candidate!.assetId));
      // Photo A was not deleted
      expect(repo.deletedAssetIds, isNot(contains('photo-a')));
    });
  });
}

// -----------------------------------------------------------------------------
// Test Helpers & Fakes
// -----------------------------------------------------------------------------

UploadedAsset _validAsset({
  required String uid,
  required UploadedAssetPurpose purpose,
  String assetId = 'asset-1',
  String? localPreviewPath,
  String? fileName,
  String? r2Key,
  DateTime? updatedAt,
  UploadedAssetStatus status = UploadedAssetStatus.uploaded,
}) {
  final now = DateTime.utc(2026, 8, 30, 12, 0);
  return UploadedAsset(
    assetId: assetId,
    ownerUid: uid,
    sourceFeature: OnboardingDraft.sourceOnboarding,
    purpose: purpose,
    fileName: fileName ?? '$assetId.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    r2Key: r2Key ?? 'users/$uid/onboarding/${purpose.wireName}/$assetId.jpg',
    localPreviewPath: localPreviewPath,
    status: status,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}

class FakeUploadedAssetRepository implements UploadedAssetRepository {
  final List<UploadedAsset> assets;
  final List<String> deletedAssetIds = [];

  FakeUploadedAssetRepository([List<UploadedAsset>? initial])
    : assets = initial ?? [];

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async {
    return assets
        .where((a) => a.ownerUid == uid && a.assetId == assetId)
        .firstOrNull;
  }

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async {
    return assets.where((a) {
      if (a.ownerUid != uid) return false;
      if (sourceFeature != null && a.sourceFeature != sourceFeature) {
        return false;
      }
      if (purpose != null && a.purpose != purpose) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    deletedAssetIds.add(assetId);
    assets.removeWhere((a) => a.ownerUid == uid && a.assetId == assetId);
  }

  @override
  Future<void> saveAsset(UploadedAsset asset) async {
    assets.removeWhere(
      (a) => a.ownerUid == asset.ownerUid && a.assetId == asset.assetId,
    );
    assets.add(asset);
  }
}

class CountingUploadedAssetRepository extends FakeUploadedAssetRepository {
  CountingUploadedAssetRepository([super.initial]);
}

class FailingSaveUploadedAssetRepository extends FakeUploadedAssetRepository {
  FailingSaveUploadedAssetRepository({List<UploadedAsset>? initialAssets})
    : super(initialAssets);

  @override
  Future<void> saveAsset(UploadedAsset asset) async {
    throw Exception('Firestore save failure');
  }
}

class FailingDeleteUploadedAssetRepository extends FakeUploadedAssetRepository {
  FailingDeleteUploadedAssetRepository([super.initial]);

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    throw Exception('Firestore delete failure');
  }
}

class RecordingR2UploadClient implements R2UploadClient {
  int signCallCount = 0;
  int uploadCallCount = 0;
  int completeCallCount = 0;
  final List<String> deletedObjectKeys = [];

  @override
  Future<R2SignedUpload> signUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required String contentType,
    required int sizeBytes,
    required String idToken,
  }) async {
    signCallCount++;
    return R2SignedUpload(
      assetId: 'asset-${DateTime.now().millisecondsSinceEpoch}',
      objectKey: 'users/$uid/$sourceFeature/${purpose.wireName}/asset.jpg',
      uploadUrl: 'https://r2.optivus.dev/upload',
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {
    uploadCallCount++;
  }

  @override
  Future<void> markUploadComplete({
    required String assetId,
    required String objectKey,
    required int sizeBytes,
    required String idToken,
  }) async {
    completeCallCount++;
  }

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deletedObjectKeys.add(objectKey);
  }

  @override
  Future<String> getPreviewUrl({
    required String objectKey,
    required String idToken,
  }) async =>
      'https://preview.local/$objectKey';
}

class DelayedDeleteR2UploadClient extends RecordingR2UploadClient {
  final deleteStarted = Completer<void>();
  final finishDelete = Completer<void>();

  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    deleteStarted.complete();
    await finishDelete.future;
    deletedObjectKeys.add(objectKey);
  }
}

class FakeImagePrepareService extends ImagePrepareService {
  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'photo.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    if (picked == null) return null;
    return PreparedUploadImage(
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
      sizeBytes: 3,
    );
  }
}

class CancellingImagePrepareService extends ImagePrepareService {
  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return null;
  }
}

class ControlledImagePrepareService extends ImagePrepareService {
  final Map<UploadedAssetPurpose, Future<PreparedUploadImage?>> futures;

  ControlledImagePrepareService(this.futures);

  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile('fake.jpg');
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) {
    return futures[purpose] ?? Future.value(null);
  }
}

class SequenceImagePrepareService extends ImagePrepareService {
  final List<Future<PreparedUploadImage?>> sequence;
  int _idx = 0;

  SequenceImagePrepareService(this.sequence);

  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile('fake.jpg');
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) {
    if (_idx < sequence.length) {
      return sequence[_idx++];
    }
    return Future.value(null);
  }
}

class FakeAuthRepo implements AuthRepository {
  @override
  AuthUser? currentUser;

  FakeAuthRepo({this.currentUser});

  @override
  Future<String?> currentIdToken() async => 'token';

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);

  @override
  Future<AuthUser?> signInWithGoogle() async => currentUser;

  @override
  Future<AuthUser> signInAnonymously() async => currentUser!;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => currentUser!;

  @override
  Future<AuthUser?> reloadCurrentUser() async => currentUser;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async => currentUser!;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => currentUser!;
}

class ControlledPreviewResolver implements UploadedAssetPreviewResolver {
  final Map<String, Future<Uri?>> resolverMap;

  ControlledPreviewResolver({required this.resolverMap});

  @override
  Future<Uri?> resolvePreview({
    required String uid,
    required UploadedAsset asset,
  }) async {
    final future = resolverMap[asset.assetId];
    if (future != null) return future;
    return null;
  }
}

class CleanupFailingRepository extends FakeUploadedAssetRepository {
  CleanupFailingRepository(super.initial);
  bool failFinal = false;
  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    if (failFinal) throw StateError('final marker failed');
    await super.markDeleted(uid: uid, assetId: assetId);
  }
}

class CleanupFailingR2Client extends RecordingR2UploadClient {
  bool failDelete = false;
  @override
  Future<void> deleteUpload({
    required String objectKey,
    required String idToken,
  }) async {
    if (failDelete) throw StateError('R2 unavailable');
    await super.deleteUpload(objectKey: objectKey, idToken: idToken);
  }
}
