import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/optivus_app.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/firebase_options.dart';
import 'package:optivus/config/runtime_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:optivus/app/configuration_failure_app.dart';

import 'package:optivus/core/utils/platform_channel_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await safePlatformCall(
    call: () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    fallback: null,
    operationName: 'setEnabledSystemUIMode',
  );

  runApp(await buildOptivusRoot());
}

typedef RuntimeValidator =
    void Function({required String generatedFirebaseProjectId});
typedef FirebaseInitializer = Future<void> Function(FirebaseOptions options);

/// Builds the only two legal startup roots: the app after a fully successful
/// bootstrap, or a deterministic safe failure UI. This boundary is injectable
/// so configuration and Firebase failures are widget-testable.
Future<Widget> buildOptivusRoot({
  bool? useFirebase,
  FirebaseOptions? firebaseOptions,
  RuntimeValidator? validateRuntime,
  FirebaseInitializer? initializeFirebase,
}) async {
  try {
    final shouldUseFirebase = useFirebase ?? OptivusBackendConfig.useFirebase;
    final resolvedOptions = shouldUseFirebase
        ? (firebaseOptions ?? DefaultFirebaseOptions.currentPlatform)
        : null;
    (validateRuntime ?? OptivusRuntimeConfig.validateForStartup)(
      generatedFirebaseProjectId: resolvedOptions?.projectId ?? '',
    );
    if (resolvedOptions != null) {
      await (initializeFirebase ??
          (options) =>
              Firebase.initializeApp(options: options))(resolvedOptions);
      debugPrint('Optivus backend mode: Firebase initialized');
    } else {
      debugPrint('Optivus backend mode: fake frontend/dev mode');
    }
    return const ProviderScope(child: OptivusApp());
  } catch (error) {
    debugPrint('Optivus startup failed safely (${error.runtimeType}).');
    return const ConfigurationFailureApp();
  }
}
