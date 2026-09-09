part of '../onboarding_step_7_skin_care_setup.dart';

class _SkinCareHeader extends StatelessWidget {
  const _SkinCareHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skin Care',
          style: TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Face and skin routine setup.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SkinCareChoiceScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareChoiceScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> select(String value) async {
      final onboardingNotifier = ref.read(onboardingStateProvider.notifier);
      final uploadController = ref.read(
        onboardingUploadInteractionProvider.notifier,
      );
      final assetRepository = ref.read(uploadedAssetRepositoryProvider);
      final authRepository = ref.read(authRepositoryProvider);
      final uploadClient = ref.read(r2UploadClientProvider);
      final restoredUploadsNotifier = ref.read(
        restoredUploadsProvider.notifier,
      );
      onboardingNotifier.clearValidation();
      if (value == 'skip') {
        final draft = ref.read(onboardingStateProvider).draft;
        final uid = ref.read(authProvider).user?.uid ?? draft.uid;
        final restored = ref.read(restoredUploadsProvider);
        if (uid.trim().isEmpty ||
            restored.isHydrating ||
            restored.errorMessage != null) {
          ref
              .read(onboardingStateProvider.notifier)
              .setValidationMessage(
                'Reconnect before skipping so your private photos can be removed safely.',
              );
          return;
        }
        onboardingNotifier.setStepLoading(onboardingSkinCareStepIndex, true);
        var cleanupSucceeded = true;
        for (final slot in const [
          onboardingSkinProductsUploadSlot,
          onboardingSkinFaceUploadSlot,
        ]) {
          final slotState = ref.read(onboardingUploadInteractionProvider)[slot];
          if (slotState?.hasDurableAsset == true) {
            cleanupSucceeded =
                await uploadController.remove(slot, uid: uid) &&
                cleanupSucceeded;
            if (!context.mounted) return;
          }
        }
        final cleanupAssets = <String, UploadedAsset>{};
        final legacy = restored
            .forPurpose(UploadedAssetPurpose.skinCare)
            ?.asset;
        if (legacy != null) cleanupAssets[legacy.assetId] = legacy;
        try {
          final recentAssets = await assetRepository.fetchRecentAssets(
            uid: uid,
            sourceFeature: 'onboarding',
            limit: 100,
          );
          if (!context.mounted) return;
          for (final asset in recentAssets) {
            if (asset.errorMessage == 'private_cleanup_pending' &&
                const [
                  UploadedAssetPurpose.skinCare,
                  UploadedAssetPurpose.skinFace,
                  UploadedAssetPurpose.skinProducts,
                ].contains(asset.purpose)) {
              cleanupAssets[asset.assetId] = asset;
            }
          }
          for (final asset in cleanupAssets.values) {
            await assetRepository.saveAsset(
              asset.copyWith(
                status: UploadedAssetStatus.deleted,
                updatedAt: DateTime.now(),
                errorMessage: 'private_cleanup_pending',
              ),
            );
            if (!context.mounted) return;
            final token = await authRepository.currentIdToken();
            if (!context.mounted) return;
            if (token == null ||
                token.trim().isEmpty ||
                (authRepository.currentUser?.uid ?? uid) != uid) {
              throw StateError('Private cleanup requires the same account');
            }
            await uploadClient.deleteUpload(
              objectKey: asset.r2Key,
              idToken: token,
            );
            if (!context.mounted) return;
            await assetRepository.markDeleted(uid: uid, assetId: asset.assetId);
            if (!context.mounted) return;
            restoredUploadsNotifier.removePurpose(
              uid: uid,
              purpose: asset.purpose,
            );
          }
        } catch (_) {
          cleanupSucceeded = false;
        }
        if (!context.mounted) return;
        onboardingNotifier.setStepLoading(onboardingSkinCareStepIndex, false);
        if (!cleanupSucceeded) {
          onboardingNotifier.setValidationMessage(
            'Your photo could not be removed yet. Try again before skipping.',
          );
          return;
        }
      }
      if (!context.mounted) return;
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final isSkip = value == 'skip';
        final switchedPath = base.skinCareSetupPath != value;
        final legacyR2Key = base.skinCareProductPhotoR2Key?.trim() ?? '';
        final migrateLegacyFace =
            value == 'no_products' &&
            (base.skinCareSetupPath == 'has_products' ||
                base.skinCareSetupPath == 'no_products') &&
            (base.skinCareFacePhotoAssetId?.trim().isEmpty ?? true) &&
            (base.skinCareProductPhotoAssetId?.trim().isNotEmpty ?? false) &&
            legacyR2Key.contains('/skin_care/');
        final clearGeneratedData = isSkip || switchedPath;
        final blocks = switchedPath || isSkip
            ? base.blocks.where((b) => b.section != 'skin_care').toList()
            : base.blocks;
        return base.copyWith(
          blocks: blocks,
          skinCareSetupPath: value,
          skinCareSetupStep: 1,
          skinCareSkipped: isSkip,
          skinCareSpecialCareNotes: clearGeneratedData
              ? const []
              : base.skinCareSpecialCareNotes,
          skinCareFacePhotoAssetId: migrateLegacyFace
              ? base.skinCareProductPhotoAssetId
              : null,
          skinCareFacePhotoR2Key: migrateLegacyFace
              ? base.skinCareProductPhotoR2Key
              : null,
          skinCareFacePhotoStatus: migrateLegacyFace
              ? base.skinCareProductPhotoStatus
              : null,
          skinCareFacePhotoCreatedAt: migrateLegacyFace
              ? base.skinCareProductPhotoCreatedAt
              : null,
          skinCareFacePhotoUpdatedAt: migrateLegacyFace
              ? base.skinCareProductPhotoUpdatedAt
              : null,
          clearSkinCareProductNames: isSkip,
          clearSkinCareProductPhoto: isSkip || migrateLegacyFace,
          clearSkinCareFacePhoto: isSkip,
          clearSkinCareSkinType: isSkip,
          clearSkinCareProblems: isSkip,
          clearSkinCareBudget: isSkip,
          clearSkinCarePreference: isSkip,
          clearSkinCareProductRecommendations: isSkip,
          clearSkinCareSelectedProductNames: isSkip,
          clearSkinCareSuggestedProducts: isSkip,
          clearSkinCareReviewedProducts: isSkip,
          clearSkinCareRecommendationFingerprint: isSkip || switchedPath,
          clearSkinCareRoutineFingerprint: isSkip || switchedPath,
        );
      });
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SkinCarePathCard(
            title: 'I have products',
            subtitle: 'Type product names to build a routine.',
            icon: Icons.spa_rounded,
            accent: OptivusColors.roseAccent,
            selected:
                base.skinCareSetupPath == 'has_products' &&
                !base.skinCareSkipped,
            onTap: () => select('has_products'),
          ),
          const SizedBox(height: 12),
          _SkinCarePathCard(
            title: 'No products',
            subtitle: 'Get products for your skin, budget, and location.',
            icon: Icons.face_retouching_natural_rounded,
            accent: OptivusColors.purpleAccent,
            selected:
                base.skinCareSetupPath == 'no_products' &&
                !base.skinCareSkipped,
            onTap: () => select('no_products'),
          ),
          const SizedBox(height: 12),
          _SkinCarePathCard(
            title: 'Skip',
            subtitle: 'Skin care will be skipped for now.',
            icon: Icons.skip_next_rounded,
            accent: OptivusColors.textSecondary,
            selected: base.skinCareSetupPath == 'skip' || base.skinCareSkipped,
            onTap: () => select('skip'),
          ),
        ],
      ),
    );
  }
}

class _SkinCarePathCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _SkinCarePathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        tint: selected
            ? accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.48),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.62)
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
