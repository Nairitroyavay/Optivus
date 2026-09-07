part of '../onboarding_step_7_skin_care_setup.dart';

class _HasProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _HasProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_HasProductsModeScreen> createState() =>
      _HasProductsModeScreenState();
}

class _HasProductsModeScreenState
    extends ConsumerState<_HasProductsModeScreen> {
  static const double _setupTileHeight = 184;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  late final AiGenerationController _lifecycle;
  bool _removingPhoto = false;
  bool _editingExisting = false;
  late bool _photoProductsReviewed;
  List<SkinCareDetectedProduct> _reviewedPhotoDetails = const [];
  String? _generationError;
  late _ProductInputSource _inputSource;
  int _selectedDay = DateTime.now().weekday;
  final _productNamesTargetKey = GlobalKey();
  String? _publishedActionSignature;
  late final Step7ActionBridgeNotifier _actionBridge;
  late final SkinCareFlowController _flowController;

  void _publishPrimaryAction(OnboardingStep7PrimaryAction? action) {
    final signature = action == null
        ? null
        : '${action.label}|${action.enabled}|${action.loading}';
    if (_publishedActionSignature == signature) return;
    _publishedActionSignature = signature;
    final epoch = _flowController.currentEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _publishedActionSignature != signature) return;
      _actionBridge.publish(
        ownerId: 'has_products',
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
    _controller = TextEditingController(text: widget.base.skinCareProductNames);
    _focusNode = FocusNode();
    final draft = ref.read(mockOnboardingProvider).draft;
    _uploadedAsset =
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinProducts,
        ) ??
        durableSkinProductsAssetFromDraft(draft);
    _inputSource = _uploadedAsset != null
        ? _ProductInputSource.photo
        : _initialProductInputSource(widget.base);
    _reviewedPhotoDetails = widget.base.skinCareReviewedProducts;
    _photoProductsReviewed =
        _inputSource == _ProductInputSource.photo &&
        _reviewedPhotoDetails.isNotEmpty;
  }

  void _onLifecycleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_onLifecycleChanged);
    _lifecycle.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _actionBridge.clear(
      ownerId: 'has_products',
      epoch: _flowController.currentEpoch,
    );
    super.dispose();
  }

  Future<void> _startUpload() async {
    final initialUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
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
    final controller = ref.read(onboardingUploadInteractionProvider.notifier);
    final asset = retrying
        ? await controller.retry(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : source == _SkinPhotoSource.camera
        ? await controller.takePhoto(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : await controller.chooseFromGallery(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          );
    if (!mounted) return;

    final latestUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final latestAsset = asset;
    if (latestAsset != null) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareProductPhotoAssetId: latestAsset.assetId,
          skinCareProductPhotoR2Key: latestAsset.r2Key,
          skinCareProductPhotoStatus: latestAsset.status.wireName,
          skinCareProductPhotoCreatedAt: latestAsset.createdAt,
          skinCareProductPhotoUpdatedAt: latestAsset.updatedAt,
          skinCareSkipped: false,
        ),
      );
    }
    setState(() {
      if (latestAsset != null) {
        _uploadedAsset = latestAsset;
        _inputSource = _ProductInputSource.photo;
        _photoProductsReviewed = false;
        _reviewedPhotoDetails = const [];
      } else if (_uploadedAsset == null &&
          _inputSource == _ProductInputSource.photo) {
        _inputSource = _ProductInputSource.none;
      }
      _uploadError = latestUploadState?.phase == UploadInteractionPhase.failed
          ? _friendlySkinCareUploadMessage(latestUploadState?.attemptError)
          : null;
      _generationError = null;
    });
    if (latestAsset != null) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          clearSkinCareReviewedProducts: true,
          skinCareSkipped: false,
        ),
      );
      ref.read(restoredUploadsProvider.notifier).registerUploaded(latestAsset);
    }
  }

  Future<void> _removeUploadedAsset() async {
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;
    final draft = ref.read(mockOnboardingProvider).draft;
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinProducts,
        ) ??
        durableSkinProductsAssetFromDraft(draft);
    if (asset != null && asset.assetId.trim().isNotEmpty) {
      setState(() {
        _removingPhoto = true;
        _uploadError = null;
        _generationError = null;
      });
      final removed = await ref
          .read(onboardingUploadInteractionProvider.notifier)
          .remove(
            onboardingSkinProductsUploadSlot,
            uid: asset.ownerUid.trim().isNotEmpty ? asset.ownerUid : draft.uid,
          );
      if (!mounted) return;
      final latest = ref.read(
        onboardingUploadInteractionProvider,
      )[onboardingSkinProductsUploadSlot];
      if (!removed) {
        setState(() {
          _removingPhoto = false;
          _uploadError = _friendlySkinCareUploadMessage(latest?.attemptError);
        });
        if (latest?.durableAsset == null) {
          setState(() {
            _uploadedAsset = null;
            _reviewedPhotoDetails = const [];
            _photoProductsReviewed = false;
            _inputSource = _controller.text.trim().isEmpty
                ? _ProductInputSource.none
                : _ProductInputSource.typed;
          });
          updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (base) => base.copyWith(
              clearSkinCareProductPhoto: true,
              clearSkinCareReviewedProducts: true,
              clearSkinCareRoutineFingerprint: true,
              clearSkinCareSuggestedProducts: true,
            ),
          );
        }
        return;
      }
    }
    final hasTypedProducts = _controller.text.trim().isNotEmpty;
    final manuallyReviewed = onboarding7ParseTypedProductDetails(
      _controller.text,
    );
    setState(() {
      _uploadedAsset = null;
      _removingPhoto = false;
      _photoProductsReviewed = false;
      _reviewedPhotoDetails = const [];
      _uploadError = null;
      _generationError = null;
      _inputSource = hasTypedProducts
          ? _ProductInputSource.typed
          : _ProductInputSource.none;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareProductPhoto: true,
        skinCareReviewedProducts: manuallyReviewed,
        clearSkinCareRoutineFingerprint: true,
        clearSkinCareSuggestedProducts: true,
        skinCareSkipped: false,
      ),
    );
  }

  Future<void> _generate() async {
    if (_lifecycle.state.isActive) return;
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy) return;

    final activeSource = _inputSource;
    final draft = ref.read(mockOnboardingProvider).draft;
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinProducts,
        ) ??
        durableSkinProductsAssetFromDraft(draft);
    var typedProductDetails = onboarding7ParseTypedProductDetails(
      _controller.text,
    );
    if (activeSource == _ProductInputSource.none) {
      setState(() {
        _generationError = _onboarding7NoTypedProductsMessage;
        _uploadError = null;
      });
      return;
    }
    if ((activeSource == _ProductInputSource.typed ||
            (activeSource == _ProductInputSource.photo &&
                _photoProductsReviewed)) &&
        typedProductDetails.isEmpty) {
      setState(() {
        _generationError = _onboarding7NoTypedProductsMessage;
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.photo && asset == null) {
      setState(() {
        _generationError = _onboarding7PhotoUnreadableMessage;
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.photo &&
        asset!.r2Key.trim().isEmpty) {
      setState(() {
        _generationError = 'Upload incomplete. Please upload again.';
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.photo &&
        !_isSupportedSkinCareImageContentType(asset!.contentType)) {
      setState(() {
        _generationError =
            'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
        _uploadError = null;
      });
      return;
    }

    final currentAuthGeneration = ref.read(authGenerationProvider);
    final currentSource = activeSource;
    final currentAssetId = asset?.assetId;
    final currentAssetKey = asset?.r2Key;
    final user = ref.read(authProvider).user;
    final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;

    setState(() {
      _generationError = null;
      _uploadError = null;
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    final isPhotoAnalyze =
        _inputSource == _ProductInputSource.photo && !_photoProductsReviewed;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    final run = await _lifecycle.run<bool>(
      operationType: isPhotoAnalyze ? 'skin-care-analyze' : 'skin-care-routine',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: isPhotoAnalyze
          ? 'Getting your photo ready…'
          : 'Getting your skin care preferences ready…',
      isSessionCurrent: () =>
          mounted &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(mockOnboardingProvider).draft.uid) ==
              uid &&
          (currentSource != _ProductInputSource.photo ||
              (() {
                final live =
                    ref
                        .read(
                          onboardingUploadInteractionProvider,
                        )[onboardingSkinProductsUploadSlot]
                        ?.durableAsset ??
                    durableSkinProductsAssetFromDraft(
                      ref.read(mockOnboardingProvider).draft,
                    );
                return live?.assetId == currentAssetId &&
                    live?.r2Key == currentAssetKey;
              })()) &&
          _inputSource == currentSource,
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
        final desiredApplicationsPerDay = ref
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline
            .skinCareDesiredApplicationsPerDay;
        final latestBase = ref.read(mockOnboardingProvider).draft.baseTimeline;
        final skinType = latestBase.skinCareSkinType ?? 'not_sure';
        final mainProblem = latestBase.skinCareProblems
            .where((problem) => problem != 'none')
            .firstOrNull;
        final budget = latestBase.skinCareBudget ?? 'medium';
        final routinePreference = latestBase.skinCarePreference ?? 'balanced';

        if (isPhotoAnalyze) {
          scope.transition(
            AiGenerationPhase.analyzing,
            message: 'Analyzing your skin care products…',
          );
          final analysis = await client.analyzeProducts(
            uid: uid,
            idToken: idToken,
            productPhotos: [asset!.r2Key.trim()],
          );
          if (!scope.isCurrent) return false;
          if (analysis.hasError) {
            throw _SkinCareResponseException(
              onboarding7FriendlyAiMessage(
                analysis.errorMessage,
                analysis.warnings,
              ),
              errorCode: analysis.errorCode,
            );
          }
          final photoProductDetails = analysis.detectedProducts;
          final photoProductNames = onboarding7ExtractPhotoProductNames(
            analysis.products,
          );
          final hasMeaningfulPhotoProducts = photoProductDetails.any(
            (product) => product.hasMeaningfulData,
          );
          if (photoProductNames.isEmpty && !hasMeaningfulPhotoProducts) {
            throw const _SkinCareResponseException(
              _onboarding7PhotoUnreadableMessage,
            );
          }
          final reviewText = photoProductDetails
              .where((product) => product.hasMeaningfulData)
              .map((product) {
                final displayName = product.displayName.trim();
                final name = displayName.isNotEmpty
                    ? displayName
                    : product.fallbackLabel.trim();
                final category = product.category.trim();
                return category.isEmpty ? name : '$name - $category';
              })
              .where((line) => line.isNotEmpty)
              .join('\n');
          final fallbackText = photoProductNames.join('\n');
          _controller.text = reviewText.isNotEmpty ? reviewText : fallbackText;
          updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (base) => base.copyWith(
              skinCareProductNames: _controller.text,
              skinCareReviewedProducts: photoProductDetails,
              skinCareSkipped: false,
            ),
          );
          _reviewedPhotoDetails = photoProductDetails;
          _photoProductsReviewed = true;
          return true;
        } else {
          scope.transition(
            AiGenerationPhase.generating,
            message: 'Building your skin care routine…',
          );
          final typedProductDetails = onboarding7ReconcileReviewedProducts(
            _controller.text,
            ref
                .read(mockOnboardingProvider)
                .draft
                .baseTimeline
                .skinCareReviewedProducts,
          );
          final ownedProductDetails = typedProductDetails;
          final ownedProductNames = typedProductDetails
              .map((product) => product.displayName.trim())
              .where((name) => name.isNotEmpty)
              .toList(growable: false);
          final routineParams = {
            'productInputSource': 'typed',
            'typedProductDetails': typedProductDetails
                .map((product) => product.toMap())
                .toList(),
            'desiredApplicationsPerDay': desiredApplicationsPerDay,
            'skinType': skinType,
            'mainProblem': mainProblem ?? 'none',
            'budget': budget,
            'routinePreference': routinePreference,
          };

          var result = await client.generateRoutine(
            uid: uid,
            idToken: idToken,
            params: routineParams,
          );

          var didCompactPayloadRetry = false;
          if (result.hasError && result.errorCode == 'json_payload_too_large') {
            didCompactPayloadRetry = true;
            result = await client.generateRoutine(
              uid: uid,
              idToken: idToken,
              params: {
                ...routineParams,
                'typedProductDetails': typedProductDetails
                    .map((product) => product.toCompactRoutinePayload())
                    .toList(),
                'compact': true,
              },
            );
          }
          if (!scope.isCurrent) return false;

          final routinePlans = result.routinePlans;

          if (result.hasError || routinePlans.isEmpty) {
            final errMsg = routinePlans.isEmpty && !result.hasError
                ? _onboarding7AiEmptyMessage
                : (didCompactPayloadRetry &&
                          result.errorCode == 'json_payload_too_large'
                      ? onboarding7CompactPayloadFinalMessage
                      : onboarding7FriendlyAiMessage(
                          result.errorMessage,
                          result.warnings,
                        ));
            throw _SkinCareResponseException(
              errMsg,
              errorCode: result.errorCode,
            );
          }

          final partitioned = onboarding7PartitionRoutinePlans(routinePlans);
          var dailyPlans = partitioned.dailyPlans.where((plan) {
            if (plan.productNames.isEmpty && plan.missingItems.isNotEmpty) {
              return false;
            }
            if (plan.productNames.isEmpty) {
              return false;
            }
            return true;
          }).toList();
          final specialPlans = partitioned.specialCarePlans;

          final specialCareNotesForResult =
              onboarding7SpecialCareNotesFromAiResult(
                suggestedProducts: result.suggestedProducts,
                weeklyRoutine: result.weeklyRoutine,
                specialCarePlans: specialPlans,
                ownedProductNames: ownedProductNames,
              );

          if (result.warnings.any(
            (warning) =>
                warning.contains('ai_wrong_daily_slot_count') ||
                warning.contains('ai_missing_required_slot:') ||
                warning.contains('ai_extra_daily_slot_count'),
          )) {
            updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
              return base.copyWith(
                skinCareProductNames: _controller.text,
                skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
                skinCareSkipped: false,
                skinCareSpecialCareNotes:
                    base.blocks.any((block) => block.section == 'skin_care')
                    ? base.skinCareSpecialCareNotes
                    : specialCareNotesForResult,
              );
            });
            throw _SkinCareResponseException(
              onboarding7FriendlyAiMessage(null, result.warnings),
            );
          }

          final schedule = onboarding7ScheduleSkinCareRoutine(
            baseTimeline: ref.read(mockOnboardingProvider).draft.baseTimeline,
            routinePlans: dailyPlans,
            desiredApplicationsPerDay: desiredApplicationsPerDay,
            ownedProductNames: ownedProductNames,
            ownedProductDetails: ownedProductDetails,
            forceEveryDay: true,
          );
          if (schedule.hasError || schedule.blocks.isEmpty) {
            updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
              return base.copyWith(
                skinCareProductNames: _controller.text,
                skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
                skinCareSkipped: false,
                skinCareSpecialCareNotes:
                    base.blocks.any((block) => block.section == 'skin_care')
                    ? base.skinCareSpecialCareNotes
                    : specialCareNotesForResult,
              );
            });
            throw _SkinCareResponseException(
              schedule.errorMessage ?? _onboarding7AiEmptyMessage,
            );
          }

          updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
            final draftForFingerprint = base.copyWith(
              skinCareProductNames: _controller.text,
              skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
              skinCareReviewedProducts: ownedProductDetails,
              skinCareSkipped: false,
              skinCareSpecialCareNotes: specialCareNotesForResult,
            );
            final routineFingerprint = draftForFingerprint
                .computeSkinCareRoutineFingerprint();
            final taggedBlocks = schedule.blocks.map((block) {
              final prov = List<String>.from(block.provenanceSourceIds);
              final token = 'skin-care-generation:$routineFingerprint';
              if (!prov.contains(token)) prov.add(token);
              if (_uploadedAsset != null) {
                if (_uploadedAsset!.assetId.isNotEmpty &&
                    !prov.contains(_uploadedAsset!.assetId)) {
                  prov.add(_uploadedAsset!.assetId);
                }
                if (_uploadedAsset!.r2Key.isNotEmpty &&
                    !prov.contains(_uploadedAsset!.r2Key)) {
                  prov.add(_uploadedAsset!.r2Key);
                }
              }
              return block.copyWith(provenanceSourceIds: prov);
            }).toList();

            final List<TimelineBlockDraft> nextBlocks =
                base.blocks.where((b) => b.section != 'skin_care').toList()
                  ..addAll(taggedBlocks);
            return draftForFingerprint.copyWith(
              blocks: nextBlocks,
              skinCareRoutineFingerprint: routineFingerprint,
            );
          });

          return true;
        }
      },
    );

    if (mounted) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _editingExisting = false;
          _generationError = null;
        });
        ref
            .read(skinCareFlowControllerProvider.notifier)
            .commitRebuildSuccess(
              ref.read(mockOnboardingProvider).draft.baseTimeline,
            );
      } else if (run.error != null) {
        setState(() {
          _generationError = run.error!.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;
    final restored = ref.watch(restoredUploadsProvider);
    final draft = ref.watch(mockOnboardingProvider).draft;
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinProducts,
    );
    final uploadState = ref.watch(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final slotAsset = uploadState?.durableAsset;
    final effectiveAsset =
        _uploadedAsset ??
        slotAsset ??
        restoredAsset ??
        durableSkinProductsAssetFromDraft(draft);
    final uploadBusy = uploadState?.isBusy == true;
    final uploadError =
        _uploadError ??
        ((uploadState?.phase == UploadInteractionPhase.failed ||
                uploadState?.cleanupPending == true)
            ? _friendlySkinCareUploadMessage(uploadState?.attemptError)
            : null);
    final busy = uploadBusy || _lifecycle.state.isActive || _removingPhoto;
    final sourceLabel =
        _inputSource == _ProductInputSource.photo && _photoProductsReviewed
        ? 'Review detected products before building'
        : _productInputSourceLabel(_inputSource);
    final textInputEnabled = !_lifecycle.state.isActive;
    final photoUploadEnabled = !busy;
    final typedPreviewProducts = onboarding7ParseTypedProductDetails(
      _controller.text,
    );
    final canGenerate =
        !busy &&
        (switch (_inputSource) {
          _ProductInputSource.none =>
            typedPreviewProducts.isNotEmpty || effectiveAsset != null,
          _ProductInputSource.typed => typedPreviewProducts.isNotEmpty,
          _ProductInputSource.photo =>
            effectiveAsset != null &&
                (!_photoProductsReviewed || typedPreviewProducts.isNotEmpty),
        });
    final inReviewMode = generated && !_editingExisting;
    final usesGlobalBuildAction =
        !inReviewMode &&
        (_inputSource != _ProductInputSource.photo || _photoProductsReviewed);
    final hasSharedFooter =
        context.findAncestorWidgetOfExactType<OnboardingStepShell>() != null;
    _publishPrimaryAction(
      usesGlobalBuildAction && hasSharedFooter
          ? OnboardingStep7PrimaryAction(
              label: 'Build skin routine',
              enabled: canGenerate,
              loading: _lifecycle.state.isActive,
              onPressed: _generate,
            )
          : null,
    );
    final textHelper =
        _inputSource == _ProductInputSource.photo && !_photoProductsReviewed
        ? 'Read labels to review and correct detected products.'
        : null;

    void handleProductNamesChanged(String value) {
      final hasText = value.trim().isNotEmpty;
      final canonical = onboarding7ReconcileReviewedProducts(
        value,
        ref
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline
            .skinCareReviewedProducts,
      );
      setState(() {
        _generationError = null;
        if (_inputSource == _ProductInputSource.none && hasText) {
          _inputSource = _ProductInputSource.typed;
        } else if (_inputSource == _ProductInputSource.typed && !hasText) {
          _inputSource = _ProductInputSource.none;
        }
        if (_inputSource == _ProductInputSource.photo &&
            _photoProductsReviewed) {
          _reviewedPhotoDetails = canonical;
        }
      });
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareProductNames: value,
          skinCareReviewedProducts: canonical,
          skinCareSkipped: false,
        ),
      );
    }

    final setupCard = _HasProductsSetupCard(
      base: widget.base,
      controller: _controller,
      focusNode: _focusNode,
      productNamesTargetKey: _productNamesTargetKey,
      asset: effectiveAsset,
      tileHeight: _setupTileHeight,
      sourceLabel: sourceLabel,
      productCount: typedPreviewProducts.length,
      desiredApplicationsPerDay: widget.base.skinCareDesiredApplicationsPerDay,
      uploadBusy: uploadBusy || _removingPhoto,
      uploadStatusLabel: _removingPhoto
          ? 'Removing photo...'
          : uploadBusy
          ? _skinCareInteractionStatusLabel(uploadState!.phase)
          : null,
      localPreviewPath: uploadState?.usablePreviewPath,
      busy: busy,
      generating: _lifecycle.state.isActive,
      photoEnabled: photoUploadEnabled,
      textInputEnabled: textInputEnabled,
      photoHelper: _inputSource == _ProductInputSource.typed
          ? 'Or add one photo, then review the detected products.'
          : null,
      textHelper: textHelper,
      onUpload: photoUploadEnabled ? _startUpload : null,
      onRemove: busy ? null : _removeUploadedAsset,
      showGenerateAction: !usesGlobalBuildAction || !hasSharedFooter,
      generateLabel:
          _inputSource == _ProductInputSource.photo && !_photoProductsReviewed
          ? 'Read product labels'
          : 'Build skin routine',
      onGenerate: canGenerate ? _generate : null,
      onSkinTypeChanged: busy
          ? null
          : (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCareSkinType: value,
                skinCareSkipped: false,
              ),
            ),
      onConcernChanged: busy
          ? null
          : (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCareProblems: [value],
                skinCareSkipped: false,
              ),
            ),
      onPreferenceChanged: busy
          ? null
          : (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCarePreference: value,
                skinCareSkipped: false,
              ),
            ),
      onFrequencyChanged: busy
          ? null
          : (value) {
              setState(() => _generationError = null);
              updateBaseTimelineDraft(
                ref,
                onboardingSkinCareStepIndex,
                (base) => base.copyWith(
                  skinCareDesiredApplicationsPerDay: value,
                  skinCareSkipped: false,
                ),
              );
            },
      onChanged: handleProductNamesChanged,
    );
    final message = uploadError ?? _generationError;

    if (_lifecycle.state.isActive) {
      final isPhotoAnalyze =
          _inputSource == _ProductInputSource.photo && !_photoProductsReviewed;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiThinkingCard(
            title: 'Skin Care AI',
            detail: isPhotoAnalyze
                ? 'Looking for product names and active ingredients'
                : 'Building your routine from product names and labels',
            accent: OptivusColors.roseAccent,
            state: _lifecycle.state,
            onRetry: _generate,
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

    if (!generated || _editingExisting) {
      if (!_editingExisting && MediaQuery.viewInsetsOf(context).bottom > 0) {
        return _SkinCareProductNamesTarget(
          key: _productNamesTargetKey,
          controller: _controller,
          focusNode: _focusNode,
          enabled: textInputEnabled,
          helperText: textHelper,
          productCount: typedPreviewProducts.length,
          onChanged: handleProductNamesChanged,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editingExisting) ...[
            const _SkinCareInlineMessage(
              message: 'Changes not applied yet. Your last routine is kept.',
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('onboarding-step7-cancel-rebuild'),
                onPressed: busy
                    ? null
                    : () {
                        ref
                            .read(skinCareFlowControllerProvider.notifier)
                            .cancelEditing();
                        final base = ref
                            .read(mockOnboardingProvider)
                            .draft
                            .baseTimeline;
                        _controller.text = base.skinCareProductNames ?? '';
                        setState(() {
                          _editingExisting = false;
                          _generationError = null;
                        });
                      },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Close editor'),
              ),
            ),
            const SizedBox(height: 4),
          ],
          setupCard,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OnboardingGlassCard(
                tint: OptivusColors.roseAccent.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                radius: 20,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: OptivusColors.roseAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                draft.baseTimeline.isSkinCareRoutineCurrent(
                                      draft.uid,
                                    )
                                    ? 'Routine built'
                                    : 'Changes not applied yet',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.base.skinCareDesiredApplicationsPerDay} routines per day',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    OnboardingActionPill(
                      label: 'Rebuild / Edit',
                      icon: Icons.edit_rounded,
                      accent: OptivusColors.roseAccent,
                      compact: true,
                      onTap: () {
                        ref
                            .read(skinCareFlowControllerProvider.notifier)
                            .startEditing(draft.baseTimeline);
                        setState(() {
                          _editingExisting = true;
                          _generationError = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          _SkinCareInlineMessage(message: message),
        ],
        const SizedBox(height: 12),
        _SkinCareTimelineSection(
          selectedDay: _selectedDay,
          blocks: widget.blocks,
          onDayChanged: (d) => setState(() => _selectedDay = d),
          emptyLabel: 'Build your skin-care routine first.',
          accent: OptivusColors.roseAccent,
          specialCareNotes: widget.base.skinCareSpecialCareNotes,
        ),
      ],
    );
  }
}

class _HasProductsSetupCard extends StatelessWidget {
  final BaseTimelineDraft base;
  final TextEditingController controller;
  final UploadedAsset? asset;
  final double tileHeight;
  final String? sourceLabel;
  final int productCount;
  final int desiredApplicationsPerDay;
  final bool uploadBusy;
  final String? uploadStatusLabel;
  final String? localPreviewPath;
  final FocusNode? focusNode;
  final Key? productNamesTargetKey;
  final bool busy;
  final bool generating;
  final bool photoEnabled;
  final bool textInputEnabled;
  final String? photoHelper;
  final String? textHelper;
  final VoidCallback? onUpload;
  final VoidCallback? onRemove;
  final VoidCallback? onGenerate;
  final bool showGenerateAction;
  final String generateLabel;
  final ValueChanged<String>? onSkinTypeChanged;
  final ValueChanged<String>? onConcernChanged;
  final ValueChanged<String>? onPreferenceChanged;
  final ValueChanged<int>? onFrequencyChanged;
  final ValueChanged<String> onChanged;

  const _HasProductsSetupCard({
    required this.base,
    required this.controller,
    this.focusNode,
    this.productNamesTargetKey,
    required this.asset,
    required this.tileHeight,
    required this.sourceLabel,
    required this.productCount,
    required this.desiredApplicationsPerDay,
    required this.uploadBusy,
    required this.uploadStatusLabel,
    required this.localPreviewPath,
    required this.busy,
    required this.generating,
    required this.photoEnabled,
    required this.textInputEnabled,
    required this.photoHelper,
    required this.textHelper,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
    this.showGenerateAction = true,
    required this.generateLabel,
    required this.onSkinTypeChanged,
    required this.onConcernChanged,
    required this.onPreferenceChanged,
    required this.onFrequencyChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final effectiveTileHeight = keyboardOpen ? 120.0 : tileHeight;
    return OnboardingGlassCard(
      key: const ValueKey('onboarding-step7-products-setup-card'),
      tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'I have products',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                if (sourceLabel != null) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: OptivusColors.roseAccent,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      sourceLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.roseAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Upload one clear photo with all your skin-care products together. Keep front labels visible.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 280;
              final photo = SizedBox(
                height: effectiveTileHeight,
                child: _SkinCarePhotoTarget(
                  asset: asset,
                  localPreviewPath: localPreviewPath,
                  purpose: UploadedAssetPurpose.skinProducts,
                  title: 'Add photo',
                  uploadedTitle: 'Photo uploaded',
                  busy: uploadBusy,
                  busyLabel: uploadStatusLabel,
                  enabled: photoEnabled,
                  helperText: photoHelper,
                  onRemove: onRemove,
                  onTap: onUpload,
                ),
              );
              final input = SizedBox(
                height: effectiveTileHeight,
                child: _SkinCareProductNamesTarget(
                  key: productNamesTargetKey,
                  controller: controller,
                  focusNode: focusNode,
                  enabled: textInputEnabled,
                  helperText: textHelper,
                  productCount: productCount,
                  onChanged: onChanged,
                ),
              );

              if (!sideBySide) {
                if (keyboardOpen) {
                  return input;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [photo, const SizedBox(height: 10), input],
                );
              }

              return SizedBox(
                height: effectiveTileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: photo),
                    const SizedBox(width: 10),
                    Expanded(child: input),
                  ],
                ),
              );
            },
          ),
          if (!keyboardOpen) ...[
            const SizedBox(height: 4),
            _SkinCarePersonalizeSection(
              skinType: base.skinCareSkinType ?? 'not_sure',
              concern: base.skinCareProblems.firstOrNull ?? 'none',
              preference: base.skinCarePreference ?? 'balanced',
              onSkinTypeChanged: onSkinTypeChanged,
              onConcernChanged: onConcernChanged,
              onPreferenceChanged: onPreferenceChanged,
            ),
            const SizedBox(height: 4),
            _SkinCareFrequencySelector(
              value: desiredApplicationsPerDay,
              onChanged: onFrequencyChanged,
            ),
            if (showGenerateAction) ...[
              const SizedBox(height: 12),
              _SkinCareGenerateRoutineButton(
                label: uploadBusy ? 'Please wait...' : generateLabel,
                busy: generating,
                onTap: onGenerate,
                accent: OptivusColors.roseAccent,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
