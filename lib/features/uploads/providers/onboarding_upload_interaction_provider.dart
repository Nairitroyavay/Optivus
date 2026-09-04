import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

const onboardingClassUploadSlot = 'class';
const onboardingWorkUploadSlot = 'work';
const onboardingEatingUploadSlot = 'eating';
const onboardingSkinProductsUploadSlot = 'skin-products';
const onboardingSkinFaceUploadSlot = 'skin-face';

const onboardingUploadShellConfig = UploadShellConfig(
  title: 'Onboarding photos',
  slots: [
    UploadSlotConfig(
      key: onboardingClassUploadSlot,
      label: 'Class',
      title: 'Class timetable',
      icon: Icons.school_rounded,
      purpose: UploadedAssetPurpose.classTimetable,
    ),
    UploadSlotConfig(
      key: onboardingWorkUploadSlot,
      label: 'Work',
      title: 'Work schedule',
      icon: Icons.work_rounded,
      purpose: UploadedAssetPurpose.workSchedule,
    ),
    UploadSlotConfig(
      key: onboardingEatingUploadSlot,
      label: 'Eating',
      title: 'Menu',
      icon: Icons.restaurant_menu_rounded,
      purpose: UploadedAssetPurpose.eatingMenu,
    ),
    UploadSlotConfig(
      key: onboardingSkinProductsUploadSlot,
      label: 'Products',
      title: 'Skin-care products',
      icon: Icons.spa_rounded,
      purpose: UploadedAssetPurpose.skinProducts,
    ),
    UploadSlotConfig(
      key: onboardingSkinFaceUploadSlot,
      label: 'Face',
      title: 'Face photo',
      icon: Icons.face_retouching_natural_rounded,
      purpose: UploadedAssetPurpose.skinFace,
    ),
  ],
);

final onboardingUploadInteractionProvider =
    StateNotifierProvider<UploadInteractionController, UploadInteractionMap>((
      ref,
    ) {
      final controller = UploadInteractionController(
        shellConfig: onboardingUploadShellConfig,
        assetRepository: ref.watch(uploadedAssetRepositoryProvider),
        authRepository: ref.watch(authRepositoryProvider),
        imagePrepareService: ref.watch(imagePrepareServiceProvider),
        r2UploadClient: ref.watch(r2UploadClientProvider),
        permissionService: ref.watch(uploadPermissionServiceProvider),
        restoredController: ref.watch(restoredUploadsProvider.notifier),
      );

      ref.listen<RestoredUploadsState>(restoredUploadsProvider, (_, next) {
        final uid = ref.read(authRepositoryProvider).currentUser?.uid;
        if (uid == null || uid.trim().isEmpty) {
          controller.resetForSignedOut();
        } else {
          controller.syncWithDurableState(next, uid: uid);
        }
      }, fireImmediately: true);

      return controller;
    });
