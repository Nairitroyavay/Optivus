import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class CoachQuickActions extends StatelessWidget {
  final List<String> quickReplies;
  final ValueChanged<String> onTap;

  const CoachQuickActions({
    super.key,
    required this.quickReplies,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: quickReplies.length,
        itemBuilder: (context, index) {
          final reply = quickReplies[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
            child: ActionChip(
              backgroundColor: OptivusColors.glassFill,
              side: const BorderSide(color: OptivusColors.glassBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              label: Text(
                reply,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.textPrimary,
                ),
              ),
              onPressed: () => onTap(reply),
            ),
          );
        },
      ),
    );
  }
}
