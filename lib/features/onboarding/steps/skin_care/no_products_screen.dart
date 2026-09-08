part of '../onboarding_step_7_skin_care_setup.dart';

class _NoProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _NoProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_NoProductsModeScreen> createState() =>
      _NoProductsModeScreenState();
}

class _NoProductsModeScreenState extends ConsumerState<_NoProductsModeScreen> {
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  late final AiGenerationController _lifecycle;
  bool _removingPhoto = false;
  int? _pendingDesiredApplicationsPerDay;
  String? _generationError;
  bool _recommendationRetryAvailable = false;
  bool _routineRetryAvailable = false;
  int _selectedDay = DateTime.now().weekday;
  String? _publishedActionSignature;
  final Object _actionOwner = Object();
  int? _publishedActionEpoch;
  String? _publishedActionOwnerUid;
  int? _publishedActionAuthGeneration;
  late final Step7ActionBridgeNotifier _actionBridge;
  late final SkinCareFlowController _flowController;

  void _publishPrimaryAction(OnboardingStep7PrimaryAction? action) {
    final signature = action == null
        ? null
        : '${action.label}|${action.enabled}|${action.loading}';
    final epoch = _flowController.currentEpoch;
    final draft = ref.read(mockOnboardingProvider).draft;
    final ownerUid = ref.read(authProvider).user?.uid ?? draft.uid;
    final authGeneration = ref.read(authGenerationProvider);
    final bridgeState = ref.read(step7ActionBridgeProvider);
    final bridgeStillOwnsAction =
        action == null ||
        (bridgeState.action != null &&
            bridgeState.activeToken?.ownerId == _actionOwner &&
            bridgeState.activeToken?.epoch == _publishedActionEpoch);
    if (_publishedActionSignature == signature &&
        _publishedActionEpoch == epoch &&
        _publishedActionOwnerUid == ownerUid &&
        _publishedActionAuthGeneration == authGeneration &&
        bridgeStillOwnsAction) {
      return;
    }
    _publishedActionSignature = signature;
    _publishedActionEpoch = epoch;
    _publishedActionOwnerUid = ownerUid;
    _publishedActionAuthGeneration = authGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _publishedActionSignature != signature ||
          _publishedActionEpoch != epoch ||
          _publishedActionOwnerUid != ownerUid ||
          _publishedActionAuthGeneration != authGeneration) {
        return;
      }
      _actionBridge.publish(
        ownerId: _actionOwner,
        epoch: epoch,
        action: action,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _actionBridge = ref.read(step7ActionBridgeProvider.notifier);
    _flowController = ref.read(skinCareFlowControllerProvider.notifier);
    _lifecycle = AiGenerationController()..addListener(_onLifecycleChanged);
    final draft = ref.read(mockOnboardingProvider).draft;
    final restored = ref.read(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinFace,
    );
    _uploadedAsset = restoredAsset ?? durableSkinFaceAssetFromDraft(draft);
  }

  void _onLifecycleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_onLifecycleChanged);
    _lifecycle.dispose();
    if (_publishedActionEpoch != null) {
      final owner = _actionOwner;
      final epoch = _publishedActionEpoch!;
      final bridge = _actionBridge;
      Future<void>.microtask(() {
        bridge.clear(ownerId: owner, epoch: epoch);
      });
    }
    super.dispose();
  }

  void _resetPublishedActionCache() {
    _publishedActionSignature = null;
    _publishedActionEpoch = null;
    _publishedActionOwnerUid = null;
    _publishedActionAuthGeneration = null;
  }

  bool _isCurrentUploadBinding({
    required String uid,
    required int authGeneration,
    required int flowEpoch,
    required SkinCareFlowState expectedState,
  }) {
    if (!mounted) return false;
    final draft = ref.read(mockOnboardingProvider).draft;
    final currentUid = ref.read(authProvider).user?.uid ?? draft.uid;
    final flow = ref.read(skinCareFlowControllerProvider);
    return currentUid == uid &&
        ref.read(authGenerationProvider) == authGeneration &&
        flow.epoch == flowEpoch &&
        flow.state == expectedState;
  }

  UploadedAsset? _slotAssetIfBoundToDraft(
    UploadSlotRuntimeState? uploadState,
    OnboardingDraft draft,
  ) {
    final asset = uploadState?.effectiveAsset;
    if (asset == null) return null;
    final base = draft.baseTimeline;
    return asset.assetId == base.skinCareFacePhotoAssetId &&
            asset.r2Key == base.skinCareFacePhotoR2Key
        ? asset
        : null;
  }

  Future<void> _startUpload() async {
    final initialUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    if (initialUploadState?.isBusy == true) return;
    final retrying =
        initialUploadState?.phase == UploadInteractionPhase.failed &&
        initialUploadState?.transientFile != null;
    var source = retrying ? null : await _showSkinPhotoSourceSheet(context);
    if (!mounted) return;
    if (!retrying && source == null) {
      return;
    }
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final requestAuthGeneration = ref.read(authGenerationProvider);
    final requestFlowEpoch = _flowController.currentEpoch;
    final requestFlowState = _flowController.currentFlowState;
    final isEditing = requestFlowState.isEditing;
    final controller = ref.read(onboardingUploadInteractionProvider.notifier);
    final asset = retrying
        ? await controller.retry(
            onboardingSkinFaceUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            deferReplacement: isEditing,
          )
        : source == _SkinPhotoSource.camera
        ? await controller.takePhoto(
            onboardingSkinFaceUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            deferReplacement: isEditing,
          )
        : await controller.chooseFromGallery(
            onboardingSkinFaceUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            deferReplacement: isEditing,
          );

    if (!mounted) return;
    if (!_isCurrentUploadBinding(
      uid: uid,
      authGeneration: requestAuthGeneration,
      flowEpoch: requestFlowEpoch,
      expectedState: requestFlowState,
    )) {
      return;
    }

    final latestUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final latestAsset = asset;
    if (latestAsset != null) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareFacePhotoAssetId: latestAsset.assetId,
          skinCareFacePhotoR2Key: latestAsset.r2Key,
          skinCareFacePhotoStatus: latestAsset.status.wireName,
          skinCareFacePhotoCreatedAt: latestAsset.createdAt,
          skinCareFacePhotoUpdatedAt: latestAsset.updatedAt,
          clearSkinCareProductRecommendations: true,
          clearSkinCareSelectedProductNames: true,
          clearSkinCareSuggestedProducts: !base.blocks.any(
            (block) => block.section == 'skin_care',
          ),
          skinCareSkipped: false,
        ),
      );
    }
    setState(() {
      if (latestAsset != null) {
        _uploadedAsset = latestAsset;
      }
      _uploadError = latestUploadState?.phase == UploadInteractionPhase.failed
          ? _friendlySkinCareUploadMessage(latestUploadState?.attemptError)
          : null;
    });
    if (latestAsset != null && !isEditing) {
      ref.read(restoredUploadsProvider.notifier).registerUploaded(latestAsset);
    }
  }

  Future<void> _removeUploadedAsset() async {
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;
    final draft = ref.read(mockOnboardingProvider).draft;
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinFace,
        ) ??
        durableSkinFaceAssetFromDraft(draft);
    if (asset != null && asset.assetId.trim().isNotEmpty) {
      setState(() {
        _removingPhoto = true;
        _uploadError = null;
        _generationError = null;
      });
      final removed = await ref
          .read(onboardingUploadInteractionProvider.notifier)
          .remove(
            onboardingSkinFaceUploadSlot,
            uid: asset.ownerUid.trim().isNotEmpty ? asset.ownerUid : draft.uid,
          );
      if (!mounted) return;
      final latest = ref.read(
        onboardingUploadInteractionProvider,
      )[onboardingSkinFaceUploadSlot];
      if (!removed) {
        setState(() {
          _removingPhoto = false;
          _uploadError = _friendlySkinCareUploadMessage(latest?.attemptError);
        });
        if (latest?.durableAsset == null &&
            latest?.pendingReplacementAsset == null) {
          setState(() {
            _uploadedAsset = null;
          });
          _flowController.clearSnapshotPhoto(isFacePhoto: true);
          updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (base) => base.copyWith(
              clearSkinCareFacePhoto: true,
              clearSkinCareProductRecommendations: true,
              clearSkinCareSelectedProductNames: true,
              clearSkinCareRecommendationFingerprint: true,
              clearSkinCareRoutineFingerprint: true,
              clearSkinCareSuggestedProducts: true,
            ),
          );
        }
        return;
      }
    }
    _flowController.clearSnapshotPhoto(isFacePhoto: true);
    setState(() {
      _uploadedAsset = null;
      _removingPhoto = false;
      _uploadError = null;
      _generationError = null;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareFacePhoto: true,
        clearSkinCareProductRecommendations: true,
        clearSkinCareSelectedProductNames: true,
        clearSkinCareSuggestedProducts: true,
        clearSkinCareRecommendationFingerprint: true,
        clearSkinCareRoutineFingerprint: true,
        skinCareSkipped: false,
      ),
    );
  }

  Future<void> _findProducts() async {
    if (_lifecycle.state.isActive) return;
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final currentBase = draft.baseTimeline;
    final desiredApplicationsPerDay = _effectiveDesiredApplications(
      currentBase,
    );
    final restored = ref.read(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinFace,
    );
    final asset =
        _uploadedAsset ?? restoredAsset ?? durableSkinFaceAssetFromDraft(draft);
    if (asset == null ||
        asset.r2Key.trim().isEmpty ||
        currentBase.skinCareSkinType == null ||
        currentBase.skinCareProblems.isEmpty ||
        currentBase.skinCareBudget == null) {
      setState(() {
        _generationError =
            'Add a face photo, then choose your skin type, concerns, and budget.';
        _uploadError = null;
      });
      return;
    }
    if (!_isSupportedSkinCareImageContentType(asset.contentType)) {
      setState(() {
        _generationError =
            'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
        _uploadError = null;
      });
      return;
    }

    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final currentAuthGeneration = ref.read(authGenerationProvider);
    final currentAssetId = asset.assetId;
    final currentAssetKey = asset.r2Key;
    final user = ref.read(authProvider).user;
    final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    setState(() {
      _generationError = null;
      _uploadError = null;
      _recommendationRetryAvailable = false;
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    _flowController.startGeneration(
      SkinCareFlowState.noProductsFindingProducts,
    );
    final requestEpoch = _flowController.currentEpoch;

    final run = await _lifecycle.run<bool>(
      operationType: 'skin-care-find-products',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: 'Getting your face photo ready…',
      isSessionCurrent: () =>
          mounted &&
          _flowController.currentEpoch == requestEpoch &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(mockOnboardingProvider).draft.uid) ==
              uid &&
          (() {
            final live =
                ref
                    .read(
                      onboardingUploadInteractionProvider,
                    )[onboardingSkinFaceUploadSlot]
                    ?.durableAsset ??
                durableSkinFaceAssetFromDraft(
                  ref.read(mockOnboardingProvider).draft,
                );
            return live?.assetId == currentAssetId &&
                live?.r2Key == currentAssetKey;
          })(),
      mapError: (error) => AiGenerationError(
        category: error is _SkinCareResponseException
            ? error.category
            : AiGenerationErrorCategory.serviceUnavailable,
        message: error is _SkinCareResponseException
            ? error.message
            : onboarding7UnexpectedAiMessage(error),
        canRetry: true,
      ),
      operation: (scope) async {
        final idToken =
            await ref.read(authRepositoryProvider).currentIdToken() ?? '';
        if (!scope.isCurrent) return false;
        final client = ref.read(skinCareAiClientProvider);
        // Region resolution is a hydrated, user-scoped responsibility.  In
        // particular, a locale fallback must never replace saved settings in
        // a request assembled by this screen.
        final region = ref.read(regionSettingsProvider);
        scope.transition(
          AiGenerationPhase.analyzing,
          message:
              'Finding useful products available in ${region.countryName}…',
        );

        final result = await client.generateRoutine(
          uid: uid,
          idToken: idToken,
          params: {
            'recommendationOnly': true,
            'skinType': currentBase.skinCareSkinType,
            'mainProblem': currentBase.skinCareProblems.isNotEmpty
                ? currentBase.skinCareProblems.first
                : 'none',
            'skinConcerns': currentBase.skinCareProblems,
            'budget': currentBase.skinCareBudget,
            'routinePreference': currentBase.skinCarePreference,
            'desiredApplicationsPerDay': desiredApplicationsPerDay,
            'facePhotoR2Key': asset.r2Key,
            'countryCode': region.countryCode,
            'countryName': region.countryName,
            'currencyCode': region.currencyCode,
          },
        );
        if (!scope.isCurrent) return false;

        final deduped = onboarding7NormalizeRecommendations(
          result.recommendedProducts,
        );

        final recommendationDrafts = deduped
            .map(
              (product) => SkinCareProductRecommendationDraft(
                name: product.name,
                brand: product.brand,
                category: product.category,
                estimatedPrice: product.estimatedPrice,
                currencyCode: product.currencyCode,
                reason: product.reason,
              ),
            )
            .toList(growable: false);
        final missingEssentialCategories =
            onboarding7MissingEssentialRecommendationCategories(
              recommendationDrafts,
            );
        final recommendationRepairFailed = result.warnings.any(
          (warning) => warning.startsWith('ai_recommendation_repair_failed:'),
        );

        if (result.hasError ||
            deduped.isEmpty ||
            missingEssentialCategories.isNotEmpty) {
          throw _SkinCareResponseException(
            recommendationRepairFailed
                ? onboarding7FriendlyAiMessage(null, result.warnings)
                : !result.hasError
                ? 'AI could not provide a complete branded cleanser, moisturizer, and sunscreen set with local prices. Please try again.'
                : onboarding7FriendlyAiMessage(
                    result.errorCode == 'json_payload_too_large'
                        ? 'json_payload_too_large'
                        : result.errorMessage,
                    result.warnings,
                  ),
            errorCode: result.errorCode,
          );
        }

        updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
          final hasExistingRoutine = base.blocks.any(
            (block) => block.section == 'skin_care',
          );
          final draftForFingerprint = base.copyWith(
            skinCareProductRecommendations: recommendationDrafts,
            clearSkinCareSelectedProductNames: !hasExistingRoutine,
            skinCareRecommendationCountryCode: region.countryCode,
            skinCareRecommendationCurrencyCode: region.currencyCode,
            clearSkinCareSuggestedProducts: !hasExistingRoutine,
            skinCareFacePhotoSkipped: false,
            skinCareSkipped: false,
          );
          final recFingerprint = draftForFingerprint
              .computeSkinCareRecommendationFingerprint();
          return draftForFingerprint.copyWith(
            skinCareRecommendationFingerprint: recFingerprint,
          );
        });

        return true;
      },
    );

    if (mounted) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _generationError = null;
          _recommendationRetryAvailable = false;
        });
        if (_flowController.currentEpoch == requestEpoch) {
          _flowController.completeGeneration();
        }
      } else if (run.error != null) {
        setState(() {
          _recommendationRetryAvailable = true;
          _generationError =
              "We couldn't find products right now. ${run.error!.message}";
        });
        _flowController.failGeneration(run.error!.message);
      }
    }
  }

  Future<void> _generate() async {
    if (_lifecycle.state.isActive) return;
    final draft = ref.read(mockOnboardingProvider).draft;
    final currentBase = draft.baseTimeline;
    final desiredApplicationsPerDay = _effectiveDesiredApplications(
      currentBase,
    );
    final selectedKeys = currentBase.skinCareSelectedProductNames
        .map((name) => normalizeSkinCareSelectionKey(name))
        .toSet();
    final selected = currentBase.skinCareProductRecommendations
        .where((product) => selectedKeys.contains(product.selectionKey))
        .toList(growable: false);
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinFace,
        ) ??
        durableSkinFaceAssetFromDraft(draft);
    if (selected.isEmpty) {
      setState(() => _generationError = 'Select at least one product.');
      return;
    }
    final missingEssentialSelections =
        onboarding7MissingEssentialRecommendationCategories(selected);
    if (missingEssentialSelections.isNotEmpty) {
      setState(() {
        _generationError = _onboarding7EssentialSelectionMessage(
          missingEssentialSelections,
        );
      });
      return;
    }
    if (asset == null || asset.r2Key.trim().isEmpty) {
      _flowController.transitionTo(SkinCareFlowState.noProductsInput);
      setState(() {
        _generationError = 'Add a face photo before building your routine.';
      });
      return;
    }

    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final currentAuthGeneration = ref.read(authGenerationProvider);
    final currentAssetId = asset.assetId;
    final currentAssetKey = asset.r2Key;
    final user = ref.read(authProvider).user;
    final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    setState(() {
      _generationError = null;
      _uploadError = null;
      _routineRetryAvailable = false;
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    _flowController.startGeneration(
      SkinCareFlowState.noProductsGeneratingRoutine,
    );
    final requestEpoch = _flowController.currentEpoch;

    final run = await _lifecycle.run<bool>(
      operationType: 'skin-care-routine',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: 'Getting your skin care routine ready…',
      isSessionCurrent: () =>
          mounted &&
          _flowController.currentEpoch == requestEpoch &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(mockOnboardingProvider).draft.uid) ==
              uid &&
          (() {
            final live =
                ref
                    .read(
                      onboardingUploadInteractionProvider,
                    )[onboardingSkinFaceUploadSlot]
                    ?.durableAsset ??
                durableSkinFaceAssetFromDraft(
                  ref.read(mockOnboardingProvider).draft,
                );
            return live?.assetId == currentAssetId &&
                live?.r2Key == currentAssetKey;
          })(),
      mapError: (error) => AiGenerationError(
        category: error is _SkinCareResponseException
            ? error.category
            : AiGenerationErrorCategory.serviceUnavailable,
        message: error is _SkinCareResponseException
            ? error.message
            : onboarding7UnexpectedAiMessage(error),
        canRetry: true,
      ),
      operation: (scope) async {
        final idToken =
            await ref.read(authRepositoryProvider).currentIdToken() ?? '';
        if (!scope.isCurrent) return false;
        final region = ref.read(regionSettingsProvider);
        final selectedNames = selected
            .map((product) => product.displayName)
            .where((name) => name.isNotEmpty)
            .toList(growable: false);

        scope.transition(
          AiGenerationPhase.generating,
          message: 'Building your skin care routine…',
        );

        final result = await ref
            .read(skinCareAiClientProvider)
            .generateRoutine(
              uid: uid,
              idToken: idToken,
              params: {
                'sourceFeature': OnboardingDraft.sourceOnboarding,
                'productInputSource': 'typed',
                'typedProductDetails': selected
                    .map(
                      (product) => {
                        'name': product.name,
                        'brand': product.brand,
                        'category': product.category,
                        'source': 'ai_recommended',
                      },
                    )
                    .toList(growable: false),
                'skinType': currentBase.skinCareSkinType,
                'mainProblem':
                    currentBase.skinCareProblems.firstOrNull ?? 'none',
                'skinConcerns': currentBase.skinCareProblems,
                'budget': currentBase.skinCareBudget,
                'routinePreference': currentBase.skinCarePreference,
                'desiredApplicationsPerDay': desiredApplicationsPerDay,
                'countryCode': region.countryCode,
                'countryName': region.countryName,
                'currencyCode': region.currencyCode,
              },
            );
        if (!scope.isCurrent) return false;

        if (result.hasError || result.routinePlans.isEmpty) {
          throw _SkinCareResponseException(
            result.routinePlans.isEmpty && !result.hasError
                ? _onboarding7NoProductsAiEmptyMessage
                : onboarding7FriendlyAiMessage(
                    result.errorCode == 'json_payload_too_large'
                        ? 'json_payload_too_large'
                        : result.errorMessage,
                    result.warnings,
                  ),
            errorCode: result.errorCode,
          );
        }
        if (result.warnings.any(
          (warning) =>
              warning.contains('ai_wrong_daily_slot_count') ||
              warning.contains('ai_missing_required_slot:') ||
              warning.contains('ai_extra_daily_slot_count'),
        )) {
          throw _SkinCareResponseException(
            onboarding7FriendlyAiMessage(null, result.warnings),
          );
        }

        final partitioned = onboarding7PartitionRoutinePlans(
          result.routinePlans,
        );
        final schedule = onboarding7ScheduleSkinCareRoutine(
          baseTimeline: ref.read(mockOnboardingProvider).draft.baseTimeline,
          routinePlans: partitioned.dailyPlans,
          desiredApplicationsPerDay: desiredApplicationsPerDay,
          ownedProductNames: selectedNames,
          forceEveryDay: true,
        );
        if (schedule.hasError || schedule.blocks.isEmpty) {
          throw _SkinCareResponseException(
            schedule.errorMessage ?? _onboarding7NoProductsAiEmptyMessage,
          );
        }

        final specialCareNotes = onboarding7SpecialCareNotesFromAiResult(
          suggestedProducts: result.suggestedProducts,
          weeklyRoutine: result.weeklyRoutine,
          specialCarePlans: partitioned.specialCarePlans,
          ownedProductNames: selectedNames,
        );
        updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
          final draftForFingerprint = base.copyWith(
            skinCareProductNames: selectedNames.join('\n'),
            skinCareSpecialCareNotes: specialCareNotes,
            skinCareSuggestedProducts: selectedNames,
            skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
            skinCareFacePhotoSkipped: false,
            skinCareSkipped: false,
          );
          final routineFingerprint = draftForFingerprint
              .computeSkinCareRoutineFingerprint();
          final taggedBlocks = schedule.blocks.map((block) {
            final prov = List<String>.from(block.provenanceSourceIds);
            final token = 'skin-care-generation:$routineFingerprint';
            if (!prov.contains(token)) prov.add(token);
            if (asset.assetId.isNotEmpty && !prov.contains(asset.assetId)) {
              prov.add(asset.assetId);
            }
            if (asset.r2Key.isNotEmpty && !prov.contains(asset.r2Key)) {
              prov.add(asset.r2Key);
            }
            return block.copyWith(provenanceSourceIds: prov);
          }).toList();

          final nextBlocks =
              base.blocks
                  .where((block) => block.section != 'skin_care')
                  .toList()
                ..addAll(taggedBlocks);
          return draftForFingerprint.copyWith(
            blocks: nextBlocks,
            skinCareRoutineFingerprint: routineFingerprint,
          );
        });

        return true;
      },
    );

    if (mounted) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _pendingDesiredApplicationsPerDay = null;
          _generationError = null;
          _routineRetryAvailable = false;
        });
        if (_flowController.currentEpoch == requestEpoch) {
          _flowController.commitRebuildSuccess(
            ref.read(mockOnboardingProvider).draft.baseTimeline,
          );
        }
      } else if (run.error != null) {
        setState(() {
          _routineRetryAvailable = true;
          _generationError =
              'Products are ready, but routine generation failed. '
              '${run.error!.message}';
        });
        _flowController.failGeneration(run.error!.message);
      }
    }
  }

  void _toggleProduct(SkinCareProductRecommendationDraft product) {
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final next = [...base.skinCareSelectedProductNames];
    final index = next.indexWhere(
      (name) => normalizeSkinCareSelectionKey(name) == product.selectionKey,
    );
    if (index >= 0) {
      next.removeAt(index);
    } else {
      final group = _onboarding7ProductSelectionGroup(product);
      final productsByKey = {
        for (final recommendation in base.skinCareProductRecommendations)
          recommendation.selectionKey: recommendation,
      };
      next.removeWhere((name) {
        final selectedProduct =
            productsByKey[normalizeSkinCareSelectionKey(name)];
        return selectedProduct != null &&
            _onboarding7ProductSelectionGroup(selectedProduct) == group;
      });
      next.add(product.displayName);
    }
    setState(() => _generationError = null);
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        skinCareSelectedProductNames: next,
        skinCareSkipped: false,
      ),
    );
  }

  void _changeDetails() {
    final hasRoutine = ref
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .blocks
        .any((block) => block.section == 'skin_care');
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareProductRecommendations: true,
        clearSkinCareSelectedProductNames: !hasRoutine,
        clearSkinCareSuggestedProducts: !hasRoutine,
        skinCareSkipped: false,
      ),
    );
    setState(() {
      _generationError = null;
    });
  }

  int _effectiveDesiredApplications(BaseTimelineDraft base) {
    return onboarding7NormalizeDesiredApplications(
      _pendingDesiredApplicationsPerDay ??
          base.skinCareDesiredApplicationsPerDay,
    );
  }

  void _changeDesiredApplications(int value) {
    final normalized = onboarding7NormalizeDesiredApplications(value);
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final hasExistingRoutine = base.blocks.any(
      (block) => block.section == 'skin_care',
    );
    setState(() {
      _pendingDesiredApplicationsPerDay = hasExistingRoutine
          ? normalized
          : null;
      _generationError = null;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        skinCareDesiredApplicationsPerDay: hasExistingRoutine
            ? null
            : normalized,
        clearSkinCareRoutineFingerprint: hasExistingRoutine,
        clearSkinCareProductRecommendations: true,
        clearSkinCareSelectedProductNames: !hasExistingRoutine,
        clearSkinCareSuggestedProducts: !hasExistingRoutine,
        skinCareSkipped: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final restored = ref.watch(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinFace,
    );
    final uploadState = ref.watch(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final slotAsset = _slotAssetIfBoundToDraft(uploadState, draft);
    final effectiveAsset =
        _uploadedAsset ??
        slotAsset ??
        restoredAsset ??
        durableSkinFaceAssetFromDraft(draft);
    final uploadBusy = uploadState?.isBusy == true;
    final uploadError =
        _uploadError ??
        ((uploadState?.phase == UploadInteractionPhase.failed ||
                uploadState?.cleanupPending == true)
            ? _friendlySkinCareUploadMessage(uploadState?.attemptError)
            : null);
    final inputsComplete =
        effectiveAsset != null &&
        effectiveAsset.r2Key.trim().isNotEmpty &&
        base.skinCareSkinType != null &&
        base.skinCareProblems.isNotEmpty &&
        base.skinCareBudget != null;
    final message = uploadError ?? _generationError;
    final region = ref.watch(regionSettingsProvider);
    final recommendationCountryName =
        base.skinCareRecommendationCountryCode?.trim().isNotEmpty == true
        ? RegionSettings.forCountry(
            userId: draft.uid,
            countryCode: base.skinCareRecommendationCountryCode!,
          ).countryName
        : region.countryName;
    final desiredApplicationsPerDay = _effectiveDesiredApplications(base);

    final flowStateHolder = ref.watch(skinCareFlowControllerProvider);
    final flowState = flowStateHolder.state;
    final isEditing = flowState == SkinCareFlowState.noProductsEditing;
    final inReviewMode = flowState == SkinCareFlowState.noProductsReview;
    final lifecycleActive = _lifecycle.state.isActive && flowState.isGenerating;
    final busy = uploadBusy || lifecycleActive || _removingPhoto;

    ref.listen(skinCareFlowControllerProvider, (previous, next) {
      final sessionOrEpochChanged =
          previous?.ownerUid != next.ownerUid ||
          previous?.authGeneration != next.authGeneration ||
          previous?.epoch != next.epoch;
      if (sessionOrEpochChanged) {
        _resetPublishedActionCache();
      }
      if (previous?.state.isGenerating == true && !next.state.isGenerating) {
        if (_lifecycle.state.isActive) {
          _lifecycle.cancel();
        }
        ref
            .read(mockOnboardingProvider.notifier)
            .setStepLoading(onboardingSkinCareStepIndex, false);
      }
      if (previous?.state.isEditing == true && !next.state.isEditing) {
        final draft = ref.read(mockOnboardingProvider).draft;
        setState(() {
          _pendingDesiredApplicationsPerDay = null;
          _generationError = null;
          _uploadedAsset =
              _restoredSkinAssetForSlot(
                restored: ref.read(restoredUploadsProvider),
                draft: draft,
                purpose: UploadedAssetPurpose.skinFace,
              ) ??
              durableSkinFaceAssetFromDraft(draft);
        });
      }
    });

    final showProductSelection =
        flowState == SkinCareFlowState.noProductsProductSelection ||
        flowState == SkinCareFlowState.noProductsGeneratingRoutine ||
        (isEditing && base.skinCareProductRecommendations.isNotEmpty);
    final hasProductSelection =
        !inReviewMode &&
        showProductSelection &&
        base.skinCareProductRecommendations.isNotEmpty;
    final hasSharedFooter =
        context.findAncestorWidgetOfExactType<OnboardingStepShell>() != null;
    if (hasProductSelection && hasSharedFooter) {
      final missing = onboarding7MissingEssentialRecommendationCategories(
        base.skinCareProductRecommendations,
        selectedProductNames: base.skinCareSelectedProductNames,
      );
      _publishPrimaryAction(
        OnboardingStep7PrimaryAction(
          label: _routineRetryAvailable
              ? 'Retry routine'
              : 'Build skin routine',
          enabled: !busy && missing.isEmpty,
          loading: busy,
          onPressed: _generate,
        ),
      );
    } else {
      _publishPrimaryAction(null);
    }

    if (lifecycleActive) {
      final isFindProducts =
          _lifecycle.state.operationId?.contains('find-products') ?? false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiThinkingCard(
            title: isFindProducts
                ? 'Skin Care AI'
                : 'Products found ✓ — Skin Care AI',
            detail: isFindProducts
                ? 'Finding useful products available in ${region.countryName}'
                : 'Building your routine from product names and labels',
            accent: isFindProducts
                ? OptivusColors.purpleAccent
                : OptivusColors.roseAccent,
            state: _lifecycle.state,
            onRetry: isFindProducts ? _findProducts : _generate,
          ),
          if (uploadState?.cleanupPending == true)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final resolved = await ref
                          .read(onboardingUploadInteractionProvider.notifier)
                          .remove(uploadState!.slotKey, uid: draft.uid);
                      if (mounted && resolved) {
                        setState(() {
                          _uploadError = null;
                        });
                      }
                    },
              child: const Text('Retry private cleanup'),
            ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
        ],
      );
    }

    if (flowState == SkinCareFlowState.noProductsReview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              base.isSkinCareRoutineCurrent(draft.uid)
                  ? 'Routine built'
                  : 'Changes not applied yet',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          if (!base.isSkinCareRoutineCurrent(draft.uid))
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 2, 24, 0),
              child: Text(
                'Your last routine is kept until a replacement succeeds.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final selectedProductsButton =
                  base.skinCareSuggestedProducts.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey(
                        'onboarding-step7-selected-products-button',
                      ),
                      tooltip: 'Selected products',
                      onPressed: () => _showSkinCareSelectedProductsSheet(
                        context,
                        products: base.skinCareSuggestedProducts,
                        recommendations: base.skinCareProductRecommendations,
                        accent: OptivusColors.purpleAccent,
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      color: OptivusColors.purpleAccent,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      splashRadius: 16,
                    );
              final rebuildAction = OnboardingActionPill(
                label: 'Rebuild / Edit',
                icon: Icons.edit_rounded,
                accent: OptivusColors.purpleAccent,
                compact: true,
                onTap: () {
                  ref
                      .read(skinCareFlowControllerProvider.notifier)
                      .startEditing(base);
                  setState(() {
                    _pendingDesiredApplicationsPerDay = null;
                    _generationError = null;
                  });
                },
              );
              final compactHeader =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18;

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
                child: compactHeader
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: const Text(
                                  'Skin Care',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: OptivusColors.textPrimary,
                                  ),
                                ),
                              ),
                              ?selectedProductsButton,
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Review your routine for the week.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: rebuildAction,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: const Text(
                              'Skin Care',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                          ?selectedProductsButton,
                          rebuildAction,
                        ],
                      ),
              );
            },
          ),
          if (uploadState?.cleanupPending == true)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final resolved = await ref
                          .read(onboardingUploadInteractionProvider.notifier)
                          .remove(uploadState!.slotKey, uid: draft.uid);
                      if (mounted && resolved) {
                        setState(() {
                          _uploadError = null;
                        });
                      }
                    },
              child: const Text('Retry private cleanup'),
            ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
          _SkinCareTimelineSection(
            selectedDay: _selectedDay,
            blocks: widget.blocks,
            onDayChanged: (day) => setState(() => _selectedDay = day),
            emptyLabel: 'No skin care scheduled for this day.',
            accent: OptivusColors.purpleAccent,
            specialCareNotes: base.skinCareSpecialCareNotes,
          ),
        ],
      );
    }

    if (showProductSelection &&
        base.skinCareProductRecommendations.isNotEmpty) {
      final selectedKeys = base.skinCareSelectedProductNames
          .map((name) => normalizeSkinCareSelectionKey(name))
          .toSet();
      final missingEssentialSelections =
          onboarding7MissingEssentialRecommendationCategories(
            base.skinCareProductRecommendations,
            selectedProductNames: base.skinCareSelectedProductNames,
          );
      final selectionMessage = _onboarding7EssentialSelectionMessage(
        missingEssentialSelections,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 0,
            children: [
              TextButton(
                onPressed: busy ? null : _changeDetails,
                child: const Text('Change details'),
              ),
              if (isEditing)
                TextButton.icon(
                  key: const ValueKey(
                    'onboarding-step7-no-products-cancel-rebuild',
                  ),
                  onPressed: () {
                    ref
                        .read(skinCareFlowControllerProvider.notifier)
                        .cancelEditing();
                    setState(() {
                      _pendingDesiredApplicationsPerDay = null;
                      _generationError = null;
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Close editor'),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                // The shell overlays its shared CTA. Reserve its measured
                // obstruction so the final product card can scroll entirely
                // above both the CTA and Android navigation.
                bottom: hasSharedFooter
                    ? OnboardingFooterMetrics.resolve(
                        context,
                      ).requiredContentInset
                    : 8,
              ),
              child: OnboardingGlassCard(
                tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
                padding: const EdgeInsets.all(12),
                radius: 18,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Choose products available in $recommendationCountryName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI matched these to your skin and ${base.skinCareBudget} budget. Select products for $desiredApplicationsPerDay times per day.',
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      if (!hasSharedFooter) ...[
                        const SizedBox(height: 10),
                        _SkinCareGenerateRoutineButton(
                          label: _routineRetryAvailable
                              ? 'Retry routine'
                              : 'Build skin routine',
                          busy: busy,
                          accent: OptivusColors.purpleAccent,
                          onTap: !busy && missingEssentialSelections.isEmpty
                              ? _generate
                              : null,
                        ),
                      ],
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: base.skinCareProductRecommendations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product =
                              base.skinCareProductRecommendations[index];
                          final selected = selectedKeys.contains(
                            product.selectionKey,
                          );
                          final normalizedCategory =
                              onboarding7RecommendationCategory(product);
                          final details = [
                            if (normalizedCategory.isNotEmpty)
                              _onboarding7ProductCategoryLabel(
                                normalizedCategory,
                              )
                            else if (product.category.isNotEmpty)
                              product.category,
                            if (product.estimatedPrice.isNotEmpty)
                              [
                                product.currencyCode,
                                product.estimatedPrice,
                              ].where((part) => part.isNotEmpty).join(' '),
                          ].join(' • ');
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                'onboarding-step7-product-${product.selectionKey}',
                              ),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _toggleProduct(product),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: selected
                                      ? OptivusColors.purpleAccent.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.white.withValues(alpha: 0.38),
                                  border: Border.all(
                                    color: selected
                                        ? OptivusColors.purpleAccent
                                        : Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: selected
                                          ? OptivusColors.purpleAccent
                                          : OptivusColors.textSecondary,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.displayName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: OptivusColors.textPrimary,
                                            ),
                                          ),
                                          if (details.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              details,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    OptivusColors.purpleAccent,
                                              ),
                                            ),
                                          ],
                                          if (product.reason.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              product.reason,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                height: 1.3,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    OptivusColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (uploadState?.cleanupPending == true)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final resolved = await ref
                                      .read(
                                        onboardingUploadInteractionProvider
                                            .notifier,
                                      )
                                      .remove(
                                        uploadState!.slotKey,
                                        uid: draft.uid,
                                      );
                                  if (mounted && resolved) {
                                    setState(() {
                                      _uploadError = null;
                                    });
                                  }
                                },
                          child: const Text('Retry private cleanup'),
                        ),
                      if (message != null) ...[
                        const SizedBox(height: 8),
                        _SkinCareInlineMessage(message: message),
                      ],
                      if (message == null && selectionMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          selectionMessage,
                          key: const ValueKey(
                            'onboarding-step7-essential-selection-message',
                          ),
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEditing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SkinCareInlineMessage(
                message: 'Changes not applied yet. Your last routine is kept.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey(
                    'onboarding-step7-no-products-cancel-rebuild',
                  ),
                  onPressed: busy
                      ? null
                      : () {
                          ref
                              .read(skinCareFlowControllerProvider.notifier)
                              .cancelEditing();
                          setState(() {
                            _pendingDesiredApplicationsPerDay = null;
                            _generationError = null;
                          });
                        },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Close editor'),
                ),
              ),
            ],
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OnboardingGlassCard(
              tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(12),
              radius: 18,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dense = constraints.maxHeight < 620;
                  final sectionGap = dense ? 6.0 : 8.0;
                  final content = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No products',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add a clear face photo and tell us your skin needs. The photo is required for personalized product suggestions.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      if (message != null) ...[
                        SizedBox(height: sectionGap),
                        _SkinCareInlineMessage(message: message, compact: true),
                      ],
                      SizedBox(height: dense ? 6 : 8),
                      SizedBox(
                        height:
                            112 *
                            math.max(
                              1.0,
                              MediaQuery.textScalerOf(context).scale(14) / 14,
                            ),
                        child: _SkinCarePhotoTarget(
                          asset: effectiveAsset,
                          purpose: UploadedAssetPurpose.skinFace,
                          title: 'Add photo',
                          uploadedTitle: 'Photo uploaded',
                          busy: uploadBusy || _removingPhoto,
                          busyLabel: _removingPhoto
                              ? 'Removing...'
                              : uploadBusy
                              ? _skinCareInteractionStatusLabel(
                                  uploadState!.phase,
                                )
                              : null,
                          localPreviewPath: slotAsset == null
                              ? null
                              : uploadState?.usablePreviewPath,
                          helperText: effectiveAsset == null
                              ? 'Face photo required'
                              : null,
                          onRemove: busy ? null : _removeUploadedAsset,
                          onTap: busy ? null : _startUpload,
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareChipGroup(
                        label: 'Skin Type',
                        compact: true,
                        children: [
                          for (final option in const [
                            _SkinOption('oily', 'Oily'),
                            _SkinOption('dry', 'Dry'),
                            _SkinOption('combination', 'Combination'),
                            _SkinOption('not_sure', 'Not sure'),
                          ])
                            _SkinCarePreferenceChip(
                              label: option.label,
                              selected: base.skinCareSkinType == option.key,
                              accent: OptivusColors.purpleAccent,
                              compact: true,
                              onTap: busy
                                  ? null
                                  : () => updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) {
                                        final hasRoutine = base.blocks.any(
                                          (block) =>
                                              block.section == 'skin_care',
                                        );
                                        return base.copyWith(
                                          skinCareSkinType: option.key,
                                          clearSkinCareProductRecommendations:
                                              true,
                                          clearSkinCareSelectedProductNames:
                                              !hasRoutine,
                                          clearSkinCareSuggestedProducts:
                                              !hasRoutine,
                                          skinCareSkipped: false,
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareChipGroup(
                        label: 'Concerns',
                        compact: true,
                        children: [
                          for (final option in const [
                            _SkinOption('pimples', 'Acne'),
                            _SkinOption('dark_spots', 'Spots'),
                            _SkinOption('tan', 'Tan'),
                            _SkinOption('dryness', 'Dryness'),
                            _SkinOption('oiliness', 'Oiliness'),
                            _SkinOption('none', 'None'),
                          ])
                            _SkinCarePreferenceChip(
                              label: option.label,
                              selected: base.skinCareProblems.contains(
                                option.key,
                              ),
                              accent: OptivusColors.purpleAccent,
                              compact: true,
                              onTap: busy
                                  ? null
                                  : () {
                                      final next = {...base.skinCareProblems};
                                      if (option.key == 'none') {
                                        next
                                          ..clear()
                                          ..add('none');
                                      } else {
                                        next.remove('none');
                                        next.contains(option.key)
                                            ? next.remove(option.key)
                                            : next.add(option.key);
                                      }
                                      updateBaseTimelineDraft(
                                        ref,
                                        onboardingSkinCareStepIndex,
                                        (base) {
                                          final hasRoutine = base.blocks.any(
                                            (block) =>
                                                block.section == 'skin_care',
                                          );
                                          return base.copyWith(
                                            skinCareProblems: next.toList(),
                                            clearSkinCareProductRecommendations:
                                                true,
                                            clearSkinCareSelectedProductNames:
                                                !hasRoutine,
                                            clearSkinCareSuggestedProducts:
                                                !hasRoutine,
                                            skinCareSkipped: false,
                                          );
                                        },
                                      );
                                    },
                            ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareChipGroup(
                        label: 'Budget',
                        compact: true,
                        children: [
                          for (final option in const [
                            _SkinOption('low', 'Low'),
                            _SkinOption('medium', 'Medium'),
                            _SkinOption('high', 'High'),
                          ])
                            _SkinCarePreferenceChip(
                              label: option.label,
                              selected: base.skinCareBudget == option.key,
                              accent: OptivusColors.purpleAccent,
                              compact: true,
                              onTap: busy
                                  ? null
                                  : () => updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) {
                                        final hasRoutine = base.blocks.any(
                                          (block) =>
                                              block.section == 'skin_care',
                                        );
                                        return base.copyWith(
                                          skinCareBudget: option.key,
                                          clearSkinCareProductRecommendations:
                                              true,
                                          clearSkinCareSelectedProductNames:
                                              !hasRoutine,
                                          clearSkinCareSuggestedProducts:
                                              !hasRoutine,
                                          skinCareSkipped: false,
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareFrequencySelector(
                        value: desiredApplicationsPerDay,
                        accent: OptivusColors.purpleAccent,
                        compact: true,
                        onChanged: busy ? null : _changeDesiredApplications,
                      ),
                      SizedBox(height: dense ? 8 : 10),
                      _SkinCareGenerateRoutineButton(
                        label: _recommendationRetryAvailable
                            ? 'Retry recommendation'
                            : 'Find products',
                        busy: busy,
                        accent: OptivusColors.purpleAccent,
                        onTap: !busy && inputsComplete ? _findProducts : null,
                      ),
                      if (!inputsComplete) ...[
                        const SizedBox(height: 5),
                        const Text(
                          'Add a face photo and choose skin type, at least one concern, and budget to continue.',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                      if (uploadState?.cleanupPending == true)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final resolved = await ref
                                      .read(
                                        onboardingUploadInteractionProvider
                                            .notifier,
                                      )
                                      .remove(
                                        uploadState!.slotKey,
                                        uid: draft.uid,
                                      );
                                  if (mounted && resolved) {
                                    setState(() {
                                      _uploadError = null;
                                    });
                                  }
                                },
                          child: const Text('Retry private cleanup'),
                        ),
                    ],
                  );
                  return SingleChildScrollView(
                    key: const ValueKey(
                      'onboarding-step7-no-products-scroll-view',
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: OnboardingFooterMetrics.resolve(
                        context,
                      ).requiredContentInset,
                    ),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: content,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
