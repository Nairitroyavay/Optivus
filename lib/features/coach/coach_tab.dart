import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/features/coach/screens/coach_sub_screens.dart';

class CoachTab extends ConsumerStatefulWidget {
  const CoachTab({super.key});

  @override
  ConsumerState<CoachTab> createState() => _CoachTabState();
}

class _CoachTabState extends ConsumerState<CoachTab> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late final AnimationController _waveAnimationController;

  String _selectedSessionId = 'session-1'; // Default seeded session

  @override
  void initState() {
    super.initState();
    // Animated iridescent sine waves controller
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Auto-scroll to bottom of conversation
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _waveAnimationController.dispose();
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
    ref.read(mockCoachProvider.notifier).sendMessage(_selectedSessionId, text.trim());
    _messageController.clear();
    _scrollToBottom();

    // Scroll to bottom again after brief delay to catch the incoming user message
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    // Trigger visual scroll update after mock coach reply completes
    Future.delayed(const Duration(milliseconds: 1600), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(mockCoachProvider);
    final activeSession = sessions.firstWhere(
      (s) => s.id == _selectedSessionId,
      orElse: () => sessions.first,
    );

    final messages = activeSession.messages;

    final quickReplies = [
      'Hello!',
      'I am feeling tired...',
      'Water logged!',
      'Verify Gym Proof',
      'Dump overthinking thoughts',
    ];

    return Column(
      children: [
        // Top Header Actions Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI COACH AURA',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: OptivusColors.textSecondary,
                    ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.forum_outlined, color: OptivusColors.brandAccent, size: 18),
                    onPressed: () => showCoachSessionsListScreen(context, ref),
                    tooltip: 'All Threads',
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, color: OptivusColors.brandAccent, size: 18),
                    onPressed: () => showCoachSettingsScreen(context, ref),
                    tooltip: 'Persona Configurations',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Session Header Picker
        if (sessions.length > 1)
          Container(
            height: 40,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final s = sessions[index];
                final isSel = s.id == _selectedSessionId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(s.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedSessionId = s.id);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                      }
                    },
                  ),
                );
              },
            ),
          ),

        // Chat bubbles scroll container
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ListView.builder(
                controller: _chatScrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildChatBubble(msg),
                  );
                },
              ),
            ),
          ),
        ),

        // Quick replies pill horizontal list
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 8),
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
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  side: const BorderSide(color: OptivusColors.borderSoft),
                  label: Text(
                    reply,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: OptivusColors.brandAccent,
                    ),
                  ),
                  onPressed: () => _sendMessage(reply),
                ),
              );
            },
          ),
        ),

        // Iridescent waving mathematical text composer canvas
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dynamic math sine wave painter
                    AnimatedBuilder(
                      animation: _waveAnimationController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(double.infinity, 36),
                          painter: IridescentWavePainter(
                            phase: _waveAnimationController.value * 2 * math.pi,
                            isTyping: _messageController.text.isNotEmpty,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Input row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Talk to Aura Coach...',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: OptivusColors.borderSoft),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: OptivusColors.brandAccent),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {});
                            },
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [OptivusColors.brandAccent, OptivusColors.aquaAccent],
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: () => _sendMessage(_messageController.text),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildChatBubble(CoachMessage msg) {
    final isCoach = msg.isFromCoach;
    return Align(
      alignment: isCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: Column(
          crossAxisAlignment: isCoach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCoach ? const Color(0xFFDCCBFF).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isCoach ? const Radius.circular(4) : const Radius.circular(20),
                  bottomRight: isCoach ? const Radius.circular(20) : const Radius.circular(4),
                ),
                border: Border.all(
                  color: isCoach ? const Color(0xFFDCCBFF) : OptivusColors.borderSoft,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  if (msg.blocks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final block in msg.blocks) _buildCoachActionCard(block),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.timestamp,
              style: const TextStyle(fontSize: 9, color: OptivusColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachActionCard(CoachResponseBlock block) {
    IconData cardIcon = Icons.stars;
    Color blockColor = OptivusColors.brandAccent;

    switch (block.type) {
      case CoachResponseBlockType.routineSuggestionCard:
        cardIcon = Icons.lock_reset;
        blockColor = OptivusColors.success;
        break;
      case CoachResponseBlockType.trackerActionCard:
        cardIcon = Icons.local_drink_outlined;
        blockColor = OptivusColors.brandAccent;
        break;
      case CoachResponseBlockType.goalProofCard:
        cardIcon = Icons.verified_user;
        blockColor = Colors.orange;
        break;
      case CoachResponseBlockType.mindNoteCard:
        cardIcon = Icons.bubble_chart;
        blockColor = Colors.deepPurple;
        break;
      default:
        cardIcon = Icons.stars;
        blockColor = OptivusColors.brandAccent;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blockColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(cardIcon, color: blockColor, size: 16),
              const SizedBox(width: 8),
              Text(
                block.heading ?? '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: blockColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            block.body ?? '',
            style: const TextStyle(fontSize: 10, height: 1.3, color: OptivusColors.textBody),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blockColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
            ),
            onPressed: () {
              if (block.payload == 'pivot_routine') {
                final gym = ref.read(mockRoutineProvider).firstWhere((r) => r.title.contains('Gym'));
                ref.read(mockRoutineProvider.notifier).updateRoutineItem(
                      gym.copyWith(startMinute: 18 * 60, endMinute: 19 * 60 + 30),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Applied: Gym delayed to 18:00.'), behavior: SnackBarBehavior.floating),
                );
              } else if (block.payload == 'water_250') {
                ref.read(mockTrackerProvider.notifier).logHydration(250);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged +250ml Water!'), behavior: SnackBarBehavior.floating),
                );
              } else if (block.payload == 'verify_proof_body') {
                final gymGoal = ref.read(mockGoalProvider).firstWhere((g) => g.identityTitle.contains('Gym'));
                ref.read(mockGoalProvider.notifier).toggleGoalProofCompleted(gymGoal.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gym Goal Daily Proof Verified!'), behavior: SnackBarBehavior.floating),
                );
              } else if (block.payload == 'open_notebook') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mind Notebook is open on your Home tab!'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: Text(block.buttonLabel ?? 'Confirm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ── Iridescent Siri-style Mathematical Wavy Sine Painter ────────────────────
class IridescentWavePainter extends CustomPainter {
  final double phase;
  final bool isTyping;

  IridescentWavePainter({required this.phase, required this.isTyping});

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    final double width = size.width;

    final double amplitude = isTyping ? 14.0 : 5.0;
    final double frequency = isTyping ? 0.04 : 0.02;

    _drawSingleWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amp: amplitude,
      freq: frequency,
      phaseOffset: phase,
      colors: [const Color(0xFFE0B51F), const Color(0xFF7BE6DC)],
      strokeWidth: 2.5,
    );

    _drawSingleWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amp: amplitude * 0.7,
      freq: frequency * 1.3,
      phaseOffset: phase + math.pi / 2,
      colors: [const Color(0xFF7BE6DC), const Color(0xFFDCCBFF)],
      strokeWidth: 1.5,
    );

    _drawSingleWave(
      canvas: canvas,
      width: width,
      midY: midY,
      amp: amplitude * 0.4,
      freq: frequency * 0.8,
      phaseOffset: phase + math.pi,
      colors: [const Color(0xFFDCCBFF), const Color(0xFFFFB6DC)],
      strokeWidth: 1.0,
    );
  }

  void _drawSingleWave({
    required Canvas canvas,
    required double width,
    required double midY,
    required double amp,
    required double freq,
    required double phaseOffset,
    required List<Color> colors,
    required double strokeWidth,
  }) {
    final path = Path();
    path.moveTo(0, midY);

    for (double x = 0; x <= width; x += 3) {
      final double taper = math.sin((x / width) * math.pi);
      final double y = midY + math.sin(x * freq + phaseOffset) * amp * taper;
      path.lineTo(x, y);
    }

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(colors: colors).createShader(Rect.fromLTWH(0, 0, width, 36));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant IridescentWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isTyping != isTyping;
  }
}
