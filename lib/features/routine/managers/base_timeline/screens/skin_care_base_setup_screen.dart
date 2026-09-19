import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/skin_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_upload_lifecycle_helper.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/skin_care_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

class SkinCareBaseSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SkinCareBaseSetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<SkinCareBaseSetupScreen> createState() =>
      _SkinCareBaseSetupScreenState();
}

class _SkinCareBaseSetupScreenState
    extends ConsumerState<SkinCareBaseSetupScreen> {
  bool _isEditing = false;
  int _selectedDay = 1;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isExtracting = false;
  String? _errorMessage;
  String _aiActionTitle = 'Formulating routine...';
  List<String> _aiProgressMessages = const [
    'Analyzing skin goals and ingredients...',
    'Allocating morning and night applications...',
    'Validating routine safety and balance...',
  ];

  late List<TimelineBlockDraft> _workingBlocks;
  String? _workingPath; // 'products', 'build_for_me', 'skip'
  bool _workingSkipped = false;
  String? _workingProductNames;
  String? _workingSkinType;
  List<String> _workingProblems = [];
  String? _workingBudget;
  String? _workingPreference;
  String? _workingFacePhotoAssetId;
  String? _workingFacePhotoR2Key;
  bool _workingFacePhotoSkipped = false;
  String? _workingProductPhotoAssetId;
  String? _workingProductPhotoR2Key;
  List<SkinCareDetectedProduct> _workingReviewedProducts = [];
  List<String> _workingSelectedProductNames = [];
  List<SkinCareProductRecommendationDraft> _workingRecommendations = [];
  List<String> _workingSpecialCareNotes = [];

  String? _initialProductPhotoAssetId;
  String? _initialProductPhotoR2Key;
  String? _initialFacePhotoAssetId;
  String? _initialFacePhotoR2Key;

  int? _editorBaseRevision;
  int? _refreshPendingRevision;
  String? _refreshPendingMessage;
  String? _frontBlockId;
  int _requestGeneration = 0;
  String? _editorOwnerUid;

  final TextEditingController _productsController = TextEditingController();

  void _initWorkingState(BaseTimelineSetup setup) {
    _workingBlocks = List.from(setup.skinCareBlocks);
    _workingPath = setup.skinCareSetupPath ?? 'build_for_me';
    _workingSkipped = setup.skinCareSkipped;
    _workingProductNames = setup.skinCareProductNames;
    _workingSkinType = setup.skinCareSkinType ?? 'combination';
    _workingProblems = List.from(setup.skinCareProblems);
    _workingBudget = setup.skinCareBudget ?? 'medium';
    _workingPreference = setup.skinCarePreference ?? 'balanced';
    _workingFacePhotoAssetId = setup.skinCareFacePhotoAssetId;
    _workingFacePhotoR2Key = setup.skinCareFacePhotoR2Key;
    _workingFacePhotoSkipped = setup.skinCareFacePhotoSkipped;
    _workingProductPhotoAssetId = setup.skinCareProductPhotoAssetId;
    _workingProductPhotoR2Key = setup.skinCareProductPhotoR2Key;
    _workingReviewedProducts = List.from(setup.skinCareReviewedProducts);
    _workingSelectedProductNames = List.from(
      setup.skinCareSelectedProductNames,
    );
    _workingRecommendations = List.from(setup.skinCareProductRecommendations);
    _workingSpecialCareNotes = List.from(setup.skinCareSpecialCareNotes);

    _initialProductPhotoAssetId = setup.skinCareProductPhotoAssetId;
    _initialProductPhotoR2Key = setup.skinCareProductPhotoR2Key;
    _initialFacePhotoAssetId = setup.skinCareFacePhotoAssetId;
    _initialFacePhotoR2Key = setup.skinCareFacePhotoR2Key;

    _editorBaseRevision = setup.revision;
    _editorOwnerUid = setup.uid;
    _productsController.text = setup.skinCareProductNames ?? '';
    _isDirty = false;
  }

  @override
  void dispose() {
    _requestGeneration++;
    _productsController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Any unsaved skin care edits will be lost.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    final confirmed = res ?? false;
    if (confirmed) {
      final uid = ref.read(userProfileProvider).uid;
      final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
      if (_workingProductPhotoAssetId != null &&
          _workingProductPhotoAssetId != _initialProductPhotoAssetId) {
        try {
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingProductPhotoAssetId,
            objectKey: _workingProductPhotoR2Key,
          );
        } catch (_) {}
      }
      if (_workingFacePhotoAssetId != null &&
          _workingFacePhotoAssetId != _initialFacePhotoAssetId) {
        try {
          await helper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingFacePhotoAssetId,
            objectKey: _workingFacePhotoR2Key,
          );
        } catch (_) {}
      }
    }
    return confirmed;
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Take Photo of Products',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _inferCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sun') ||
        lower.contains('spf') ||
        lower.contains('uv')) {
      return 'sunscreen';
    }
    if (lower.contains('cleanse') ||
        lower.contains('wash') ||
        lower.contains('soap')) {
      return 'cleanser';
    }
    if (lower.contains('moistur') ||
        lower.contains('cream') ||
        lower.contains('lotion')) {
      return 'moisturizer';
    }
    if (lower.contains('serum') ||
        lower.contains('acid') ||
        lower.contains('retinol') ||
        lower.contains('niacinamide')) {
      return 'serum';
    }
    return 'general';
  }

  Future<void> _showTypedProductsDialog() async {
    final controller = TextEditingController(text: _productsController.text);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Your Skin Care Products',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the products you currently use (separated by commas or new lines):',
              style: TextStyle(
                color: OptivusColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'e.g. CeraVe Cleanser, Niacinamide Serum, SPF 50 Sunscreen',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.mintAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Generate Routine',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _productsController.text = controller.text.trim();
      await _generateFromMyProducts();
    }
  }

  Future<void> _showBuildForMeSheet() async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

    String skinType = _workingSkinType ?? 'combination';
    Set<String> concerns = Set.from(
      _workingProblems.isEmpty ? ['none'] : _workingProblems,
    );
    String budget = _workingBudget ?? 'medium';
    String preference = _workingPreference ?? 'balanced';
    bool faceSkipped = _workingFacePhotoSkipped;
    String? candidateFaceAssetId;
    String? candidateFaceR2Key;
    bool isUploadingFace = false;
    String? faceUploadError;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OptivusColors.backgroundBottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final effectiveR2Key = (faceSkipped)
              ? null
              : (candidateFaceR2Key ?? _workingFacePhotoR2Key);

          Future<void> pickFacePhoto(ImageSource source) async {
            setSheetState(() {
              isUploadingFace = true;
              faceUploadError = null;
            });
            try {
              final uploadNotifier = ref.read(
                uploadControllerProvider.notifier,
              );
              final asset = await uploadNotifier.startUpload(
                uid: uid,
                sourceFeature: 'routine_base_timeline',
                purpose: UploadedAssetPurpose.skinFace,
                source: source,
              );
              if (asset != null) {
                if (candidateFaceAssetId != null) {
                  try {
                    await ref
                        .read(baseTimelineUploadLifecycleHelperProvider)
                        .retireUncommittedUpload(
                          uid: uid,
                          assetId: candidateFaceAssetId,
                          objectKey: candidateFaceR2Key,
                        );
                  } catch (_) {}
                }
                setSheetState(() {
                  candidateFaceAssetId = asset.assetId;
                  candidateFaceR2Key = asset.r2Key;
                  faceSkipped = false;
                  isUploadingFace = false;
                });
              } else {
                setSheetState(() => isUploadingFace = false);
              }
            } catch (e) {
              setSheetState(() {
                isUploadingFace = false;
                faceUploadError = 'Failed to upload photo: $e';
              });
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Personalized Skin Care',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: OptivusColors.textSecondary,
                          ),
                          onPressed: () => Navigator.pop(sheetCtx, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Face Photo Section
                    const Text(
                      'Face Photo (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (effectiveR2Key != null && !faceSkipped)
                            BaseTimelinePhotoPreviewCard(
                              r2Key: effectiveR2Key,
                              assetId:
                                  candidateFaceAssetId ??
                                  _workingFacePhotoAssetId,
                              title: 'Face Photo',
                              height: 120,
                            )
                          else
                            Row(
                              children: [
                                Icon(
                                  faceSkipped
                                      ? Icons.no_photography_outlined
                                      : Icons.face_rounded,
                                  color: OptivusColors.mintAccent,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    faceSkipped
                                        ? 'Face photo skipped'
                                        : 'Add a face photo to improve analysis',
                                    style: TextStyle(
                                      color: faceSkipped
                                          ? OptivusColors.textSecondary
                                          : Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          if (isUploadingFace)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(
                                color: OptivusColors.mintAccent,
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Camera'),
                                  onPressed: () =>
                                      pickFacePhoto(ImageSource.camera),
                                ),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Gallery'),
                                  onPressed: () =>
                                      pickFacePhoto(ImageSource.gallery),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setSheetState(() {
                                      faceSkipped = !faceSkipped;
                                    });
                                  },
                                  child: Text(
                                    faceSkipped ? 'Include' : 'Skip photo',
                                    style: const TextStyle(
                                      color: OptivusColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (faceUploadError != null)
                            Text(
                              faceUploadError!,
                              style: const TextStyle(
                                color: OptivusColors.danger,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Skin Type
                    const Text(
                      'Skin Type',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in const [
                          ('oily', 'Oily'),
                          ('dry', 'Dry'),
                          ('combination', 'Combination'),
                          ('not_sure', 'Not sure'),
                        ])
                          ChoiceChip(
                            label: Text(opt.$2),
                            selected: skinType == opt.$1,
                            selectedColor: OptivusColors.mintAccent.withValues(
                              alpha: 0.3,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setSheetState(() => skinType = opt.$1);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Concerns
                    const Text(
                      'Concerns',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in const [
                          ('pimples', 'Acne'),
                          ('dark_spots', 'Spots'),
                          ('tan', 'Tan'),
                          ('dryness', 'Dryness'),
                          ('oiliness', 'Oiliness'),
                          ('none', 'None'),
                        ])
                          FilterChip(
                            label: Text(opt.$2),
                            selected: concerns.contains(opt.$1),
                            selectedColor: OptivusColors.mintAccent.withValues(
                              alpha: 0.3,
                            ),
                            onSelected: (sel) {
                              setSheetState(() {
                                if (opt.$1 == 'none') {
                                  if (sel) {
                                    concerns = {'none'};
                                  }
                                } else {
                                  concerns.remove('none');
                                  if (sel) {
                                    concerns.add(opt.$1);
                                  } else {
                                    concerns.remove(opt.$1);
                                    if (concerns.isEmpty) {
                                      concerns.add('none');
                                    }
                                  }
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Budget
                    const Text(
                      'Budget',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in const [
                          ('low', 'Budget'),
                          ('medium', 'Standard'),
                          ('high', 'Premium'),
                        ])
                          ChoiceChip(
                            label: Text(opt.$2),
                            selected: budget == opt.$1,
                            selectedColor: OptivusColors.mintAccent.withValues(
                              alpha: 0.3,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setSheetState(() => budget = opt.$1);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Routine Style / Preference
                    const Text(
                      'Routine Style',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in const [
                          ('simple', 'Simple'),
                          ('balanced', 'Balanced'),
                        ])
                          ChoiceChip(
                            label: Text(opt.$2),
                            selected: preference == opt.$1,
                            selectedColor: OptivusColors.mintAccent.withValues(
                              alpha: 0.3,
                            ),
                            onSelected: (sel) {
                              if (sel) {
                                setSheetState(() => preference = opt.$1);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OptivusColors.mintAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(sheetCtx, true),
                      child: const Text(
                        'Build Routine',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == true && mounted) {
      await _generateBuildForMe(
        skinType: skinType,
        problems: concerns.toList(),
        budget: budget,
        preference: preference,
        candidateFaceAssetId: candidateFaceAssetId,
        candidateFaceR2Key: candidateFaceR2Key,
        faceSkipped: faceSkipped,
      );
    } else {
      if (candidateFaceAssetId != null) {
        try {
          await ref
              .read(baseTimelineUploadLifecycleHelperProvider)
              .retireUncommittedUpload(
                uid: uid,
                assetId: candidateFaceAssetId,
                objectKey: candidateFaceR2Key,
              );
        } catch (_) {}
      }
    }
  }

  Future<void> _generateBuildForMe({
    String? skinType,
    List<String>? problems,
    String? budget,
    String? preference,
    String? candidateFaceAssetId,
    String? candidateFaceR2Key,
    bool? faceSkipped,
  }) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;
    final generation = ++_requestGeneration;
    final lifecycleHelper = ref.read(baseTimelineUploadLifecycleHelperProvider);

    final resolvedSkinType = skinType ?? _workingSkinType ?? 'combination';
    final resolvedProblems = problems ?? _workingProblems;
    final resolvedBudget = budget ?? _workingBudget ?? 'medium';
    final resolvedPreference = preference ?? _workingPreference ?? 'balanced';
    final resolvedFaceSkipped = faceSkipped ?? _workingFacePhotoSkipped;
    final resolvedFaceR2Key = (resolvedFaceSkipped)
        ? null
        : (candidateFaceR2Key ?? _workingFacePhotoR2Key);

    final idToken =
        await ref.read(authRepositoryProvider).currentIdToken() ?? '';
    final engine = ref.read(skinCareDomainEngineProvider);
    final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
    final currentSetup =
        setupAsync.value ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _aiActionTitle = 'Building personalized skin care routine...';
      _aiProgressMessages = const [
        'Assessing skin type and target concerns...',
        'Selecting dermatologically recommended products...',
        'Balancing morning protection and night repair...',
      ];
    });

    try {
      final buildResult = await engine.generateBuildForMeRoutine(
        uid: uid,
        idToken: idToken,
        skinType: resolvedSkinType,
        problems: resolvedProblems,
        desiredApplicationsPerDay: 2,
        baseTimeline: currentSetup.toBaseTimelineDraft(),
        budget: resolvedBudget,
        preference: resolvedPreference,
        facePhotoR2Key: resolvedFaceR2Key,
      );

      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        if (candidateFaceAssetId != null) {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: candidateFaceAssetId,
            objectKey: candidateFaceR2Key,
          );
        }
        return;
      }

      if (candidateFaceAssetId != null) {
        if (_workingFacePhotoAssetId != null &&
            _workingFacePhotoAssetId != _initialFacePhotoAssetId) {
          try {
            await lifecycleHelper.retireUncommittedUpload(
              uid: uid,
              assetId: _workingFacePhotoAssetId,
              objectKey: _workingFacePhotoR2Key,
            );
          } catch (_) {}
        }
        _workingFacePhotoAssetId = candidateFaceAssetId;
        _workingFacePhotoR2Key = candidateFaceR2Key;
      }

      if (_workingProductPhotoAssetId != null &&
          _workingProductPhotoAssetId != _initialProductPhotoAssetId) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingProductPhotoAssetId,
            objectKey: _workingProductPhotoR2Key,
          );
        } catch (_) {}
      }

      setState(() {
        _workingBlocks = buildResult.blocks;
        _workingPath = 'build_for_me';
        _workingSkipped = false;
        _workingSkinType = resolvedSkinType;
        _workingProblems = resolvedProblems;
        _workingBudget = resolvedBudget;
        _workingPreference = resolvedPreference;
        _workingFacePhotoSkipped = resolvedFaceSkipped;
        _workingRecommendations = buildResult.productRecommendations;
        _workingSelectedProductNames = buildResult.selectedProductNames;
        _workingSpecialCareNotes = buildResult.specialCareNotes;
        _workingProductNames = null;
        _workingProductPhotoAssetId = null;
        _workingProductPhotoR2Key = null;
        _workingReviewedProducts = const [];
        _isDirty = true;
        _isExtracting = false;
      });
    } catch (e) {
      if (candidateFaceAssetId != null) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: candidateFaceAssetId,
            objectKey: candidateFaceR2Key,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('StateError: ', '');
        });
      }
    }
  }

  Future<void> _generateFromMyProducts() async {
    final rawText = _productsController.text.trim();
    if (rawText.isEmpty) {
      await _showTypedProductsDialog();
      return;
    }

    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;
    final generation = ++_requestGeneration;

    final idToken =
        await ref.read(authRepositoryProvider).currentIdToken() ?? '';
    final engine = ref.read(skinCareDomainEngineProvider);
    final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
    final currentSetup =
        setupAsync.value ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

    final productNames = rawText
        .split(RegExp(r'[\n,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final detected = productNames.map((name) {
      return SkinCareDetectedProduct(
        name: name,
        category: _inferCategory(name),
      );
    }).toList();

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _aiActionTitle = 'Analyzing products & formulating routine...';
      _aiProgressMessages = const [
        'Evaluating product compatibility and ingredients...',
        'Allocating morning and night application steps...',
        'Validating routine safety and balance...',
      ];
    });

    try {
      final blocks = await engine.generateRoutineFromProducts(
        uid: uid,
        idToken: idToken,
        products: detected,
        skinType: _workingSkinType ?? 'combination',
        problems: _workingProblems,
        desiredApplicationsPerDay: 2,
        baseTimeline: currentSetup.toBaseTimelineDraft(),
      );

      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        return;
      }

      if (mounted) {
        final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
        if (_workingProductPhotoAssetId != null &&
            _workingProductPhotoAssetId != _initialProductPhotoAssetId) {
          try {
            await helper.retireUncommittedUpload(
              uid: uid,
              assetId: _workingProductPhotoAssetId,
              objectKey: _workingProductPhotoR2Key,
            );
          } catch (_) {}
        }
        if (_workingFacePhotoAssetId != null &&
            _workingFacePhotoAssetId != _initialFacePhotoAssetId) {
          try {
            await helper.retireUncommittedUpload(
              uid: uid,
              assetId: _workingFacePhotoAssetId,
              objectKey: _workingFacePhotoR2Key,
            );
          } catch (_) {}
        }

        setState(() {
          _workingBlocks = blocks;
          _workingPath = 'products';
          _workingSkipped = false;
          _workingProductNames = rawText;
          _workingProductPhotoAssetId = null;
          _workingProductPhotoR2Key = null;
          _workingReviewedProducts = detected;
          _workingFacePhotoAssetId = null;
          _workingFacePhotoR2Key = null;
          _workingFacePhotoSkipped = false;
          _workingRecommendations = const [];
          _workingSelectedProductNames = const [];
          _workingSpecialCareNotes = const [];
          _isDirty = true;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('StateError: ', '');
        });
      }
    }
  }

  void _skipSkinCare() {
    final uid = ref.read(userProfileProvider).uid;
    final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
    if (_workingProductPhotoAssetId != null &&
        _workingProductPhotoAssetId != _initialProductPhotoAssetId) {
      try {
        helper.retireUncommittedUpload(
          uid: uid,
          assetId: _workingProductPhotoAssetId,
          objectKey: _workingProductPhotoR2Key,
        );
      } catch (_) {}
    }
    if (_workingFacePhotoAssetId != null &&
        _workingFacePhotoAssetId != _initialFacePhotoAssetId) {
      try {
        helper.retireUncommittedUpload(
          uid: uid,
          assetId: _workingFacePhotoAssetId,
          objectKey: _workingFacePhotoR2Key,
        );
      } catch (_) {}
    }
    setState(() {
      _workingBlocks = [];
      _workingPath = 'skip';
      _workingSkipped = true;
      _workingProductPhotoAssetId = null;
      _workingProductPhotoR2Key = null;
      _workingFacePhotoAssetId = null;
      _workingFacePhotoR2Key = null;
      _workingFacePhotoSkipped = false;
      _workingProductNames = null;
      _workingReviewedProducts = const [];
      _workingRecommendations = const [];
      _workingSelectedProductNames = const [];
      _workingSpecialCareNotes = const [];
      _isDirty = true;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;
    final generation = ++_requestGeneration;
    final lifecycleHelper = ref.read(baseTimelineUploadLifecycleHelperProvider);
    final uploadNotifier = ref.read(uploadControllerProvider.notifier);

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _aiActionTitle = 'Analyzing skin care products...';
      _aiProgressMessages = const [
        'Uploading product photo...',
        'Detecting product names and active ingredients...',
        'Formulating schedule steps...',
      ];
    });

    UploadedAsset? candidateAsset;
    try {
      candidateAsset = await uploadNotifier.startUpload(
        uid: uid,
        sourceFeature: 'routine_base_timeline',
        purpose: UploadedAssetPurpose.skinProducts,
        source: source,
      );

      if (candidateAsset == null) {
        if (mounted) setState(() => _isExtracting = false);
        return;
      }

      final idToken =
          await ref.read(authRepositoryProvider).currentIdToken() ?? '';
      final engine = ref.read(skinCareDomainEngineProvider);

      final analysis = await engine.analyzeProducts(
        uid: uid,
        idToken: idToken,
        productPhotos: [candidateAsset.r2Key],
      );

      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAsset.assetId,
          objectKey: candidateAsset.r2Key,
        );
        return;
      }

      final detected = analysis.detectedProducts;
      if (detected.isEmpty) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAsset.assetId,
          objectKey: candidateAsset.r2Key,
        );

        if (mounted) {
          setState(() {
            _isExtracting = false;
            _errorMessage =
                analysis.warnings.firstOrNull ??
                'No products detected in photo. Please type your products.';
          });
          await _showTypedProductsDialog();
        }
        return;
      }

      final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
      final currentSetup =
          setupAsync.value ??
          BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

      final blocks = await engine.generateRoutineFromProducts(
        uid: uid,
        idToken: idToken,
        products: detected,
        skinType: _workingSkinType ?? 'combination',
        problems: _workingProblems,
        desiredApplicationsPerDay: 2,
        baseTimeline: currentSetup.toBaseTimelineDraft(),
      );

      if (!mounted ||
          generation != _requestGeneration ||
          ref.read(userProfileProvider).uid != uid) {
        await lifecycleHelper.retireUncommittedUpload(
          uid: uid,
          assetId: candidateAsset.assetId,
          objectKey: candidateAsset.r2Key,
        );
        return;
      }

      if (_workingProductPhotoAssetId != null &&
          _workingProductPhotoAssetId != _initialProductPhotoAssetId) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingProductPhotoAssetId,
            objectKey: _workingProductPhotoR2Key,
          );
        } catch (_) {}
      }

      if (_workingFacePhotoAssetId != null &&
          _workingFacePhotoAssetId != _initialFacePhotoAssetId) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: _workingFacePhotoAssetId,
            objectKey: _workingFacePhotoR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        final names = detected.map((p) => p.displayName).join(', ');
        _productsController.text = names;
        setState(() {
          _workingBlocks = blocks;
          _workingProductPhotoAssetId = candidateAsset!.assetId;
          _workingProductPhotoR2Key = candidateAsset.r2Key;
          _workingPath = 'products';
          _workingProductNames = names;
          _workingReviewedProducts = detected;
          _workingSkipped = false;
          _workingFacePhotoAssetId = null;
          _workingFacePhotoR2Key = null;
          _workingFacePhotoSkipped = false;
          _workingRecommendations = const [];
          _workingSelectedProductNames = const [];
          _workingSpecialCareNotes = const [];
          _isDirty = true;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (candidateAsset != null) {
        try {
          await lifecycleHelper.retireUncommittedUpload(
            uid: uid,
            assetId: candidateAsset.assetId,
            objectKey: candidateAsset.r2Key,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('StateError: ', '');
        });
      }
    }
  }

  Future<void> _saveWorkingSetup() async {
    if (_isSaving) return;

    for (final block in _workingBlocks) {
      if (block.title.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skin care block titles cannot be empty.'),
            backgroundColor: OptivusColors.danger,
          ),
        );
        return;
      }
      if (block.startMinute >= block.endMinute) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Block "${block.title}" has start time after or equal to end time.',
            ),
            backgroundColor: OptivusColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(userProfileProvider).uid;
      if (uid.trim().isEmpty || uid != _editorOwnerUid) {
        throw StateError('The active account changed. Reload Skin Care setup.');
      }
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.skinCare,
        newBlocks: _workingBlocks,
        expectedRevision: _editorBaseRevision,
        updateSetup: (current) {
          if (_workingSkipped ||
              _workingPath == 'skip' ||
              _workingBlocks.isEmpty) {
            return current.asSkinCareSkipped();
          }
          if (_workingPath == 'products') {
            return current.asSkinCareProducts(
              productNames: _workingProductNames,
              productPhotoAssetId: _workingProductPhotoAssetId,
              productPhotoR2Key: _workingProductPhotoR2Key,
              reviewedProducts: _workingReviewedProducts,
              blocks: _workingBlocks,
            );
          }
          return current.asSkinCareBuildForMe(
            facePhotoAssetId: _workingFacePhotoAssetId,
            facePhotoR2Key: _workingFacePhotoR2Key,
            facePhotoSkipped: _workingFacePhotoSkipped,
            skinType: _workingSkinType,
            problems: _workingProblems,
            budget: _workingBudget,
            preference: _workingPreference,
            selectedProductNames: _workingSelectedProductNames,
            productRecommendations: _workingRecommendations,
            specialCareNotes: _workingSpecialCareNotes,
            blocks: _workingBlocks,
          );
        },
      );

      final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
      if (_initialProductPhotoAssetId != null &&
          _initialProductPhotoAssetId != _workingProductPhotoAssetId) {
        try {
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: _initialProductPhotoAssetId!,
            oldObjectKey: _initialProductPhotoR2Key,
          );
        } catch (_) {}
      }
      if (_initialFacePhotoAssetId != null &&
          _initialFacePhotoAssetId != _workingFacePhotoAssetId) {
        try {
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: _initialFacePhotoAssetId!,
            oldObjectKey: _initialFacePhotoR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        _initialProductPhotoAssetId = _workingProductPhotoAssetId;
        _initialProductPhotoR2Key = _workingProductPhotoR2Key;
        _initialFacePhotoAssetId = _workingFacePhotoAssetId;
        _initialFacePhotoR2Key = _workingFacePhotoR2Key;
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _isDirty = false;
          _editorBaseRevision = result.revision;
          _refreshPendingRevision = result.routineRefreshPending
              ? result.revision
              : null;
          _refreshPendingMessage = result.routineRefreshMessage;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.routineRefreshPending
                  ? 'Saved. Routine needs to refresh.'
                  : 'Skin care routine updated successfully',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isConflict =
            e.toString().toLowerCase().contains('conflict') ||
            e.toString().toLowerCase().contains('concurrency');
        setState(() {
          _isSaving = false;
          _errorMessage = isConflict
              ? 'This setup changed elsewhere. Reload the latest setup before saving again.'
              : 'Failed to save Skin Care setup. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update skin care: $e'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _resetSkinCareSetup(BaseTimelineSetup setup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Skin Care Setup?',
          style: TextStyle(
            color: OptivusColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This will remove all skin care routine blocks and reset skin care to unconfigured. Your skin care schedule will be cleared from Base Timeline.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OptivusColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

    try {
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      final result = await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.skinCare,
        newBlocks: const [],
        expectedRevision: setup.revision,
        updateSetup: (current) => current.asSkinCareSkipped(),
      );

      final helper = ref.read(baseTimelineUploadLifecycleHelperProvider);
      if (setup.skinCareProductPhotoAssetId != null) {
        try {
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: setup.skinCareProductPhotoAssetId!,
            oldObjectKey: setup.skinCareProductPhotoR2Key,
          );
        } catch (_) {}
      }
      if (setup.skinCareFacePhotoAssetId != null) {
        try {
          await helper.retireReplacedAsset(
            uid: uid,
            oldAssetId: setup.skinCareFacePhotoAssetId!,
            oldObjectKey: setup.skinCareFacePhotoR2Key,
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isDirty = false;
          _editorBaseRevision = result.revision;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skin Care setup reset successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset Skin Care setup: $e'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
  }

  void _addSkinBlock() {
    final block = TimelineBlockDraft(
      id: 'skin_${DateTime.now().millisecondsSinceEpoch}',
      section: 'skin_care',
      title: 'Skin Care Routine',
      startMinute: 20 * 60,
      endMinute: 20 * 60 + 15,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
      skincareSlotLabel: 'Night routine',
      skincareSteps: const ['Cleanse', 'Moisturize'],
    );
    SkinTimelineAdapter.showSkinEditSheet(
      context: context,
      block: block,
      onSave: (updated) async {
        setState(() {
          _workingBlocks.add(updated);
          _workingSkipped = false;
          _isDirty = true;
        });
        return true;
      },
    );
  }

  void _editSkinBlock(TimelineBlockDraft block) {
    SkinTimelineAdapter.showSkinEditSheet(
      context: context,
      block: block,
      onSave: (updated) async {
        setState(() {
          final index = _workingBlocks.indexWhere(
            (item) => item.id == block.id,
          );
          if (index >= 0) _workingBlocks[index] = updated;
          _isDirty = true;
        });
        return true;
      },
    );
  }

  void _deleteSkinBlock(String id) {
    setState(() {
      _workingBlocks.removeWhere((block) => block.id == id);
      if (_frontBlockId == id) _frontBlockId = null;
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);

    return setupAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Failed to load setup',
                style: TextStyle(color: OptivusColors.textPrimary),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(baseTimelineSetupNotifierProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (setup) {
        final snapshot = setup.snapshotFor(BaseTimelineSection.skinCare);
        const adapter = SkinTimelineAdapter(accent: OptivusColors.mintAccent);

        if (_isEditing) {
          final entries = _workingBlocks
              .expand((b) => adapter.toEntries(b))
              .toList();
          final workingMap = {
            for (final block in _workingBlocks) block.id: block,
          };

          return PopScope(
            canPop: !_isDirty && !_isSaving && !_isExtracting,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop || _isSaving || _isExtracting) return;
              if (await _confirmDiscard()) {
                setState(() => _isEditing = false);
              }
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: OptivusColors.textPrimary,
                            ),
                            onPressed: (_isSaving || _isExtracting)
                                ? null
                                : () async {
                                    if (await _confirmDiscard()) {
                                      setState(() => _isEditing = false);
                                    }
                                  },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Edit Skin Care',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OptivusColors.mintAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveWorkingSetup,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Apply changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Choice Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: OptivusColors.mintAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                              ),
                              label: const Text('Build For Me'),
                              onPressed: _isExtracting
                                  ? null
                                  : _showBuildForMeSheet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.spa_rounded, size: 16),
                              label: const Text('My Products'),
                              onPressed: _isExtracting
                                  ? null
                                  : _generateFromMyProducts,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                            ),
                            style: IconButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isExtracting
                                ? null
                                : _showPhotoSourceSheet,
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: OptivusColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Skip Option
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: const Text('Add block'),
                            onPressed: _isExtracting ? null : _addSkinBlock,
                          ),
                          TextButton.icon(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 14,
                              color: OptivusColors.textSecondary,
                            ),
                            label: const Text(
                              'Clear / Skip Skin Care',
                              style: TextStyle(
                                color: OptivusColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: _skipSkinCare,
                          ),
                        ],
                      ),
                    ),

                    // Interactive Timeline View
                    Expanded(
                      child: _isExtracting
                          ? BaseTimelineAiThinkingView(
                              initialMessage: _aiActionTitle,
                              progressMessages: _aiProgressMessages,
                            )
                          : _workingSkipped
                          ? const Center(
                              child: Text(
                                'Skin Care will be skipped.\nTap Save to remove from Base Timeline.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            )
                          : FullScreenTimelineScaffold(
                              entries: entries,
                              selectedDay: _selectedDay,
                              onDayChanged: (day) =>
                                  setState(() => _selectedDay = day),
                              styleBuilder: (entry) =>
                                  adapter.styleForEntry(entry),
                              overlapPresentation:
                                  TimelineOverlapPresentation.frontAndExposed,
                              frontEntryId: _frontBlockId,
                              onFrontSelected: (id) =>
                                  setState(() => _frontBlockId = id),
                              blockBuilder: (context, positioned) {
                                final block =
                                    workingMap[positioned.entry.sourceId];
                                if (block == null) {
                                  return const SizedBox.shrink();
                                }
                                return BaseTimelineDomainCard(
                                  positioned: positioned,
                                  block: block,
                                  domain: BaseTimelineCardDomain.skinCare,
                                  accent: OptivusColors.mintAccent,
                                  isEditable: true,
                                  onTap: () {
                                    if (positioned.hasOverlap &&
                                        !positioned.isFront) {
                                      HapticFeedback.lightImpact();
                                      setState(
                                        () =>
                                            _frontBlockId = positioned.entry.id,
                                      );
                                    } else {
                                      _editSkinBlock(block);
                                    }
                                  },
                                  onDelete: () => _deleteSkinBlock(block.id),
                                );
                              },
                              accent: OptivusColors.mintAccent,
                              onEntryTapped: null,
                              visibleRangePolicy:
                                  TimelineVisibleRangePolicy.contentAdaptive,
                              stretchPolicy:
                                  TimelineStretchPolicy.constraintBased,
                              emptyDayMessage:
                                  'No skin care routine on this day.',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Current Setup View
        final entries = setup.skinCareBlocks
            .expand((b) => adapter.toEntries(b))
            .toList();
        final blockMap = {
          for (final block in setup.skinCareBlocks) block.id: block,
        };

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BaseTimelineCurrentSetupHeader(
                  title: 'Skin Care',
                  summary: snapshot.summary,
                  accent: OptivusColors.mintAccent,
                  onBack: widget.onBack,
                  primaryButtonLabel: snapshot.isConfigured
                      ? 'Change setup'
                      : 'Set up Skin Care',
                  onPrimaryAction: () {
                    _initWorkingState(setup);
                    setState(() {
                      _isEditing = true;
                      _isDirty = false;
                    });
                  },
                  resetLabel: snapshot.isConfigured
                      ? 'Reset Skin Care Setup'
                      : null,
                  onReset: snapshot.isConfigured
                      ? () => _resetSkinCareSetup(setup)
                      : null,
                ),

                // Source Photo Preview
                if (snapshot.sourceR2Key != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BaseTimelinePhotoPreviewCard(
                      r2Key: snapshot.sourceR2Key,
                      assetId: snapshot.sourceAssetId,
                      title: 'Skin Care Photo',
                      height: 140,
                    ),
                  ),

                // Timeline View
                if (_refreshPendingRevision != null)
                  BaseTimelineRefreshPendingBanner(
                    message: _refreshPendingMessage,
                    onRetry: () async {
                      final result = await ref
                          .read(baseTimelineTransactionCoordinatorProvider)
                          .retryRoutineRefresh(
                            uid: ref.read(userProfileProvider).uid,
                            targetRevision: _refreshPendingRevision,
                          );
                      if (mounted && result.isRefreshed) {
                        setState(() {
                          _refreshPendingRevision = null;
                          _refreshPendingMessage = null;
                        });
                      }
                    },
                  ),
                Expanded(
                  child:
                      snapshot.origin == BaseSetupOrigin.skipped ||
                          entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.spa_outlined,
                                color: OptivusColors.textSecondary,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Skin Care is not set up',
                                style: TextStyle(
                                  color: OptivusColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap Change Setup to add products or build a routine.',
                                style: TextStyle(
                                  color: OptivusColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: OptivusColors.mintAccent,
                                ),
                                onPressed: () {
                                  _initWorkingState(setup);
                                  setState(() => _isEditing = true);
                                },
                                child: const Text('Set Up Skin Care'),
                              ),
                            ],
                          ),
                        )
                      : FullScreenTimelineScaffold(
                          entries: entries,
                          selectedDay: _selectedDay,
                          onDayChanged: (day) =>
                              setState(() => _selectedDay = day),
                          styleBuilder: (entry) => adapter.styleForEntry(entry),
                          overlapPresentation:
                              TimelineOverlapPresentation.frontAndExposed,
                          frontEntryId: _frontBlockId,
                          onFrontSelected: (id) =>
                              setState(() => _frontBlockId = id),
                          blockBuilder: (context, positioned) {
                            final block = blockMap[positioned.entry.sourceId];
                            if (block == null) return const SizedBox.shrink();
                            return BaseTimelineDomainCard(
                              positioned: positioned,
                              block: block,
                              domain: BaseTimelineCardDomain.skinCare,
                              accent: OptivusColors.mintAccent,
                              isEditable: false,
                              onTap:
                                  positioned.hasOverlap && !positioned.isFront
                                  ? () {
                                      HapticFeedback.lightImpact();
                                      setState(
                                        () =>
                                            _frontBlockId = positioned.entry.id,
                                      );
                                    }
                                  : null,
                            );
                          },
                          accent: OptivusColors.mintAccent,
                          mode: TimelineMode.previewReadOnly,
                          visibleRangePolicy:
                              TimelineVisibleRangePolicy.contentAdaptive,
                          stretchPolicy: TimelineStretchPolicy.constraintBased,
                          emptyDayMessage: 'No skin care routine on this day.',
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
