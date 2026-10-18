import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/live_voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_director.dart';
import '../widgets/shared_companion_viewer.dart';
import 'settings_screen.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  static const String characterScale = '1 1 1';
  static const String characterCameraOrbit = '0deg 78deg 240%';
  static const String characterCameraTarget = 'auto auto auto';
  static const String characterFieldOfView = 'auto';

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final LiveVoiceService _liveVoice = LiveVoiceService();
  final CharacterDirector _director = CharacterDirector();
  AppState? _app;
  bool liveActive = false;
  String currentTranscript = '';
  String speechBubbleText = '';
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
    _director.setSpeechText(app.speechText);
    _director.setSpeaking(app.isSpeaking);
    if (app.isSpeaking) {
      if (app.spokenWord.isNotEmpty) {
        _director.setSpokenWord(app.spokenWord);
      } else {
        _director.setSpeechProgress(app.speechProgress);
      }
    } else if (app.mood == CompanionMood.thinking &&
        _director.clip != 'think') {
      _director.play('think', userInitiated: false);
    } else if (app.mood != CompanionMood.thinking &&
        _director.clip == 'think') {
      _director.play(liveActive ? 'listen' : 'idle', userInitiated: false);
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
    final line = _director.lineFor(
      clip,
      companion: state.companionName,
    );
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
      _showSpeech('See you later, ${state.companionName}!',
          duration: const Duration(seconds: 3));
    } else {
      setState(() => liveActive = true);
      _director.setLiveLocked(true);
      _showSpeech('Listening... Talk to ${state.companionName}!',
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

    _showSpeech('${state.companionName} is thinking...',
        duration: const Duration(seconds: 10));
    state.setMood(CompanionMood.thinking);
    _director.play('think', userInitiated: false);

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
    final companionName = state.companionName;
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
                Text(
                  'Say something to $companionName',
                  style: const TextStyle(
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
                hintText: 'Ask $companionName a question or say hello...',
                filled: true,
                fillColor: AppTheme.surface,
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
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: AppTheme.ink,
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
    final companionName = context.watch<AppState>().companionName;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: _VoiceGardenBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 620;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        compact ? 8 : 14,
                        20,
                        compact ? 4 : 10,
                      ),
                      child: SizedBox(
                        height: compact ? 84 : 116,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: showBubble ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: IgnorePointer(
                              ignoring: !showBubble,
                              child: _buildSpeechBubble(
                                companionName,
                                maxHeight: compact ? 84 : 116,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: Consumer<AppState>(
                          builder: (context, state, _) =>
                              SharedCharacterViewerSlot(
                            director: _director,
                            characterId: state.companionId ?? 'milo',
                            cameraOrbit: VoiceScreen.characterCameraOrbit,
                            cameraTarget: VoiceScreen.characterCameraTarget,
                            fieldOfView: VoiceScreen.characterFieldOfView,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                      child: Consumer<AppState>(
                        builder: (context, state, _) => _actionBar(state),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(AppState state) {
    final label = state.mood == CompanionMood.thinking
        ? 'Thinking'
        : state.mood == CompanionMood.listening
            ? 'Listening'
            : state.mood == CompanionMood.talking
                ? 'Speaking'
                : state.companionName;
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
              color: liveActive ? const Color(0xff16845b) : AppTheme.brightBlue,
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
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.97),
            (AppTheme.isSuzu
                    ? const Color(0xfffff1f6)
                    : const Color(0xfffff9e9))
                .withValues(alpha: 0.97),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1c375638),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _labeledAction(
            icon: Icons.arrow_upward_rounded,
            label: 'Jump',
            color: AppTheme.blue,
            onTap: () => _userMove(state, 'jump'),
          ),
          _labeledAction(
            icon: Icons.music_note_rounded,
            label: 'Dance',
            color: AppTheme.blue,
            onTap: () => _userMove(state, 'dance'),
          ),
          _bellButton(state),
          _labeledAction(
            icon: Icons.waving_hand_rounded,
            label: 'Wave',
            color: AppTheme.blue,
            onTap: () => _userMove(state, 'wave'),
          ),
          _labeledAction(
            icon: Icons.rotate_right_rounded,
            label: 'Spin',
            color: AppTheme.blue,
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
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      color.withValues(alpha: 0.12),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.16)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.14),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
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
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: liveActive
                    ? const [Color(0xff398e63), Color(0xff176b49)]
                    : AppTheme.isSuzu
                        ? [const Color(0xffed9fbd), const Color(0xffd96694)]
                        : const [Color(0xffffce58), Color(0xffedaa30)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (liveActive
                          ? const Color(0xff35875d)
                          : AppTheme.brightBlue)
                      .withValues(alpha: 0.36),
                  blurRadius: liveActive ? 18 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.mic_rounded, color: Colors.white, size: 27),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            liveActive ? 'Stop' : 'Talk',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.blue,
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

  Widget _buildSpeechBubble(
    String companionName, {
    required double maxHeight,
  }) =>
      Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 320, maxHeight: maxHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.brightBlue, width: 1.6),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppTheme.blue),
                  const SizedBox(width: 6),
                  Text(
                    companionName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.blue,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    speechBubbleText.isEmpty
                        ? 'Tap the microphone to talk with $companionName.'
                        : speechBubbleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff131b2e),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _VoiceGardenBackground extends StatelessWidget {
  const _VoiceGardenBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xffdff4ff),
                  Color(0xfff7f7df),
                  Color(0xffe8f2c9),
                ],
                stops: [0, 0.62, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: 118,
          left: -34,
          child: _gardenCloud(width: 142, opacity: 0.78),
        ),
        Positioned(
          top: 185,
          right: -18,
          child: _gardenCloud(width: 110, opacity: 0.64),
        ),
        const Positioned.fill(
          child: CustomPaint(
            painter: _GardenHillsPainter(),
          ),
        ),
        const Positioned(
          bottom: 148,
          left: 14,
          child: Icon(
            Icons.local_florist_rounded,
            size: 26,
            color: Color(0xfff5b84e),
          ),
        ),
        const Positioned(
          bottom: 176,
          right: 16,
          child: Icon(
            Icons.local_florist_rounded,
            size: 20,
            color: Color(0xfff1a6a0),
          ),
        ),
      ],
    );
  }

  Widget _gardenCloud({required double width, required double opacity}) =>
      Opacity(
        opacity: opacity,
        child: SizedBox(
          width: width,
          height: width * 0.42,
          child: Stack(
            children: [
              Positioned(
                left: width * 0.08,
                right: width * 0.08,
                bottom: 0,
                child: Container(
                  height: width * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(width),
                  ),
                ),
              ),
              Positioned(
                left: width * 0.2,
                bottom: width * 0.08,
                child: _cloudPuff(width * 0.27),
              ),
              Positioned(
                left: width * 0.4,
                bottom: width * 0.12,
                child: _cloudPuff(width * 0.36),
              ),
              Positioned(
                right: width * 0.12,
                bottom: width * 0.07,
                child: _cloudPuff(width * 0.24),
              ),
            ],
          ),
        ),
      );

  Widget _cloudPuff(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
}

class _GardenHillsPainter extends CustomPainter {
  const _GardenHillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final backHill = Path()
      ..moveTo(0, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.58,
        size.width * 0.56,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.79,
        size.height * 0.9,
        size.width,
        size.height * 0.7,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      backHill,
      Paint()..color = const Color(0xffc4e2a1).withValues(alpha: 0.66),
    );

    final frontHill = Path()
      ..moveTo(0, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.69,
        size.width * 0.65,
        size.height * 0.84,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.92,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(frontHill, Paint()..color = const Color(0xff9bcf82));
  }

  @override
  bool shouldRepaint(covariant _GardenHillsPainter oldDelegate) => false;
}
