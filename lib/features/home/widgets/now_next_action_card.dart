import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';

class NowNextActionCard extends StatelessWidget {
  final NowNextActionState? actionState;

  const NowNextActionCard({super.key, this.actionState});

  @override
  Widget build(BuildContext context) {
    if (actionState == null) return const SizedBox.shrink();

    final isMissed = actionState!.currentType == NowActionType.missedTask;
    final isHardBlock =
        actionState!.currentType == NowActionType.hardBlock ||
        actionState!.currentType == NowActionType.workBlock;

    const cardColor = Color(0xFFFBF6F6);
    const pillBgColor = Color(0xFFFAF0D7);
    const pillBorderColor = Color(0xFFF1E4C3);
    const pillTextColor = Color(0xFF6B5824);
    const titleColor = Color(0xFF322F2E);
    const subtitleColor = Color(0xFF86807D);
    const btnColor = Color(0xFFE2B814);
    const btnTextColor = Color(0xFF534304);
    const dividerColor = Color(0xFFEDE4E1);
    const circleBtnColor = Color(0xFFF4ECEC);
    const nextLabelColor = Color(0xFFA59E9A);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMissed ? OptivusColors.danger.withValues(alpha: 0.1) : pillBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isMissed ? OptivusColors.danger.withValues(alpha: 0.3) : pillBorderColor),
                      ),
                      child: Text(
                        isMissed ? 'MISSED' : 'NOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isMissed ? OptivusColors.danger : pillTextColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      actionState!.currentTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMissed && actionState!.missedTaskTime != null
                          ? 'Was planned at ${actionState!.missedTaskTime}'
                          : actionState!.currentSubtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isHardBlock && !isMissed)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: btnColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      foregroundColor: btnTextColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Start',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          if (isMissed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    child: const Text('Do tiny version'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {}, 
                  child: const Text('Skip', style: TextStyle(color: OptivusColors.textSecondary)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: dividerColor, height: 1, thickness: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: circleBtnColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actionState!.currentType == NowActionType.freeTime
                        ? 'NEXT SMALL WIN'
                        : 'NEXT FREE ACTION',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: nextLabelColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actionState!.nextActionTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
