import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/optivus_app.dart';

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

  // Enable edge-to-edge mode (default app mode — not forced immersive hidden bars)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Frontend-only mode: no backend initialization
  debugPrint('Optivus frontend-only mode: backend disabled');

  runApp(const ProviderScope(child: OptivusApp()));
}
