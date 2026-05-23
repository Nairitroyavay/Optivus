import 'package:flutter/material.dart';

/// Wraps a Scaffold with the Optivus gradient background.
/// Use this instead of raw Scaffold for every screen inside the app shell.
class LiquidScreenScaffold extends StatelessWidget {
  final Widget child;
  final Color topColor;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final PreferredSizeWidget? appBar;

  const LiquidScreenScaffold({
    super.key,
    required this.child,
    required this.topColor,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, Colors.white, Colors.white],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        appBar: appBar,
        body: child,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
