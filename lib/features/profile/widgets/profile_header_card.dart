import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/features/profile/widgets/profile_status_chip.dart';

class ProfileHeaderCard extends StatelessWidget {
  final UserProfile profile;
  final String? usernameLabel;
  final VoidCallback? onEditTap;

  const ProfileHeaderCard({
    super.key,
    required this.profile,
    this.usernameLabel,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final safeUsername = usernameLabel?.trim().isNotEmpty == true
        ? usernameLabel!.trim()
        : 'Set username';

    return LiquidGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: OptivusColors.profileAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'YOUR PROFILE',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 10,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Column
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: OptivusColors.profileAccent.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      gradient: const LinearGradient(
                        colors: [
                          OptivusColors.profileTop,
                          OptivusColors.profileAccent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Manage photo in Edit Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.textSecondary.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Identity details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName
                          : 'Profile',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      safeUsername,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Life OS Status: ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OptivusColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        ProfileStatusChip(
                          label: 'Active',
                          type: ProfileStatusType.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onEditTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.profileAccent.withValues(
                alpha: 0.1,
              ),
              foregroundColor: OptivusColors.profileAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: OptivusColors.profileAccent.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
