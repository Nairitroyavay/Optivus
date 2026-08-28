import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/router/app_router.dart';
import 'package:optivus/core/theme/optivus_theme.dart';

/// Root application widget — configures theme, router, and global providers.
class OptivusApp extends ConsumerWidget {
  const OptivusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OptivusTheme.lightSystemUiOverlayStyle,
      child: MaterialApp.router(
        title: 'Optivus',
        debugShowCheckedModeBanner: false,
        theme: OptivusTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
