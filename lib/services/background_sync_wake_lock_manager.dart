import 'dart:async';
import 'package:flutter/foundation.dart';

/// Abstract contract for managing system wake locks and background process claims.
abstract class SystemWakeLock {
  Future<void> acquire({required String tag});
  Future<void> release({required String tag});
  bool isHeld(String tag);
}

/// Default implementation tracking active background wake lock claims.
class DefaultSystemWakeLock implements SystemWakeLock {
  final Set<String> _heldTags = <String>{};

  @override
  Future<void> acquire({required String tag}) async {
    _heldTags.add(tag);
    debugPrint('[SystemWakeLock] Acquired wake lock claim.');
  }

  @override
  Future<void> release({required String tag}) async {
    _heldTags.remove(tag);
    debugPrint('[SystemWakeLock] Released wake lock claim.');
  }

  @override
  bool isHeld(String tag) => _heldTags.contains(tag);
}

/// Wraps background sync operations with guaranteed system wake lock acquisition and release.
/// Enforces strict `try ... finally` semantics to ensure that the wake lock is unconditionally released
/// regardless of whether [syncTask] completes normally or throws an exception.
Future<T> runWithWakeLock<T>({
  required String tag,
  required SystemWakeLock wakeLock,
  required Future<T> Function() syncTask,
}) async {
  await wakeLock.acquire(tag: tag);
  try {
    return await syncTask();
  } finally {
    await wakeLock.release(tag: tag);
  }
}
