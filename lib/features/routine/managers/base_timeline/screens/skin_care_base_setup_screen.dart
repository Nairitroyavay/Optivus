import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/skin_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/skin_care_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_ai_thinking_view.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
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
  String? _workingAssetId;
  String? _workingR2Key;

  final TextEditingController _productsController = TextEditingController();

  void _initWorkingState(dynamic setup) {
    _workingBlocks = List.from(setup.skinCareBlocks);
    _workingPath = setup.skinCareSetupPath ?? 'build_for_me';
    _workingSkipped = setup.skinCareSkipped;
    _workingProductNames = setup.skinCareProductNames;
    _workingSkinType = setup.skinCareSkinType ?? 'Combination';
    _workingProblems = List.from(setup.skinCareProblems);
    _workingAssetId =
        setup.skinCareProductPhotoAssetId ?? setup.skinCareFacePhotoAssetId;
    _workingR2Key =
        setup.skinCareProductPhotoR2Key ?? setup.skinCareFacePhotoR2Key;
    _productsController.text = setup.skinCareProductNames ?? '';
    _isDirty = false;
  }

  @override
  void dispose() {
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
    return res ?? false;
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
                  'Choose from Gallery',
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

  Future<void> _generateFromMyProducts() async {
    final rawText = _productsController.text.trim();
    if (rawText.isEmpty) {
      await _showTypedProductsDialog();
      return;
    }

    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

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
        skinType: _workingSkinType ?? 'Combination',
        problems: _workingProblems,
        desiredApplicationsPerDay: 2,
        baseTimeline: currentSetup.toBaseTimelineDraft(),
      );

      if (mounted) {
        setState(() {
          _workingBlocks = blocks;
          _workingPath = 'products';
          _workingSkipped = false;
          _workingProductNames = rawText;
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

  Future<void> _generateBuildForMe() async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

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
      final blocks = await engine.generateBuildForMeRoutine(
        uid: uid,
        idToken: idToken,
        skinType: _workingSkinType ?? 'Combination',
        problems: _workingProblems,
        desiredApplicationsPerDay: 2,
        baseTimeline: currentSetup.toBaseTimelineDraft(),
      );

      if (mounted) {
        setState(() {
          _workingBlocks = blocks;
          _workingPath = 'build_for_me';
          _workingSkipped = false;
          // Clear photo provenance when switching to generated mode
          _workingAssetId = null;
          _workingR2Key = null;
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
    setState(() {
      _workingBlocks = [];
      _workingPath = 'skip';
      _workingSkipped = true;
      // Clear photo provenance on skip
      _workingAssetId = null;
      _workingR2Key = null;
      _isDirty = true;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final uid = ref.read(userProfileProvider).uid;
    if (uid.trim().isEmpty) return;

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

    try {
      final asset = await uploadNotifier.startUpload(
        uid: uid,
        sourceFeature: 'routine_base_timeline',
        purpose: UploadedAssetPurpose.skinProducts,
        source: source,
      );

      if (asset == null) {
        if (mounted) setState(() => _isExtracting = false);
        return;
      }

      final idToken =
          await ref.read(authRepositoryProvider).currentIdToken() ?? '';
      final engine = ref.read(skinCareDomainEngineProvider);

      final analysis = await engine.analyzeProducts(
        uid: uid,
        idToken: idToken,
        productPhotos: [asset.r2Key],
      );

      final detected = analysis.detectedProducts;
      final setupAsync = ref.read(baseTimelineSetupNotifierProvider);
      final currentSetup =
          setupAsync.value ??
          BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());

      if (detected.isNotEmpty) {
        final blocks = await engine.generateRoutineFromProducts(
          uid: uid,
          idToken: idToken,
          products: detected,
          skinType: _workingSkinType ?? 'Combination',
          problems: _workingProblems,
          desiredApplicationsPerDay: 2,
          baseTimeline: currentSetup.toBaseTimelineDraft(),
        );

        if (mounted) {
          final names = detected.map((p) => p.displayName).join(', ');
          _productsController.text = names;
          setState(() {
            _workingBlocks = blocks;
            _workingAssetId = asset.assetId;
            _workingR2Key = asset.r2Key;
            _workingPath = 'products';
            _workingProductNames = names;
            _workingSkipped = false;
            _isDirty = true;
            _isExtracting = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _workingAssetId = asset.assetId;
            _workingR2Key = asset.r2Key;
            _workingPath = 'products';
            _isExtracting = false;
            _errorMessage =
                analysis.warnings.firstOrNull ??
                'No products detected in photo. Please type your products.';
          });
          await _showTypedProductsDialog();
        }
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

  Future<void> _saveWorkingSetup() async {
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(userProfileProvider).uid;
      final coordinator = ref.read(baseTimelineTransactionCoordinatorProvider);
      await coordinator.replaceSection(
        uid: uid,
        section: BaseTimelineSection.skinCare,
        newBlocks: _workingBlocks,
        updateSetup: (current) => current.copyWith(
          skinCareBlocks: _workingBlocks,
          skinCareSetupPath: _workingPath,
          skinCareSkipped: _workingSkipped,
          skinCareProductNames: _workingProductNames,
          skinCareSkinType: _workingSkinType,
          skinCareProblems: _workingProblems,
          skinCareProductPhotoAssetId: _workingPath == 'products'
              ? _workingAssetId
              : null,
          clearSkinCareProductPhotoAssetId:
              _workingPath != 'products' || _workingAssetId == null,
          skinCareProductPhotoR2Key: _workingPath == 'products'
              ? _workingR2Key
              : null,
          clearSkinCareProductPhotoR2Key:
              _workingPath != 'products' || _workingR2Key == null,
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
          _isDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skin care routine updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update skin care: $e'),
            backgroundColor: OptivusColors.danger,
          ),
        );
      }
    }
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

          return PopScope(
            canPop: !_isDirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop) {
                if (await _confirmDiscard()) {
                  setState(() => _isEditing = false);
                }
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
                            onPressed: () async {
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
                                    'Save',
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
                                  : _generateBuildForMe,
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
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
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
                              accent: OptivusColors.mintAccent,
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

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Nav Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: OptivusColors.textPrimary,
                        ),
                        onPressed: widget.onBack,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Skin Care',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                            Text(
                              snapshot.summary,
                              style: const TextStyle(
                                fontSize: 12,
                                color: OptivusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                        label: const Text('Change setup'),
                        style: FilledButton.styleFrom(
                          backgroundColor: OptivusColors.mintAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          _initWorkingState(setup);
                          setState(() {
                            _isEditing = true;
                            _isDirty = false;
                          });
                        },
                      ),
                    ],
                  ),
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
                          accent: OptivusColors.mintAccent,
                          mode: TimelineMode.previewReadOnly,
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
