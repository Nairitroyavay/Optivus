import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps native platform channel calls (iOS/Android) in a typed async error boundary.
/// Safely catches [MissingPluginException], [PlatformException], and unexpected errors,
/// logging diagnostic output and returning [fallback].
Future<T> safePlatformCall<T>({
  required Future<T> Function() call,
  required T fallback,
  String? operationName,
  void Function(Object error, StackTrace stackTrace)? onError,
}) async {
  try {
    return await call();
  } on MissingPluginException catch (e, st) {
    debugPrint(
      '[PlatformChannelBoundary] MissingPluginException in ${operationName ?? "call"}: $e',
    );
    onError?.call(e, st);
    return fallback;
  } on PlatformException catch (e, st) {
    debugPrint(
      '[PlatformChannelBoundary] PlatformException in ${operationName ?? "call"}: [${e.code}] ${e.message}',
    );
    onError?.call(e, st);
    return fallback;
  } catch (e, st) {
    debugPrint(
      '[PlatformChannelBoundary] Unexpected error in ${operationName ?? "call"}: $e',
    );
    onError?.call(e, st);
    return fallback;
  }
}
