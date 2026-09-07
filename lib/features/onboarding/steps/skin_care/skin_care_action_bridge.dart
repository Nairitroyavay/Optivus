import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding_step_7_primary_action.dart';

/// Uniquely identifies the owner and lifecycle epoch of a Step 7 action publication.
@immutable
class Step7ActionToken {
  final Object ownerId;
  final int epoch;

  const Step7ActionToken({required this.ownerId, required this.epoch});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Step7ActionToken &&
          runtimeType == other.runtimeType &&
          ownerId == other.ownerId &&
          epoch == other.epoch;

  @override
  int get hashCode => Object.hash(ownerId, epoch);

  @override
  String toString() => 'Step7ActionToken($ownerId, epoch: $epoch)';
}

/// Holds the active action and its owning token.
@immutable
class Step7ActionBridgeState {
  final OnboardingStep7PrimaryAction? action;
  final Step7ActionToken? activeToken;

  const Step7ActionBridgeState({this.action, this.activeToken});
}

/// Ownership-safe and epoch-guarded notifier for Step 7 primary footer action.
///
/// Prevents:
/// 1. Stale post-frame callbacks from older screens/states publishing over newer ones.
/// 2. Disposing widgets clearing actions owned by a newer active widget.
/// 3. Retaining actions after leaving Step 7 or switching modes.
class Step7ActionBridgeNotifier extends StateNotifier<Step7ActionBridgeState> {
  final Ref ref;
  Step7ActionBridgeNotifier(this.ref) : super(const Step7ActionBridgeState());

  /// Publishes a new action if the token epoch is current.
  void publish({
    required Object ownerId,
    required int epoch,
    required OnboardingStep7PrimaryAction? action,
  }) {
    final currentToken = state.activeToken;
    if (currentToken != null && epoch < currentToken.epoch) {
      // Ignore stale publication from an earlier epoch.
      return;
    }
    state = Step7ActionBridgeState(
      action: action,
      activeToken: Step7ActionToken(ownerId: ownerId, epoch: epoch),
    );
    ref.read(onboardingStep7PrimaryActionProvider.notifier).state = action;
  }

  /// Clears the action only if the caller is the current owner and matches the epoch.
  void clear({required Object ownerId, required int epoch}) {
    final currentToken = state.activeToken;
    if (currentToken == null) return;
    if (currentToken.ownerId != ownerId || currentToken.epoch != epoch) {
      // Do not allow an older or different owner to clear a newer owner's action.
      return;
    }
    state = const Step7ActionBridgeState(action: null, activeToken: null);
    ref.read(onboardingStep7PrimaryActionProvider.notifier).state = null;
  }

  /// Unconditionally clears any published action. Used on step exit or full reset.
  void clearAll() {
    state = const Step7ActionBridgeState(action: null, activeToken: null);
    ref.read(onboardingStep7PrimaryActionProvider.notifier).state = null;
  }
}

final step7ActionBridgeProvider =
    StateNotifierProvider<Step7ActionBridgeNotifier, Step7ActionBridgeState>(
      (ref) => Step7ActionBridgeNotifier(ref),
    );

/// Canonical provider for watching or setting the active Step 7 primary action.
final onboardingStep7PrimaryActionProvider =
    StateProvider<OnboardingStep7PrimaryAction?>((ref) => null);
