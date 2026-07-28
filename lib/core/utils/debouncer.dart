import 'dart:async';

/// Generic timer-based debouncer that delays execution of actions until a quiet period has elapsed.
/// Supports cancellation, checking pending status, and immediate flushing of pending actions.
class Debouncer {
  final Duration delay;
  Timer? _timer;
  Future<void> Function()? _pendingAction;
  final List<Completer<void>> _completers = [];

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  /// Indicates whether a debounced action is currently scheduled.
  bool get isPending => _timer?.isActive ?? false;

  /// Schedules [action] to run after [delay]. Any previously scheduled action is cancelled.
  Future<void> run(Future<void> Function() action) {
    _timer?.cancel();
    _pendingAction = action;
    final completer = Completer<void>();
    _completers.add(completer);

    _timer = Timer(delay, () async {
      await flush();
    });

    return completer.future;
  }

  /// Immediately executes the pending action if scheduled, cancelling the delay timer.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final task = _pendingAction;
    final activeCompleters = List<Completer<void>>.from(_completers);
    _pendingAction = null;
    _completers.clear();

    if (task != null) {
      try {
        await task();
        for (final c in activeCompleters) {
          if (!c.isCompleted) c.complete();
        }
      } catch (e, st) {
        for (final c in activeCompleters) {
          if (!c.isCompleted) c.completeError(e, st);
        }
      }
    } else {
      for (final c in activeCompleters) {
        if (!c.isCompleted) c.complete();
      }
    }
  }

  /// Cancels any pending scheduled action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
    for (final c in _completers) {
      if (!c.isCompleted) c.complete();
    }
    _completers.clear();
  }

  /// Disposes resources held by this debouncer.
  void dispose() {
    cancel();
  }
}
