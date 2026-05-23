import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/mind_note.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/widgets/animated_bot_avatar.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final TextEditingController _thoughtController = TextEditingController();
  MindNoteType _selectedType = MindNoteType.overthinking;
  MindNoteIntensity _selectedIntensity = MindNoteIntensity.medium;

  @override
  void dispose() {
    _thoughtController.dispose();
    super.dispose();
  }

  String _getTimeGreeting(String name) {
    final hour = DateTime.now().hour;
    final displayName = name.isNotEmpty ? name : 'Roy';
    if (hour < 12) {
      return 'Good morning, $displayName';
    } else if (hour < 17) {
      return 'Good afternoon, $displayName';
    } else {
      return 'Good evening, $displayName';
    }
  }

  String _formatMinute(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(mockUserProfileProvider);
    final routineItems = ref.watch(mockRoutineProvider);
    final mindNotes = ref.watch(mockMindNoteProvider);

    // Calculate completed vs pending tasks for Daily Mission
    final totalTasks = routineItems.length;
    final completedTasks = routineItems.where((item) => item.isCompleted).length;
    final completionRatio = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    // Scan for Now vs Next routine blocks based on current time
    final now = DateTime.now();
    final currentMinuteOfDay = now.hour * 60 + now.minute;

    RoutineItem? nowItem;
    RoutineItem? nextItem;

    for (final item in routineItems) {
      if (currentMinuteOfDay >= item.startMinute && currentMinuteOfDay < item.endMinute) {
        nowItem = item;
      }
    }

    // If no specific overlapping item is active, get the closest future one
    List<RoutineItem> sortedItems = List.from(routineItems)
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    for (final item in sortedItems) {
      if (item.startMinute > currentMinuteOfDay) {
        nextItem = item;
        break;
      }
    }
    // Fallback if none are in future, get the first one of next day
    if (nextItem == null && sortedItems.isNotEmpty) {
      nextItem = sortedItems.first;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120), // Bottom padding for floating tabbar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. GREETING & STATUS SUB-CARD
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTimeGreeting(profile.displayName),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bio-Schedule Sync: 98% Optimal',
                      style: TextStyle(
                        fontSize: 13,
                        color: OptivusColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 48,
                height: 48,
                child: AnimatedBotAvatar(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. NOW / NEXT TIMELINE HUB
          Text(
            'LIVE COMMAND CENTER',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: OptivusColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Now Card
              Expanded(
                child: _buildNowNextCard(
                  context: context,
                  label: 'ACTIVE NOW',
                  item: nowItem,
                  fallbackTitle: 'Flexible Sandbox Time',
                  fallbackDesc: 'No scheduled routine block right now.',
                  iconColor: OptivusColors.brandAccent,
                  isNow: true,
                ),
              ),
              const SizedBox(width: 12),
              // Next Card
              Expanded(
                child: _buildNowNextCard(
                  context: context,
                  label: 'UP NEXT',
                  item: nextItem,
                  fallbackTitle: 'Schedule End',
                  fallbackDesc: 'No upcoming routine blocks.',
                  iconColor: OptivusColors.aquaAccent,
                  isNow: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. DAILY MISSION INDICATOR CARD
          LiquidGlassPanel(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: completionRatio,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(OptivusColors.brandAccent),
                      ),
                    ),
                    Text(
                      '${(completionRatio * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Habit Progress',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completedTasks of $totalTasks routine blocks completed.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: OptivusColors.textBody,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4. MIND NOTEBOOK COMPOSER
          Text(
            'MIND NOTEBOOK & COGNITIVE SHELF',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: OptivusColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          LiquidGlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Offload Mental Clutter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Write down details, tasks, or worries immediately to free cognitive RAM.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _thoughtController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Type your raw thought/distraction here...',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: OptivusColors.borderSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: OptivusColors.brandAccent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Type selector
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OptivusColors.borderSoft),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MindNoteType>(
                            value: _selectedType,
                            icon: const Icon(Icons.arrow_drop_down, color: OptivusColors.textPrimary),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.textPrimary, fontSize: 13),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedType = val);
                            },
                            items: MindNoteType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.name.toUpperCase()),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Intensity selector
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OptivusColors.borderSoft),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MindNoteIntensity>(
                            value: _selectedIntensity,
                            icon: const Icon(Icons.arrow_drop_down, color: OptivusColors.textPrimary),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.textPrimary, fontSize: 13),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedIntensity = val);
                            },
                            items: MindNoteIntensity.values.map((intensity) {
                              return DropdownMenuItem(
                                value: intensity,
                                child: Text(intensity.name.toUpperCase()),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OptivusColors.brandAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final text = _thoughtController.text.trim();
                    if (text.isEmpty) return;
                    ref.read(mockMindNoteProvider.notifier).addMindNote(
                          text,
                          _selectedType,
                          _selectedIntensity,
                        );
                    _thoughtController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thought shelved in chronological Mind Timeline.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Shelf Thought', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 5. MIND TIMELINE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHRONOLOGICAL MIND TIMELINE',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: OptivusColors.textSecondary,
                    ),
              ),
              if (mindNotes.isNotEmpty)
                Text(
                  '${mindNotes.length} Note${mindNotes.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OptivusColors.textSecondary),
                )
            ],
          ),
          const SizedBox(height: 12),

          if (mindNotes.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.bubble_chart, color: OptivusColors.textSecondary, size: 36),
                  SizedBox(height: 10),
                  Text(
                    'Your cognitive shelf is empty.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.textSecondary, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dump thoughts above to clean your focus.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: OptivusColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              itemCount: mindNotes.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final note = mindNotes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildMindNoteCard(context, note),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNowNextCard({
    required BuildContext context,
    required String label,
    required RoutineItem? item,
    required String fallbackTitle,
    required String fallbackDesc,
    required Color iconColor,
    required bool isNow,
  }) {
    final title = item?.title ?? fallbackTitle;
    final subtitle = item != null
        ? '${_formatMinute(item.startMinute)} - ${_formatMinute(item.endMinute)}'
        : fallbackDesc;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNow ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNow ? OptivusColors.brandAccent.withValues(alpha: 0.4) : Colors.white,
          width: 1.5,
        ),
        boxShadow: isNow
            ? [
                BoxShadow(
                  color: OptivusColors.brandAccent.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: iconColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMindNoteCard(BuildContext context, MindNote note) {
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.notes;

    switch (note.type) {
      case MindNoteType.idea:
        typeColor = const Color(0xFFFFB830);
        typeIcon = Icons.lightbulb_outline;
        break;
      case MindNoteType.decision:
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.check_circle_outline;
        break;
      case MindNoteType.overthinking:
        typeColor = const Color(0xFFEF4444);
        typeIcon = Icons.warning_amber;
        break;
      case MindNoteType.existential:
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.psychology;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.bubble_chart;
    }

    Color intensityColor = Colors.grey;
    switch (note.intensity) {
      case MindNoteIntensity.low:
        intensityColor = const Color(0xFF10B981);
        break;
      case MindNoteIntensity.medium:
        intensityColor = const Color(0xFFF59E0B);
        break;
      case MindNoteIntensity.high:
        intensityColor = const Color(0xFFEF4444);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(typeIcon, color: typeColor == const Color(0xFFDCCBFF) ? Colors.deepPurple : typeColor, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        note.type.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: typeColor == const Color(0xFFDCCBFF) ? Colors.deepPurple : typeColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      // Intensity chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: intensityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          note.intensity.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: intensityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    note.content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withValues(alpha: 0.4),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: OptivusColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    note.timestamp,
                    style: const TextStyle(fontSize: 10, color: OptivusColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Share with Coach button
                  InkWell(
                    onTap: () {
                      ref.read(mockMindNoteProvider.notifier).toggleShareWithCoach(note.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(note.isSharedWithCoach
                              ? 'Unshared with AI Coach.'
                              : 'Shared with AI Coach for timeline audits.'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            note.isSharedWithCoach ? Icons.cloud_done : Icons.cloud_upload_outlined,
                            size: 14,
                            color: note.isSharedWithCoach ? OptivusColors.success : OptivusColors.brandAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            note.isSharedWithCoach ? 'Shared' : 'Share with Coach',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: note.isSharedWithCoach ? OptivusColors.success : OptivusColors.brandAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: OptivusColors.danger),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ref.read(mockMindNoteProvider.notifier).deleteMindNote(note.id);
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
