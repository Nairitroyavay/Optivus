import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/features/onboarding/timeline/adapters/skin_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/layout/timeline_overlap_engine.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/timeline_viewport.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/uploads/controllers/upload_interaction_controller.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

class _FakeSkinCareAiClient implements SkinCareAiClient {
  const _FakeSkinCareAiClient();

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    return const SkinCareAiProductResult(products: []);
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    if (params['recommendationOnly'] == true ||
        params['recommendationsOnly'] == true) {
      return const SkinCareAiRoutineResult(
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
        routinePlans: [],
        recommendedProducts: [
          SkinCareProductRecommendation(
            name: 'Minimalist Gentle Cleanser',
            category: 'cleanser',
            brand: 'Minimalist',
            estimatedPrice: '300-400',
            currencyCode: 'INR',
            reason: 'Gentle daily cleanser',
          ),
          SkinCareProductRecommendation(
            name: 'Minimalist Barrier Moisturizer',
            category: 'moisturizer',
            brand: 'Minimalist',
            estimatedPrice: '400-500',
            currencyCode: 'INR',
            reason: 'Barrier repair hydration',
          ),
          SkinCareProductRecommendation(
            name: 'Minimalist SPF 50 Sunscreen',
            category: 'sunscreen',
            brand: 'Minimalist',
            estimatedPrice: '500-600',
            currencyCode: 'INR',
            reason: 'Broad spectrum UV protection',
          ),
        ],
      );
    }
    return const SkinCareAiRoutineResult(
      morningRoutine: [],
      nightRoutine: [],
      weeklyRoutine: [],
      timelineBlocks: [],
      routinePlans: [
        SkinCareRoutinePlan(
          slotLabel: 'morning',
          title: 'Morning Skin Care',
          steps: ['Wash face', 'Apply sunscreen'],
          productNames: [
            'Minimalist Gentle Cleanser',
            'Minimalist SPF 50 Sunscreen',
          ],
        ),
        SkinCareRoutinePlan(
          slotLabel: 'night',
          title: 'Night Skin Care',
          steps: ['Wash face', 'Moisturize'],
          productNames: [
            'Minimalist Gentle Cleanser',
            'Minimalist Barrier Moisturizer',
          ],
        ),
      ],
    );
  }
}

class _DummyAssetRepo implements UploadedAssetRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyImageService implements ImagePrepareService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyR2Client implements R2UploadClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestDeviceCountryService implements DeviceCountryService {
  final DeviceCountry? result;
  const _TestDeviceCountryService(this.result);
  @override
  Future<DeviceCountry?> detectCountry() async => result;
}

class _TestUploadInteractionController extends UploadInteractionController {
  _TestUploadInteractionController()
    : super(
        shellConfig: onboardingUploadShellConfig,
        assetRepository: _DummyAssetRepo(),
        authRepository: _DummyAuthRepo(),
        imagePrepareService: _DummyImageService(),
        r2UploadClient: _DummyR2Client(),
        permissionService: const DefaultUploadPermissionService(),
      );
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier()
    : super(
        const AuthState(
          user: AuthUser(
            uid: 'shell-integration-user',
            email: 'test@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestApp({
  required OnboardingDraft draft,
  Size screenSize = const Size(390, 844),
  double textScale = 1.0,
  Widget? home,
}) {
  return ProviderScope(
    key: ValueKey(draft.uid),
    overrides: [
      authProvider.overrideWith((ref) => _FakeAuthNotifier()),
      onboardingStateProvider.overrideWith((ref) {
        final notifier = OnboardingNotifier();
        notifier.loadSeedData(draft);
        return notifier;
      }),
      skinCareAiClientProvider.overrideWithValue(const _FakeSkinCareAiClient()),
      onboardingUploadInteractionProvider.overrideWith(
        (_) => _TestUploadInteractionController(),
      ),
      deviceCountryServiceProvider.overrideWithValue(
        const _TestDeviceCountryService(null),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: screenSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: home ?? const Scaffold(body: OnboardingStep7()),
      ),
    ),
  );
}

OnboardingDraft buildInitialDraft({String uid = 'user-seq-test'}) {
  const planABlocks = [
    TimelineBlockDraft(
      id: 'plan-a-morning',
      section: 'skin_care',
      title: 'Morning Skin Care',
      startMinute: 480,
      endMinute: 495,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
      skincareProducts: [
        'Minimalist Gentle Cleanser',
        'Minimalist SPF 50 Sunscreen',
      ],
      skincareSteps: ['Wash face', 'Apply sunscreen'],
      skincareSlotLabel: 'morning',
    ),
    TimelineBlockDraft(
      id: 'plan-a-night',
      section: 'skin_care',
      title: 'Night Skin Care',
      startMinute: 1260,
      endMinute: 1275,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.softBlockKey,
      skincareProducts: [
        'Minimalist Gentle Cleanser',
        'Minimalist Barrier Moisturizer',
      ],
      skincareSteps: ['Wash face', 'Moisturize'],
      skincareSlotLabel: 'night',
    ),
  ];

  final draftBase = BaseTimelineDraft(
    skinCareSetupStep: 1,
    skinCareSetupPath: 'no_products',
    skinCareSkinType: 'oily',
    skinCareProblems: const ['pimples'],
    skinCareBudget: 'medium',
    skinCareDesiredApplicationsPerDay: 2,
    skinCareFacePhotoAssetId: 'skin-asset',
    skinCareFacePhotoR2Key: 'users/$uid/onboarding/skin_face/skin-asset.jpg',
    skinCareFacePhotoStatus: 'uploaded',
    skinCareFacePhotoCreatedAt: DateTime.utc(2026, 6, 15, 10),
    skinCareFacePhotoUpdatedAt: DateTime.utc(2026, 6, 15, 10),
    eatingSetupPath: 'skip',
    eatingSetupStep: 1,
    skinCareProductNames:
        'Minimalist Gentle Cleanser\nMinimalist Barrier Moisturizer\nMinimalist SPF 50 Sunscreen',
    skinCareSuggestedProducts: const [
      'Minimalist Gentle Cleanser',
      'Minimalist Barrier Moisturizer',
      'Minimalist SPF 50 Sunscreen',
    ],
    skinCareSelectedProductNames: const [
      'Minimalist Gentle Cleanser',
      'Minimalist Barrier Moisturizer',
      'Minimalist SPF 50 Sunscreen',
    ],
    skinCareProductRecommendations: const [
      SkinCareProductRecommendationDraft(
        name: 'Minimalist Gentle Cleanser',
        category: 'cleanser',
        brand: 'Minimalist',
        estimatedPrice: '300-400',
        currencyCode: 'INR',
        reason: 'Gentle daily cleanser',
      ),
      SkinCareProductRecommendationDraft(
        name: 'Minimalist Barrier Moisturizer',
        category: 'moisturizer',
        brand: 'Minimalist',
        estimatedPrice: '400-500',
        currencyCode: 'INR',
        reason: 'Barrier repair hydration',
      ),
      SkinCareProductRecommendationDraft(
        name: 'Minimalist SPF 50 Sunscreen',
        category: 'sunscreen',
        brand: 'Minimalist',
        estimatedPrice: '500-600',
        currencyCode: 'INR',
        reason: 'Broad spectrum UV protection',
      ),
    ],
    blocks: [
      BaseTimelineDraft.defaultSleepBlock(),
      BaseTimelineDraft.defaultBathBlock(),
      const TimelineBlockDraft(
        id: 'meal-lunch',
        section: 'eating',
        title: 'Lunch',
        startMinute: 720,
        endMinute: 750,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
      ...planABlocks,
    ],
  );

  final recFingerprint = draftBase.computeSkinCareRecommendationFingerprint();
  final baseWithRec = draftBase.copyWith(
    skinCareRecommendationFingerprint: recFingerprint,
  );
  final routineFingerprint = baseWithRec.computeSkinCareRoutineFingerprint();
  final taggedBlocks = baseWithRec.blocks.map((block) {
    if (block.section != 'skin_care') return block;
    return block.copyWith(
      provenanceSourceIds: [
        ...block.provenanceSourceIds,
        'skin-care-generation:$routineFingerprint',
      ],
    );
  }).toList();

  return OnboardingDraft(
    uid: uid,
    currentStep: 7,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < 7,
    ),
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
    baseTimeline: baseWithRec.copyWith(
      skinCareRoutineFingerprint: routineFingerprint,
      blocks: taggedBlocks,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 7 Price Display Formatting', () {
    test('recommendation currency validation rejects mixed source values', () {
      expect(onboarding7PriceMatchesCurrency('₹399', 'INR'), isTrue);
      expect(onboarding7PriceMatchesCurrency(r'$12 USD', 'INR'), isFalse);
      expect(onboarding7PriceMatchesCurrency('EUR 20', 'GBP'), isFalse);
      expect(onboarding7PriceMatchesCurrency('¥1200', 'JPY'), isTrue);
    });
    test(
      'formatSkinCarePriceDisplay handles various price and currency shapes',
      () {
        // Duplicated currency prefix
        expect(formatSkinCarePriceDisplay('INR', 'INR 300-400'), 'INR 300-400');
        expect(formatSkinCarePriceDisplay('inr', 'INR 500'), 'INR 500');
        expect(formatSkinCarePriceDisplay('USD', 'USD 15.99'), 'USD 15.99');

        // Normal formatting without duplication
        expect(formatSkinCarePriceDisplay('INR', '300-400'), 'INR 300-400');
        expect(formatSkinCarePriceDisplay('USD', '15'), 'USD 15');

        // Currency symbols in price
        expect(formatSkinCarePriceDisplay('USD', r'$15'), r'$15');
        expect(formatSkinCarePriceDisplay('INR', '₹450'), '₹450');
        expect(formatSkinCarePriceDisplay('EUR', '€20'), '€20');
        expect(formatSkinCarePriceDisplay('GBP', '£12'), '£12');

        // Empty handling
        expect(formatSkinCarePriceDisplay(null, '300'), '300');
        expect(formatSkinCarePriceDisplay('INR', null), '');
        expect(formatSkinCarePriceDisplay('', '300'), '300');
        expect(formatSkinCarePriceDisplay('INR', ''), '');
        expect(formatSkinCarePriceDisplay('', ''), '');
      },
    );
  });

  group('Step 7 Geometry and Horizontal Inset Contract', () {
    testWidgets(
      'Has-products setup card and rebuild editor respect 24px horizontal margin',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final draft = OnboardingDraft(
          uid: 'user-geo-1',
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 2,
            skinCareProductNames: 'Cleanser\nMoisturizer',
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();

        // 1. In initial setup mode, the card should start at 24px and end at 390 - 24 = 366px
        final setupCardFinder = find.byType(OnboardingGlassCard);
        expect(setupCardFinder, findsWidgets);
        final setupRect = tester.getRect(setupCardFinder.first);
        expect(setupRect.left, 24.0);
        expect(setupRect.right, 366.0);

        // Enter rebuild editing mode
        final context = tester.element(find.byType(OnboardingStep7));
        final container = ProviderScope.containerOf(context);
        container
            .read(skinCareFlowControllerProvider.notifier)
            .startEditing(draft.baseTimeline);
        await tester.pumpAndSettle();

        // 2. In rebuild edit mode, the editor card must also maintain the 24px inset contract
        final rebuildCardFinder = find.byType(OnboardingGlassCard);
        expect(rebuildCardFinder, findsWidgets);
        final rebuildRect = tester.getRect(rebuildCardFinder.first);
        expect(rebuildRect.left, 24.0);
        expect(rebuildRect.right, 366.0);
      },
    );

    testWidgets(
      'Rebuild editor on compact screen with 1.5 text scale does not overflow',
      (tester) async {
        final blocks = [
          const TimelineBlockDraft(
            id: 'entry-geo-compact',
            section: 'skin_care',
            title: 'Morning Routine',
            startMinute: 480,
            endMinute: 510,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.softBlockKey,
          ),
        ];
        final draft = OnboardingDraft(
          uid: 'user-geo-compact',
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 2,
            blocks: blocks,
          ),
        );

        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            draft: draft,
            screenSize: const Size(360, 640),
            textScale: 1.5,
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(OnboardingStep7));
        final container = ProviderScope.containerOf(context);
        container
            .read(skinCareFlowControllerProvider.notifier)
            .startEditing(draft.baseTimeline);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    for (final width in [390.0, 360.0]) {
      for (final textScale in [1.0, 1.5]) {
        testWidgets(
          'Geometry matrix (${width.toInt()}px, textScale $textScale): setup, editor, first-time AI, rebuild AI respect 24px inset; review timeline is full bleed',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            // 1. Has-products setup mode
            final hasDraft = OnboardingDraft(
              uid: 'geo-has-$width-$textScale',
              currentStep: 7,
              baseTimeline: const BaseTimelineDraft(
                skinCareSetupStep: 1,
                skinCareSetupPath: 'has_products',
                skinCareDesiredApplicationsPerDay: 2,
                skinCareProductNames: 'Cleanser\nMoisturizer',
              ),
            );
            await tester.pumpWidget(
              _buildTestApp(
                draft: hasDraft,
                screenSize: Size(width, 844),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final hasSetupRect = tester.getRect(
              find.byType(OnboardingGlassCard).first,
            );
            expect(hasSetupRect.left, 24.0);
            expect(hasSetupRect.right, width - 24.0);

            // Has-products rebuild editor mode
            final hasContext = tester.element(find.byType(OnboardingStep7));
            final hasContainer = ProviderScope.containerOf(hasContext);
            hasContainer
                .read(skinCareFlowControllerProvider.notifier)
                .startEditing(hasDraft.baseTimeline);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final hasRebuildRect = tester.getRect(
              find.byType(OnboardingGlassCard).first,
            );
            expect(hasRebuildRect.left, 24.0);
            expect(hasRebuildRect.right, width - 24.0);

            // 2. No-products setup mode
            final noDraft = OnboardingDraft(
              uid: 'geo-no-$width-$textScale',
              currentStep: 7,
              baseTimeline: const BaseTimelineDraft(
                skinCareSetupStep: 1,
                skinCareSetupPath: 'no_products',
                skinCareSkinType: 'oily',
                skinCareProblems: ['pimples'],
                skinCareBudget: 'medium',
                skinCareDesiredApplicationsPerDay: 2,
              ),
            );
            await tester.pumpWidget(
              _buildTestApp(
                draft: noDraft,
                screenSize: Size(width, 844),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final noSetupRect = tester.getRect(
              find.byType(OnboardingGlassCard).first,
            );
            expect(noSetupRect.left, 24.0);
            expect(noSetupRect.right, width - 24.0);

            // First-time AI thinking card
            final noContext = tester.element(find.byType(OnboardingStep7));
            final noContainer = ProviderScope.containerOf(noContext);
            noContainer
                .read(skinCareFlowControllerProvider.notifier)
                .startGeneration(SkinCareFlowState.noProductsFindingProducts);
            await tester.pump();
            expect(tester.takeException(), isNull);

            final firstAiRect = tester.getRect(
              find.byType(OnboardingGlassCard).first,
            );
            expect(firstAiRect.left, 24.0);
            expect(firstAiRect.right, width - 24.0);

            // Rebuild AI thinking card
            noContainer
                .read(skinCareFlowControllerProvider.notifier)
                .startEditing(noDraft.baseTimeline);
            await tester.pump();
            noContainer
                .read(skinCareFlowControllerProvider.notifier)
                .startGeneration(SkinCareFlowState.noProductsGeneratingRoutine);
            await tester.pump();
            expect(tester.takeException(), isNull);

            final rebuildAiRect = tester.getRect(
              find.byType(OnboardingGlassCard).first,
            );
            expect(rebuildAiRect.left, 24.0);
            expect(rebuildAiRect.right, width - 24.0);

            // 3. Full-screen review timeline
            const reviewBlock = TimelineBlockDraft(
              id: 'geo-review-block',
              section: 'skin_care',
              title: 'Morning Care',
              startMinute: 480,
              endMinute: 510,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: ['Cleanser', 'Moisturizer'],
              skincareSteps: ['Wash face', 'Apply cream'],
            );
            final reviewDraft = OnboardingDraft(
              uid: 'geo-review-$width-$textScale',
              currentStep: 7,
              baseTimeline: const BaseTimelineDraft(
                skinCareSetupStep: 1,
                skinCareSetupPath: 'has_products',
                skinCareDesiredApplicationsPerDay: 1,
                skinCareRoutineFingerprint: 'geo-fp',
                blocks: [reviewBlock],
              ),
            );
            await tester.pumpWidget(
              _buildTestApp(
                draft: reviewDraft,
                screenSize: Size(width, 844),
                textScale: textScale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final timelineFinder = find.byKey(
              const ValueKey('onboarding-step7-full-timeline'),
            );
            expect(timelineFinder, findsOneWidget);
            final timelineRect = tester.getRect(timelineFinder);
            expect(timelineRect.left, 0.0);
            expect(timelineRect.right, width);
          },
        );
      }
    }
  });

  group('Timeline Viewport Weekday Auto-Scroll Contract', () {
    testWidgets(
      'autoScrollIdentity triggers auto-scroll when day changes between identical routines',
      (tester) async {
        // Monday and Tuesday have identical schedule blocks
        final blocks = [
          const TimelineEntry(
            id: 'entry-1',
            sourceId: 'source-1',
            startMinute: 600, // 10:00 AM (down the page)
            endMinute: 630,
            title: 'Morning Care',
            category: TimelineCategory.skinCare,
            repeatDays: [1, 2],
          ),
        ];

        final controller = ScrollController();
        const adapter = SkinTimelineAdapter();
        int currentDay = 1;

        Widget buildTimeline(int day) {
          final layoutResult = TimelineOverlapEngine.computeLayout(
            entries: blocks,
            availableWidth: 390,
            selectedDay: day,
          );

          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: TimelineViewport(
                  layoutResult: layoutResult,
                  styleBuilder: adapter.styleForEntry,
                  scrollController: controller,
                  autoScrollToFirstEntry: true,
                  autoScrollIdentity: day,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTimeline(currentDay));
        await tester.pumpAndSettle();

        final initialOffset = controller.offset;
        expect(initialOffset, greaterThan(0.0));

        // Manually scroll to top (offset 0)
        controller.jumpTo(0.0);
        await tester.pumpAndSettle();
        expect(controller.offset, 0.0);

        // Switch to Tuesday (identical layout, but autoScrollIdentity changes)
        currentDay = 2;
        await tester.pumpWidget(buildTimeline(currentDay));
        await tester.pumpAndSettle();

        // Viewport should have auto-scrolled back down to first entry
        expect(controller.offset, equals(initialOffset));
      },
    );
  });

  group('Card Height & Pathological Content Bounding Contract', () {
    testWidgets('Normal card renders all steps without clipping or overflow', (
      tester,
    ) async {
      const normalBlock = TimelineBlockDraft(
        id: 'normal-1',
        section: 'skin_care',
        title: 'Morning Routine',
        startMinute: 480,
        endMinute: 510,
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        skincareProducts: ['Cleanser', 'Moisturizer', 'Sunscreen'],
        skincareSteps: ['Wash face', 'Apply cream', 'Protect with SPF'],
      );

      final draft = OnboardingDraft(
        uid: 'user-normal-card',
        currentStep: 7,
        baseTimeline: const BaseTimelineDraft(
          skinCareSetupStep: 1,
          skinCareSetupPath: 'has_products',
          skinCareDesiredApplicationsPerDay: 1,
          skinCareRoutineFingerprint: 'valid-fp',
          blocks: [normalBlock],
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
      );
      await tester.pumpAndSettle();

      // All steps should be rendered on the normal card
      expect(find.text('1. Wash face'), findsOneWidget);
      expect(find.text('2. Apply cream'), findsOneWidget);
      expect(find.text('3. Protect with SPF'), findsOneWidget);
      expect(find.text('• Cleanser'), findsOneWidget);
      expect(find.text('• Moisturizer'), findsOneWidget);
      expect(find.text('• Sunscreen'), findsOneWidget);

      // 'View full details' should NOT be present for normal cards
      expect(
        find.byKey(const ValueKey('onboarding-step7-full-details-normal-1')),
        findsNothing,
      );

      // Verify normal card height boundary geometry: content does not exceed card bottom
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('onboarding-step7-block-normal-1')),
      );
      final productsTextFinder = find.text('• Sunscreen');
      expect(productsTextFinder, findsOneWidget);
      final productsRect = tester.getRect(productsTextFinder);
      expect(
        productsRect.bottom,
        lessThanOrEqualTo(cardRect.bottom),
        reason: 'Normal card content bottom must not exceed card bottom',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Pathological card renders every detail inside the expanded card',
      (tester) async {
        final longSteps = [
          'Wash face thoroughly with lukewarm water',
          'Apply toner gently with cotton pad',
          'Apply hyaluronic acid serum on damp skin',
          'Apply vitamin C serum avoiding eye area',
          'Apply peptide moisturizer evenly across cheeks and forehead',
          'Apply broad spectrum sunscreen generously',
        ];
        final longProducts = [
          'Gentle Cleanser',
          'Hydrating Toner',
          'Hyaluronic Serum',
          'Vitamin C Booster',
          'Peptide Cream',
          'SPF 50 Sunscreen',
        ];

        final pathologicalBlock = TimelineBlockDraft(
          id: 'pathological-1',
          section: 'skin_care',
          title: 'Extensive Care Routine',
          startMinute: 480,
          endMinute: 540,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: longProducts,
          skincareSteps: longSteps,
        );

        final draft = OnboardingDraft(
          uid: 'user-pathological-card',
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 1,
            skinCareRoutineFingerprint: 'valid-fp',
            blocks: [pathologicalBlock],
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        for (var i = 0; i < longSteps.length; i += 1) {
          expect(find.text('${i + 1}. ${longSteps[i]}'), findsOneWidget);
        }
        for (final product in longProducts) {
          expect(find.text('• $product'), findsOneWidget);
        }
        expect(find.text('View full details'), findsNothing);
        expect(find.textContaining('more'), findsNothing);

        final cardRect = tester.getRect(
          find.byKey(const ValueKey('onboarding-step7-block-pathological-1')),
        );
        final lastProductRect = tester.getRect(
          find.text('• ${longProducts.last}'),
        );
        expect(lastProductRect.bottom, lessThanOrEqualTo(cardRect.bottom + 1));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Edit Sheet Mutex & Rapid Tap Prevention', () {
    testWidgets(
      'Rapid multiple taps on card and edit icon open only one edit sheet',
      (tester) async {
        const block = TimelineBlockDraft(
          id: 'mutex-block-1',
          section: 'skin_care',
          title: 'Daily Care',
          startMinute: 500,
          endMinute: 530,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.softBlockKey,
          skincareProducts: ['Cleanser'],
          skincareSteps: ['Wash'],
        );

        final draft = OnboardingDraft(
          uid: 'user-mutex-test',
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 1,
            skinCareRoutineFingerprint: 'valid-fp',
            blocks: [block],
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(
          const ValueKey('onboarding-step7-block-mutex-block-1'),
        );
        final editButtonFinder = find.byKey(
          const ValueKey('onboarding-step7-edit-mutex-block-1'),
        );

        // Rapidly trigger taps on both the card and the edit button
        await tester.tap(editButtonFinder);
        await tester.tap(cardFinder, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Exactly one edit sheet title field should exist
        expect(
          find.byKey(const ValueKey('onboarding-step7-edit-title-field')),
          findsOneWidget,
        );

        // Cancel the sheet
        await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
        await tester.pumpAndSettle();

        // Modal should be completely closed
        expect(
          find.byKey(const ValueKey('onboarding-step7-edit-title-field')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Step 7 Timeline Edit Product Authority and Validation Defense', () {
    test(
      'validateSkinCareSetup enforces product ownership defense-in-depth',
      () {
        const uid = 'defense-uid';

        const reviewedProduct = SkinCareDetectedProduct(
          name: 'Cleanser',
          brand: 'Simple',
          category: 'cleanser',
        );
        var baseHas = const BaseTimelineDraft(
          skinCareSetupStep: 1,
          skinCareSetupPath: 'has_products',
          skinCareDesiredApplicationsPerDay: 2,
          skinCareProductNames: 'Cleanser',
          skinCareReviewedProducts: [reviewedProduct],
        );
        final fpHas = baseHas.computeSkinCareRoutineFingerprint();
        baseHas = baseHas.copyWith(
          skinCareRoutineFingerprint: fpHas,
          blocks: [
            TimelineBlockDraft(
              id: 'b1',
              section: 'skin_care',
              title: 'Morning',
              startMinute: 480,
              endMinute: 495,
              repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: const ['Cleanser'],
              provenanceSourceIds: ['skin-care-generation:$fpHas'],
            ),
            TimelineBlockDraft(
              id: 'b2',
              section: 'skin_care',
              title: 'Night',
              startMinute: 1260,
              endMinute: 1275,
              repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: const ['Cleanser'],
              provenanceSourceIds: ['skin-care-generation:$fpHas'],
            ),
          ],
        );

        // 1. Has-products valid
        expect(baseHas.validateSkinCareSetup(uid), isNull);

        // 2. Has-products with unowned product
        final invalidHas = baseHas.copyWith(
          blocks: baseHas.blocks.map((b) {
            if (b.id != 'b1') return b;
            return b.copyWith(
              skincareProducts: ['Cleanser', 'Prescription Retinol X'],
            );
          }).toList(),
        );
        final hasErr = invalidHas.validateSkinCareSetup(uid);
        expect(hasErr, isNotNull);
        expect(hasErr, contains('Prescription Retinol X'));

        // 3. No-products valid
        final validNo = buildInitialDraft(uid: uid);
        expect(validNo.baseTimeline.validateSkinCareSetup(uid), isNull);

        // 4. No-products with unselected recommendation
        final invalidNoBlocks = validNo.baseTimeline.blocks.map((b) {
          if (b.section != 'skin_care') return b;
          return b.copyWith(
            skincareProducts: [...b.skincareProducts, 'Unselected Serum X'],
          );
        }).toList();
        final invalidNo = validNo.copyWith(
          baseTimeline: validNo.baseTimeline.copyWith(blocks: invalidNoBlocks),
        );
        final noErr = invalidNo.baseTimeline.validateSkinCareSetup(uid);
        expect(noErr, isNotNull);
        expect(noErr, contains('Unselected Serum X'));
      },
    );

    testWidgets(
      'Has-products timeline edit rejects unowned product, keeps sheet open with error, and preserves block until valid',
      (tester) async {
        final draft = OnboardingDraft(
          uid: 'user-authority-has',
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'has_products',
            skinCareDesiredApplicationsPerDay: 2,
            skinCareProductNames: 'Cleanser\nMoisturizer',
            skinCareRoutineFingerprint: 'valid-fp',
            blocks: [
              TimelineBlockDraft(
                id: 'auth-has-1',
                section: 'skin_care',
                title: 'Morning Skin Care',
                startMinute: 480,
                endMinute: 495,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.softBlockKey,
                skincareProducts: ['Cleanser'],
                skincareSteps: ['Wash face'],
                skincareSlotLabel: 'morning',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildTestApp(draft: draft));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Open edit sheet
        final cardFinder = find.byKey(
          const ValueKey('onboarding-step7-block-auth-has-1'),
        );
        expect(cardFinder, findsOneWidget);
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final titleField = find.byKey(
          const ValueKey('onboarding-step7-edit-title-field'),
        );
        final productsField = find.byKey(
          const ValueKey('onboarding-step7-edit-products-field'),
        );
        final saveBtn = find.byKey(
          const ValueKey('onboarding-step7-edit-save-button'),
        );
        expect(titleField, findsOneWidget);
        expect(productsField, findsOneWidget);

        // Enter unowned product
        await tester.enterText(
          productsField,
          'Cleanser\nPrescription Retinol X',
        );
        await tester.pump();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Sheet must remain open and display validation error
        expect(titleField, findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data?.contains('Prescription Retinol X') ?? false),
          ),
          findsOneWidget,
        );

        // Underlying draft block must remain unchanged
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        final blockBefore = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .blocks
            .firstWhere((b) => b.id == 'auth-has-1');
        expect(blockBefore.skincareProducts, ['Cleanser']);

        // Now enter valid owned product and save
        await tester.enterText(productsField, 'Cleanser\nMoisturizer');
        await tester.pump();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Sheet closed
        expect(titleField, findsNothing);

        // Block updated
        final blockAfter = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .blocks
            .firstWhere((b) => b.id == 'auth-has-1');
        expect(blockAfter.skincareProducts, ['Cleanser', 'Moisturizer']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'No-products timeline edit rejects unselected recommendation, keeps sheet open with error, and preserves block until valid',
      (tester) async {
        final draft = OnboardingDraft(
          uid: 'user-authority-no',
          currentStep: 7,
          baseTimeline: const BaseTimelineDraft(
            skinCareSetupStep: 1,
            skinCareSetupPath: 'no_products',
            skinCareDesiredApplicationsPerDay: 2,
            skinCareRoutineFingerprint: 'valid-fp',
            skinCareProductNames:
                'Minimalist Gentle Cleanser\nMinimalist Barrier Moisturizer\nMinimalist SPF 50 Sunscreen',
            skinCareSuggestedProducts: [
              'Minimalist Gentle Cleanser',
              'Minimalist Barrier Moisturizer',
              'Minimalist SPF 50 Sunscreen',
            ],
            skinCareSelectedProductNames: [
              'Minimalist Gentle Cleanser',
              'Minimalist Barrier Moisturizer',
              'Minimalist SPF 50 Sunscreen',
            ],
            blocks: [
              TimelineBlockDraft(
                id: 'auth-no-1',
                section: 'skin_care',
                title: 'Morning Care',
                startMinute: 480,
                endMinute: 495,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.softBlockKey,
                skincareProducts: ['Minimalist Gentle Cleanser'],
                skincareSteps: ['Wash face'],
                skincareSlotLabel: 'morning',
              ),
            ],
          ),
        );

        await tester.pumpWidget(_buildTestApp(draft: draft));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Open edit sheet
        final cardFinder = find.byKey(
          const ValueKey('onboarding-step7-block-auth-no-1'),
        );
        expect(cardFinder, findsOneWidget);
        await tester.tap(cardFinder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final titleField = find.byKey(
          const ValueKey('onboarding-step7-edit-title-field'),
        );
        final productsField = find.byKey(
          const ValueKey('onboarding-step7-edit-products-field'),
        );
        final saveBtn = find.byKey(
          const ValueKey('onboarding-step7-edit-save-button'),
        );
        expect(titleField, findsOneWidget);
        expect(productsField, findsOneWidget);

        // Enter unselected recommendation
        await tester.enterText(
          productsField,
          'Minimalist Gentle Cleanser\nUnselected Vitamin C Serum B',
        );
        await tester.pump();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Sheet must remain open with validation error
        expect(titleField, findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data?.contains('Unselected Vitamin C Serum B') ?? false),
          ),
          findsOneWidget,
        );

        // Underlying draft block unchanged
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        final blockBefore = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .blocks
            .firstWhere((b) => b.id == 'auth-no-1');
        expect(blockBefore.skincareProducts, ['Minimalist Gentle Cleanser']);

        // Enter valid selected recommendation and save
        await tester.enterText(
          productsField,
          'Minimalist Gentle Cleanser\nMinimalist SPF 50 Sunscreen',
        );
        await tester.pump();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Sheet closed
        expect(titleField, findsNothing);

        // Block updated
        final blockAfter = container
            .read(onboardingStateProvider)
            .draft
            .baseTimeline
            .blocks
            .firstWhere((b) => b.id == 'auth-no-1');
        expect(blockAfter.skincareProducts, [
          'Minimalist Gentle Cleanser',
          'Minimalist SPF 50 Sunscreen',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Section 19 Exact Physical Interaction Sequence Regression', () {
    Future<void> ensureAllProductsSelected(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingStep7)),
      );
      final currentSelected = container
          .read(onboardingStateProvider)
          .draft
          .baseTimeline
          .skinCareSelectedProductNames;

      for (final name in const [
        'Minimalist Gentle Cleanser',
        'Minimalist Barrier Moisturizer',
        'Minimalist SPF 50 Sunscreen',
      ]) {
        final isSelected = currentSelected.any(
          (s) => s.contains(name) || name.contains(s),
        );
        if (!isSelected) {
          final productFinder = find.text(name);
          await tester.ensureVisible(productFinder);
          await tester.pump();
          await tester.tap(productFinder);
          await tester.pump();
        }
      }
    }

    testWidgets(
      'Full sequence: timeline -> whole-card edit (Save) -> 3-dot edit (Cancel) -> 3-dot edit (system back) -> Rebuild / Edit -> Change details -> change inputs -> Find products -> Change details AGAIN -> Find products AGAIN -> select products -> Close editor -> Plan A review',
      (tester) async {
        final draft = buildInitialDraft();
        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 1. Initial State: Valid Plan A routine on full-screen timeline
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Skin Care'), findsOneWidget);
        expect(find.text('Night Skin Care'), findsOneWidget);
        expect(find.text('Routine built'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        expect(
          onboarding7CanContinue(
            container.read(onboardingStateProvider).draft.baseTimeline,
            'user-seq-test',
          ),
          isTrue,
        );

        // 2. Whole-card edit -> modify fields -> Save
        final morningCard = find.byKey(
          const ValueKey('onboarding-step7-block-plan-a-morning'),
        );
        expect(morningCard, findsOneWidget);
        await tester.tap(morningCard);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final titleField = find.byKey(
          const ValueKey('onboarding-step7-edit-title-field'),
        );
        expect(titleField, findsOneWidget);
        await tester.enterText(titleField, 'Morning Glow Care');
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey('onboarding-step7-edit-save-button')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(titleField, findsNothing);
        expect(find.text('Morning Glow Care'), findsOneWidget);

        // 3. 3-dot edit -> Cancel
        final morningEditIcon = find.byKey(
          const ValueKey('onboarding-step7-edit-plan-a-morning'),
        );
        expect(morningEditIcon, findsOneWidget);
        await tester.tap(morningEditIcon);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsOneWidget);

        await tester.tap(find.byKey(const Key('timeline-edit-cancel-button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsNothing);

        // 4. 3-dot edit -> system Back
        await tester.tap(morningEditIcon);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(titleField, findsNothing);

        // 5. Rebuild / Edit
        final rebuildBtn = find.text('Rebuild / Edit');
        expect(rebuildBtn, findsOneWidget);
        await tester.tap(rebuildBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 6. Change details
        final changeDetailsBtn = find.text('Change details');
        expect(changeDetailsBtn, findsOneWidget);
        await tester.ensureVisible(changeDetailsBtn);
        await tester.tap(changeDetailsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 7. Change inputs
        final freq2 = find.byKey(
          const ValueKey('onboarding-step7-frequency-2'),
        );
        await tester.ensureVisible(freq2);
        await tester.tap(freq2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 8. Find products
        final findProductsBtn = find.text('Find products');
        await tester.ensureVisible(findProductsBtn);
        await tester.tap(findProductsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Product selection stage is now active
        expect(find.text('Minimalist Gentle Cleanser'), findsOneWidget);

        // 9. Product selection
        await ensureAllProductsSelected(tester);
        expect(tester.takeException(), isNull);

        // 10. Change details AGAIN
        final changeDetailsAgain = find.text('Change details');
        expect(changeDetailsAgain, findsOneWidget);
        await tester.ensureVisible(changeDetailsAgain);
        await tester.tap(changeDetailsAgain);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 11. Find products AGAIN
        final findProductsAgain = find.text('Find products');
        await tester.ensureVisible(findProductsAgain);
        await tester.tap(findProductsAgain);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 12. Select products
        await ensureAllProductsSelected(tester);
        expect(tester.takeException(), isNull);

        // 13. Close editor / Back
        final closeEditorBtn = find.byKey(
          const ValueKey('onboarding-step7-no-products-cancel-rebuild'),
        );
        expect(closeEditorBtn, findsOneWidget);
        await tester.tap(closeEditorBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 14. Plan-A review intact with our earlier saved edit
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Glow Care'), findsOneWidget);
        expect(find.text('Night Skin Care'), findsOneWidget);
        expect(find.text('Routine built'), findsOneWidget);
        final containerAfterCancel = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        expect(
          onboarding7CanContinue(
            containerAfterCancel
                .read(onboardingStateProvider)
                .draft
                .baseTimeline,
            'user-seq-test',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Plan B completion after rebuild: valid routine -> Rebuild / Edit -> Change details -> Find products -> select products -> Build skin routine -> Plan B review',
      (tester) async {
        final draft = buildInitialDraft();
        await tester.pumpWidget(
          _buildTestApp(draft: draft, screenSize: const Size(390, 844)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Initial state: Plan A review
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Skin Care'), findsOneWidget);
        expect(find.text('Night Skin Care'), findsOneWidget);
        expect(find.text('Routine built'), findsOneWidget);

        // 1. Rebuild / Edit
        final rebuildBtn = find.text('Rebuild / Edit');
        expect(rebuildBtn, findsOneWidget);
        await tester.tap(rebuildBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 2. Change details
        final changeDetailsBtn = find.text('Change details');
        expect(changeDetailsBtn, findsOneWidget);
        await tester.ensureVisible(changeDetailsBtn);
        await tester.tap(changeDetailsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 3. Find products
        final findProductsBtn = find.text('Find products');
        await tester.ensureVisible(findProductsBtn);
        await tester.tap(findProductsBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 4. Select products
        await ensureAllProductsSelected(tester);
        expect(tester.takeException(), isNull);

        // 5. Build skin routine
        final buildRoutineBtn = find.text('Build skin routine');
        expect(buildRoutineBtn, findsOneWidget);
        await tester.ensureVisible(buildRoutineBtn);
        await tester.tap(buildRoutineBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 6. Plan B timeline review is active
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Before-bed Skin Care'), findsOneWidget);
        expect(find.textContaining('Skin Care'), findsWidgets);
        expect(find.text('Routine built'), findsOneWidget);
        final containerPlanB = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingStep7)),
        );
        expect(
          onboarding7CanContinue(
            containerPlanB.read(onboardingStateProvider).draft.baseTimeline,
            'user-seq-test',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Real shell OnboardingFlow integration: Plan A -> Rebuild / Edit -> Change details -> Find products -> select products -> Build skin routine -> Plan B review -> Next Step advances to Step 8',
      (tester) async {
        final draft = buildInitialDraft(uid: 'shell-integration-user');
        await tester.pumpWidget(
          _buildTestApp(draft: draft, home: const OnboardingFlow()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // 1. Initial State: Valid Plan A routine review in OnboardingFlow shell
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Morning Skin Care'), findsOneWidget);
        expect(find.text('Next Step'), findsOneWidget);

        // 2. Rebuild / Edit
        final rebuildBtn = find.text('Rebuild / Edit');
        expect(rebuildBtn, findsOneWidget);
        await tester.tap(rebuildBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // 3. Change details
        final changeDetailsBtn = find.text('Change details');
        expect(changeDetailsBtn, findsOneWidget);
        await tester.ensureVisible(changeDetailsBtn);
        await tester.tap(changeDetailsBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // 4. Find products
        final findProductsBtn = find.text('Find products');
        expect(findProductsBtn, findsOneWidget);
        await tester.ensureVisible(findProductsBtn);
        await tester.tap(findProductsBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        await ensureAllProductsSelected(tester);
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Shell CTA should now be 'Build skin routine'
        final buildRoutineShellBtn = find.byKey(
          const ValueKey('onboarding-step7-generate-button'),
        );
        expect(buildRoutineShellBtn, findsOneWidget);
        expect(find.textContaining('Build skin routine'), findsOneWidget);

        // 6. Tap Build skin routine in shell
        await tester.tap(buildRoutineShellBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // 7. Plan B review is shown with Next Step
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );
        expect(find.text('Next Step'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('onboarding-step7-generate-button')),
          findsNothing,
        );

        // 8. Tap Next Step in shell
        await tester.tap(find.text('Next Step'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        // Flow advances to Step 8
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingFlow)),
        );
        expect(container.read(onboardingStateProvider).currentStep, 8);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
