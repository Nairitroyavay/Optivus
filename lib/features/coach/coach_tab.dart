import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/features/coach/widgets/coach_message_bubble.dart';
import 'package:optivus/features/coach/widgets/coach_input_field.dart';
import 'package:optivus/features/coach/widgets/coach_quick_actions.dart';
import 'package:optivus/features/coach/widgets/coach_response_cards.dart';
import 'package:optivus/features/coach/widgets/coach_bottom_sheets.dart';
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
  String _selectedSessionId = 'session-1'; // Default seeded session

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
    if (text.trim().isEmpty) return;
    
    // Simulate sending message locally
    ref.read(mockCoachProvider.notifier).sendMessage(_selectedSessionId, text.trim());
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

  void _handleSessionTypeChange(String label) {
    // In a real app this would create a new Firestore session
    // For this pass we just mock a demo local state change
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to $label Mode'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildActionCard(CoachResponseBlock block) {
    // Basic mapping for demo purposes
    if (block.type == CoachResponseBlockType.routineSuggestionCard || block.type == CoachResponseBlockType.actionCard) {
      return TodayPlanCard(
        onStartMeditation: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started Meditation')));
        },
        onOpenRoutine: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opened Routine')));
        },
        onImprovePlan: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Improve Plan triggered')));
        },
      );
    }
    return const SizedBox.shrink(); // Placeholders for others would go here
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(mockCoachProvider);
    final coachPreferences = ref.watch(mockCoachPreferencesProvider);
    
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
      backgroundColor: Colors.transparent, // Calm purple background handled by AppShell
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(coachPreferences.name),
            
            // ── Quick Actions ──
            CoachQuickActions(
              quickReplies: const ['Today\'s Plan', 'Recover', 'Improve Routine', 'Calm', 'Focus'],
              onTap: _sendMessage,
            ),
            
            const SizedBox(height: 8),

            // ── Chat Area ──
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16).copyWith(bottom: MediaQuery.of(context).padding.bottom + 80),
                physics: const BouncingScrollPhysics(),
                itemCount: (messages.isEmpty ? 1 : messages.length) + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (messages.isEmpty) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CoachMessageBubble(
                          message: CoachMessage(
                            id: 'empty',
                            content: 'Hello, I’m ${coachPreferences.name}, your personal AI coach.\nHow can I support you today?',
                            timestamp: 'Just now',
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 60), // Space for floating nav
              child: CoachInputField(
                controller: _messageController,
                focusNode: _focusNode,
                hasText: _messageController.text.isNotEmpty,
                onSend: () => _sendMessage(_messageController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String coachName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coachName,
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
                      Text(
                        'Online · Ask Anything',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OptivusColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: OptivusColors.coachAccent),
                onPressed: () {
                  CoachBottomSheets.showNewSessionSheet(
                    context, 
                    onSessionSelected: _handleSessionTypeChange
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: OptivusColors.coachAccent),
                onPressed: () {
                  CoachBottomSheets.showCoachMenuSheet(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

}
