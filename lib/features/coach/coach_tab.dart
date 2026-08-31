import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/coach/screens/coach_flow_screens.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/features/coach/widgets/coach_message_bubble.dart';
import 'package:optivus/features/coach/widgets/coach_input_field.dart';
import 'package:optivus/features/coach/widgets/coach_quick_actions.dart';
import 'package:optivus/features/coach/widgets/coach_response_cards.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/widgets/animated_bot_avatar.dart';

class CoachTab extends ConsumerStatefulWidget {
  const CoachTab({super.key});

  @override
  ConsumerState<CoachTab> createState() => _CoachTabState();
}

class _CoachTabState extends ConsumerState<CoachTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  String _selectedSessionId = '';
  CoachDetailView _activeDetail = CoachDetailView.none;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String text) {
    if (!ref.read(fakeDataAllowedProvider)) return;
    if (text.trim().isEmpty) return;
    if (_selectedSessionId.isEmpty) return;

    // Simulate sending message locally
    ref
        .read(mockCoachProvider.notifier)
        .sendMessage(_selectedSessionId, text.trim());
    _messageController.clear();

    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    // Fake typing delay for UI demonstration
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  void _openDetail(CoachDetailView view) {
    setState(() => _activeDetail = view);
  }

  void _closeDetail() {
    setState(() => _activeDetail = CoachDetailView.none);
  }

  void _createSession(CoachSessionOption option) {
    if (!ref.read(fakeDataAllowedProvider)) return;
    final prefs = ref.read(mockCoachPreferencesProvider);
    ref
        .read(mockCoachProvider.notifier)
        .createNewSession(option.title, option.type, prefs.name, prefs.style);
    final sessions = ref.read(mockCoachProvider);
    if (sessions.isNotEmpty) {
      setState(() => _selectedSessionId = sessions.first.id);
    }
    _closeDetail();
  }

  Widget _buildActionCard(CoachResponseBlock block) {
    // Basic mapping for demo purposes
    if (block.type == CoachResponseBlockType.routineSuggestionCard ||
        block.type == CoachResponseBlockType.actionCard) {
      return TodayPlanCard(
        onStartMeditation: () {
          ref.read(appNavigationProvider.notifier).goToTracker();
          ref.read(trackerDetailViewRequestProvider.notifier).state =
              TrackerDetailTarget.view(TrackerDetailView.meditation);
        },
        onOpenRoutine: () {
          ref.read(appNavigationProvider.notifier).goToRoutine();
        },
        onImprovePlan: () {
          ref.read(appNavigationProvider.notifier).goToRoutine();
          ref
              .read(routineDetailViewRequestProvider.notifier)
              .state = const RoutineDetailTarget(
            view: RoutineDetailView.routineSettings,
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(coachDetailViewRequestProvider, (previous, next) {
      if (next == CoachDetailView.none) return;
      _openDetail(next);
      ref.read(coachDetailViewRequestProvider.notifier).state =
          CoachDetailView.none;
    });

    final pending = ref.watch(coachDetailViewRequestProvider);
    if (pending != CoachDetailView.none && _activeDetail != pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openDetail(pending);
        ref.read(coachDetailViewRequestProvider.notifier).state =
            CoachDetailView.none;
      });
    }

    final sessions = ref.watch(mockCoachProvider);
    final coachPreferences = ref.watch(mockCoachPreferencesProvider);
    final fakeDataAllowed = ref.watch(fakeDataAllowedProvider);

    if (_activeDetail != CoachDetailView.none) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeDetail();
        },
        child: _buildDetail(),
      );
    }

    if (sessions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(coachPreferences.name),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AnimatedBotAvatar(
                          baseColor: OptivusColors.glassFill,
                          rimColor: OptivusColors.coachTop,
                          lightColor: Colors.white,
                          iconColor: OptivusColors.coachAccent,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No coach sessions yet.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: fakeDataAllowed
                              ? () => _openDetail(CoachDetailView.newSession)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OptivusColors.coachAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Start new session'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeSession = sessions.firstWhere(
      (s) => s.id == _selectedSessionId,
      orElse: () => sessions.first,
    );

    // Keep session sync
    if (_selectedSessionId != activeSession.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSessionId = activeSession.id);
      });
    }

    final messages = activeSession.messages;

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Calm purple background handled by AppShell
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(coachPreferences.name),

            // ── Quick Actions ──
            CoachQuickActions(
              quickReplies: const [
                'Today\'s Plan',
                'Recover',
                'Improve Routine',
                'Calm',
                'Focus',
              ],
              onTap: _sendMessage,
            ),

            const SizedBox(height: 8),

            // ── Chat Area ──
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 80),
                physics: const BouncingScrollPhysics(),
                itemCount:
                    (messages.isEmpty ? 1 : messages.length) +
                    (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (messages.isEmpty) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CoachMessageBubble(
                          message: CoachMessage(
                            id: 'empty',
                            content: fakeDataAllowed
                                ? 'Hello, I’m ${coachPreferences.name}, your personal AI coach.\nHow can I support you today?'
                                : 'No messages yet.',
                            timestamp: '',
                            isFromCoach: true,
                          ),
                          onBuildActionCard: _buildActionCard,
                        ),
                      );
                    }
                  } else if (index < messages.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CoachMessageBubble(
                        message: messages[index],
                        onBuildActionCard: _buildActionCard,
                      ),
                    );
                  }

                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: TypingBubble(),
                  );
                },
              ),
            ),

            // ── Input Bar ──
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 60,
              ), // Space for floating nav
              child: CoachInputField(
                controller: _messageController,
                focusNode: _focusNode,
                hasText: _messageController.text.isNotEmpty,
                onSend: () => _sendMessage(_messageController.text),
                onQuickPrompt: _sendMessage,
                onNewSession: () => _openDetail(CoachDetailView.newSession),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail() {
    return switch (_activeDetail) {
      CoachDetailView.sessionHistory => CoachSessionHistoryScreen(
        onBack: _closeDetail,
        onSelectSession: (id) {
          setState(() => _selectedSessionId = id);
          _closeDetail();
        },
        onNewSession: () => _openDetail(CoachDetailView.newSession),
      ),
      CoachDetailView.coachSettings => CoachSettingsInlineScreen(
        onBack: _closeDetail,
      ),
      CoachDetailView.newSession => CoachNewSessionScreen(
        onBack: _closeDetail,
        onCreate: _createSession,
      ),
      CoachDetailView.privacyData => CoachPrivacyDataScreen(
        onBack: _closeDetail,
      ),
      CoachDetailView.none => const SizedBox.shrink(),
    };
  }

  Widget _buildHeader(String coachName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: const AnimatedBotAvatar(
                    baseColor: OptivusColors.glassFill,
                    rimColor: OptivusColors.coachTop,
                    lightColor: Colors.white,
                    iconColor: OptivusColors.coachAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coachName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: OptivusColors.success,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Online · Ask Anything',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: OptivusColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: OptivusColors.coachAccent,
                ),
                onPressed: () => _openDetail(CoachDetailView.newSession),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_horiz,
                  color: OptivusColors.coachAccent,
                ),
                onPressed: _showCoachMenu,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCoachMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Coach Menu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _CoachMenuRow(
                icon: Icons.settings_outlined,
                label: 'Coach Settings',
                onTap: () {
                  Navigator.of(context).pop();
                  _openDetail(CoachDetailView.coachSettings);
                },
              ),
              _CoachMenuRow(
                icon: Icons.history_outlined,
                label: 'Session History',
                onTap: () {
                  Navigator.of(context).pop();
                  _openDetail(CoachDetailView.sessionHistory);
                },
              ),
              _CoachMenuRow(
                icon: Icons.add_circle_outline_rounded,
                label: 'New Session',
                onTap: () {
                  Navigator.of(context).pop();
                  _openDetail(CoachDetailView.newSession);
                },
              ),
              _CoachMenuRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy / Export / Delete',
                onTap: () {
                  Navigator.of(context).pop();
                  _openDetail(CoachDetailView.privacyData);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CoachMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: OptivusColors.coachAccent),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: OptivusColors.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
