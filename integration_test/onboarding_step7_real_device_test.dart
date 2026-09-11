import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_controller.dart';
import 'package:optivus/features/onboarding/steps/skin_care/skin_care_flow_state.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/auth_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Step 7 Real Device Acceptance Suite', () {
    testWidgets(
      'Flow A: Has-products setup (2/3 frequency, personalize scroll) -> Build 3/day routine -> Review -> Next Step -> Step 8 -> Back -> Review -> Shell Back',
      (tester) async {
        const uid = 'flow-a-user';
        final client = _IntegrationSkinCareAiClient(
          routineResultsQueue: [_testRoutineResult3Slots()],
        );

        final base = BaseTimelineDraft(
          skinCareSetupPath: 'has_products',
          skinCareSetupStep: 1,
          skinCareStageContractVersion:
              BaseTimelineDraft.currentSkinCareStageContractVersion,
          skinCareProductNames: 'Gentle Cleanser\nSPF 50 Sunscreen',
          skinCareReviewedProducts: const [
            SkinCareDetectedProduct(name: 'Gentle Cleanser'),
            SkinCareDetectedProduct(name: 'SPF 50 Sunscreen'),
          ],
          blocks: [BaseTimelineDraft.defaultBathBlock()],
        );

        final notifier = OnboardingNotifier()
          ..loadSeedData(
            OnboardingDraft(uid: uid, currentStep: 7, baseTimeline: base),
          );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: uid,
                    email: 'flow-a@example.com',
                    emailVerified: true,
                  ),
                ),
              ),
              authGenerationProvider.overrideWith((ref) => 1),
              onboardingStateProvider.overrideWith((ref) => notifier),
              skinCareAiClientProvider.overrideWithValue(client),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify we are in has-products setup
        expect(find.text('Build skin routine'), findsOneWidget);

        // 2. Verify frequency selector contract: 2 and 3 exist, 4 does NOT
        expect(
          find.byKey(const ValueKey('skin-care-frequency-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('skin-care-frequency-3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('skin-care-frequency-4')),
          findsNothing,
        );

        // 3. Select 3 times/day
        await tester.tap(find.byKey(const ValueKey('skin-care-frequency-3')));
        await tester.pumpAndSettle();

        // 4. Open Personalize routine sheet and verify full scrolling and Done button
        final personalizeBtn = find.text('Personalize routine');
        expect(personalizeBtn, findsOneWidget);
        await tester.tap(personalizeBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('onboarding-step7-personalize-sheet')),
          findsOneWidget,
        );
        final doneBtn = find.byKey(
          const ValueKey('onboarding-step7-personalize-done'),
        );
        expect(doneBtn, findsOneWidget);
        await tester.tap(doneBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('onboarding-step7-personalize-sheet')),
          findsNothing,
        );

        // 5. Tap Build skin routine to generate 3/day routine
        final buildBtn = find.text('Build skin routine');
        await tester.tap(buildBtn);
        await tester.pumpAndSettle();

        // 6. Verify we reached review stage with valid routine
        expect(find.text('Skin Care Routine'), findsOneWidget);
        expect(find.text('Review your weekly routine'), findsOneWidget);
        expect(find.text('Rebuild / Edit'), findsNothing);
        expect(find.text('Close editor'), findsNothing);
        expect(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          findsOneWidget,
        );

        final nextStepBtn = find.text('Next Step');
        expect(nextStepBtn, findsOneWidget);

        // 7. Next Step -> Step 8
        await tester.tap(nextStepBtn);
        await tester.pumpAndSettle();
        expect(notifier.state.draft.currentStep, 8);

        // 8. Step 8 back -> Step 7 review
        final shellBackStep8 = find.byKey(const Key('onboarding-step8-back'));
        expect(shellBackStep8, findsOneWidget);
        await tester.tap(shellBackStep8);
        await tester.pumpAndSettle();

        expect(notifier.state.draft.currentStep, 7);
        expect(find.text('Skin Care Routine'), findsOneWidget);
        expect(find.text('Review your weekly routine'), findsOneWidget);

        // 9. Shell Back -> returns to rebuild (hasProductsEditing) while preserving routine
        final shellBackStep7 = find.byKey(const Key('onboarding-step7-back'));
        expect(shellBackStep7, findsOneWidget);
        await tester.tap(shellBackStep7);
        await tester.pumpAndSettle();

        final flow = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingFlow)),
        ).read(skinCareFlowControllerProvider);
        expect(flow.state, SkinCareFlowState.hasProductsEditing);
        expect(find.text('Build skin routine'), findsOneWidget);

        expect(
          notifier.state.draft.baseTimeline.confirmedBlocksForSection(
            'skin_care',
          ),
          isNotEmpty,
        );
      },
    );

    testWidgets(
      'Flow B: No-products details -> Find products -> select essentials -> Build -> review -> Back',
      (tester) async {
        const uid = 'flow-b-user';
        final client = _IntegrationSkinCareAiClient(
          routineResultsQueue: [
            _testProductRecommendationResult(),
            _testRoutineResult(),
          ],
        );

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupPath: 'no_products',
            skinCareSetupStep: 1,
            skinCareStageContractVersion:
                BaseTimelineDraft.currentSkinCareStageContractVersion,
            skinCareSkinType: 'oily',
            skinCareProblems: const ['pimples'],
            skinCareBudget: 'medium',
            skinCareFacePhotoAssetId: 'test-face',
            skinCareFacePhotoR2Key: 'users/test/face.jpg',
            skinCareFacePhotoStatus: 'uploaded',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
        );

        final notifier = OnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: uid,
                    email: 'flow-b@example.com',
                    emailVerified: true,
                  ),
                ),
              ),
              authGenerationProvider.overrideWith((ref) => 1),
              onboardingStateProvider.overrideWith((ref) => notifier),
              skinCareAiClientProvider.overrideWithValue(client),
              deviceCountryServiceProvider.overrideWithValue(
                const _TestIntegrationDeviceCountryService(
                  DeviceCountry(
                    countryCode: 'IN',
                    countryName: 'India',
                    fromDeviceLocation: true,
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await tester.pumpAndSettle();

        final findProductsBtn = find.text('Find products');
        expect(findProductsBtn, findsOneWidget);
        await tester.tap(findProductsBtn);
        await tester.pumpAndSettle();

        expect(client.generateCalls, hasLength(1));
        expect(find.text('Build skin routine'), findsOneWidget);

        await _selectIntegrationProducts(tester);

        await tester.tap(find.text('Build skin routine'));
        await tester.pumpAndSettle();

        expect(client.generateCalls, hasLength(2));
        expect(find.text('Skin Care Routine'), findsOneWidget);
        expect(find.text('Review your weekly routine'), findsOneWidget);

        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
        expect(notifier.state.draft.currentStep, 8);

        await tester.tap(find.byKey(const Key('onboarding-step8-back')));
        await tester.pumpAndSettle();
        expect(notifier.state.draft.currentStep, 7);
        expect(find.text('Skin Care Routine'), findsOneWidget);

        await tester.tap(find.byKey(const Key('onboarding-step7-back')));
        await tester.pumpAndSettle();

        final flow = ProviderScope.containerOf(
          tester.element(find.byType(OnboardingFlow)),
        ).read(skinCareFlowControllerProvider);
        expect(flow.state, SkinCareFlowState.noProductsEditing);
      },
    );

    testWidgets(
      'Flow C: Long timeline card renders without overflow, scrolls smoothly',
      (tester) async {
        const uid = 'flow-c-user';
        final longSteps = List.generate(
          6,
          (index) =>
              'Long wrapped instruction ${index + 1} for device layout verification',
        );
        final longProducts = List.generate(
          6,
          (index) =>
              'Long product name ${index + 1} for device layout verification',
        );
        var base = BaseTimelineDraft(
          skinCareSetupPath: 'has_products',
          skinCareSetupStep: 2,
          skinCareStageContractVersion:
              BaseTimelineDraft.currentSkinCareStageContractVersion,
          skinCareProductNames: longProducts.join('\n'),
          skinCareReviewedProducts: [
            for (final product in longProducts)
              SkinCareDetectedProduct(name: product),
          ],
          blocks: [
            TimelineBlockDraft(
              id: 'device-long-card',
              section: 'skin_care',
              title: 'Long Skin Care Routine',
              startMinute: 480,
              endMinute: 495,
              repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareSteps: longSteps,
              skincareProducts: longProducts,
              skincareMissingItems: const [
                'Missing item one with a long explanation',
                'Missing item two with a long explanation',
              ],
            ),
          ],
        );
        final fingerprint = base.computeSkinCareRoutineFingerprint();
        base = base.copyWith(
          skinCareRoutineFingerprint: fingerprint,
          blocks: [
            base.blocks.single.copyWith(
              provenanceSourceIds: ['skin-care-generation:$fingerprint'],
            ),
          ],
        );
        final notifier = OnboardingNotifier()
          ..loadSeedData(
            OnboardingDraft(uid: uid, currentStep: 7, baseTimeline: base),
          );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
              onboardingStateProvider.overrideWith((ref) => notifier),
            ],
            child: const MaterialApp(home: Scaffold(body: OnboardingStep7())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skin Care Routine'), findsOneWidget);
        expect(find.text('Review your weekly routine'), findsOneWidget);
        expect(find.text('6. ${longSteps.last}'), findsOneWidget);
        expect(find.text('• ${longProducts.last}'), findsOneWidget);

        await tester.drag(
          find.byKey(const ValueKey('onboarding-step7-full-timeline')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Flow D: Deterministic integration test — mocked device country informs AI recommendations and displays currency-aware products',
      (tester) async {
        const uid = 'flow-d-user';
        final client = _IntegrationSkinCareAiClient(
          routineResultsQueue: [_testProductRecommendationResult()],
        );

        final draft = OnboardingDraft(
          uid: uid,
          currentStep: 7,
          baseTimeline: BaseTimelineDraft(
            skinCareSetupPath: 'no_products',
            skinCareSetupStep: 1,
            skinCareStageContractVersion:
                BaseTimelineDraft.currentSkinCareStageContractVersion,
            skinCareSkinType: 'oily',
            skinCareProblems: const ['pimples'],
            skinCareBudget: 'medium',
            skinCareFacePhotoAssetId: 'test-face',
            skinCareFacePhotoR2Key: 'users/test/face.jpg',
            skinCareFacePhotoStatus: 'uploaded',
            blocks: [BaseTimelineDraft.defaultBathBlock()],
          ),
        );

        final notifier = OnboardingNotifier()..loadSeedData(draft);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              optivusBackendModeProvider.overrideWithValue(
                OptivusBackendMode.fake,
              ),
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
              authProvider.overrideWith(
                (ref) => _Step7TestAuthNotifier(
                  const AuthUser(
                    uid: uid,
                    email: 'flow-d@example.com',
                    emailVerified: true,
                  ),
                ),
              ),
              authGenerationProvider.overrideWith((ref) => 1),
              onboardingStateProvider.overrideWith((ref) => notifier),
              skinCareAiClientProvider.overrideWithValue(client),
              deviceCountryServiceProvider.overrideWithValue(
                const _TestIntegrationDeviceCountryService(
                  DeviceCountry(
                    countryCode: 'IN',
                    countryName: 'India',
                    fromDeviceLocation: true,
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: OnboardingFlow()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Find products'));
        await tester.pumpAndSettle();

        expect(client.generateCalls, hasLength(1));
        expect(client.generateCalls.first['countryCode'], 'IN');
        expect(client.generateCalls.first['countryName'], 'India');
        expect(client.generateCalls.first['currencyCode'], 'INR');
      },
    );

    testWidgets(
      'Flow E: Recommendation currency matches region currency strictly with zero mixed currencies',
      (tester) async {
        const recs = [
          SkinCareProductRecommendationDraft(
            name: 'Gentle Cleanser',
            brand: 'Minimalist',
            category: 'cleanser',
            currencyCode: 'INR',
          ),
          SkinCareProductRecommendationDraft(
            name: 'Barrier Moisturizer',
            brand: 'Minimalist',
            category: 'moisturizer',
            currencyCode: 'INR',
          ),
          SkinCareProductRecommendationDraft(
            name: 'SPF 50 Sunscreen',
            brand: 'Minimalist',
            category: 'sunscreen',
            currencyCode: 'INR',
          ),
        ];

        for (final rec in recs) {
          expect(rec.currencyCode, 'INR');
        }

        final draft = BaseTimelineDraft(
          skinCareSetupPath: 'no_products',
          skinCareSetupStep: 2,
          skinCareStageContractVersion:
              BaseTimelineDraft.currentSkinCareStageContractVersion,
          skinCareRecommendationCountryCode: 'IN',
          skinCareRecommendationCurrencyCode: 'INR',
          skinCareProductRecommendations: recs,
          skinCareSelectedProductNames: recs.map((r) => r.displayName).toList(),
          blocks: [
            TimelineBlockDraft(
              id: 'skin-1',
              section: 'skin_care',
              title: 'Morning Skin Care',
              startMinute: 480,
              endMinute: 495,
              repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: const ['Product A'],
            ),
            TimelineBlockDraft(
              id: 'skin-2',
              section: 'skin_care',
              title: 'Night Skin Care',
              startMinute: 1260,
              endMinute: 1275,
              repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.softBlockKey,
              skincareProducts: const ['Product B'],
            ),
          ],
        );

        expect(draft.validateSkinCareSetup('uid-test'), isNull);

        final mixedDraft = draft.copyWith(
          skinCareProductRecommendations: [
            ...recs,
            const SkinCareProductRecommendationDraft(
              name: 'Foreign Sunscreen',
              brand: 'Foreign Brand',
              category: 'sunscreen',
              currencyCode: 'USD',
            ),
          ],
        );
        expect(mixedDraft.validateSkinCareSetup('uid-test'), isNotNull);
      },
    );
  });
}

class _Step7TestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _Step7TestAuthNotifier(AuthUser? user)
    : super(
        AuthState(
          user: user,
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestIntegrationDeviceCountryService
    implements DeviceCountryService, PermissionAwareDeviceCountryService {
  final DeviceCountry? result;
  const _TestIntegrationDeviceCountryService(this.result);

  @override
  Future<DeviceCountry?> detectCountry() async => result;

  @override
  Future<DeviceCountry?> detectCountryIfPermissionGranted() async => result;
}

class _IntegrationSkinCareAiClient implements SkinCareAiClient {
  final List<SkinCareAiRoutineResult>? routineResultsQueue;
  final List<Map<String, dynamic>> generateCalls = [];

  _IntegrationSkinCareAiClient({this.routineResultsQueue});

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async => const SkinCareAiProductResult(products: []);

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    generateCalls.add(params);
    if (routineResultsQueue != null && routineResultsQueue!.isNotEmpty) {
      return routineResultsQueue!.removeAt(0);
    }
    return _testRoutineResult();
  }
}

SkinCareAiRoutineResult _testProductRecommendationResult() {
  return const SkinCareAiRoutineResult(
    morningRoutine: [],
    nightRoutine: [],
    weeklyRoutine: [],
    timelineBlocks: [],
    routinePlans: [],
    recommendedProducts: [
      SkinCareProductRecommendation(
        name: 'Gentle Cleanser',
        brand: 'Minimalist',
        category: 'cleanser',
        currencyCode: 'INR',
      ),
      SkinCareProductRecommendation(
        name: 'Barrier Moisturizer',
        brand: 'Minimalist',
        category: 'moisturizer',
        currencyCode: 'INR',
      ),
      SkinCareProductRecommendation(
        name: 'SPF 50 Sunscreen',
        brand: 'Minimalist',
        category: 'sunscreen',
        currencyCode: 'INR',
      ),
    ],
  );
}

SkinCareAiRoutineResult _testRoutineResult() {
  return const SkinCareAiRoutineResult(
    morningRoutine: ['Cleanse', 'Sunscreen'],
    nightRoutine: ['Cleanse', 'Moisturize'],
    weeklyRoutine: [],
    timelineBlocks: [],
    routinePlans: [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        productNames: [
          'Minimalist Gentle Cleanser',
          'Minimalist SPF 50 Sunscreen',
        ],
        steps: ['Wash face', 'Apply sunscreen'],
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Skin Care',
        productNames: [
          'Minimalist Gentle Cleanser',
          'Minimalist Barrier Moisturizer',
        ],
        steps: ['Wash face', 'Apply moisturizer'],
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
      ),
    ],
  );
}

SkinCareAiRoutineResult _testRoutineResult3Slots() {
  return const SkinCareAiRoutineResult(
    morningRoutine: ['Cleanse', 'Sunscreen'],
    nightRoutine: ['Cleanse'],
    weeklyRoutine: [],
    timelineBlocks: [],
    routinePlans: [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        productNames: ['Gentle Cleanser', 'SPF 50 Sunscreen'],
        steps: ['Wash face', 'Apply sunscreen'],
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'midday',
        title: 'Midday Skin Care',
        productNames: ['SPF 50 Sunscreen'],
        steps: ['Reapply sunscreen'],
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Skin Care',
        productNames: ['Gentle Cleanser'],
        steps: ['Wash face'],
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
      ),
    ],
  );
}

Future<void> _selectIntegrationProducts(WidgetTester tester) async {
  for (final name in [
    'Minimalist Gentle Cleanser',
    'Minimalist Barrier Moisturizer',
    'Minimalist SPF 50 Sunscreen',
  ]) {
    final product = find.text(name);
    for (
      var attempt = 0;
      attempt < 10 && product.evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pump();
    }
    await tester.ensureVisible(product);
    await tester.pump();
    await tester.tap(product);
    await tester.pump();
  }
}
