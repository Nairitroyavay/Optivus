import 'package:flutter/material.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'home_glass_widgets.dart';

class LifeOsSnapshot extends StatelessWidget {
  final List<LifeOsPillarProgress> pillars;

  const LifeOsSnapshot({super.key, required this.pillars});

  Color _getPillarColor(LifePillar pillar) {
    switch (pillar) {
      case LifePillar.body:
        return const Color(0xFFF7B1AB); // Light pink
      case LifePillar.mind:
        return const Color(0xFFD4BDB7); // Light taupe
      case LifePillar.workStudy:
        return const Color(0xFFE9C434); // Mustard yellow
      case LifePillar.finance:
        return const Color(0xFFD3CEB1); // Khaki green
      case LifePillar.focus:
        return const Color(0xFFDCDCE2); // Light grey/lavender
      case LifePillar.growth:
        return const Color(0xFF6B5319); // Dark olive/brown
      case LifePillar.skill:
        return const Color(0xFF8B5A2B); // Brownish
    }
  }

  String _formatPillarName(LifePillar pillar) {
    switch (pillar) {
      case LifePillar.body:
        return 'Body';
      case LifePillar.mind:
        return 'Mind';
      case LifePillar.workStudy:
        return 'Work Study';
      case LifePillar.finance:
        return 'Finance';
      case LifePillar.focus:
        return 'Focus';
      case LifePillar.growth:
        return 'Growth';
      case LifePillar.skill:
        return 'Skill';
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Life OS Snapshot',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A4A3D),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pillars.map((p) => _buildPillarChip(context, p)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarChip(BuildContext context, LifeOsPillarProgress progress) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            height: 200,
            color: Colors.white,
            alignment: Alignment.center,
            child: Text('${_formatPillarName(progress.pillar)} Detail Sheet (Demo)'),
          ),
        );
      },
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // pill shape
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getPillarColor(progress.pillar),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_formatPillarName(progress.pillar)} (${progress.current}/${progress.target})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    ));
  }
}
