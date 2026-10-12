import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/milo_avatar.dart';
import 'chat_screen.dart';
import 'history_screen.dart';

import 'settings_screen.dart';
import 'voice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final query = TextEditingController();

  @override
  void dispose() {
    query.dispose();
    super.dispose();
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
            body: SafeArea(
          child: Column(children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: Column(children: [
                  _hero(state.mood),
                  const SizedBox(height: 20),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _search()),
                  const SizedBox(height: 16),
                  _voiceButton(),
                  const SizedBox(height: 24),
                  if (recents.isNotEmpty) ...[
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _sectionLabel('RECENT CONVERSATIONS',
                            onViewAll: () => _open(const HistoryScreen()))),
                    const SizedBox(height: 8),
                    ...recents.map((item) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _conversationCard(item))),
                  ] else
                    _starterPrompts(),
                ]),
              ),
            ),
            _nav(),
          ]),
        ));
      });

  Widget _header() => Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: AppTheme.canvas, boxShadow: [
        BoxShadow(color: Color(0x0a000000), blurRadius: 8, offset: Offset(0, 1))
      ]),
      child: Row(children: [
        const Icon(Icons.auto_awesome_rounded, color: AppTheme.blue, size: 28),
        const SizedBox(width: 8),
        Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Milo',
                  style: _style(18, FontWeight.w600, AppTheme.ink,
                      tracking: -0.45, leading: 18)),
              Text('Home',
                  style: _style(11, FontWeight.w700, AppTheme.blue,
                      tracking: 0.275, leading: 13.75)),
            ])),
        _roundButton(
            size: 32,
            iconSize: 16,
            icon: Icons.settings_rounded,
            onTap: () => _open(const SettingsScreen())),
      ]));

  Widget _hero(CompanionMood mood) => Column(children: [
        SizedBox(
            width: 208,
            height: 208,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                  width: 192,
                  height: 192,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66cee5ff), Color(0x00cee5ff)]))),
              Container(
                width: 176,
                height: 176,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: MiloAvatar(size: 144, mood: mood),
              ),
            ])),
        const SizedBox(height: 12),
        Text("Hi, I'm Milo.",
            textAlign: TextAlign.center,
            style: _style(22, FontWeight.w700, AppTheme.ink,
                tracking: -0.55, leading: 28)),
        const SizedBox(height: 4),
        Text('What would you like to know today?',
            textAlign: TextAlign.center,
            style: _style(14, FontWeight.w400, AppTheme.subtle, leading: 20)),
      ]);

  Widget _starterPrompts() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A good place to start',
                style: _style(15, FontWeight.w700, AppTheme.ink)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Explain something tricky',
                'Help me plan my day',
                'Tell me a fun fact',
              ]
                  .map((prompt) => ActionChip(
                        label: Text(prompt),
                        onPressed: () => _ask(prompt),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.paleBlue),
                        labelStyle: const TextStyle(
                            color: AppTheme.ink, fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _search() => Container(
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
              hintText: 'Ask Milo anything...',
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

  Widget _voiceButton() => Center(
        child: Material(
          color: AppTheme.wash,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _open(const VoiceScreen()),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppTheme.brightBlue),
                    child: const Icon(Icons.mic_rounded,
                        size: 19, color: Color(0xfffdfcff))),
                const SizedBox(width: 12),
                Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tap to talk',
                          style: _style(14, FontWeight.w700, AppTheme.ink,
                              tracking: 0.14, leading: 17.5)),
                      Text('Voice Assistant',
                          style: _style(11, FontWeight.w700, AppTheme.blue,
                              tracking: 0.44, leading: 11)),
                    ]),
              ]),
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

  Widget _conversationCard(Conversation item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(const ChatScreen()),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0d000000),
                  blurRadius: 2,
                  offset: Offset(0, 1)),
            ],
          ),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppTheme.paleBlue),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 20, color: Color(0xff004a75))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(14, FontWeight.w600, AppTheme.ink,
                          leading: 20)),
                  const SizedBox(height: 0),
                  Text(_ago(item.updatedAt),
                      style: _style(11, FontWeight.w700, AppTheme.muted,
                          tracking: 0.44, leading: 14)),
                ])),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xffbfc7d3)),
          ]),
        ),
      ),
    );
  }

  Widget _nav() => Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 70.67),
      decoration: const BoxDecoration(color: AppTheme.canvas, boxShadow: [
        BoxShadow(
            color: Color(0x0f0288d1), blurRadius: 20, offset: Offset(0, -4)),
        BoxShadow(
            color: Color(0x0a000000), blurRadius: 8, offset: Offset(0, -1)),
      ]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _navItem('Chat', Icons.chat_bubble_outline_rounded, 20,
            () => _open(const ChatScreen())),
        _navItem('History', Icons.history_rounded, 18,
            () => _open(const HistoryScreen())),
      ]));

  Widget _navItem(
          String label, IconData icon, double iconSize, VoidCallback onTap) =>
      GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.only(top: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: iconSize, color: AppTheme.subtle),
              const SizedBox(height: 2),
              Text(label,
                  style: _style(12, FontWeight.w600, AppTheme.subtle,
                      tracking: 0.24, leading: 16)),
            ]),
          ));

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

  static String _ago(DateTime time) {
    final gap = DateTime.now().difference(time);
    if (gap.inMinutes < 60) return 'Just now';
    if (gap.inHours < 24) return '${gap.inHours}h ago';
    if (gap.inDays == 1) return 'Yesterday';
    return '${gap.inDays} days ago';
  }
}
