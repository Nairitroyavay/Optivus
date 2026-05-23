import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/widgets/glass_logo.dart';

/// Shown while resolving the user's Auth and Firestore status.
/// Prevents premature redirects and gives a polished first-launch experience.
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Simple automatic navigation check:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // TODO: Connect real Firebase Auth check later:
      // FirebaseAuth.instance.authStateChanges().first.then((user) { ... });
      
      // Simulate checking mock session/state briefly for splash feeling
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          // Go to home, let the GoRouter redirect logic handle the actual destination
          context.go('/');
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const Spacer(flex: 2),

              // Pulsing glass logo
              ScaleTransition(
                scale: _pulse,
                child: const GlassLogo(),
              ),
              const SizedBox(height: 28),

              // App name
              const Text(
                'Optivus',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F111A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),

              // Yellow accent divider
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD426),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Tagline
              Text(
                'PLAN. EXECUTE. BECOME.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade700,
                  letterSpacing: 2.5,
                ),
              ),

              const Spacer(flex: 2),

              // Animated loading dots
              _LoadingDots(controller: _controller),
              const SizedBox(height: 48),
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
        final animation = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.25, end: 1.0)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.25)
                .chain(CurveTween(curve: Curves.easeOut)),
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
