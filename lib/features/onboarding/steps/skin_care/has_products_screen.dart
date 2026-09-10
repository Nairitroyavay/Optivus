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
  String? _generationError;
  late _ProductInputSource _inputSource;
  int _selectedDay = DateTime.now().weekday;
  final _productNamesTargetKey = GlobalKey();
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
    final draft = ref.read(onboardingStateProvider).draft;
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
    _controller = TextEditingController(text: widget.base.skinCareProductNames);
    _focusNode = FocusNode();
    final draft = ref.read(onboardingStateProvider).draft;
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
    final draft = ref.read(onboardingStateProvider).draft;
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
    if (uploadState?.effectiveAsset == null) return null;
    return currentSkinPhotoForTransaction(
      slot: uploadState,
      draft: draft,
      purpose: UploadedAssetPurpose.skinProducts,
    );
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
    ref.read(onboardingStateProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(onboardingStateProvider).draft.uid;
    final requestAuthGeneration = ref.read(authGenerationProvider);
    final requestFlowEpoch = _flowController.currentEpoch;
    final requestFlowState = _flowController.currentFlowState;
    final isEditing = requestFlowState.isEditing;
    final controller = ref.read(onboardingUploadInteractionProvider.notifier);
    final asset = retrying
        ? await controller.retry(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            deferReplacement: isEditing,
          )
        : source == _SkinPhotoSource.camera
        ? await controller.takePhoto(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            deferReplacement: isEditing,
          )
        : await controller.chooseFromGallery(
            onboardingSkinProductsUploadSlot,
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
      if (!isEditing) {
        ref
            .read(restoredUploadsProvider.notifier)
            .registerUploaded(latestAsset);
      }
    }
  }

  Future<void> _removeUploadedAsset() async {
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;
    final draft = ref.read(onboardingStateProvider).draft;
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
        if (latest?.durableAsset == null &&
            latest?.pendingReplacementAsset == null) {
          setState(() {
            _uploadedAsset = null;
            _inputSource = _controller.text.trim().isEmpty
                ? _ProductInputSource.none
                : _ProductInputSource.typed;
          });
          _flowController.clearSnapshotPhoto(isProductPhoto: true);
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
    _flowController.clearSnapshotPhoto(isProductPhoto: true);
    setState(() {
      _uploadedAsset = null;
      _removingPhoto = false;
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
    final draft = ref.read(onboardingStateProvider).draft;
    final asset = currentSkinPhotoForTransaction(
      slot: uploadState,
      draft: draft,
      purpose: UploadedAssetPurpose.skinProducts,
    );
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
    final flowState = _flowController.currentFlowState;
    final photoNeedsReview =
        activeSource == _ProductInputSource.photo &&
        (flowState == SkinCareFlowState.hasProductsPhotoReview ||
            widget.base.skinCareReviewedProducts.isEmpty);
    if ((activeSource == _ProductInputSource.typed ||
            (activeSource == _ProductInputSource.photo && !photoNeedsReview)) &&
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
    final uid = user?.uid ?? ref.read(onboardingStateProvider).draft.uid;

    setState(() {
      _generationError = null;
      _uploadError = null;
    });
    ref
        .read(onboardingStateProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    final isPhotoAnalyze = photoNeedsReview;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    _flowController.startGeneration(SkinCareFlowState.hasProductsGenerating);
    final requestEpoch = _flowController.currentEpoch;

    final run = await _lifecycle.run<bool>(
      operationType: isPhotoAnalyze ? 'skin-care-analyze' : 'skin-care-routine',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: isPhotoAnalyze
          ? 'Getting your photo ready…'
          : 'Getting your skin care preferences ready…',
      isSessionCurrent: () =>
          mounted &&
          _flowController.currentEpoch == requestEpoch &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(onboardingStateProvider).draft.uid) ==
              uid &&
          (currentSource != _ProductInputSource.photo ||
              (() {
                final live = currentSkinPhotoForTransaction(
                  slot: ref.read(
                    onboardingUploadInteractionProvider,
                  )[onboardingSkinProductsUploadSlot],
                  draft: ref.read(onboardingStateProvider).draft,
                  purpose: UploadedAssetPurpose.skinProducts,
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
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .skinCareDesiredApplicationsPerDay;
        final latestBase = ref.read(onboardingStateProvider).draft.baseTimeline;
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
          return true;
        } else {
          scope.transition(
            AiGenerationPhase.generating,
            message: 'Building your skin care routine…',
          );
          final typedProductDetails = onboarding7ReconcileReviewedProducts(
            _controller.text,
            ref
                .read(onboardingStateProvider)
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
            baseTimeline: ref.read(onboardingStateProvider).draft.baseTimeline,
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
              if (asset != null) {
                if (asset.assetId.isNotEmpty && !prov.contains(asset.assetId)) {
                  prov.add(asset.assetId);
                }
                if (asset.r2Key.isNotEmpty && !prov.contains(asset.r2Key)) {
                  prov.add(asset.r2Key);
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
              skinCareSetupStep: 2,
            );
          });

          return true;
        }
      },
    );

    if (mounted) {
      ref
          .read(onboardingStateProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _generationError = null;
        });
        if (isPhotoAnalyze) {
          if (_flowController.currentEpoch == requestEpoch) {
            _flowController.completeGeneration();
          }
        } else {
          _flowController.commitRebuildSuccess(
            ref.read(onboardingStateProvider).draft.baseTimeline,
          );
        }
      } else if (run.error != null) {
        setState(() {
          _generationError = run.error!.message;
        });
        _flowController.failGeneration(run.error!.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingStateProvider).draft;
    final flowStateHolder = ref.watch(skinCareFlowControllerProvider);
    final flowState = flowStateHolder.state;
    final isEditing = flowState == SkinCareFlowState.hasProductsEditing;
    final isEditingTransaction =
        isEditing ||
        (flowState.isGenerating &&
            flowStateHolder.generationOrigin?.isEditing == true);
    final inReviewMode = flowState == SkinCareFlowState.hasProductsReview;
    final lifecycleActive = _lifecycle.state.isActive && flowState.isGenerating;

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
            .read(onboardingStateProvider.notifier)
            .setStepLoading(onboardingSkinCareStepIndex, false);
      }
      if (previous?.state.isEditing == true && !next.state.isEditing) {
        final draft = ref.read(onboardingStateProvider).draft;
        final base = draft.baseTimeline;
        _controller.text = base.skinCareProductNames ?? '';
        final restoredCurrent =
            _restoredSkinAssetForSlot(
              restored: ref.read(restoredUploadsProvider),
              draft: draft,
              purpose: UploadedAssetPurpose.skinProducts,
            ) ??
            durableSkinProductsAssetFromDraft(draft);
        setState(() {
          _generationError = null;
          _uploadedAsset = restoredCurrent;
          _inputSource = _uploadedAsset != null
              ? _ProductInputSource.photo
              : _controller.text.trim().isNotEmpty
              ? _ProductInputSource.typed
              : _ProductInputSource.none;
        });
      }
    });

    final restored = ref.watch(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinProducts,
    );
    final uploadState = ref.watch(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final slotAsset = _slotAssetIfBoundToDraft(uploadState, draft);
    final effectiveAsset =
        slotAsset ??
        restoredAsset ??
        _uploadedAsset ??
        durableSkinProductsAssetFromDraft(draft);
    final uploadBusy = uploadState?.isBusy == true;
    final uploadError =
        _uploadError ??
        ((uploadState?.phase == UploadInteractionPhase.failed ||
                uploadState?.cleanupPending == true)
            ? _friendlySkinCareUploadMessage(uploadState?.attemptError)
            : null);
    final busy = uploadBusy || lifecycleActive || _removingPhoto;
    final isPhotoReview =
        flowState == SkinCareFlowState.hasProductsPhotoReview ||
        (_inputSource == _ProductInputSource.photo &&
            widget.base.skinCareReviewedProducts.isEmpty &&
            effectiveAsset != null);
    final photoProductsReviewed =
        _inputSource != _ProductInputSource.photo ||
        (!isPhotoReview && widget.base.skinCareReviewedProducts.isNotEmpty);
    final sourceLabel =
        _inputSource == _ProductInputSource.photo && photoProductsReviewed
        ? 'Review detected products before building'
        : _productInputSourceLabel(_inputSource);
    final textInputEnabled = !lifecycleActive;
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
                (!photoProductsReviewed || typedPreviewProducts.isNotEmpty),
        });
    final usesGlobalBuildAction =
        !inReviewMode &&
        (_inputSource != _ProductInputSource.photo || photoProductsReviewed);
    final hasSharedFooter =
        context.findAncestorWidgetOfExactType<OnboardingStepShell>() != null;
    _publishPrimaryAction(
      usesGlobalBuildAction && hasSharedFooter
          ? OnboardingStep7PrimaryAction(
              label: 'Build skin routine',
              enabled: canGenerate,
              loading: lifecycleActive,
              onPressed: _generate,
            )
          : null,
    );
    final textHelper =
        _inputSource == _ProductInputSource.photo && !photoProductsReviewed
        ? 'Read labels to review and correct detected products.'
        : null;

    void handleProductNamesChanged(String value) {
      final hasText = value.trim().isNotEmpty;
      final canonical = onboarding7ReconcileReviewedProducts(
        value,
        ref
            .read(onboardingStateProvider)
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
      localPreviewPath: slotAsset == null
          ? null
          : uploadState?.usablePreviewPath,
      busy: busy,
      generating: lifecycleActive,
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
          _inputSource == _ProductInputSource.photo && !photoProductsReviewed
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

    if (lifecycleActive) {
      final isPhotoAnalyze =
          _inputSource == _ProductInputSource.photo && !photoProductsReviewed;
      final setupPane = Column(
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
      return _SkinCareContainedPane(
        enabled: isEditingTransaction,
        child: setupPane,
      );
    }

    if (flowState != SkinCareFlowState.hasProductsReview) {
      if (!isEditing && MediaQuery.viewInsetsOf(context).bottom > 0) {
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
      final setupBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

      final editorContent = isEditing
          ? SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: hasSharedFooter
                    ? OnboardingFooterMetrics.resolve(
                        context,
                      ).requiredContentInset
                    : 8,
              ),
              child: setupBody,
            )
          : setupBody;

      return _SkinCareContainedPane(
        enabled: isEditingTransaction,
        child: editorContent,
      );
    }

    return _SkinCareTimelineSection(
      selectedDay: _selectedDay,
      blocks: widget.blocks,
      onDayChanged: (d) => setState(() => _selectedDay = d),
      emptyLabel: 'Build your skin-care routine first.',
      accent: OptivusColors.roseAccent,
      specialCareNotes: widget.base.skinCareSpecialCareNotes,
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
