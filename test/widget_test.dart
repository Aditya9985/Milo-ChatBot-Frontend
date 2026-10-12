import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:milo_companion/main.dart';
import 'package:milo_companion/screens/chat_screen.dart';
import 'package:milo_companion/screens/home_screen.dart';
import 'package:milo_companion/services/api_chat_service.dart';
import 'package:milo_companion/services/app_state.dart';
import 'package:milo_companion/services/service_contracts.dart';

class _RetryingChatService implements ChatService {
  int requests = 0;

  @override
  Future<String> replyTo(String prompt) async {
    requests += 1;
    if (requests == 1) {
      throw const ChatServiceException('Connection unavailable.');
    }
    return 'Here is a helpful answer.';
  }
}

void main() {
  testWidgets('opens the home screen directly with no demo conversations',
      (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(),
    ));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text("Hi, I'm Milo."), findsOneWidget);
    expect(find.text('A good place to start'), findsOneWidget);
    expect(find.text('RECENT CONVERSATIONS'), findsNothing);
    expect(state.conversations, isEmpty);
    expect(state.messages, isEmpty);
  });

  testWidgets('shows a retry action when chat is unavailable', (tester) async {
    final service = _RetryingChatService();
    final state = AppState(chatService: service);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(),
    ));

    await tester.enterText(
        find.byType(TextField).first, 'Explain something tricky');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Connection unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.requests, 2);
    expect(find.text('Here is a helpful answer.'), findsOneWidget);
  });
}
