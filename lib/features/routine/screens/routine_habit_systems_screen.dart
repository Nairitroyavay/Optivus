import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/controllers/habit_systems_controller.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/habit_system_record.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/auth_state.dart';

class RoutineHabitSystemsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const RoutineHabitSystemsScreen({super.key, required this.onBack});

  @override
  ConsumerState<RoutineHabitSystemsScreen> createState() =>
      _RoutineHabitSystemsScreenState();
}

class _RoutineHabitSystemsScreenState
    extends ConsumerState<RoutineHabitSystemsScreen> {
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final currentUser = ref.read(authProvider).user;
      final uid = currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        if (ref.read(habitSystemsNotifierProvider).systems.isEmpty) {
          ref.read(habitSystemsNotifierProvider.notifier).loadForOwner(uid);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitState = ref.watch(habitSystemsNotifierProvider);
    final routineItems = ref.watch(routineNotifierProvider).items;
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return LiquidDetailScaffold(
        eyebrow: 'Routine',
        title: 'Habit Systems',
        subtitle: 'Loading your habit systems...',
        accentColor: OptivusColors.routineAccent,
        onBack: widget.onBack,
        children: const [
          LiquidDetailSection(
            title: 'Loading...',
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            ],
          )
        ],
      );
    }

    final user = auth.user;
    if (user == null || user.uid.isEmpty) {
      return LiquidDetailScaffold(
        eyebrow: 'Routine',
        title: 'Habit Systems',
        subtitle: 'Sign in to manage your habit systems.',
        accentColor: OptivusColors.routineAccent,
        onBack: widget.onBack,
        children: const [
          LiquidDetailSection(
            title: 'Authentication Required',
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('You must be signed in to view and manage Habit Systems.'),
              )
            ],
          )
        ],
      );
    }

    final uid = user.uid;

    final activeSystems = habitState.activeSystems;
    final pausedSystems = habitState.pausedSystems;
    final archivedSystems = habitState.archivedSystems;

    final goodHabits = activeSystems
        .where((s) => s.systemType == HabitSystemType.goodHabit)
        .toList();
    final badHabits = activeSystems
        .where((s) => s.systemType == HabitSystemType.badHabit)
        .toList();
    final identities = activeSystems
        .where((s) => s.systemType == HabitSystemType.identity)
        .toList();

    final overload = activeSystems.length;

    return LiquidDetailScaffold(
      eyebrow: 'Routine',
      title: 'Habit Systems',
      subtitle:
          'Persistent good habits, bad habits, identity systems, and linked routines.',
      accentColor: OptivusColors.routineAccent,
      onBack: widget.onBack,
      children: [
        if (habitState.error != null)
          LiquidDetailSection(
            title: 'Error',
            tint: OptivusColors.danger.withValues(alpha: 0.12),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: OptivusColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      habitState.error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OptivusColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: habitState.loading || habitState.saving
                        ? null
                        : () => ref
                              .read(habitSystemsNotifierProvider.notifier)
                              .loadForOwner(uid),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        if (habitState.failedOperations.isNotEmpty)
          LiquidDetailSection(
            title: 'Failed Operations',
            tint: OptivusColors.danger.withValues(alpha: 0.12),
            children: habitState.failedOperations.values.map((failedOp) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: OptivusColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Failed to ${failedOp.type.name}: ${failedOp.userMessage}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: OptivusColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (habitState.pendingOperationKeys.contains(failedOp.operationId))
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      TextButton(
                        onPressed: () => ref
                            .read(habitSystemsNotifierProvider.notifier)
                            .retryOperation(failedOp.operationId),
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        LiquidDetailSection(
          title: 'System Management',
          children: [
            LiquidActionRow(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create New Habit System',
              subtitle:
                  'Build a new good habit, bad habit, or identity system.',
              accentColor: OptivusColors.routineAccent,
              onTap: habitState.saving
                  ? null
                  : () => _showCreateSystemSheet(context, ref, uid),
            ),
            LiquidActionRow(
              icon: Icons.archive_outlined,
              title: _showArchived
                  ? 'Hide Archived Systems'
                  : 'Show Archived Systems',
              subtitle: '${archivedSystems.length} archived systems in store.',
              accentColor: OptivusColors.textSecondary,
              onTap: () => setState(() => _showArchived = !_showArchived),
            ),
          ],
        ),
        if (habitState.loading)
          const LiquidDetailSection(
            title: 'Loading Systems...',
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          )
        else ...[
          _RealSystemSection(
            title: 'Good Habits',
            systems: goodHabits,
            emptyMessage:
                'No active Good Habit systems. Create one to get started.',
            routineItems: routineItems,
            onTapSystem: (system) =>
                _showSystemActionSheet(context, ref, system, routineItems),
          ),
          _RealSystemSection(
            title: 'Bad Habits',
            systems: badHabits,
            emptyMessage: 'No active Bad Habit check-in systems configured.',
            routineItems: routineItems,
            onTapSystem: (system) =>
                _showSystemActionSheet(context, ref, system, routineItems),
          ),
          _RealSystemSection(
            title: 'Identity Goal Systems',
            systems: identities,
            emptyMessage: 'No active Identity Goal systems configured.',
            routineItems: routineItems,
            onTapSystem: (system) =>
                _showSystemActionSheet(context, ref, system, routineItems),
          ),
          if (pausedSystems.isNotEmpty)
            _RealSystemSection(
              title: 'Paused Systems (${pausedSystems.length})',
              systems: pausedSystems,
              emptyMessage: '',
              routineItems: routineItems,
              isPausedSection: true,
              onTapSystem: (system) =>
                  _showSystemActionSheet(context, ref, system, routineItems),
            ),
          if (_showArchived && archivedSystems.isNotEmpty)
            _RealSystemSection(
              title: 'Archived Systems (${archivedSystems.length})',
              systems: archivedSystems,
              emptyMessage: '',
              routineItems: routineItems,
              isArchivedSection: true,
              onTapSystem: (system) =>
                  _showSystemActionSheet(context, ref, system, routineItems),
            ),
        ],
        LiquidDetailSection(
          title: 'System Capacity Guardrail',
          tint: overload > 5
              ? OptivusColors.warning.withValues(alpha: 0.08)
              : null,
          children: [
            Text(
              overload > 5
                  ? 'High system load: $overload active systems are currently active. Consider pausing or archiving inactive systems.'
                  : 'System load nominal: $overload active habit systems are currently managed.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: overload > 5
                    ? OptivusColors.warning
                    : OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Phase Boundaries',
          children: [
            LiquidActionRow(
              icon: Icons.flag_outlined,
              title: 'Goal Proofs & Streaks (Phase 5)',
              subtitle:
                  'Goal identity tracking and proof validation is Phase 5.',
              accentColor: OptivusColors.textSecondary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Goal proofs and automated streaks are Phase 5 features and currently unavailable.',
                    ),
                  ),
                );
              },
            ),
            LiquidActionRow(
              icon: Icons.track_changes_rounded,
              title: 'Open Tracker',
              subtitle: 'Tracker owns progress sessions and check-ins.',
              accentColor: OptivusColors.trackerAccent,
              onTap: () =>
                  ref.read(appNavigationProvider.notifier).goToTracker(),
            ),
          ],
        ),
      ],
    );
  }

  void _showCreateSystemSheet(BuildContext context, WidgetRef ref, String uid) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    RoutineCategory selectedCategory = RoutineCategory.habit;
    HabitSystemType selectedType = HabitSystemType.goodHabit;
    bool isSaving = false;
    String? errorMsg;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final media = MediaQuery.of(context);
            return Container(
              margin: const EdgeInsets.all(16),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + media.viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Habit System',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Daily Meditation System',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g. 10m morning mindfulness',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<HabitSystemType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'System Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: HabitSystemType.goodHabit,
                          child: Text('Good Habit System'),
                        ),
                        DropdownMenuItem(
                          value: HabitSystemType.badHabit,
                          child: Text('Bad Habit Check-in System'),
                        ),
                        DropdownMenuItem(
                          value: HabitSystemType.identity,
                          child: Text('Identity Goal System'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateModal(() {
                            selectedType = val;
                            if (val == HabitSystemType.goodHabit) {
                              selectedCategory = RoutineCategory.habit;
                            } else if (val == HabitSystemType.badHabit) {
                              selectedCategory = RoutineCategory.badHabit;
                            } else {
                              selectedCategory = RoutineCategory.identity;
                            }
                          });
                        }
                      },
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMsg!,
                        style: const TextStyle(color: OptivusColors.danger, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;
                            
                            setStateModal(() {
                              isSaving = true;
                              errorMsg = null;
                            });

                            final success = await ref
                                .read(habitSystemsNotifierProvider.notifier)
                                .createSystem(
                                  title: title,
                                  description: descController.text.trim(),
                                  category: selectedCategory,
                                  systemType: selectedType,
                                );
                            
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            } else if (context.mounted) {
                              setStateModal(() {
                                isSaving = false;
                                errorMsg = ref.read(habitSystemsNotifierProvider).error ?? 'Failed to create system. Please try again.';
                              });
                            }
                          },
                          child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSystemActionSheet(
    BuildContext context,
    WidgetRef ref,
    HabitSystemRecord system,
    List<RoutineItem> routineItems,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final linkedRoutines = routineItems
            .where((r) => system.linkedRoutineIds.contains(r.id))
            .toList();

        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + media.padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  system.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                if (system.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    system.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (linkedRoutines.isNotEmpty) ...[
                  const Text(
                    'Linked Routines:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: linkedRoutines
                        .map(
                          (r) => Chip(
                            label: Text(
                              r.title,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: OptivusColors.routineAccent
                                .withValues(alpha: 0.12),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                _SheetAction(
                  label: system.isPaused ? 'Resume system' : 'Pause system',
                  icon: system.isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final notifier = ref.read(habitSystemsNotifierProvider.notifier);
                    final success = system.isPaused
                        ? await notifier.resumeSystem(system.systemId)
                        : await notifier.pauseSystem(system.systemId);
                    
                    if (!success && context.mounted) {
                      final errorMsg = ref.read(habitSystemsNotifierProvider).error ?? 'Operation failed';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
                    }
                  },
                ),
                _SheetAction(
                  label: 'Manage Linked Routines',
                  icon: Icons.link_rounded,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showManageRoutinesSheet(
                      context,
                      ref,
                      system,
                      routineItems,
                    );
                  },
                ),
                _SheetAction(
                  label: system.isArchived
                      ? 'Restore system'
                      : 'Archive system',
                  icon: system.isArchived
                      ? Icons.unarchive_rounded
                      : Icons.archive_rounded,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final notifier = ref.read(habitSystemsNotifierProvider.notifier);
                    final success = system.isArchived
                        ? await notifier.restoreSystem(system.systemId)
                        : await notifier.archiveSystem(system.systemId);
                    
                    if (!success && context.mounted) {
                      final errorMsg = ref.read(habitSystemsNotifierProvider).error ?? 'Operation failed';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
                    }
                  },
                ),
                _SheetAction(
                  label: 'Delete system',
                  icon: Icons.delete_outline_rounded,
                  textColor: OptivusColors.danger,
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDelete(context, ref, system);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManageRoutinesSheet(
    BuildContext context,
    WidgetRef ref,
    HabitSystemRecord system,
    List<RoutineItem> routineItems,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final currentLinked = Set<String>.from(system.linkedRoutineIds);
            final media = MediaQuery.of(context);

            return Container(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link Routines: ${system.title}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (routineItems.isEmpty)
                    const Text(
                      'No routines available to link.',
                      style: TextStyle(color: OptivusColors.textSecondary),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: routineItems.length,
                        itemBuilder: (context, index) {
                          final routine = routineItems[index];
                          final isLinked = currentLinked.contains(routine.id);
                          return Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              title: Text(routine.title),
                              subtitle: Text(routine.blockTypeLabel),
                              value: isLinked,
                              onChanged: (checked) {
                                setStateModal(() {
                                  if (checked == true) {
                                    currentLinked.add(routine.id);
                                    ref
                                        .read(
                                          habitSystemsNotifierProvider.notifier,
                                        )
                                        .linkRoutine(
                                          system.systemId,
                                          routine.id,
                                        );
                                  } else {
                                    currentLinked.remove(routine.id);
                                    ref
                                        .read(
                                          habitSystemsNotifierProvider.notifier,
                                        )
                                        .unlinkRoutine(
                                          system.systemId,
                                          routine.id,
                                        );
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HabitSystemRecord system,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Habit System?'),
          content: Text(
            'Are you sure you want to delete "${system.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.danger,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await ref
                    .read(habitSystemsNotifierProvider.notifier)
                    .deleteSystem(system.systemId);
                
                if (!success && context.mounted) {
                  final errorMsg = ref.read(habitSystemsNotifierProvider).error ?? 'Failed to delete system';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _RealSystemSection extends StatelessWidget {
  final String title;
  final List<HabitSystemRecord> systems;
  final String emptyMessage;
  final List<RoutineItem> routineItems;
  final bool isPausedSection;
  final bool isArchivedSection;
  final ValueChanged<HabitSystemRecord> onTapSystem;

  const _RealSystemSection({
    required this.title,
    required this.systems,
    required this.emptyMessage,
    required this.routineItems,
    this.isPausedSection = false,
    this.isArchivedSection = false,
    required this.onTapSystem,
  });

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty && emptyMessage.isEmpty) {
      return const SizedBox.shrink();
    }

    if (systems.isEmpty) {
      return LiquidDetailSection(
        title: title,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 13,
                color: OptivusColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return LiquidDetailSection(
      title: title,
      children: systems.map((system) {
        final count = system.linkedRoutineIds.length;
        final sub = count == 0
            ? (system.description.isNotEmpty
                  ? system.description
                  : 'No routines linked')
            : '$count linked routine${count == 1 ? '' : 's'} · ${system.description}';

        return LiquidActionRow(
          icon: _iconFor(system),
          title: system.title,
          subtitle: sub,
          accentColor: _colorFor(system),
          onTap: () => onTapSystem(system),
        );
      }).toList(),
    );
  }

  IconData _iconFor(HabitSystemRecord system) {
    if (isPausedSection) return Icons.pause_circle_outline_rounded;
    if (isArchivedSection) return Icons.archive_outlined;
    return switch (system.category) {
      RoutineCategory.badHabit => Icons.smoke_free_outlined,
      RoutineCategory.identity => Icons.flag_outlined,
      RoutineCategory.finance => Icons.savings_outlined,
      RoutineCategory.meditation => Icons.self_improvement_rounded,
      _ => Icons.auto_awesome_motion_rounded,
    };
  }

  Color _colorFor(HabitSystemRecord system) {
    if (isPausedSection || isArchivedSection) {
      return OptivusColors.textSecondary;
    }
    return switch (system.category) {
      RoutineCategory.badHabit => OptivusColors.danger,
      RoutineCategory.identity => OptivusColors.goalsAccent,
      RoutineCategory.finance => OptivusColors.mintAccent,
      RoutineCategory.meditation => OptivusColors.purpleAccent,
      _ => OptivusColors.routineAccent,
    };
  }
}

class _SheetAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color textColor;
  final VoidCallback onTap;

  const _SheetAction({
    required this.label,
    required this.icon,
    this.textColor = OptivusColors.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
