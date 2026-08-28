import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/widgets/glass_logo.dart';

import 'package:optivus/core/utils/asset_precache_service.dart';

/// Shown while resolving the user's Auth and Firestore status.
/// Prevents premature redirects and gives a polished first-launch experience.
class LoadingScreen extends ConsumerStatefulWidget {
  final String? message;

  const LoadingScreen({super.key, this.message});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      SplashAssetCacheService.precacheSplashAssets(context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final message =
        widget.message ??
        (auth.isRestoringOnboarding
            ? 'Restoring your setup...'
            : 'Starting Optivus...');

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6E6B4), // Soft warm golden
              Color(0xFFFCF8EE), // Light cream
              Color(0xFFFFFFFF), // Pure white at bottom
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ScaleTransition(scale: _pulse, child: const GlassLogo()),
              const SizedBox(height: 30),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D6470),
                ),
              ),
              const SizedBox(height: 18),
              _LoadingDots(controller: _controller),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Three animated dots that stagger in opacity ─────────────────────────────
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final delay = i * 0.2;
        final animation =
            TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween<double>(
                  begin: 0.25,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeIn)),
                weight: 50,
              ),
              TweenSequenceItem(
                tween: Tween<double>(
                  begin: 1.0,
                  end: 0.25,
                ).chain(CurveTween(curve: Curves.easeOut)),
                weight: 50,
              ),
            ]).animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(
                  delay.clamp(0.0, 0.8),
                  (delay + 0.6).clamp(0.0, 1.0),
                ),
              ),
            );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Opacity(
              opacity: animation.value,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD426),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
