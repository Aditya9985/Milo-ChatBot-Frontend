import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/live_voice_service.dart';
import '../widgets/character_director.dart';
import '../widgets/milo_character_viewer.dart';
import 'settings_screen.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final LiveVoiceService _liveVoice = LiveVoiceService();
  final CharacterDirector _director = CharacterDirector();
  AppState? _app;
  bool liveActive = false;
  String currentTranscript = '';
  String speechBubbleText = 'Tap the microphone to talk with Milo.';
  bool showBubble = true;
  Timer? _bubbleTimer;

  @override
  void initState() {
    super.initState();
    _director.startWandering();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _app = context.read<AppState>();
      _app!.addListener(_syncSpokenVoice);
      _syncSpokenVoice();
    });
  }

  void _syncSpokenVoice() {
    final app = _app;
    if (app == null) return;
    _director.setSpeaking(app.isSpeaking);
    if (app.isSpeaking) {
      _director.setSpokenWord(app.spokenWord);
    }
  }

  @override
  void dispose() {
    _app?.removeListener(_syncSpokenVoice);
    _bubbleTimer?.cancel();
    _director.dispose();
    _liveVoice.stopListening();
    super.dispose();
  }

  void _showSpeech(String text,
      {Duration duration = const Duration(seconds: 5)}) {
    if (!mounted) return;
    setState(() {
      speechBubbleText = text;
      showBubble = true;
    });
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(duration, () {
      if (mounted && !liveActive) {
        setState(() => showBubble = false);
      }
    });
  }

  void _userMove(AppState state, String clip) {
    _director.play(clip, userInitiated: true);
    final line = _director.lineFor(clip);
    _showSpeech(line);
    state.speak(line);
  }

  void _stopLive(AppState state) {
    if (!mounted) return;
    setState(() {
      liveActive = false;
      currentTranscript = '';
    });
    _liveVoice.stopListening();
    state.stopSpeaking();
    state.setMood(CompanionMood.happy);
    _director.setLiveLocked(false);
  }

  Future<void> toggleLiveMode(AppState state) async {
    if (liveActive) {
      _stopLive(state);
      _showSpeech('See you later!', duration: const Duration(seconds: 3));
    } else {
      setState(() => liveActive = true);
      _director.setLiveLocked(true);
      _showSpeech('Listening... Talk to Milo!',
          duration: const Duration(seconds: 4));
      await _runListeningTurn(state);
    }
  }

  Future<void> _runListeningTurn(AppState state) async {
    if (!liveActive || !mounted) return;

    setState(() => currentTranscript = '');
    state.setMood(CompanionMood.listening);
    _director.setLiveLocked(true);

    await _liveVoice.startListening(
      onResult: (words, isFinal) {
        if (!mounted || !liveActive) return;
        setState(() {
          currentTranscript = words;
          if (words.isNotEmpty) {
            speechBubbleText = words;
            showBubble = true;
          }
        });
      },
      onDone: () async {
        if (!mounted || !liveActive) return;
        final spokenText = currentTranscript.trim();
        if (spokenText.isNotEmpty) {
          await _handleSpokenInput(state, spokenText);
        } else if (liveActive && mounted) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (liveActive && mounted) _runListeningTurn(state);
        }
      },
    );
  }

  Future<void> _handleSpokenInput(AppState state, String text) async {
    if (!mounted || !liveActive) return;

    _showSpeech('Milo is thinking...', duration: const Duration(seconds: 10));
    state.setMood(CompanionMood.thinking);

    await state.sendMessage(text, readAloud: false);
    if (!mounted || !liveActive) return;

    final latestReply = state.messages.isNotEmpty &&
            state.messages.last.author == MessageAuthor.assistant
        ? state.messages.last.text
        : 'I hear you!';

    _showSpeech(latestReply, duration: const Duration(seconds: 10));
    _director.fromReply(latestReply);

    await state.speakWithCallback(latestReply, onComplete: () {
      if (liveActive && mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (liveActive && mounted) _runListeningTurn(state);
        });
      }
    });
  }

  void _showTextInputDialog(AppState state) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Say something to Milo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff131b2e),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Ask Milo a question or say hello...',
                filled: true,
                fillColor: const Color(0xfff1f5f9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx);
                if (val.trim().isNotEmpty) {
                  _handleSpokenInput(state, val.trim());
                }
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff006096),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final text = textController.text.trim();
                  Navigator.pop(ctx);
                  if (text.isNotEmpty) {
                    _handleSpokenInput(state, text);
                  }
                },
                child: const Text('Send message',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xffeaf3fa),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffedf7ff), Color(0xffc8e1f2)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: topPad + 36,
            bottom: 118,
            child: CompanionCharacterViewer(
              director: _director,
            ),
          ),
          if (showBubble)
            Positioned(
              top: topPad + 64,
              left: 20,
              right: 20,
              child: _buildSpeechBubble(),
            ),
          Positioned(
            top: topPad + 8,
            left: 12,
            right: 12,
            child: Consumer<AppState>(
              builder: (context, state, _) => Row(
                children: [
                  _glassIcon(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  _statusPill(state),
                  const Spacer(),
                  _glassIcon(
                    icon: Icons.keyboard_rounded,
                    onTap: () => _showTextInputDialog(state),
                  ),
                  const SizedBox(width: 8),
                  _glassIcon(
                    icon: Icons.info_outline_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Consumer<AppState>(
              builder: (context, state, _) => _actionBar(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(AppState state) {
    final label = !liveActive
        ? 'Milo'
        : (state.mood == CompanionMood.listening
            ? 'Listening'
            : (state.mood == CompanionMood.thinking ? 'Thinking' : 'Speaking'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1a000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: liveActive
                  ? const Color(0xff10b981)
                  : const Color(0xff007abc),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xff131b2e),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(AppState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _labeledAction(
            icon: Icons.arrow_upward_rounded,
            label: 'Jump',
            color: const Color(0xff0f766e),
            onTap: () => _userMove(state, 'jump'),
          ),
          _labeledAction(
            icon: Icons.music_note_rounded,
            label: 'Dance',
            color: const Color(0xffc026d3),
            onTap: () => _userMove(state, 'dance'),
          ),
          _bellButton(state),
          _labeledAction(
            icon: Icons.waving_hand_rounded,
            label: 'Wave',
            color: const Color(0xff0284c7),
            onTap: () => _userMove(state, 'wave'),
          ),
          _labeledAction(
            icon: Icons.rotate_right_rounded,
            label: 'Spin',
            color: const Color(0xffb45309),
            onTap: () => _userMove(state, 'spin'),
          ),
        ],
      ),
    );
  }

  Widget _labeledAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bellButton(AppState state) {
    return GestureDetector(
      onTap: () => toggleLiveMode(state),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: liveActive
                  ? const Color(0xff006096)
                  : const Color(0xff007abc),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff007abc).withValues(alpha: 0.4),
                  blurRadius: liveActive ? 16 : 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.mic_rounded, color: Colors.white, size: 29),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            liveActive ? 'Stop' : 'Talk',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xff006096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xff1e293b),
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildSpeechBubble() => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xff38bdf8), width: 1.6),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 14,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 18, color: Color(0xff006096)),
                  SizedBox(width: 6),
                  Text(
                    'MILO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff006096),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                speechBubbleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff131b2e),
                ),
              ),
            ],
          ),
        ),
      );
}
