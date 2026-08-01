import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToastType { error, warning, info, success }

class ToastItem {
  final String id;
  final String message;
  final ToastType type;
  final Duration duration;

  ToastItem({
    required this.id,
    required this.message,
    this.type = ToastType.error,
    this.duration = const Duration(seconds: 3),
  });
}

class ToastQueueState {
  final ToastItem? current;
  final List<ToastItem> queue;

  const ToastQueueState({this.current, this.queue = const []});
}

class ToastQueueNotifier extends StateNotifier<ToastQueueState> {
  Timer? _timer;

  ToastQueueNotifier() : super(const ToastQueueState());

  void showToast(
    String message, {
    ToastType type = ToastType.error,
    Duration? duration,
  }) {
    if (message.isEmpty) return;
    if (state.current?.message == message) return;
    if (state.queue.any((item) => item.message == message)) return;

    final item = ToastItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      type: type,
      duration: duration ?? const Duration(seconds: 3),
    );

    if (state.current == null) {
      _displayToast(item);
    } else {
      state = ToastQueueState(
        current: state.current,
        queue: [...state.queue, item],
      );
    }
  }

  void _displayToast(ToastItem item) {
    state = ToastQueueState(current: item, queue: state.queue);
    _timer?.cancel();
    _timer = Timer(item.duration, () => dismissCurrent());
  }

  void dismissCurrent() {
    _timer?.cancel();
    if (state.queue.isNotEmpty) {
      final next = state.queue.first;
      final remaining = state.queue.sublist(1);
      state = ToastQueueState(current: null, queue: remaining);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _displayToast(next);
      });
    } else {
      state = const ToastQueueState(current: null, queue: []);
    }
  }

  void clearAll() {
    _timer?.cancel();
    state = const ToastQueueState(current: null, queue: []);
  }

  void resetForSignedOut() => clearAll();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final toastQueueProvider =
    StateNotifierProvider<ToastQueueNotifier, ToastQueueState>(
      (ref) => ToastQueueNotifier(),
    );
