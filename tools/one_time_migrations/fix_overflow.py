"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/steps/base_timeline_step.dart'
with open(file_path, 'r') as f:
    content = f.read()

old_col = """                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: ["""

new_col = """                        Expanded(
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ["""

content = content.replace(old_col, new_col)

old_col_end = """                                ),
                              ],
                            ),
                          ),
                        ),"""

new_col_end = """                                ),
                              ],
                            ),
                          ),
                        ),
                        ),"""

# Wait, let's just do an exact block replace to avoid messing up braces

old_block = """                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: OptivusColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_timeLabel(item.startMinute ~/ 60)} - ${_timeLabel(_clampHour(item.endMinute ~/ 60, 0, 24))} | $dayLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: OptivusColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),"""

new_block = """                        Expanded(
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: OptivusColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_timeLabel(item.startMinute ~/ 60)} - ${_timeLabel(_clampHour(item.endMinute ~/ 60, 0, 24))} | $dayLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: OptivusColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),"""

content = content.replace(old_block, new_block)

with open(file_path, 'w') as f:
    f.write(content)

print('Done fixing overflow!')
