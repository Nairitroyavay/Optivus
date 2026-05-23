import 'package:flutter/material.dart';

import 'package:optivus/core/theme/optivus_colors.dart';

/// Mock permission card with connect/disconnect toggle.
/// Shows status badge with colored indicator.
class PermissionStatusCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String status; // 'Not connected', 'Mock connected', 'Coming later'
  final VoidCallback? onTap;

  const PermissionStatusCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.onTap,
  });

  bool get _isConnected => status == 'Mock connected';
  bool get _isComingLater => status == 'Coming later';

  Color get _statusColor {
    if (_isConnected) return OptivusColors.success;
    if (_isComingLater) return OptivusColors.pending;
    return OptivusColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: _isConnected
            ? OptivusColors.success.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.7),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 22, color: _statusColor),
                ),
                const SizedBox(width: 14),
                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isConnected ? OptivusColors.success : Colors.white,
                    border: Border.all(
                      color: _isConnected
                          ? OptivusColors.success
                          : OptivusColors.borderSoft,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isConnected ? 'Connected' : (_isComingLater ? 'Later' : 'Connect'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isConnected
                          ? Colors.white
                          : OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
