import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/character_director.dart';
import '../widgets/milo_avatar.dart';
import '../widgets/milo_splash_screen.dart';
import '../widgets/shared_companion_viewer.dart';
import 'chat_screen.dart';
import 'history_screen.dart';

import 'settings_screen.dart';
import 'voice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.enable3dCharacter = true,
    this.enable3dPreviews = true,
  });

  static const String characterCameraOrbit = '0deg 78deg 190%';
  static const String characterCameraTarget = 'auto auto auto';
  static const String characterFieldOfView = 'auto';

  final bool enable3dCharacter;
  final bool enable3dPreviews;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final query = TextEditingController();
  final CharacterDirector _director = CharacterDirector();
  late final AnimationController _entrance;
  AppState? _appState;
  String? _loadedCharacterId;
  bool _modelReady = false;
  bool _modelLoadFailed = false;
  int _modelAttempt = 0;
  Timer? _modelLoadTimeout;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    if (widget.enable3dCharacter) {
      _director.startWandering();
      _startModelLoadTimeout();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appState = context.read<AppState>()..addListener(_syncCharacterVoice);
      unawaited(_appState!.loadPreferences());
      _syncCharacterVoice();
    });
  }

  void _startModelLoadTimeout() {
    _modelLoadTimeout?.cancel();
    _modelLoadTimeout = Timer(const Duration(seconds: 30), () {
      if (mounted && !_modelReady) {
        setState(() => _modelLoadFailed = true);
      }
    });
  }

  void _retryModelLoad() {
    setState(() {
      _modelAttempt += 1;
      _modelLoadFailed = false;
      _modelReady = false;
    });
    _startModelLoadTimeout();
  }

  void _onModelLoadError(Object error) {
    debugPrint('Companion model initialization failed: $error');
    if (!mounted) return;
    _modelLoadTimeout?.cancel();
    setState(() => _modelLoadFailed = true);
  }

  @override
  void dispose() {
    query.dispose();
    _appState?.removeListener(_syncCharacterVoice);
    _director.dispose();
    _entrance.dispose();
    _modelLoadTimeout?.cancel();
    super.dispose();
  }

  void _syncCharacterVoice() {
    final state = _appState;
    if (state == null) return;
    if (_loadedCharacterId != null && _loadedCharacterId != state.companionId) {
      _modelLoadTimeout?.cancel();
      _modelReady = false;
      _modelLoadFailed = false;
      _startModelLoadTimeout();
    }
    _loadedCharacterId = state.companionId;
    _director.setSpeaking(state.isSpeaking);
    if (state.isSpeaking) {
      _director.setSpokenWord(state.spokenWord);
    } else if (state.mood == CompanionMood.thinking &&
        _director.clip != 'think') {
      _director.play('think', userInitiated: false);
    } else if (state.mood != CompanionMood.thinking &&
        _director.clip == 'think') {
      _director.play('idle', userInitiated: false);
    }
  }

  void _sayHello(AppState state) {
    _director.play('wave');
    state.speak(
      _director.lineFor('wave', companion: state.companionName),
    );
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _ask(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    final state = context.read<AppState>();
    query.clear();
    FocusScope.of(context).unfocus();
    state.sendMessage(value);
    _open(const ChatScreen());
  }

  static TextStyle _style(double size, FontWeight weight, Color color,
          {double tracking = 0, double leading = 0}) =>
      TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: tracking,
          height: leading == 0 ? null : leading / size);

  @override
  Widget build(BuildContext context) =>
      Consumer<AppState>(builder: (_, state, __) {
        final recents = state.conversations.take(2).toList();
        return Scaffold(
            body: Stack(
          children: [
            const Positioned.fill(child: _PlayfulHomeBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heroHeight =
                      math.min(300.0, constraints.maxHeight * 0.4);
                  return Column(
                    children: [
                      _header(state),
                      Expanded(
                        child: Column(
                          children: [
                            SizedBox(
                              height: heroHeight,
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: 300,
                                  child: _hero(state),
                                ),
                              ),
                            ),
                            Expanded(
                              child: FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _entrance,
                                  curve: Curves.easeOut,
                                ),
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.04),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _entrance,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 24,
                                    ),
                                    child: Column(
                                      children: [
                                        _voiceButton(state),
                                        const SizedBox(height: 12),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: _search(state),
                                        ),
                                        const SizedBox(height: 20),
                                        _adventureSection(),
                                        const SizedBox(height: 20),
                                        if (recents.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: _sectionLabel(
                                              'RECENT CHAT BUBBLES',
                                              onViewAll: () =>
                                                  _open(const HistoryScreen()),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...recents.map(
                                            (item) => Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                16,
                                                0,
                                                16,
                                                8,
                                              ),
                                              child: _conversationCard(
                                                  state, item),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _nav(),
                    ],
                  );
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring:
                    state.isReady && (!widget.enable3dCharacter || _modelReady),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: !state.isReady ||
                          (widget.enable3dCharacter && !_modelReady)
                      ? MiloSplashScreen(
                          key: const ValueKey('milo-startup-splash'),
                          companionName: state.companionName,
                          message: _modelLoadFailed
                              ? '${state.companionName}’s 3D world could not start.'
                              : !state.isReady
                                  ? 'Getting your space ready…'
                                  : 'Loading ${state.companionName}’s 3D world…',
                          onRetry: _modelLoadFailed ? _retryModelLoad : null,
                        )
                      : const SizedBox.expand(
                          key: ValueKey('milo-startup-ready'),
                        ),
                ),
              ),
            ),
          ],
        ));
      });

  String _firstName(AppState state) {
    final displayName = state.accountUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }

    final emailName = state.accountUser?.email?.split('@').first;
    if (emailName != null && emailName.isNotEmpty) {
      final firstPart = emailName.split(RegExp(r'[^A-Za-z0-9]+')).first;
      if (firstPart.isNotEmpty) {
        return firstPart[0].toUpperCase() + firstPart.substring(1);
      }
    }
    return 'there';
  }

  Widget _header(AppState state) => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          border: const Border(
            bottom: BorderSide(color: Color(0x55f5e4b7), width: 1.5),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0b8a5a00),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _profileAvatar(state),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${_firstName(state)}!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(16, FontWeight.w800, AppTheme.ink),
                  ),
                  Text(
                    'Ready for an adventure?',
                    style: _style(10, FontWeight.w600, AppTheme.muted),
                  ),
                ],
              ),
            ),
            _roundButton(
              size: 38,
              iconSize: 19,
              icon: Icons.settings_rounded,
              onTap: () => _open(
                SettingsScreen(enable3dPreviews: widget.enable3dPreviews),
              ),
            ),
          ],
        ),
      );

  Widget _profileAvatar(AppState state) {
    final photoUrl = state.accountUser?.photoURL;
    final fallback = Container(
      color: AppTheme.primaryContainer.withValues(alpha: 0.34),
      alignment: Alignment.center,
      child: Text(
        _firstName(state).substring(0, 1).toUpperCase(),
        style: _style(16, FontWeight.w800, AppTheme.blue),
      ),
    );

    return SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: photoUrl == null || photoUrl.isEmpty
            ? fallback
            : Image.network(
                photoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }

  Widget _hero(AppState state) => Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 178,
                  height: 178,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: AppTheme.isSuzu
                          ? const [
                              Colors.white,
                              Color(0xffffe7f0),
                              Color(0x00ffe7f0),
                            ]
                          : const [
                              Colors.white,
                              Color(0xffe4f4ff),
                              Color(0x00d8edff),
                            ],
                      stops: const [0.25, 0.7, 1],
                    ),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3574b7dc),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  top: 45,
                  left: 13,
                  child: _FloatingCloud(width: 78, phase: 0.15),
                ),
                const Positioned(
                  top: 81,
                  right: 8,
                  child: _FloatingCloud(width: 68, phase: 0.62),
                ),
                Positioned(
                  bottom: 14,
                  child: Container(
                    width: 105,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                if (widget.enable3dCharacter) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _sayHello(state),
                    child: SizedBox(
                      width: 220,
                      height: 232,
                      child: SharedCharacterViewerSlot(
                        director: _director,
                        characterId: state.companionId ?? 'milo',
                        cameraOrbit: HomeScreen.characterCameraOrbit,
                        cameraTarget: HomeScreen.characterCameraTarget,
                        fieldOfView: HomeScreen.characterFieldOfView,
                        generation: _modelAttempt,
                        onReady: () {
                          _modelLoadTimeout?.cancel();
                          _loadedCharacterId = state.companionId;
                          if (mounted) setState(() => _modelReady = true);
                        },
                        onError: _onModelLoadError,
                      ),
                    ),
                  ),
                ] else
                  MiloAvatar(size: 138, mood: state.mood),
                const Positioned(
                  top: 27,
                  right: 64,
                  child: _FloatingSparkle(
                    icon: Icons.star_rounded,
                    color: Color(0xffedaa30),
                    size: 22,
                    phase: 0.3,
                  ),
                ),
                const Positioned(
                  left: 54,
                  bottom: 37,
                  child: _FloatingSparkle(
                    icon: Icons.auto_awesome_rounded,
                    color: Color(0xffef9c62),
                    size: 19,
                    phase: 0.8,
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 46,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x228a5a00),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'FRIEND #1',
                      style: _style(8, FontWeight.w900, AppTheme.blue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _sayHello(state),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 330),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xffb9ddf5), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1b4b95c2),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '“Hi, ${_firstName(state)}! 👋”',
                    textAlign: TextAlign.center,
                    style: _style(16, FontWeight.w900, AppTheme.blue),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'What adventure shall we discover today?',
                    textAlign: TextAlign.center,
                    style: _style(10, FontWeight.w600, AppTheme.subtle),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _adventureSection() => _starterPrompts();

  Widget _starterPrompts() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🎪', style: _style(17, FontWeight.w700, AppTheme.ink)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Pick an adventure!',
                    style: _style(15, FontWeight.w800, AppTheme.ink),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.paleBlue,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Fun modes',
                    style: _style(9, FontWeight.w700, AppTheme.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                _adventureCard(
                  icon: Icons.rocket_launch_rounded,
                  emoji: '🚀',
                  title: 'Space & Stars',
                  subtitle: 'Explore the galaxy',
                  action: 'Blast off',
                  colors: const [Color(0xff7161d8), Color(0xffa45ce2)],
                  prompt:
                      'Take me on a fun, kid-friendly adventure through space. Tell me about stars, planets, and the Moon.',
                ),
                _adventureCard(
                  icon: Icons.pets_rounded,
                  emoji: '🦕',
                  title: 'Dino Quiz',
                  subtitle: 'Guess ancient beasts',
                  action: 'Play quiz',
                  colors: const [Color(0xff20b69a), Color(0xff45c98b)],
                  prompt:
                      'Let’s play a fun dinosaur quiz for kids. Ask me one question at a time and tell me if I am right.',
                ),
                _adventureCard(
                  icon: Icons.auto_awesome_rounded,
                  emoji: '🪄',
                  title: 'Magic Ideas',
                  subtitle: 'Imagine something amazing',
                  action: 'Get creative',
                  colors: const [Color(0xfff1a33a), Color(0xffef7656)],
                  prompt:
                      'Let’s invent a kind, helpful imaginary gadget. Ask what problem it should solve, then describe it playfully.',
                ),
                _adventureCard(
                  icon: Icons.menu_book_rounded,
                  emoji: '📖',
                  title: 'Story Time',
                  subtitle: 'A cozy tale made for you',
                  action: 'Start a story',
                  colors: const [Color(0xffe875a1), Color(0xffb978d9)],
                  prompt:
                      'Tell me a short, cozy original bedtime story with a kind hero, a little adventure, and a happy ending.',
                ),
              ],
            ),
          ],
        ),
      );

  Widget _adventureCard({
    required IconData icon,
    required String emoji,
    required String title,
    required String subtitle,
    required String action,
    required List<Color> colors,
    required String prompt,
  }) =>
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _ask(prompt),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -9,
                  bottom: -15,
                  child: Opacity(
                    opacity: 0.2,
                    child: Text(emoji, style: const TextStyle(fontSize: 68)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: Colors.white, size: 21),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _style(14, FontWeight.w800, Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _style(
                          10,
                          FontWeight.w600,
                          Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '$action  ›',
                          style: _style(9, FontWeight.w800, Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _search(AppState state) => Container(
      height: 54,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(27),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1a000000),
                blurRadius: 4,
                spreadRadius: -2,
                offset: Offset(0, 2)),
            BoxShadow(
                color: Color(0x1a000000),
                blurRadius: 6,
                spreadRadius: -2,
                offset: Offset(0, 4)),
          ]),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 18, color: AppTheme.muted),
        const SizedBox(width: 21),
        Expanded(
            child: TextField(
          controller: query,
          textInputAction: TextInputAction.search,
          onSubmitted: _ask,
          style: _style(14, FontWeight.w400, AppTheme.muted, leading: 17.6),
          decoration: InputDecoration(
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Ask ${state.companionName} anything...',
              hintStyle:
                  _style(14, FontWeight.w400, AppTheme.muted, leading: 17.6)),
        )),
        const SizedBox(width: 8),
        _roundButton(
            size: 40,
            iconSize: 16,
            icon: Icons.arrow_upward_rounded,
            onTap: () => _ask(query.text)),
      ]));

  Widget _voiceButton(AppState state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(38),
          child: InkWell(
            borderRadius: BorderRadius.circular(38),
            onTap: () => _open(const VoiceScreen()),
            child: Ink(
              height: 78,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: AppTheme.isSuzu
                      ? [const Color(0xffed9fbd), const Color(0xffd96694)]
                      : [const Color(0xffffd84d), const Color(0xffffbe2e)],
                ),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (AppTheme.isSuzu
                            ? const Color(0xffd96694)
                            : const Color(0xffe8a922))
                        .withValues(alpha: 0.27),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.66),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: AppTheme.blue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap & talk with ${state.companionName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(15, FontWeight.w900, AppTheme.blue),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ask, imagine, and explore together!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(10, FontWeight.w700, AppTheme.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const _VoiceWaveIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _sectionLabel(String text, {required VoidCallback onViewAll}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(text,
            style: _style(11, FontWeight.w700, AppTheme.subtle,
                tracking: 0.55, leading: 14)),
        GestureDetector(
            onTap: onViewAll,
            child: Text('View all',
                style: _style(11, FontWeight.w700, AppTheme.blue,
                    tracking: 0.44, leading: 14))),
      ]);

  String _conversationPreview(Conversation item) {
    for (final message in item.messages.reversed) {
      if (message.author == MessageAuthor.user) return message.text;
    }
    if (item.messages.isEmpty) return 'Tap to continue your chat';
    return item.messages.last.text;
  }

  Widget _conversationCard(AppState state, Conversation item) {
    final preview = _conversationPreview(item);
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          state.openConversation(item);
          _open(const ChatScreen());
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffdceefa), width: 1.3),
          ),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xff7fc9ef), Color(0xff398dc5)],
                  ),
                ),
                child: const Icon(Icons.chat_rounded,
                    size: 21, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                      child: Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style(12, FontWeight.w800, AppTheme.ink)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _ago(item.updatedAt),
                      style: _style(8, FontWeight.w800, AppTheme.blue),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(10, FontWeight.w500, AppTheme.muted)),
                ])),
            const SizedBox(width: 6),
            Container(
              width: 29,
              height: 29,
              decoration: const BoxDecoration(
                color: Color(0xffedf7ff),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.blue,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _nav() => Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          border: const Border(
            top: BorderSide(color: Color(0xffe3f0fa), width: 1.4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x128a5a00),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(
              'Chat',
              Icons.chat_bubble_rounded,
              18,
              () => _open(const ChatScreen()),
              selected: true,
            ),
            _navItem(
              'History',
              Icons.history_rounded,
              18,
              () => _open(const HistoryScreen()),
            ),
          ],
        ),
      );

  Widget _navItem(
    String label,
    IconData icon,
    double iconSize,
    VoidCallback onTap, {
    bool selected = false,
  }) =>
      GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 22 : 18,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xff4ab6f4), Color(0xff3989ed)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(24),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x333989ed),
                        blurRadius: 9,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: selected ? Colors.white : AppTheme.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: _style(
                    12,
                    FontWeight.w800,
                    selected ? Colors.white : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ));

  static String _ago(DateTime time) {
    final gap = DateTime.now().difference(time);
    if (gap.inMinutes < 60) return 'Just now';
    if (gap.inHours < 24) return '${gap.inHours}h ago';
    if (gap.inDays == 1) return 'Yesterday';
    return '${gap.inDays} days ago';
  }

  Widget _roundButton(
          {required double size,
          required double iconSize,
          required IconData icon,
          required VoidCallback onTap}) =>
      SizedBox(
          width: size + 12,
          height: size + 12,
          child: Center(
              child: Material(
                  color: AppTheme.blue,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: SizedBox(
                        width: size,
                        height: size,
                        child: Icon(icon, size: iconSize, color: Colors.white)),
                  ))));
}

class _PlayfulHomeBackground extends StatefulWidget {
  const _PlayfulHomeBackground();

  @override
  State<_PlayfulHomeBackground> createState() => _PlayfulHomeBackgroundState();
}

class _PlayfulHomeBackgroundState extends State<_PlayfulHomeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => CustomPaint(
          painter: _HomeBackgroundPainter(_animation.value),
          child: const SizedBox.expand(),
        ),
      );
}

class _HomeBackgroundPainter extends CustomPainter {
  const _HomeBackgroundPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: AppTheme.isSuzu
            ? [
                const Color(0xffffedf4),
                const Color(0xfffff9fb),
                const Color(0xfff8e5ee),
              ]
            : [
                const Color(0xffeaf7ff),
                const Color(0xfffffdf7),
                const Color(0xfffff2d4),
              ],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final cloudAlpha = 0.56 + math.sin(progress * math.pi * 2) * 0.06;
    _drawCloud(
      canvas,
      Offset(size.width * 0.04, size.height * 0.17),
      0.86,
      cloudAlpha,
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.92, size.height * 0.32),
      0.72,
      cloudAlpha - 0.08,
    );

    final orbPaint = Paint();
    final orbs = [
      (Offset(size.width * 0.08, size.height * 0.2), 96.0, 0.0),
      (Offset(size.width * 0.92, size.height * 0.36), 112.0, 0.42),
      (Offset(size.width * 0.12, size.height * 0.82), 132.0, 0.72),
    ];
    for (final (origin, radius, phase) in orbs) {
      final drift = math.sin((progress + phase) * math.pi * 2) * 16;
      final center = origin + Offset(drift, -drift * 0.55);
      orbPaint.shader = RadialGradient(
        colors: [
          AppTheme.primaryContainer.withValues(alpha: 0.12),
          AppTheme.primaryContainer.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, orbPaint);
    }

    final sparkPaint = Paint()..style = PaintingStyle.fill;
    const sparkles = [
      (0.14, 0.12, 0.08),
      (0.84, 0.17, 0.42),
      (0.92, 0.65, 0.7),
      (0.08, 0.58, 0.3),
      (0.74, 0.82, 0.57),
      (0.32, 0.9, 0.18),
      (0.53, 0.08, 0.82),
    ];
    for (final (x, y, phase) in sparkles) {
      final twinkle = (math.sin((progress + phase) * math.pi * 2) + 1) / 2;
      final radius = 1.2 + twinkle * 1.8;
      sparkPaint.color =
          (AppTheme.isSuzu ? const Color(0xffd96694) : const Color(0xffd69a2d))
              .withValues(
        alpha: 0.12 + twinkle * 0.24,
      );
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        radius,
        sparkPaint,
      );
    }
  }

  void _drawCloud(Canvas canvas, Offset center, double scale, double alpha) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0));
    final drift = math.sin((progress + scale) * math.pi * 2) * 8;
    final x = center.dx + drift;
    final y = center.dy;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y + 8 * scale),
        width: 98 * scale,
        height: 30 * scale,
      ),
      paint,
    );
    canvas.drawCircle(Offset(x - 23 * scale, y + 2 * scale), 17 * scale, paint);
    canvas.drawCircle(Offset(x + 1 * scale, y - 7 * scale), 23 * scale, paint);
    canvas.drawCircle(Offset(x + 25 * scale, y + 1 * scale), 17 * scale, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FloatingSparkle extends StatefulWidget {
  const _FloatingSparkle({
    required this.icon,
    required this.color,
    required this.size,
    required this.phase,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double phase;

  @override
  State<_FloatingSparkle> createState() => _FloatingSparkleState();
}

class _FloatingSparkleState extends State<_FloatingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1900 + (widget.phase * 700).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -5 * _animation.value),
          child: Transform.rotate(
            angle: (_animation.value - 0.5) * 0.32,
            child: Opacity(
              opacity: 0.65 + _animation.value * 0.35,
              child: child,
            ),
          ),
        ),
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      );
}

class _FloatingCloud extends StatefulWidget {
  const _FloatingCloud({required this.width, required this.phase});

  final double width;
  final double phase;

  @override
  State<_FloatingCloud> createState() => _FloatingCloudState();
}

class _FloatingCloudState extends State<_FloatingCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 4200 + (widget.phase * 900).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            math.sin((_animation.value + widget.phase) * math.pi) * 7,
            -2 * _animation.value,
          ),
          child: child,
        ),
        child: SizedBox(
          width: widget.width,
          height: widget.width * 0.42,
          child: Stack(
            children: [
              Positioned(
                left: widget.width * 0.08,
                right: widget.width * 0.08,
                bottom: 0,
                child: Container(
                  height: widget.width * 0.2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(widget.width),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff83bada).withValues(alpha: 0.12),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: widget.width * 0.18,
                bottom: widget.width * 0.08,
                child: _cloudPuff(widget.width * 0.27),
              ),
              Positioned(
                left: widget.width * 0.37,
                bottom: widget.width * 0.12,
                child: _cloudPuff(widget.width * 0.37),
              ),
              Positioned(
                right: widget.width * 0.12,
                bottom: widget.width * 0.07,
                child: _cloudPuff(widget.width * 0.25),
              ),
            ],
          ),
        ),
      );

  Widget _cloudPuff(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
      );
}

class _VoiceWaveIndicator extends StatefulWidget {
  const _VoiceWaveIndicator();

  @override
  State<_VoiceWaveIndicator> createState() => _VoiceWaveIndicatorState();
}

class _VoiceWaveIndicatorState extends State<_VoiceWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => SizedBox(
          width: 25,
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(4, (index) {
              final wave = math.sin(
                (_animation.value * math.pi * 2) + (index * 1.15),
              );
              return Container(
                width: 4,
                height: 8 + (wave.abs() * 14),
                decoration: BoxDecoration(
                  color: AppTheme.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      );
}
