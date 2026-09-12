import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/app_preferences_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/region_settings_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/server_reconstructor.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

void main() {
  const uidA = 'user-a';
  const uidB = 'user-b';

  group('AH-F010 Restore Uploaded Asset State', () {
    test(
      'A & B: Successful uploaded metadata restores without localPath as uploaded',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(uid: uidA, purpose: UploadedAssetPurpose.classTimetable),
        ]);
        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );

        await controller.hydrate(uid: uidA);

        final restored = controller.state.forPurpose(
          UploadedAssetPurpose.classTimetable,
        );
        expect(restored, isNotNull);
        expect(restored!.asset.assetId, 'asset-1');
        expect(restored.asset.ownerUid, uidA);
        expect(restored.asset.purpose, UploadedAssetPurpose.classTimetable);
        expect(restored.asset.localPreviewPath, isNull);
        expect(
          uploadedAssetIsDurablyUploadedForSlot(
            asset: restored.asset,
            uid: uidA,
            purpose: UploadedAssetPurpose.classTimetable,
            expectedSourceFeature: UploadSourceFeature.onboarding,
          ),
          isTrue,
        );
      },
    );

    test(
      'C: Remote preview success resolves previewUri and available status',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(uid: uidA, purpose: UploadedAssetPurpose.workSchedule),
        ]);
        final previewUri = Uri.parse('https://r2.optivus.app/preview/work.jpg');
        final resolver = FakePreviewResolver(fixedUri: previewUri);

        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: resolver,
        );

        await controller.hydrate(uid: uidA);
        await Future<void>.delayed(Duration.zero);

        final restored = controller.state.forPurpose(
          UploadedAssetPurpose.workSchedule,
        );
        expect(restored, isNotNull);
        expect(restored!.previewStatus, UploadedAssetPreviewStatus.available);
        expect(restored.previewUri, previewUri);
      },
    );

    test(
      'D: Remote preview failure shows uploaded with preview unavailable',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(uid: uidA, purpose: UploadedAssetPurpose.eatingMenu),
        ]);
        final resolver = FakePreviewResolver(shouldFail: true);

        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: resolver,
        );

        await controller.hydrate(uid: uidA);
        await Future<void>.delayed(Duration.zero);

        final restored = controller.state.forPurpose(
          UploadedAssetPurpose.eatingMenu,
        );
        expect(restored, isNotNull);
        expect(restored!.previewStatus, UploadedAssetPreviewStatus.unavailable);
        expect(restored.previewUri, isNull);
        expect(
          uploadedAssetIsDurablyUploadedForSlot(
            asset: restored.asset,
            uid: uidA,
            purpose: UploadedAssetPurpose.eatingMenu,
            expectedSourceFeature: UploadSourceFeature.onboarding,
          ),
          isTrue,
        );
      },
    );

    test(
      'E & F & U & Section 54: Zero-cache reinstall assertion (zero upload & AI calls)',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            purpose: UploadedAssetPurpose.classTimetable,
            localPreviewPath: null,
          ),
        ]);
        final uploadClient = RecordingR2UploadClient();
        final routineAi = RecordingRoutineImportAiClient();
        final skinAi = RecordingSkinCareAiClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            uploadedAssetRepositoryProvider.overrideWithValue(repo),
            r2UploadClientProvider.overrideWithValue(uploadClient),
            routineImportAiClientProvider.overrideWithValue(routineAi),
            skinCareAiClientProvider.overrideWithValue(skinAi),
            authRepositoryProvider.overrideWithValue(authRepo),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
            appPreferencesRepositoryProvider.overrideWithValue(
              FakeAppPreferencesRepository(),
            ),
            regionSettingsRepositoryProvider.overrideWithValue(
              FakeRegionSettingsRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(restoredUploadsProvider.notifier);
        await controller.hydrate(uid: uidA);

        final restored = container
            .read(restoredUploadsProvider)
            .forPurpose(UploadedAssetPurpose.classTimetable);
        expect(restored, isNotNull);
        expect(
          uploadedAssetIsDurablyUploadedForSlot(
            asset: restored!.asset,
            uid: uidA,
            purpose: UploadedAssetPurpose.classTimetable,
            expectedSourceFeature: UploadSourceFeature.onboarding,
          ),
          isTrue,
        );
        expect(uploadClient.signCallCount, 0);
        expect(uploadClient.uploadCallCount, 0);
        expect(uploadClient.completeCallCount, 0);
        expect(routineAi.callCount, 0);
        expect(skinAi.callCount, 0);
      },
    );

    test(
      'G & H: Missing local File path handled safely without FileSystemException crash',
      () {
        const nonExistentPath =
            '/data/user/0/com.optivus/cache/non_existent_photo.jpg';
        final asset = _validAsset(
          uid: uidA,
          purpose: UploadedAssetPurpose.classTimetable,
          localPreviewPath: nonExistentPath,
        );

        expect(File(nonExistentPath).existsSync(), isFalse);
        final safePath = usableUploadedAssetLocalPreviewPath(asset);
        expect(safePath, isNull);
      },
    );

    test('I: Owner mismatch rejected from hydration', () async {
      final repo = FakeUploadedAssetRepository([
        _validAsset(uid: uidA, purpose: UploadedAssetPurpose.classTimetable),
      ]);
      final controller = RestoredUploadsController(
        assetRepository: repo,
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );

      await controller.hydrate(uid: uidB);

      final restored = controller.state.forPurpose(
        UploadedAssetPurpose.classTimetable,
      );
      expect(restored, isNull);
      expect(controller.state.assetsByPurpose.isEmpty, isTrue);
    });

    test('J: Purpose mismatch rejected for slot', () {
      final asset = _validAsset(
        uid: uidA,
        purpose: UploadedAssetPurpose.skinCare,
      );

      final isMatchForClass = uploadedAssetIsDurablyUploadedForSlot(
        asset: asset,
        uid: uidA,
        purpose: UploadedAssetPurpose.classTimetable,
        expectedSourceFeature: UploadSourceFeature.onboarding,
      );
      expect(isMatchForClass, isFalse);

      final isMatchForSkin = uploadedAssetIsDurablyUploadedForSlot(
        asset: asset,
        uid: uidA,
        purpose: UploadedAssetPurpose.skinCare,
        expectedSourceFeature: UploadSourceFeature.onboarding,
      );
      expect(isMatchForSkin, isTrue);
    });

    test(
      'K, L, M: Pending, failed, deleted statuses are not restored as valid uploaded',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            purpose: UploadedAssetPurpose.classTimetable,
            status: UploadedAssetStatus.pending,
          ),
          _validAsset(
            uid: uidA,
            purpose: UploadedAssetPurpose.workSchedule,
            status: UploadedAssetStatus.failed,
          ),
          _validAsset(
            uid: uidA,
            purpose: UploadedAssetPurpose.eatingMenu,
            status: UploadedAssetStatus.deleted,
          ),
        ]);
        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );

        await controller.hydrate(uid: uidA);

        expect(
          controller.state.forPurpose(UploadedAssetPurpose.classTimetable),
          isNull,
        );
        expect(
          controller.state.forPurpose(UploadedAssetPurpose.workSchedule),
          isNull,
        );
        expect(
          controller.state.forPurpose(UploadedAssetPurpose.eatingMenu),
          isNull,
        );
      },
    );

    test('Deleted newest metadata tombstones older uploaded asset', () async {
      final older = DateTime.utc(2026, 8, 30, 12);
      final newer = older.add(const Duration(minutes: 1));
      final repo = FakeUploadedAssetRepository([
        _validAsset(
          uid: uidA,
          assetId: 'asset-old',
          purpose: UploadedAssetPurpose.classTimetable,
          updatedAt: older,
        ),
        _validAsset(
          uid: uidA,
          assetId: 'asset-deleted',
          purpose: UploadedAssetPurpose.classTimetable,
          status: UploadedAssetStatus.deleted,
          updatedAt: newer,
        ),
      ]);
      final controller = RestoredUploadsController(
        assetRepository: repo,
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );

      await controller.hydrate(uid: uidA);

      expect(
        controller.state.forPurpose(UploadedAssetPurpose.classTimetable),
        isNull,
      );
    });

    test(
      'Failed replacement metadata preserves older uploaded asset',
      () async {
        final older = DateTime.utc(2026, 8, 30, 12);
        final newer = older.add(const Duration(minutes: 1));
        final repo = FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            assetId: 'asset-old',
            purpose: UploadedAssetPurpose.classTimetable,
            updatedAt: older,
          ),
          _validAsset(
            uid: uidA,
            assetId: 'asset-failed',
            purpose: UploadedAssetPurpose.classTimetable,
            status: UploadedAssetStatus.failed,
            updatedAt: newer,
          ),
        ]);
        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );

        await controller.hydrate(uid: uidA);

        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'asset-old',
        );
      },
    );

    test(
      'new B survives later superseded A delete on fresh hydration',
      () async {
        final t1 = DateTime.utc(2026, 9, 1, 9);
        final t2 = DateTime.utc(2026, 9, 1, 10);
        final t3 = DateTime.utc(2026, 9, 1, 10, 0, 1);
        final repo = FakeUploadedAssetRepository([
          // Firestore updatedAt-desc order: deleted A is returned before B.
          _validAsset(
            uid: uidA,
            assetId: 'class-a',
            purpose: UploadedAssetPurpose.classTimetable,
            status: UploadedAssetStatus.deleted,
            createdAt: t1,
            updatedAt: t3,
          ),
          _validAsset(
            uid: uidA,
            assetId: 'class-b',
            purpose: UploadedAssetPurpose.classTimetable,
            createdAt: t2,
            updatedAt: t2,
          ),
        ]);

        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );
        await controller.hydrate(uid: uidA);

        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'class-b',
        );
      },
    );

    test('new B wins when superseded A cleanup failed', () async {
      final t1 = DateTime.utc(2026, 9, 1, 9);
      final t2 = DateTime.utc(2026, 9, 1, 10);
      final controller = RestoredUploadsController(
        assetRepository: FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            assetId: 'class-a',
            purpose: UploadedAssetPurpose.classTimetable,
            createdAt: t1,
            updatedAt: t1,
          ),
          _validAsset(
            uid: uidA,
            assetId: 'class-b',
            purpose: UploadedAssetPurpose.classTimetable,
            createdAt: t2,
            updatedAt: t2,
          ),
        ]),
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );
      await controller.hydrate(uid: uidA);
      expect(
        controller.state
            .forPurpose(UploadedAssetPurpose.classTimetable)
            ?.asset
            .assetId,
        'class-b',
      );
    });

    test('explicit delete of current B prevents A resurrection', () async {
      final t1 = DateTime.utc(2026, 9, 1, 9);
      final t2 = DateTime.utc(2026, 9, 1, 10);
      final t3 = DateTime.utc(2026, 9, 1, 11);
      final controller = RestoredUploadsController(
        assetRepository: FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            assetId: 'class-b',
            purpose: UploadedAssetPurpose.classTimetable,
            status: UploadedAssetStatus.deleted,
            createdAt: t2,
            updatedAt: t3,
          ),
          _validAsset(
            uid: uidA,
            assetId: 'class-a',
            purpose: UploadedAssetPurpose.classTimetable,
            createdAt: t1,
            updatedAt: t1,
          ),
        ]),
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );
      await controller.hydrate(uid: uidA);
      expect(
        controller.state.forPurpose(UploadedAssetPurpose.classTimetable),
        isNull,
      );
    });

    for (final status in [
      UploadedAssetStatus.failed,
      UploadedAssetStatus.pending,
      UploadedAssetStatus.uploading,
    ]) {
      test('newer ${status.name} attempt preserves older upload', () async {
        final t1 = DateTime.utc(2026, 9, 1, 9);
        final t2 = DateTime.utc(2026, 9, 1, 10);
        final controller = RestoredUploadsController(
          assetRepository: FakeUploadedAssetRepository([
            _validAsset(
              uid: uidA,
              assetId: 'class-attempt',
              purpose: UploadedAssetPurpose.classTimetable,
              status: status,
              createdAt: t2,
              updatedAt: t2,
            ),
            _validAsset(
              uid: uidA,
              assetId: 'class-a',
              purpose: UploadedAssetPurpose.classTimetable,
              createdAt: t1,
              updatedAt: t1,
            ),
          ]),
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );
        await controller.hydrate(uid: uidA);
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'class-a',
        );
      });
    }

    test('later upload restores after an older deleted generation', () async {
      final t1 = DateTime.utc(2026, 9, 1, 9);
      final t2 = DateTime.utc(2026, 9, 1, 10);
      final controller = RestoredUploadsController(
        assetRepository: FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            assetId: 'menu-a',
            purpose: UploadedAssetPurpose.eatingMenu,
            status: UploadedAssetStatus.deleted,
            createdAt: t1,
            updatedAt: t2,
          ),
          _validAsset(
            uid: uidA,
            assetId: 'menu-b',
            purpose: UploadedAssetPurpose.eatingMenu,
            createdAt: t2.add(const Duration(minutes: 1)),
          ),
        ]),
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );
      await controller.hydrate(uid: uidA);
      expect(
        controller.state
            .forPurpose(UploadedAssetPurpose.eatingMenu)
            ?.asset
            .assetId,
        'menu-b',
      );
    });

    test(
      'generation resolution is independent across shared purposes',
      () async {
        final t1 = DateTime.utc(2026, 9, 1, 9);
        final t2 = DateTime.utc(2026, 9, 1, 10);
        final controller = RestoredUploadsController(
          assetRepository: FakeUploadedAssetRepository([
            _validAsset(
              uid: uidA,
              assetId: 'class-a',
              purpose: UploadedAssetPurpose.classTimetable,
              status: UploadedAssetStatus.deleted,
              createdAt: t1,
              updatedAt: t2.add(const Duration(seconds: 1)),
            ),
            _validAsset(
              uid: uidA,
              assetId: 'class-b',
              purpose: UploadedAssetPurpose.classTimetable,
              createdAt: t2,
            ),
            _validAsset(
              uid: uidA,
              assetId: 'work-w',
              purpose: UploadedAssetPurpose.workSchedule,
              createdAt: t1,
            ),
          ]),
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );
        await controller.hydrate(uid: uidA);
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'class-b',
        );
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.workSchedule)
              ?.asset
              .assetId,
          'work-w',
        );
      },
    );

    test('Remote identity must match owner, purpose, and asset ID', () {
      final wrongOwnerKey = _validAsset(
        uid: uidA,
        purpose: UploadedAssetPurpose.classTimetable,
        r2Key: 'users/$uidB/onboarding/class_timetable/asset-1.jpg',
      );
      final wrongPurposeKey = _validAsset(
        uid: uidA,
        purpose: UploadedAssetPurpose.classTimetable,
        r2Key: 'users/$uidA/onboarding/skin_care/asset-1.jpg',
      );
      final wrongAssetKey = _validAsset(
        uid: uidA,
        purpose: UploadedAssetPurpose.classTimetable,
        r2Key: 'users/$uidA/onboarding/class_timetable/different.jpg',
      );

      for (final asset in [wrongOwnerKey, wrongPurposeKey, wrongAssetKey]) {
        expect(
          uploadedAssetIsDurablyUploadedForSlot(
            asset: asset,
            uid: uidA,
            purpose: UploadedAssetPurpose.classTimetable,
            expectedSourceFeature: UploadSourceFeature.onboarding,
          ),
          isFalse,
        );
      }
    });

    test('N: Replace succeeds and updates durable identity', () async {
      final repo = FakeUploadedAssetRepository([
        _validAsset(
          uid: uidA,
          assetId: 'asset-old',
          purpose: UploadedAssetPurpose.classTimetable,
        ),
      ]);
      final uploadClient = RecordingR2UploadClient();
      final authRepo = FakeAuthRepo(
        currentUser: const AuthUser(
          uid: uidA,
          email: 'a@optivus.dev',
          emailVerified: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          uploadedAssetRepositoryProvider.overrideWithValue(repo),
          r2UploadClientProvider.overrideWithValue(uploadClient),
          authRepositoryProvider.overrideWithValue(authRepo),
          imagePrepareServiceProvider.overrideWithValue(
            FakeImagePrepareService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final restoredController = container.read(
        restoredUploadsProvider.notifier,
      );
      await restoredController.hydrate(uid: uidA);
      expect(
        container
            .read(restoredUploadsProvider)
            .forPurpose(UploadedAssetPurpose.classTimetable)
            ?.asset
            .assetId,
        'asset-old',
      );

      final uploadController = container.read(
        uploadControllerProvider.notifier,
      );
      final newAsset = await uploadController.startUpload(
        uid: uidA,
        purpose: UploadedAssetPurpose.classTimetable,
        sourceFeature: OnboardingDraft.sourceOnboarding,
      );

      expect(newAsset, isNotNull);
      restoredController.registerUploaded(newAsset!);

      final latest = container
          .read(restoredUploadsProvider)
          .forPurpose(UploadedAssetPurpose.classTimetable);
      expect(latest?.asset.assetId, newAsset.assetId);
      expect(latest?.asset.assetId, isNot('asset-old'));
    });

    test(
      'O & AB: Failed Replace / metadata write preserves previous durable asset',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-old',
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

        final container = ProviderContainer(
          overrides: [
            uploadedAssetRepositoryProvider.overrideWithValue(repo),
            r2UploadClientProvider.overrideWithValue(uploadClient),
            authRepositoryProvider.overrideWithValue(authRepo),
            imagePrepareServiceProvider.overrideWithValue(
              FakeImagePrepareService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final restoredController = container.read(
          restoredUploadsProvider.notifier,
        );
        await restoredController.hydrate(uid: uidA);

        final uploadController = container.read(
          uploadControllerProvider.notifier,
        );
        final newAsset = await uploadController.startUpload(
          uid: uidA,
          purpose: UploadedAssetPurpose.classTimetable,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );

        expect(newAsset, isNull);
        expect(
          container.read(uploadControllerProvider).status,
          UploadFlowStatus.failed,
        );

        final currentRestored = container
            .read(restoredUploadsProvider)
            .forPurpose(UploadedAssetPurpose.classTimetable);
        expect(currentRestored?.asset.assetId, 'asset-old');
      },
    );

    test('P: Remove succeeds without localPath', () async {
      final initialAsset = _validAsset(
        uid: uidA,
        assetId: 'asset-1',
        purpose: UploadedAssetPurpose.classTimetable,
        localPreviewPath: null,
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

      final container = ProviderContainer(
        overrides: [
          uploadedAssetRepositoryProvider.overrideWithValue(repo),
          r2UploadClientProvider.overrideWithValue(uploadClient),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      final restoredController = container.read(
        restoredUploadsProvider.notifier,
      );
      await restoredController.hydrate(uid: uidA);
      expect(
        container
            .read(restoredUploadsProvider)
            .forPurpose(UploadedAssetPurpose.classTimetable),
        isNotNull,
      );

      await container
          .read(uploadControllerProvider.notifier)
          .markDeleted(uid: uidA, assetId: 'asset-1');
      restoredController.removePurpose(
        uid: uidA,
        purpose: UploadedAssetPurpose.classTimetable,
      );

      expect(
        container
            .read(restoredUploadsProvider)
            .forPurpose(UploadedAssetPurpose.classTimetable),
        isNull,
      );
      expect(repo.deletedAssetIds.contains('asset-1'), isTrue);
      expect(
        uploadClient.deletedObjectKeys.contains(initialAsset.r2Key),
        isTrue,
      );
    });

    test(
      'Q: Failed Remove preserves uploaded state in restored controller',
      () async {
        final initialAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-1',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        final repo = FailingDeleteUploadedAssetRepository([initialAsset]);
        final uploadClient = RecordingR2UploadClient();
        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            uploadedAssetRepositoryProvider.overrideWithValue(repo),
            r2UploadClientProvider.overrideWithValue(uploadClient),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        final restoredController = container.read(
          restoredUploadsProvider.notifier,
        );
        await restoredController.hydrate(uid: uidA);

        await container
            .read(uploadControllerProvider.notifier)
            .markDeleted(uid: uidA, assetId: 'asset-1');
        expect(
          container.read(uploadControllerProvider).status,
          UploadFlowStatus.failed,
        );

        expect(
          container
              .read(restoredUploadsProvider)
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'asset-1',
        );
      },
    );

    test(
      'R & S & T: Account boundary and isolation (UID A -> logout -> UID B -> UID A)',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            assetId: 'asset-a',
            purpose: UploadedAssetPurpose.classTimetable,
          ),
          _validAsset(
            uid: uidB,
            assetId: 'asset-b',
            purpose: UploadedAssetPurpose.workSchedule,
          ),
        ]);
        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );

        await controller.hydrate(uid: uidA);
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'asset-a',
        );
        expect(
          controller.state.forPurpose(UploadedAssetPurpose.workSchedule),
          isNull,
        );

        controller.resetForSignedOut();
        expect(controller.state.assetsByPurpose.isEmpty, isTrue);
        expect(controller.state.uid, isNull);

        await controller.hydrate(uid: uidB);
        expect(
          controller.state.forPurpose(UploadedAssetPurpose.classTimetable),
          isNull,
        );
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.workSchedule)
              ?.asset
              .assetId,
          'asset-b',
        );

        controller.resetForSignedOut();
        await controller.hydrate(uid: uidA);
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'asset-a',
        );
        expect(
          controller.state.forPurpose(UploadedAssetPurpose.workSchedule),
          isNull,
        );
      },
    );

    test(
      'V: Harmless same-UID auth refresh is idempotent and avoids redundant metadata queries',
      () async {
        final repo = CountingUploadedAssetRepository([
          _validAsset(uid: uidA, purpose: UploadedAssetPurpose.classTimetable),
        ]);
        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );

        await controller.hydrate(uid: uidA);
        expect(repo.fetchRecentCalls, 1);

        await controller.hydrate(uid: uidA);
        expect(repo.fetchRecentCalls, 1);
      },
    );

    test('Concurrent same-UID hydration shares one metadata request', () async {
      final fetchCompleter = Completer<List<UploadedAsset>>();
      final repo = ControlledFetchUploadedAssetRepository(
        fetchCompleter.future,
      );
      final controller = RestoredUploadsController(
        assetRepository: repo,
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );

      final first = controller.hydrate(uid: uidA);
      final second = controller.hydrate(uid: uidA);
      expect(repo.fetchRecentCalls, 1);

      fetchCompleter.complete([
        _validAsset(uid: uidA, purpose: UploadedAssetPurpose.classTimetable),
      ]);
      await Future.wait([first, second]);

      expect(
        controller.state.forPurpose(UploadedAssetPurpose.classTimetable),
        isNotNull,
      );
    });

    test('Preview races are isolated per purpose', () async {
      final classPreview = Completer<Uri?>();
      final workPreview = Completer<Uri?>();
      final repo = FakeUploadedAssetRepository([
        _validAsset(
          uid: uidA,
          assetId: 'class-a',
          purpose: UploadedAssetPurpose.classTimetable,
        ),
        _validAsset(
          uid: uidA,
          assetId: 'work-a',
          purpose: UploadedAssetPurpose.workSchedule,
        ),
      ]);
      final controller = RestoredUploadsController(
        assetRepository: repo,
        previewResolver: ControlledPreviewResolver(
          resolverMap: {
            'class-a': classPreview.future,
            'class-b': Future.value(null),
            'work-a': workPreview.future,
          },
        ),
      );

      await controller.hydrate(uid: uidA);
      controller.registerUploaded(
        _validAsset(
          uid: uidA,
          assetId: 'class-b',
          purpose: UploadedAssetPurpose.classTimetable,
        ),
      );
      final workUri = Uri.parse('https://preview.optivus.app/work');
      workPreview.complete(workUri);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state
            .forPurpose(UploadedAssetPurpose.workSchedule)
            ?.previewUri,
        workUri,
      );
      classPreview.complete(null);
    });

    test('W: Stale preview result ignored after account switch', () async {
      final repo = FakeUploadedAssetRepository([
        _validAsset(
          uid: uidA,
          assetId: 'asset-a',
          purpose: UploadedAssetPurpose.classTimetable,
        ),
        _validAsset(
          uid: uidB,
          assetId: 'asset-b',
          purpose: UploadedAssetPurpose.classTimetable,
        ),
      ]);
      final completerA = Completer<Uri?>();
      final resolver = ControlledPreviewResolver(
        resolverMap: {'asset-a': completerA.future},
      );

      final controller = RestoredUploadsController(
        assetRepository: repo,
        previewResolver: resolver,
      );

      final hydrateFutureA = controller.hydrate(uid: uidA);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state
            .forPurpose(UploadedAssetPurpose.classTimetable)
            ?.previewStatus,
        UploadedAssetPreviewStatus.loading,
      );

      controller.resetForSignedOut();
      await controller.hydrate(uid: uidB);
      expect(controller.state.uid, uidB);
      expect(
        controller.state
            .forPurpose(UploadedAssetPurpose.classTimetable)
            ?.asset
            .assetId,
        'asset-b',
      );

      completerA.complete(Uri.parse('https://r2.optivus.app/preview/a.jpg'));
      await hydrateFutureA;
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.uid, uidB);
      expect(
        controller.state
            .forPurpose(UploadedAssetPurpose.classTimetable)
            ?.asset
            .assetId,
        'asset-b',
      );
    });

    test(
      'AD: Asset replacement race (late preview A discarded after replacement with B)',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(
            uid: uidA,
            assetId: 'asset-old',
            purpose: UploadedAssetPurpose.classTimetable,
          ),
        ]);
        final completerOld = Completer<Uri?>();
        final resolver = ControlledPreviewResolver(
          resolverMap: {
            'asset-old': completerOld.future,
            'asset-new': Future.value(
              Uri.parse('https://r2.optivus.app/preview/new.jpg'),
            ),
          },
        );

        final controller = RestoredUploadsController(
          assetRepository: repo,
          previewResolver: resolver,
        );

        await controller.hydrate(uid: uidA);
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.previewStatus,
          UploadedAssetPreviewStatus.loading,
        );

        final newAsset = _validAsset(
          uid: uidA,
          assetId: 'asset-new',
          purpose: UploadedAssetPurpose.classTimetable,
        );
        controller.registerUploaded(newAsset);
        await Future<void>.delayed(Duration.zero);

        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.asset
              .assetId,
          'asset-new',
        );
        expect(
          controller.state
              .forPurpose(UploadedAssetPurpose.classTimetable)
              ?.previewStatus,
          UploadedAssetPreviewStatus.available,
        );

        completerOld.complete(
          Uri.parse('https://r2.optivus.app/preview/old.jpg'),
        );
        await Future<void>.delayed(Duration.zero);

        final current = controller.state.forPurpose(
          UploadedAssetPurpose.classTimetable,
        );
        expect(current?.asset.assetId, 'asset-new');
        expect(
          current?.previewUri,
          Uri.parse('https://r2.optivus.app/preview/new.jpg'),
        );
      },
    );

    test(
      'AA: AH-F007 server reconstruction publishes destination without awaiting preview bytes',
      () async {
        final repo = FakeUploadedAssetRepository([
          _validAsset(uid: uidA, purpose: UploadedAssetPurpose.classTimetable),
        ]);
        final hangingPreviewCompleter = Completer<Uri?>();
        final resolver = ControlledPreviewResolver(
          resolverMap: {'asset-1': hangingPreviewCompleter.future},
        );

        final reconstructor = ServerReconstructor(
          source: FakeServerReconstructionSource(
            profile: UserProfile(
              uid: uidA,
              email: 'a@optivus.dev',
              displayName: 'User A',
              onboardingStep: 4,
            ),
            draft: _validDraftAtStep(uidA, 4),
          ),
        );

        final authRepo = FakeAuthRepo(
          currentUser: const AuthUser(
            uid: uidA,
            email: 'a@optivus.dev',
            emailVerified: true,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.firebase,
            ),
            uploadedAssetRepositoryProvider.overrideWithValue(repo),
            uploadedAssetPreviewResolverProvider.overrideWithValue(resolver),
            serverReconstructorProvider.overrideWithValue(reconstructor),
            authRepositoryProvider.overrideWithValue(authRepo),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
            appPreferencesRepositoryProvider.overrideWithValue(
              FakeAppPreferencesRepository(),
            ),
            regionSettingsRepositoryProvider.overrideWithValue(
              FakeRegionSettingsRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authProvider.notifier).retryBackendRestore();

        final authState = container.read(authProvider);
        expect(authState.status, AuthFlowStatus.signedInOnboardingIncomplete);
        expect(authState.resumeStep, 4);

        final restored = container
            .read(restoredUploadsProvider)
            .forPurpose(UploadedAssetPurpose.classTimetable);
        expect(restored, isNotNull);
        expect(restored!.asset.assetId, 'asset-1');
        expect(restored.previewStatus, UploadedAssetPreviewStatus.loading);

        hangingPreviewCompleter.complete(null);
      },
    );

    testWidgets(
      'AC: No empty-state flash test (renders Photo uploaded immediately, never Add photo)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        final asset = _validAsset(
          uid: uidA,
          purpose: UploadedAssetPurpose.skinProducts,
          fileName: 'skin-photo.jpg',
        );

        final controller = RestoredUploadsController(
          assetRepository: FakeUploadedAssetRepository([asset]),
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );
        await controller.hydrate(uid: uidA);

        final draft = OnboardingDraft(
          uid: uidA,
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareProductPhotoAssetId: 'asset-1',
            skinCareProductPhotoR2Key:
                'users/user-a/onboarding/skin_products/asset-1.jpg',
            skinCareProductPhotoStatus: 'uploaded',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
              optivusDebugBuildProvider.overrideWithValue(true),
              onboardingStateProvider.overrideWith((ref) {
                final notifier = OnboardingNotifier();
                notifier.loadSeedData(draft);
                return notifier;
              }),
              restoredUploadsProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
          ),
        );

        await tester.pump();

        // Invariant: Immediately renders Photo uploaded, not Add photo
        expect(find.text('Photo uploaded'), findsOneWidget);
        expect(find.text('Add photo'), findsNothing);
        expect(find.text('skin-photo.jpg'), findsOneWidget);
      },
    );

    testWidgets('Failed Step 7 replacement keeps restored asset A', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final assetA = _validAsset(
        uid: uidA,
        assetId: 'skin-a',
        purpose: UploadedAssetPurpose.skinProducts,
        fileName: 'skin-a.jpg',
      );
      final repo = FailingSaveUploadedAssetRepository(initialAssets: [assetA]);
      final restoredController = RestoredUploadsController(
        assetRepository: repo,
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );
      await restoredController.hydrate(uid: uidA);
      final draft = OnboardingDraft(
        uid: uidA,
        currentStep: 7,
        baseTimeline: const BaseTimelineDraft(
          skinCareSetupStep: 1,
          skinCareSetupPath: 'has_products',
          skinCareProductPhotoAssetId: 'skin-a',
          skinCareProductPhotoR2Key:
              'users/user-a/onboarding/skin_products/skin-a.jpg',
          skinCareProductPhotoStatus: 'uploaded',
        ),
      );
      final authRepo = FakeAuthRepo(
        currentUser: const AuthUser(
          uid: uidA,
          email: 'a@optivus.dev',
          emailVerified: true,
        ),
      );
      final uploadController = UploadController(
        assetRepository: repo,
        authRepository: authRepo,
        imagePrepareService: FakeImagePrepareService(),
        r2UploadClient: RecordingR2UploadClient(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
            optivusDebugBuildProvider.overrideWithValue(true),
            onboardingStateProvider.overrideWith((ref) {
              final notifier = OnboardingNotifier();
              notifier.loadSeedData(draft);
              return notifier;
            }),
            restoredUploadsProvider.overrideWith((ref) => restoredController),
            uploadControllerProvider.overrideWith((ref) => uploadController),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step7-photo-tile')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo uploaded'), findsOneWidget);
      expect(find.text('skin-a.jpg'), findsOneWidget);
      expect(
        restoredController.state
            .forPurpose(UploadedAssetPurpose.skinProducts)
            ?.asset
            .assetId,
        'skin-a',
      );
    });

    testWidgets('Step 7 does not accept failed draft-only photo metadata', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final draft = OnboardingDraft(
        uid: uidA,
        currentStep: 7,
        baseTimeline: const BaseTimelineDraft(
          skinCareSetupStep: 1,
          skinCareSetupPath: 'no_products',
          skinCareProductPhotoAssetId: 'failed-photo',
          skinCareProductPhotoR2Key:
              'users/user-a/onboarding/skin_care/failed-photo.jpg',
          skinCareProductPhotoStatus: 'failed',
        ),
      );
      final controller = RestoredUploadsController(
        assetRepository: FakeUploadedAssetRepository(),
        previewResolver: const UnavailableUploadedAssetPreviewResolver(),
      );
      await controller.hydrate(uid: uidA);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
            optivusDebugBuildProvider.overrideWithValue(true),
            onboardingStateProvider.overrideWith((ref) {
              final notifier = OnboardingNotifier();
              notifier.loadSeedData(draft);
              return notifier;
            }),
            restoredUploadsProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
        ),
      );
      await tester.pump();

      expect(find.text('Add photo'), findsOneWidget);
      expect(find.text('Photo uploaded'), findsNothing);
    });

    testWidgets(
      'Y: Step 4 recognizes durable restored asset without local file',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        final asset = _validAsset(
          uid: uidA,
          purpose: UploadedAssetPurpose.classTimetable,
          localPreviewPath: null, // Zero local file
        );

        final controller = RestoredUploadsController(
          assetRepository: FakeUploadedAssetRepository([asset]),
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );
        await controller.hydrate(uid: uidA);

        final draft = OnboardingDraft(
          uid: uidA,
          currentStep: 4,
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith((ref) {
                final notifier = OnboardingNotifier();
                notifier.loadSeedData(draft);
                return notifier;
              }),
              restoredUploadsProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(body: OnboardingStep4Unified()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Step 4 shows the uploaded thumbnail with class label
        expect(find.text('Photo uploaded'), findsOneWidget);
        expect(find.text('Class'), findsOneWidget);
      },
    );

    testWidgets('Step 4 restored assets satisfy every required role', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final cases = <(String, List<UploadedAsset>)>[
        (
          LifeRoleDraft.studentKey,
          [
            _validAsset(
              uid: uidA,
              purpose: UploadedAssetPurpose.classTimetable,
            ),
          ],
        ),
        (
          LifeRoleDraft.workingKey,
          [_validAsset(uid: uidA, purpose: UploadedAssetPurpose.workSchedule)],
        ),
        (
          LifeRoleDraft.businessKey,
          [_validAsset(uid: uidA, purpose: UploadedAssetPurpose.workSchedule)],
        ),
        (
          LifeRoleDraft.studentWorkingKey,
          [
            _validAsset(
              uid: uidA,
              assetId: 'class-asset',
              purpose: UploadedAssetPurpose.classTimetable,
            ),
            _validAsset(
              uid: uidA,
              assetId: 'work-asset',
              purpose: UploadedAssetPurpose.workSchedule,
            ),
          ],
        ),
      ];

      for (final (role, assets) in cases) {
        final controller = RestoredUploadsController(
          assetRepository: FakeUploadedAssetRepository(assets),
          previewResolver: const UnavailableUploadedAssetPreviewResolver(),
        );
        await controller.hydrate(uid: uidA);
        final draft = OnboardingDraft(
          uid: uidA,
          currentStep: 4,
          lifeRole: LifeRoleDraft(lifeRole: role),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith((ref) {
                final notifier = OnboardingNotifier();
                notifier.loadSeedData(draft);
                return notifier;
              }),
              restoredUploadsProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(body: OnboardingStep4Unified()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final generate = tester.widget<GestureDetector>(
          find.byKey(const ValueKey('onboarding-step4-generate-button')),
        );
        expect(generate.onTap, isNotNull, reason: 'role=$role');
        expect(
          find.text('Photo uploaded', skipOffstage: false),
          findsAtLeastNWidgets(1),
          reason: 'role=$role',
        );
      }
    });

    test(
      'Z: Step 7 recognizes a durable restored face asset but remains incomplete until routine inputs exist',
      () {
        final base = const BaseTimelineDraft(
          skinCareSetupPath: 'no_products',
          skinCareFacePhotoAssetId: 'face',
          skinCareFacePhotoR2Key:
              'users/test_uid/onboarding/skin_face/face.jpg',
          skinCareFacePhotoStatus: 'uploaded',
        );

        // The durable asset satisfies the photo requirement; the remaining
        // no-products setup is still required before the step can continue.
        final validationError = base.validateSkinCareSetup('test_uid');
        expect(
          validationError,
          'Complete your skin details before finding products.',
        );
      },
    );

    test('Step 7 validation rejects nonterminal or incomplete metadata', () {
      for (final status in ['pending', 'uploading', 'failed', 'deleted']) {
        final base = BaseTimelineDraft(
          skinCareSetupPath: 'no_products',
          skinCareProductPhotoAssetId: 'face',
          skinCareProductPhotoR2Key:
              'users/uid-1/onboarding/skin_care/face.jpg',
          skinCareProductPhotoStatus: status,
        );
        expect(
          base.validateSkinCareSetup('test_uid'),
          isNotNull,
          reason: status,
        );
      }
      expect(
        const BaseTimelineDraft(
          skinCareSetupPath: 'no_products',
          skinCareProductPhotoR2Key:
              'users/uid-1/onboarding/skin_care/face.jpg',
          skinCareProductPhotoStatus: 'uploaded',
        ).validateSkinCareSetup('test_uid'),
        isNotNull,
      );
    });
  });
}

UploadedAsset _validAsset({
  required String uid,
  required UploadedAssetPurpose purpose,
  String assetId = 'asset-1',
  String? localPreviewPath,
  String? fileName,
  String? r2Key,
  DateTime? updatedAt,
  DateTime? createdAt,
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
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

OnboardingDraft _validDraftAtStep(String uid, int step) {
  final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
  for (var index = 0; index < step; index++) {
    completed[index] = true;
  }
  final base = const BaseTimelineDraft(
    eatingSetupPath: 'create',
    eatingMode: 'flat',
    shouldPlanMeals: false,
    skinCareSkipped: true,
    blocks: [
      TimelineBlockDraft(
        id: BaseTimelineDraft.fixedSleepId,
        section: 'fixed',
        title: 'Sleep',
        startMinute: 1380,
        endMinute: 420,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
        crossesMidnight: true,
      ),
      TimelineBlockDraft(
        id: BaseTimelineDraft.fixedBathId,
        section: 'fixed',
        title: 'Bath',
        startMinute: 430,
        endMinute: 460,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ],
  );
  return OnboardingDraft(
    uid: uid,
    currentStep: step,
    stepCompleted: completed,
    patiencePledgeAccepted: true,
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: base,
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
  int fetchRecentCalls = 0;

  CountingUploadedAssetRepository([super.initial]);

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async {
    fetchRecentCalls++;
    return super.fetchRecentAssets(
      uid: uid,
      sourceFeature: sourceFeature,
      purpose: purpose,
      limit: limit,
    );
  }
}

class ControlledFetchUploadedAssetRepository
    extends FakeUploadedAssetRepository {
  final Future<List<UploadedAsset>> result;
  int fetchRecentCalls = 0;

  ControlledFetchUploadedAssetRepository(this.result);

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) {
    fetchRecentCalls++;
    return result;
  }
}

class FailingSaveUploadedAssetRepository extends FakeUploadedAssetRepository {
  FailingSaveUploadedAssetRepository({List<UploadedAsset>? initialAssets})
    : super(initialAssets);

  @override
  Future<void> saveAsset(UploadedAsset asset) async {
    throw Exception('Firestore write failed');
  }
}

class FailingDeleteUploadedAssetRepository extends FakeUploadedAssetRepository {
  FailingDeleteUploadedAssetRepository([super.initial]);

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    throw Exception('Firestore delete failed');
  }
}

class FakePreviewResolver implements UploadedAssetPreviewResolver {
  final Uri? fixedUri;
  final bool shouldFail;

  FakePreviewResolver({this.fixedUri, this.shouldFail = false});

  @override
  Future<Uri?> resolvePreview({
    required String uid,
    required UploadedAsset asset,
  }) async {
    if (shouldFail) throw Exception('Preview resolution failed');
    return fixedUri;
  }

  @override
  Future<Uri?> resolveKey({
    required String uid,
    required String objectKey,
  }) async {
    if (shouldFail) throw Exception('Preview resolution failed');
    return fixedUri;
  }
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

  @override
  Future<Uri?> resolveKey({
    required String uid,
    required String objectKey,
  }) async => null;
}

class RecordingRoutineImportAiClient implements RoutineImportAiClient {
  int callCount = 0;

  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) {
    callCount++;
    throw StateError('AI extraction must not run during asset restoration.');
  }
}

class RecordingSkinCareAiClient implements SkinCareAiClient {
  int callCount = 0;

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) {
    callCount++;
    throw StateError('Skin analysis must not run during asset restoration.');
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) {
    callCount++;
    throw StateError('Skin generation must not run during asset restoration.');
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
    final assetId = 'new-asset-${DateTime.now().millisecondsSinceEpoch}';
    return R2SignedUpload(
      assetId: assetId,
      objectKey: 'users/$uid/onboarding/${purpose.wireName}/$assetId.jpg',
      uploadUrl: 'https://r2.optivus.app/upload',
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
  }) async => 'https://preview.local/$objectKey';
}

class FakeImagePrepareService extends ImagePrepareService {
  @override
  Future<XFile?> pickImageFile({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'test.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    return PreparedUploadImage(
      fileName: 'test.jpg',
      contentType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
      sizeBytes: 3,
    );
  }
}

class FakeAuthRepo implements AuthRepository {
  final AuthUser? _user;
  FakeAuthRepo({AuthUser? currentUser}) : _user = currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(_user);

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<String?> currentIdToken() async => 'test-token';

  @override
  Future<AuthUser> signIn(String email, String password) async => _user!;

  @override
  Future<AuthUser> signInAnonymously() async => _user!;

  @override
  Future<AuthUser?> signInWithGoogle() async => _user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signUp(
    String email,
    String password, {
    String? name,
  }) async => _user!;

  @override
  Future<AuthUser> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async => _user!;

  @override
  Future<AuthUser?> reloadCurrentUser() async => _user;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class FakeServerReconstructionSource implements ServerReconstructionSource {
  final UserProfile? profile;
  final OnboardingDraft? draft;
  final OnboardingCompletionBundle? bundle;
  final OnboardingCompletionJob? run;

  FakeServerReconstructionSource({
    this.profile,
    this.draft,
    this.bundle,
    this.run,
  });

  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async {
    onProfileLoaded?.call(profile);
    return ServerReconstructionSnapshot(
      profile: profile,
      draft: draft,
      completionBundle: bundle,
      currentRun: run != null
          ? OnboardingCurrentRunSnapshot(
              hasPointer: true,
              runId: run!.jobId,
              ownerUid: run!.uid,
              job: run,
            )
          : const OnboardingCurrentRunSnapshot.none(),
    );
  }

  @override
  Future<void> createProfileShell(UserProfile profile) async {}
}
