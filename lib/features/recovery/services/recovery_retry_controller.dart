import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecoveryRetryState {
  final int attemptCount;
  final bool isCoolingDown;
  final int cooldownSecondsRemaining;
  final bool maxAttemptsReached;

  const RecoveryRetryState({
    this.attemptCount = 0,
    this.isCoolingDown = false,
    this.cooldownSecondsRemaining = 0,
    this.maxAttemptsReached = false,
  });

  bool get canRetry => !isCoolingDown && !maxAttemptsReached;

  RecoveryRetryState copyWith({
    int? attemptCount,
    bool? isCoolingDown,
    int? cooldownSecondsRemaining,
    bool? maxAttemptsReached,
  }) {
    return RecoveryRetryState(
      attemptCount: attemptCount ?? this.attemptCount,
      isCoolingDown: isCoolingDown ?? this.isCoolingDown,
      cooldownSecondsRemaining:
          cooldownSecondsRemaining ?? this.cooldownSecondsRemaining,
      maxAttemptsReached: maxAttemptsReached ?? this.maxAttemptsReached,
    );
  }
}

class RecoveryRetryController extends StateNotifier<RecoveryRetryState> {
  Timer? _timer;

  RecoveryRetryController() : super(const RecoveryRetryState());

  static int calculateBackoffSeconds(int attempt) {
    if (attempt <= 0) return 2;
    final seconds = (2 * (1 << (attempt - 1))).clamp(2, 60);
    return seconds;
  }

  void recordAttemptAndStartCooldown() {
    if (state.attemptCount >= 5) {
      state = state.copyWith(maxAttemptsReached: true, isCoolingDown: false);
      return;
    }

    final newAttempt = state.attemptCount + 1;
    final maxReached = newAttempt >= 5;
    final cooldown = calculateBackoffSeconds(newAttempt);

    _timer?.cancel();
    state = state.copyWith(
      attemptCount: newAttempt,
      isCoolingDown: true,
      cooldownSecondsRemaining: cooldown,
      maxAttemptsReached: maxReached,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.cooldownSecondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(
          isCoolingDown: false,
          cooldownSecondsRemaining: 0,
        );
      } else {
        state = state.copyWith(
          cooldownSecondsRemaining: state.cooldownSecondsRemaining - 1,
        );
      }
    });
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = const RecoveryRetryState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final recoveryRetryControllerProvider =
    StateNotifierProvider<RecoveryRetryController, RecoveryRetryState>(
      (ref) => RecoveryRetryController(),
    );
