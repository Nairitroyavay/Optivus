import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/utils/auth_error_mapper.dart';
import 'package:optivus/state/auth_state.dart';

enum VerificationMessageKind { network, rateLimited, firebaseFailure, success }

class VerificationLifecycleState {
  final bool foreground;
  final bool checking;
  final bool resendInFlight;
  final bool verificationConfirmed;
  final DateTime? nextResendAllowedAt;
  final DateTime? nextVerificationCheckAllowedAt;
  final int resendSecondsRemaining;
  final int verificationThrottleStreak;
  final int resendThrottleStreak;
  final String? message;
  final VerificationMessageKind? messageKind;

  const VerificationLifecycleState({
    this.foreground = false,
    this.checking = false,
    this.resendInFlight = false,
    this.verificationConfirmed = false,
    this.nextResendAllowedAt,
    this.nextVerificationCheckAllowedAt,
    this.resendSecondsRemaining = 0,
    this.verificationThrottleStreak = 0,
    this.resendThrottleStreak = 0,
    this.message,
    this.messageKind,
  });

  VerificationLifecycleState copyWith({
    bool? foreground,
    bool? checking,
    bool? resendInFlight,
    bool? verificationConfirmed,
    DateTime? nextResendAllowedAt,
    DateTime? nextVerificationCheckAllowedAt,
    int? resendSecondsRemaining,
    int? verificationThrottleStreak,
    int? resendThrottleStreak,
    String? message,
    VerificationMessageKind? messageKind,
    bool clearDeadline = false,
    bool clearVerificationDeadline = false,
    bool clearMessage = false,
  }) {
    return VerificationLifecycleState(
      foreground: foreground ?? this.foreground,
      checking: checking ?? this.checking,
      resendInFlight: resendInFlight ?? this.resendInFlight,
      verificationConfirmed:
          verificationConfirmed ?? this.verificationConfirmed,
      nextResendAllowedAt: clearDeadline
          ? null
          : (nextResendAllowedAt ?? this.nextResendAllowedAt),
      nextVerificationCheckAllowedAt: clearVerificationDeadline
          ? null
          : (nextVerificationCheckAllowedAt ??
                this.nextVerificationCheckAllowedAt),
      resendSecondsRemaining:
          resendSecondsRemaining ?? this.resendSecondsRemaining,
      verificationThrottleStreak:
          verificationThrottleStreak ?? this.verificationThrottleStreak,
      resendThrottleStreak: resendThrottleStreak ?? this.resendThrottleStreak,
      message: clearMessage && message == null
          ? null
          : (message ?? this.message),
      messageKind: clearMessage && messageKind == null
          ? null
          : (messageKind ?? this.messageKind),
    );
  }
}

class VerificationLifecyclePolicy {
  final List<Duration> pollIntervals;
  final Duration resendCooldown;
  final List<Duration> throttleBackoff;
  final Duration countdownTick;

  const VerificationLifecyclePolicy({
    this.pollIntervals = const [
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
      Duration(seconds: 20),
      Duration(seconds: 30),
    ],
    this.resendCooldown = const Duration(seconds: 60),
    this.throttleBackoff = const [
      Duration(seconds: 120),
      Duration(seconds: 240),
      Duration(seconds: 480),
      Duration(seconds: 900),
    ],
    this.countdownTick = const Duration(seconds: 1),
  });
}

final verificationLifecyclePolicyProvider = Provider(
  (ref) => const VerificationLifecyclePolicy(),
);

final verificationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final verificationLifecycleProvider =
    StateNotifierProvider.autoDispose<
      VerificationLifecycleController,
      VerificationLifecycleState
    >((ref) {
      return VerificationLifecycleController(
        ref,
        policy: ref.watch(verificationLifecyclePolicyProvider),
        now: ref.watch(verificationClockProvider),
      );
    });

class VerificationLifecycleController
    extends StateNotifier<VerificationLifecycleState> {
  final Ref _ref;
  final VerificationLifecyclePolicy _policy;
  final DateTime Function() _now;
  final String? _expectedUid;

  Timer? _pollTimer;
  Timer? _countdownTimer;
  Future<void>? _checkInFlight;
  Future<void>? _resendInFlight;
  int _pollIndex = 0;
  bool _disposed = false;
  bool _detached = false;

  VerificationLifecycleController(
    this._ref, {
    required VerificationLifecyclePolicy policy,
    required DateTime Function() now,
  }) : _policy = policy,
       _now = now,
       _expectedUid = _ref.read(authProvider).user?.uid,
       super(const VerificationLifecycleState()) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (_disposed) return;
      if (next.user?.uid != _expectedUid) {
        _stopSession();
        return;
      }
      if (next.user?.emailVerified == true || !next.emailUnverified) {
        _stopAfterVerification();
      }
    });
  }

  void activate() {
    if (_disposed || state.foreground || !_isEligible) return;
    _detached = false;
    state = state.copyWith(foreground: true);
    _pollIndex = 0;
    _reconcileResendDeadline();
    _startCountdownIfNeeded();
    unawaited(checkNow());
  }

  void pause() {
    if (_disposed || !state.foreground) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = state.copyWith(foreground: false);
  }

  void resume() {
    if (_disposed || !_isEligible) return;
    if (!state.foreground) {
      activate();
      return;
    }
    unawaited(checkNow());
  }

  /// Synchronously abandons the screen-owned session without notifying a
  /// widget that is already unmounting. Auto-disposal follows immediately.
  void detach() {
    _detached = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> checkNow({bool manual = false}) {
    if (_disposed || !_isEligible || state.verificationConfirmed) {
      return Future.value();
    }
    final throttledUntil = state.nextVerificationCheckAllowedAt;
    if (throttledUntil != null && throttledUntil.isAfter(_now())) {
      return Future.value();
    }
    final existing = _checkInFlight;
    if (existing != null) return existing;

    _pollTimer?.cancel();
    _pollTimer = null;
    final future = _performCheck(manual: manual);
    _checkInFlight = future;
    future.whenComplete(() {
      if (identical(_checkInFlight, future)) _checkInFlight = null;
    });
    return future;
  }

  Future<void> _performCheck({required bool manual}) async {
    final uid = _expectedUid;
    if (uid == null) return;
    state = state.copyWith(checking: true, clearMessage: manual);
    try {
      await _ref.read(authProvider.notifier).checkEmailVerification();
      if (!_canApply(uid)) return;
      final auth = _ref.read(authProvider);
      if (auth.user?.emailVerified == true || !auth.emailUnverified) {
        _stopAfterVerification();
        return;
      }

      // A successful authoritative reload that is still unverified is the
      // normal waiting state, never an invalid-link or credential error.
      state = state.copyWith(
        checking: false,
        verificationThrottleStreak: 0,
        clearVerificationDeadline: true,
        clearMessage: true,
      );
      _scheduleNextPoll();
    } catch (error) {
      if (!_canApply(uid)) return;
      final mapped = mapAuthError(error);
      if (mapped.reason == AuthFailureReason.networkFailure) {
        state = state.copyWith(
          checking: false,
          message:
              'Couldn\'t check verification. Check your connection and try again.',
          messageKind: VerificationMessageKind.network,
          verificationThrottleStreak: 0,
        );
        _scheduleNextPoll();
      } else if (mapped.reason == AuthFailureReason.tooManyRequests) {
        final streak = state.verificationThrottleStreak + 1;
        final delay = _throttleDelay(streak);
        state = state.copyWith(
          checking: false,
          verificationThrottleStreak: streak,
          nextVerificationCheckAllowedAt: _now().add(delay),
          message:
              'Too many attempts. Please wait a little before trying again.',
          messageKind: VerificationMessageKind.rateLimited,
        );
        _scheduleNextPoll(delay: delay);
      } else {
        state = state.copyWith(
          checking: false,
          message: 'Couldn\'t check verification. Please try again.',
          messageKind: VerificationMessageKind.firebaseFailure,
          verificationThrottleStreak: 0,
        );
        _scheduleNextPoll();
      }
    } finally {
      if (_canApply(uid) && state.checking) {
        state = state.copyWith(checking: false);
      }
    }
  }

  Future<void> resend() {
    if (_disposed || !_isEligible || state.resendSecondsRemaining > 0) {
      return Future.value();
    }
    final existing = _resendInFlight;
    if (existing != null) return existing;

    final future = _performResend();
    _resendInFlight = future;
    future.whenComplete(() {
      if (identical(_resendInFlight, future)) _resendInFlight = null;
    });
    return future;
  }

  Future<void> _performResend() async {
    final uid = _expectedUid;
    if (uid == null) return;
    state = state.copyWith(resendInFlight: true, clearMessage: true);
    try {
      await _ref.read(authProvider.notifier).resendEmailVerification();
      if (!_canApply(uid)) return;
      final deadline = _now().add(_policy.resendCooldown);
      state = state.copyWith(
        resendInFlight: false,
        nextResendAllowedAt: deadline,
        resendSecondsRemaining: _remainingSeconds(deadline),
        resendThrottleStreak: 0,
        message: 'Sent again. Check Spam or Promotions if it doesn\'t arrive.',
        messageKind: VerificationMessageKind.success,
      );
      _startCountdownIfNeeded();
    } catch (error) {
      if (!_canApply(uid)) return;
      final mapped = mapAuthError(error);
      if (mapped.reason == AuthFailureReason.tooManyRequests) {
        final streak = state.resendThrottleStreak + 1;
        final deadline = _now().add(_throttleDelay(streak));
        state = state.copyWith(
          resendInFlight: false,
          resendThrottleStreak: streak,
          nextResendAllowedAt: deadline,
          resendSecondsRemaining: _remainingSeconds(deadline),
          message:
              'Too many attempts. Please wait a little before trying again.',
          messageKind: VerificationMessageKind.rateLimited,
        );
        _startCountdownIfNeeded();
      } else if (mapped.reason == AuthFailureReason.networkFailure) {
        state = state.copyWith(
          resendInFlight: false,
          message:
              'Couldn\'t resend the email. Check your connection and try again.',
          messageKind: VerificationMessageKind.network,
        );
      } else {
        state = state.copyWith(
          resendInFlight: false,
          message: 'Couldn\'t resend the email. Please try again.',
          messageKind: VerificationMessageKind.firebaseFailure,
        );
      }
    } finally {
      if (_canApply(uid) && state.resendInFlight) {
        state = state.copyWith(resendInFlight: false);
      }
    }
  }

  void clearMessage() {
    if (!_disposed) state = state.copyWith(clearMessage: true);
  }

  void showAccountError(String message) {
    if (!_disposed) {
      state = state.copyWith(
        message: message,
        messageKind: VerificationMessageKind.firebaseFailure,
      );
    }
  }

  void _reconcileResendDeadline() {
    final sentAt = _ref.read(authProvider).lastVerificationEmailSent;
    final authDeadline = sentAt?.add(_policy.resendCooldown);
    // Once this controller owns a deadline (normal resend or throttle), keep
    // it authoritative. AuthState supplies only the initial/mount deadline.
    final deadline = state.nextResendAllowedAt ?? authDeadline;
    if (deadline == null) return;
    final remaining = _remainingSeconds(deadline);
    state = state.copyWith(
      nextResendAllowedAt: deadline,
      resendSecondsRemaining: remaining,
      clearDeadline: remaining == 0,
    );
  }

  int _remainingSeconds(DateTime deadline) {
    final milliseconds = deadline.difference(_now()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / Duration.millisecondsPerSecond).ceil();
  }

  void _startCountdownIfNeeded() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!state.foreground || state.resendSecondsRemaining <= 0) return;
    _countdownTimer = Timer.periodic(_policy.countdownTick, (_) {
      if (_disposed || !state.foreground) return;
      final deadline = state.nextResendAllowedAt;
      if (deadline == null) return;
      final remaining = _remainingSeconds(deadline);
      if (remaining == 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        state = state.copyWith(resendSecondsRemaining: 0, clearDeadline: true);
      } else {
        state = state.copyWith(resendSecondsRemaining: remaining);
      }
    });
  }

  void _scheduleNextPoll({Duration? delay}) {
    if (!_isEligible || !state.foreground || state.verificationConfirmed) {
      return;
    }
    _pollTimer?.cancel();
    final intervals = _policy.pollIntervals;
    if (intervals.isEmpty && delay == null) return;
    final selected =
        delay ?? intervals[_pollIndex.clamp(0, intervals.length - 1)];
    if (delay == null && _pollIndex < intervals.length - 1) {
      _pollIndex++;
    }
    _pollTimer = Timer(selected, () {
      _pollTimer = null;
      if (_isEligible && state.foreground) unawaited(checkNow());
    });
  }

  Duration _throttleDelay(int streak) {
    final backoff = _policy.throttleBackoff;
    if (backoff.isEmpty) return const Duration(minutes: 15);
    return backoff[(streak - 1).clamp(0, backoff.length - 1)];
  }

  bool get _isEligible {
    final auth = _ref.read(authProvider);
    return !_disposed &&
        !_detached &&
        _expectedUid != null &&
        auth.user?.uid == _expectedUid &&
        auth.emailUnverified &&
        auth.user?.emailVerified != true;
  }

  bool _canApply(String uid) {
    return !_disposed &&
        !_detached &&
        uid == _expectedUid &&
        _ref.read(authProvider).user?.uid == uid;
  }

  void _stopAfterVerification() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!_disposed) {
      state = state.copyWith(
        foreground: false,
        checking: false,
        resendInFlight: false,
        verificationConfirmed: true,
        message: 'Email verified',
        messageKind: VerificationMessageKind.success,
      );
    }
  }

  void _stopSession() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!_disposed) {
      state = state.copyWith(
        foreground: false,
        checking: false,
        resendInFlight: false,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
