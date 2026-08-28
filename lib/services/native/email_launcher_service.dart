import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/utils/platform_channel_boundary.dart';

abstract class EmailLauncherService {
  Future<bool> openEmailApp();
}

class MethodChannelEmailLauncherService implements EmailLauncherService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.nairitroy.optivus/email_launcher',
  );

  final MethodChannel channel;

  const MethodChannelEmailLauncherService({MethodChannel? channel})
    : channel = channel ?? _defaultChannel;

  @override
  Future<bool> openEmailApp() async {
    final result = await safePlatformCall<bool?>(
      call: () async {
        return await channel.invokeMethod<bool>('openEmailApp');
      },
      fallback: false,
      operationName: 'openEmailApp',
    );
    return result ?? false;
  }
}

final emailLauncherServiceProvider = Provider<EmailLauncherService>((ref) {
  return const MethodChannelEmailLauncherService();
});
