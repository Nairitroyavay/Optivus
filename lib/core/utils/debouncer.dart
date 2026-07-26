import 'dart:async';

/// Generic timer-based debouncer that delays execution of actions until a quiet period has elapsed.
/// Supports cancellation, checking pending status, and immediate flushing of pending actions.
class Debouncer {
  final Duration delay;
  Timer? _timer;
  Future<void> Function()? _pendingAction;

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  /// Indicates whether a debounced action is currently scheduled.
  bool get isPending => _timer?.isActive ?? false;

  /// Schedules [action] to run after [delay]. Any previously scheduled action is cancelled.
  void run(Future<void> Function() action) {
    cancel();
    _pendingAction = action;
    _timer = Timer(delay, () async {
      final task = _pendingAction;
      _pendingAction = null;
      _timer = null;
      if (task != null) {
        await task();
      }
    });
  }

  /// Immediately executes the pending action if scheduled, cancelling the delay timer.
  Future<void> flush() async {
    if (_timer != null || _pendingAction != null) {
      _timer?.cancel();
      _timer = null;
      final task = _pendingAction;
      _pendingAction = null;
      if (task != null) {
        await task();
      }
    }
  }

  /// Cancels any pending scheduled action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
  }

  /// Disposes resources held by this debouncer.
  void dispose() {
    cancel();
  }
}
