import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SkinCareSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const SkinCareSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SkinCareSetupScreen> createState() =>
      _SkinCareSetupScreenState();
}

class _SkinCareSetupScreenState extends ConsumerState<SkinCareSetupScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Skin Care Setup - Work in Progress'),
      ),
    );
  }
}
