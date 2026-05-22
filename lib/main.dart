import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:optivus/config/firebase_options.dart';
import 'package:optivus/core/router/app_router.dart';

void main() async {
  // Ensure Flutter engine bindings are fully initialized before bootstrapping services
  WidgetsFlutterBinding.ensureInitialized();

  // Configure modern Android/iOS edge-to-edge UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Enable immersive full-screen edge-to-edge mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Firebase Core safely with platforms options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('🔴 Firebase initialization error: $e');
  }

  runApp(
    const ProviderScope(
      child: OptivusApp(),
    ),
  );
}

class OptivusApp extends ConsumerWidget {
  const OptivusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Optivus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB830),
          brightness: Brightness.light,
        ),
      ),
      routerConfig: router,
    );
  }
}
