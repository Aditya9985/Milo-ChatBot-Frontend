import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'voice_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(AppState state) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    state.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (context, state, _) {
          _scrollToBottom();
          return Scaffold(
            backgroundColor: AppTheme.canvas,
            body: SafeArea(
              child: Column(
                children: [
                  _header(context, state),
                  Expanded(child: _messageList(state)),
                  if (state.chatError != null) _errorBanner(state),
                  _inputArea(state),
                ],
              ),
            ),
          );
        },
      );

  Widget _header(BuildContext context, AppState state) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppTheme.ink,
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.auto_awesome_rounded,
                color: AppTheme.blue, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.companionName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.brightBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'AI companion',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.blue),
              tooltip: 'New Conversation',
              onPressed: () {
                state.newConversation();
                _scrollToBottom();
              },
            ),
          ],
        ),
      );

  Widget _messageList(AppState state) {
    if (state.messages.isEmpty && !state.isBusy) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 44, color: AppTheme.brightBlue),
              const SizedBox(height: 14),
              Text('Start a conversation with ${state.companionName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink)),
              const SizedBox(height: 6),
              const Text('Ask a question or share what is on your mind.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, height: 1.5)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: state.messages.length + (state.isBusy ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) return _thinkingBubble(state);
        final msg = state.messages[index];
        final isUser = msg.author == MessageAuthor.user;
        return _chatBubble(state, msg.text, isUser);
      },
    );
  }

  Widget _errorBanner(AppState state) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Material(
          color: const Color(0xfffff1f0),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Color(0xffb42318), size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.chatError!,
                      style: const TextStyle(
                          color: Color(0xff7a271a), fontSize: 12)),
                ),
                TextButton(
                  onPressed: state.isBusy ? null : state.retryLastMessage,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _chatBubble(AppState state, String text, bool isUser) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.paleBlue,
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppTheme.blue),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppTheme.blue : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: isUser
                      ? null
                      : Border.all(color: const Color(0xffe2e8f0), width: 1),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isUser ? Colors.white : AppTheme.ink,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (!isUser)
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                color: AppTheme.blue,
                tooltip: 'Listen to ${state.companionName}',
                onPressed: () => state.speak(text),
              ),
            if (isUser) const SizedBox(width: 6),
          ],
        ),
      );

  Widget _thinkingBubble(AppState state) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.paleBlue,
              ),
              child: Center(
                child: Icon(Icons.auto_awesome_rounded,
                    size: 18, color: AppTheme.blue),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffe2e8f0), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.blue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${state.companionName} is thinking...',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _inputArea(AppState state) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0a000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xffe2e8f0), width: 1),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !state.isBusy,
                  onSubmitted: (_) => _send(state),
                  style: const TextStyle(fontSize: 15, color: AppTheme.ink),
                  decoration: InputDecoration(
                    hintText: 'Ask ${state.companionName} anything...',
                    hintStyle:
                        const TextStyle(color: AppTheme.muted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: state.isBusy ? null : () => _send(state),
              icon: const Icon(Icons.send_rounded),
              color: AppTheme.blue,
              iconSize: 26,
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VoiceScreen()),
              ),
              icon: const Icon(Icons.mic_rounded),
              color: AppTheme.red,
              iconSize: 26,
            ),
          ],
        ),
      );
}
