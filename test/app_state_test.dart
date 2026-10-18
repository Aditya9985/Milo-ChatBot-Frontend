import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:milo_companion/services/app_state.dart';
import 'package:milo_companion/services/service_contracts.dart';

class _PendingChatService implements ChatService {
  final Completer<String> reply = Completer<String>();

  @override
  Future<String> replyTo(String prompt, {String companion = 'milo'}) =>
      reply.future;
}

Map<String, Object> _conversation(String id, String title) => {
      'id': id,
      'title': title,
      'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      'messages': <Object>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(ttsChannel, (_) async => null);

  test(
      'conversation history is isolated by account and drops shared legacy data',
      () async {
    SharedPreferences.setMockInitialValues({
      'milo_conversations':
          jsonEncode([_conversation('legacy', 'Old shared chat')]),
      'milo_conversations_alice': jsonEncode([
        _conversation('alice-chat', 'Alice’s chat'),
      ]),
      'milo_conversations_bob': jsonEncode([
        _conversation('bob-chat', 'Bob’s chat'),
      ]),
      'milo_companion_character_alice': 'suzu',
      'milo_companion_character_bob': 'milo',
    });

    final alice = AppState(userId: 'alice');
    await alice.loadPreferences();
    expect(
      alice.conversations.map((conversation) => conversation.title),
      ['Alice’s chat'],
    );
    expect(alice.companionId, 'suzu');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('milo_conversations'), isFalse);

    final bob = AppState(userId: 'bob');
    await bob.loadPreferences();
    expect(
      bob.conversations.map((conversation) => conversation.title),
      ['Bob’s chat'],
    );
    expect(bob.companionId, 'milo');

    alice.dispose();
    bob.dispose();
  });

  test('ignores chat completion after AppState is disposed', () async {
    SharedPreferences.setMockInitialValues({});
    final chatService = _PendingChatService();
    final state = AppState(chatService: chatService);
    final request = state.sendMessage('Hello');

    state.dispose();
    chatService.reply.complete('Hi there');

    await expectLater(request, completes);
  });

  test('does not notify listeners when preferences load after disposal',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final load = state.loadPreferences();

    state.dispose();

    await expectLater(load, completes);
  });
}
