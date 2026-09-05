import 'dart:async';

import 'package:flutter/foundation.dart';

enum AiGenerationPhase {
  idle,
  preparing,
  uploading,
  analyzing,
  generating,
  success,
  error,
  retrying,
}

enum AiGenerationErrorCategory {
  network,
  timeout,
  rateLimited,
  serviceUnavailable,
  invalidInput,
  responseInvalid,
  unauthorized,
  unknown,
}

@immutable
class AiGenerationError {
  final AiGenerationErrorCategory category;
  final String message;
  final bool canRetry;

  const AiGenerationError({
    required this.category,
    required this.message,
    required this.canRetry,
  });

  const AiGenerationError.timeout()
    : category = AiGenerationErrorCategory.timeout,
      message = 'That took longer than expected. Try again.',
      canRetry = true;

  const AiGenerationError.unknown()
    : category = AiGenerationErrorCategory.unknown,
      message = 'Something went wrong while preparing this. Try again.',
      canRetry = true;
}

@immutable
class AiTimeoutPolicy {
  final Duration operationTimeout;

  const AiTimeoutPolicy({required this.operationTimeout});
}

/// Product-level operation timeouts. HTTP clients may still have a lower-level
/// socket safety timeout; lifecycle enforcement belongs here.
abstract final class AiOperationTimeouts {
  static const routineImport = AiTimeoutPolicy(
    operationTimeout: Duration(seconds: 180),
  );
  static const nutrition = AiTimeoutPolicy(
    operationTimeout: Duration(seconds: 180),
  );
  static const skinCare = AiTimeoutPolicy(
    operationTimeout: Duration(seconds: 60),
  );
  static const coach = AiTimeoutPolicy(
    operationTimeout: Duration(seconds: 180),
  );
}

@immutable
class AiGenerationState {
  final AiGenerationPhase phase;
  final String? operationId;
  final int attempt;
  final DateTime? startedAt;
  final DateTime? phaseStartedAt;
  final String? message;
  final AiGenerationError? error;

  const AiGenerationState({
    this.phase = AiGenerationPhase.idle,
    this.operationId,
    this.attempt = 0,
    this.startedAt,
    this.phaseStartedAt,
    this.message,
    this.error,
  });

  bool get isActive => switch (phase) {
    AiGenerationPhase.preparing ||
    AiGenerationPhase.uploading ||
    AiGenerationPhase.analyzing ||
    AiGenerationPhase.generating ||
    AiGenerationPhase.retrying => true,
    _ => false,
  };

  bool get canRetry =>
      phase == AiGenerationPhase.error && (error?.canRetry ?? false);
}

class AiGenerationScope {
  final void Function(AiGenerationPhase phase, {String? message}) _transition;
  final bool Function() _isCurrent;

  const AiGenerationScope(this._transition, this._isCurrent);

  bool get isCurrent => _isCurrent();

  void transition(AiGenerationPhase phase, {String? message}) {
    _transition(phase, message: message);
  }
}

@immutable
class AiGenerationRunResult<T> {
  final T? value;
  final AiGenerationError? error;
  final bool ignored;
  final bool duplicate;

  const AiGenerationRunResult._({
    this.value,
    this.error,
    this.ignored = false,
    this.duplicate = false,
  });

  const AiGenerationRunResult.success(T value) : this._(value: value);
  const AiGenerationRunResult.failed(AiGenerationError error)
    : this._(error: error);
  const AiGenerationRunResult.ignored() : this._(ignored: true);
  const AiGenerationRunResult.duplicate() : this._(duplicate: true);

  bool get isSuccess => value != null && error == null && !ignored;
}

typedef AiErrorMapper = AiGenerationError Function(Object error);

/// Feature-scoped lifecycle coordinator. It provides one in-flight fence,
/// operation identity, timeout enforcement, and terminal cleanup without
/// introducing a global AI singleton.
class AiGenerationController extends ChangeNotifier {
  AiGenerationState _state = const AiGenerationState();
  int _generation = 0;
  int _attempt = 0;
  bool _disposed = false;
  Timer? _activeTimeoutTimer;

  AiGenerationState get state => _state;
  int get operationGeneration => _generation;
  int get attempt => _attempt;
  bool get isDisposed => _disposed;

  Future<AiGenerationRunResult<T>> run<T>({
    required String operationType,
    required AiTimeoutPolicy timeoutPolicy,
    required Future<T> Function(AiGenerationScope scope) operation,
    bool Function()? isSessionCurrent,
    AiErrorMapper? mapError,
    bool retry = false,
    String? preparingMessage,
  }) async {
    if (_disposed) return const AiGenerationRunResult.ignored();
    if (_state.isActive) return const AiGenerationRunResult.duplicate();

    final generation = ++_generation;
    final now = DateTime.now();
    final operationId = '$operationType-${now.microsecondsSinceEpoch}';
    _attempt = retry ? _attempt + 1 : 1;
    if (retry) {
      _setState(
        AiGenerationState(
          phase: AiGenerationPhase.retrying,
          operationId: operationId,
          attempt: _attempt,
          startedAt: now,
          phaseStartedAt: now,
        ),
      );
    }
    _setPhase(
      AiGenerationPhase.preparing,
      operationId: operationId,
      attempt: _attempt,
      startedAt: now,
      message: preparingMessage,
    );

    bool isCurrent() {
      return !_disposed &&
          generation == _generation &&
          (isSessionCurrent?.call() ?? true);
    }

    final scope = AiGenerationScope((phase, {message}) {
      if (!isCurrent()) return;
      if (!_isAllowedTransition(_state.phase, phase)) {
        throw StateError(
          'Invalid AI lifecycle transition: ${_state.phase.name} -> ${phase.name}',
        );
      }
      _setPhase(
        phase,
        operationId: operationId,
        attempt: _attempt,
        startedAt: now,
        message: message,
      );
    }, isCurrent);

    final completer = Completer<T>();

    final timeoutTimer = Timer(timeoutPolicy.operationTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException(
            'Operation timed out',
            timeoutPolicy.operationTimeout,
          ),
        );
      }
    });
    _activeTimeoutTimer = timeoutTimer;

    try {
      operation(scope).then(
        (val) {
          timeoutTimer.cancel();
          if (!completer.isCompleted) {
            completer.complete(val);
          }
        },
        onError: (e, st) {
          timeoutTimer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(e, st);
          }
        },
      );

      final value = await completer.future;
      if (!isCurrent()) return const AiGenerationRunResult.ignored();
      _setPhase(
        AiGenerationPhase.success,
        operationId: operationId,
        attempt: _attempt,
        startedAt: now,
      );
      return AiGenerationRunResult.success(value);
    } on TimeoutException {
      if (!isCurrent()) return const AiGenerationRunResult.ignored();
      _generation++;
      const error = AiGenerationError.timeout();
      _setError(error, operationId, now);
      return const AiGenerationRunResult.failed(error);
    } catch (exception) {
      if (!isCurrent()) return const AiGenerationRunResult.ignored();
      _generation++;
      final error =
          mapError?.call(exception) ?? const AiGenerationError.unknown();
      _setError(error, operationId, now);
      return AiGenerationRunResult.failed(error);
    } finally {
      timeoutTimer.cancel();
      if (_activeTimeoutTimer == timeoutTimer) {
        _activeTimeoutTimer = null;
      }
    }
  }

  void fail(AiGenerationError error) {
    if (_state.operationId == null || !_state.isActive) return;
    _generation++;
    _setError(error, _state.operationId!, _state.startedAt ?? DateTime.now());
  }

  void cancel() {
    _activeTimeoutTimer?.cancel();
    _activeTimeoutTimer = null;
    _generation++;
    _attempt = 0;
    _setState(const AiGenerationState());
  }

  void reset() => cancel();

  void _setError(
    AiGenerationError error,
    String operationId,
    DateTime startedAt,
  ) {
    final now = DateTime.now();
    _setState(
      AiGenerationState(
        phase: AiGenerationPhase.error,
        operationId: operationId,
        attempt: _attempt,
        startedAt: startedAt,
        phaseStartedAt: now,
        message: error.message,
        error: error,
      ),
    );
  }

  void _setPhase(
    AiGenerationPhase phase, {
    required String operationId,
    required int attempt,
    required DateTime startedAt,
    String? message,
  }) {
    _setState(
      AiGenerationState(
        phase: phase,
        operationId: operationId,
        attempt: attempt,
        startedAt: startedAt,
        phaseStartedAt: DateTime.now(),
        message: message,
      ),
    );
  }

  void _setState(AiGenerationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  static bool _isAllowedTransition(
    AiGenerationPhase from,
    AiGenerationPhase to,
  ) {
    if (to == AiGenerationPhase.error) return from.isActivePhase;
    return switch (from) {
      AiGenerationPhase.preparing => const {
        AiGenerationPhase.uploading,
        AiGenerationPhase.analyzing,
        AiGenerationPhase.generating,
      }.contains(to),
      AiGenerationPhase.uploading => const {
        AiGenerationPhase.analyzing,
        AiGenerationPhase.generating,
      }.contains(to),
      AiGenerationPhase.analyzing => to == AiGenerationPhase.generating,
      AiGenerationPhase.retrying => const {
        AiGenerationPhase.preparing,
        AiGenerationPhase.uploading,
        AiGenerationPhase.analyzing,
        AiGenerationPhase.generating,
      }.contains(to),
      _ => false,
    };
  }

  @override
  void dispose() {
    _activeTimeoutTimer?.cancel();
    _activeTimeoutTimer = null;
    _generation++;
    _disposed = true;
    super.dispose();
  }
}

extension on AiGenerationPhase {
  bool get isActivePhase => switch (this) {
    AiGenerationPhase.preparing ||
    AiGenerationPhase.uploading ||
    AiGenerationPhase.analyzing ||
    AiGenerationPhase.generating ||
    AiGenerationPhase.retrying => true,
    _ => false,
  };
}
