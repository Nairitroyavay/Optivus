import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/utils/platform_channel_boundary.dart';

/// Recovers notification click intent extras and deep link payloads when the app is launched from a terminated/background state on Android.
class NotificationIntentService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.nairitroy.optivus/notification_intent',
  );

  final MethodChannel channel;

  const NotificationIntentService({MethodChannel? channel})
    : channel = channel ?? _defaultChannel;

  /// Fetches initial notification payload if app was launched via a notification click or deep link intent.
  Future<Map<String, String>?> getInitialNotificationPayload() async {
    return safePlatformCall<Map<String, String>?>(
      call: () async {
        final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
          'getInitialNotificationPayload',
        );
        if (result == null) return null;
        return result.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      },
      fallback: null,
      operationName: 'getInitialNotificationPayload',
    );
  }

  /// Clears the initial notification payload after consumption.
  Future<void> clearInitialNotificationPayload() async {
    return safePlatformCall<void>(
      call: () async {
        await channel.invokeMethod<void>('clearInitialNotificationPayload');
      },
      fallback: null,
      operationName: 'clearInitialNotificationPayload',
    );
  }
}

final notificationIntentServiceProvider = Provider<NotificationIntentService>((
  ref,
) {
  return const NotificationIntentService();
});
