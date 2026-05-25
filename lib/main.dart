import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/optivus_app.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/config/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Ensure Flutter engine bindings are fully initialized before bootstrapping services
  WidgetsFlutterBinding.ensureInitialized();

  // Configure modern Android/iOS edge-to-edge UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Enable true full screen (immersive mode, hides status and nav bars)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  if (OptivusBackendConfig.useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Optivus backend mode: Firebase initialized');
  } else {
    debugPrint('Optivus backend mode: fake frontend/dev mode');
  }

  runApp(const ProviderScope(child: OptivusApp()));
}
