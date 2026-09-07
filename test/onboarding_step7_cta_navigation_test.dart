import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_primary_action.dart';
import 'package:optivus/models/onboarding_draft.dart';

void _noop() {}

void main() {
  group('Step 7 Action Bridge - Token, Epoch & Discard Semantics', () {
    test('publish with matching epoch sets action', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      var callbackInvoked = false;
      bridge.publish(
        ownerId: 'has_products',
        epoch: 1,
        action: OnboardingStep7PrimaryAction(
          label: 'Build skin routine',
          enabled: true,
          loading: false,
          onPressed: () => callbackInvoked = true,
        ),
      );

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action, isNotNull);
      expect(state.action!.label, 'Build skin routine');
      expect(state.activeToken, isNotNull);
      expect(state.activeToken!.ownerId, 'has_products');
      expect(state.activeToken!.epoch, 1);

      // Backwards-compatible provider also reflects the action
      final legacy = container.read(onboardingStep7PrimaryActionProvider);
      expect(legacy, isNotNull);
      expect(legacy!.label, 'Build skin routine');

      state.action!.onPressed();
      expect(callbackInvoked, isTrue);
      container.dispose();
    });

    test('publish with older epoch is ignored (stale response protection)', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      // Publish at epoch 2
      bridge.publish(
        ownerId: 'no_products',
        epoch: 2,
        action: const OnboardingStep7PrimaryAction(
          label: 'Find products',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      // Late callback arrives with epoch 1
      bridge.publish(
        ownerId: 'no_products',
        epoch: 1,
        action: const OnboardingStep7PrimaryAction(
          label: 'Stale Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action!.label, 'Find products');
      expect(state.activeToken!.epoch, 2);
      container.dispose();
    });

    test('clear from different owner does not clobber active action', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      bridge.publish(
        ownerId: 'no_products',
        epoch: 3,
        action: const OnboardingStep7PrimaryAction(
          label: 'Valid Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      // Old screen disposing tries to clear
      bridge.clear(ownerId: 'has_products', epoch: 3);

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action, isNotNull);
      expect(state.action!.label, 'Valid Action');
      container.dispose();
    });

    test('clear with matching owner resets action and legacy provider', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      bridge.publish(
        ownerId: 'no_products',
        epoch: 4,
        action: const OnboardingStep7PrimaryAction(
          label: 'Active Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      bridge.clear(ownerId: 'no_products', epoch: 4);

      final state = container.read(step7ActionBridgeProvider);
      expect(state.action, isNull);
      expect(state.activeToken, isNull);
      expect(container.read(onboardingStep7PrimaryActionProvider), isNull);
      container.dispose();
    });

    test('clearAll unconditionally wipes all actions and legacy state', () {
      final container = ProviderContainer();
      final bridge = container.read(step7ActionBridgeProvider.notifier);

      bridge.publish(
        ownerId: 'has_products',
        epoch: 5,
        action: const OnboardingStep7PrimaryAction(
          label: 'Some Action',
          enabled: true,
          loading: false,
          onPressed: _noop,
        ),
      );

      bridge.clearAll();

      expect(container.read(step7ActionBridgeProvider).action, isNull);
      expect(container.read(onboardingStep7PrimaryActionProvider), isNull);
      container.dispose();
    });
  });

  group('Top-Left Back Button and Navigation Invariants', () {
    test('Choice screen suppresses top-left back button', () {
      const base = BaseTimelineDraft(
        skinCareSetupStep: 0,
        skinCareSetupPath: '',
      );

      // Without flow controller override
      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
        ),
        isFalse,
      );

      // With explicit step7CanHandleBack = false
      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
          step7CanHandleBack: false,
        ),
        isFalse,
      );
    });

    test('Active subscreen enables top-left back button', () {
      const base = BaseTimelineDraft(
        skinCareSetupStep: 1,
        skinCareSetupPath: 'has_products',
      );

      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
        ),
        isTrue,
      );

      expect(
        onboardingShouldShowTopLeftBackButton(
          currentPage: 7,
          baseTimeline: base,
          step7CanHandleBack: true,
        ),
        isTrue,
      );
    });
  });
}
