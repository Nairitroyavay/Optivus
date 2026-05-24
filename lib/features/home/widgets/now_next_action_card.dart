import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'home_glass_widgets.dart';

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

    const pillBgColor = Color(0xFFFAF0D7);
    const pillBorderColor = Color(0xFFF1E4C3);
    const pillTextColor = Color(0xFF6B5824);
    const titleColor = Color(0xFF322F2E);
    const subtitleColor = Color(0xFF86807D);
    const dividerColor = Color(0xFFEDE4E1);
    const circleBtnColor = Color(0xFFF4ECEC);
    const nextLabelColor = Color(0xFFA59E9A);

    return HomeGlassCard(
      padding: const EdgeInsets.all(16),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMissed && actionState!.missedTaskTime != null
                          ? 'Was planned at ${actionState!.missedTaskTime}'
                          : actionState!.currentSubtitle,
                      style: const TextStyle(
                        fontSize: 14,
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
                  child: HomeActionPill(
                    label: 'Start',
                    compact: true,
                    selected: true,
                    onTap: () {},
                  ),
                ),
            ],
          ),
          if (isMissed) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: HomeActionPill(
                    label: 'Do tiny version',
                    compact: true,
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 8),
                HomeActionPill(
                  label: 'Skip',
                  compact: true,
                  onTap: () {},
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: dividerColor, height: 1, thickness: 1),
          const SizedBox(height: 12),
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
