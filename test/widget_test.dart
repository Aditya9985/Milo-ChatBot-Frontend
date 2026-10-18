import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:milo_companion/main.dart';
import 'package:milo_companion/screens/auth_screen.dart';
import 'package:milo_companion/screens/chat_screen.dart';
import 'package:milo_companion/screens/companion_selection_screen.dart';
import 'package:milo_companion/screens/home_screen.dart';
import 'package:milo_companion/screens/voice_screen.dart';
import 'package:milo_companion/services/api_chat_service.dart';
import 'package:milo_companion/services/app_state.dart';
import 'package:milo_companion/services/service_contracts.dart';
import 'package:milo_companion/theme/app_theme.dart';
import 'package:milo_companion/widgets/milo_avatar.dart';
import 'package:milo_companion/widgets/companion_model_preview.dart';
import 'package:milo_companion/widgets/companion_choice_card.dart';
import 'package:milo_companion/widgets/character_director.dart';
import 'package:milo_companion/widgets/shared_companion_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RetryingChatService implements ChatService {
  int requests = 0;

  @override
  Future<String> replyTo(String prompt, {String companion = 'milo'}) async {
    requests += 1;
    if (requests == 1) {
      throw const ChatServiceException('Connection unavailable.');
    }
    return 'Here is a helpful answer.';
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Firebase bootstrap has directionality before its root stack',
      (tester) async {
    await tester.pumpWidget(const FirebaseBootstrap());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('slot removal notifies listeners after the frame',
      (tester) async {
    final coordinator = SharedCompanionViewerCoordinator();
    final director = CharacterDirector();
    final token = Object();
    coordinator.updateSlot(
      token: token,
      link: LayerLink(),
      characterId: 'milo',
      director: director,
      cameraOrbit: '0deg 78deg 3.9m',
      cameraTarget: '0m 0.68m 0m',
      fieldOfView: '39deg',
      generation: 0,
      width: 100,
      height: 100,
      enabled: true,
      routeActive: true,
    );

    var notifications = 0;
    coordinator.addListener(() => notifications++);
    coordinator.removeSlot(token);

    expect(notifications, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(notifications, 1);

    coordinator.dispose();
    director.dispose();
  });

  testWidgets('multiple MiloApp navigators use independent route observers',
      (tester) async {
    final coordinator = SharedCompanionViewerCoordinator();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Expanded(
              child: MiloApp(
                viewerCoordinator: coordinator,
                home: const Scaffold(),
              ),
            ),
            Expanded(
              child: MiloApp(
                viewerCoordinator: coordinator,
                home: const Scaffold(),
              ),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
  });

  testWidgets('shows the themed Milo startup splash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FirebaseLoadingScreen()),
    );

    expect(find.text('Milo'), findsOneWidget);
    expect(find.text('A little wonder is on its way'), findsOneWidget);
    expect(find.text('Waking up Milo…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MiloAvatar), findsNothing);
  });

  testWidgets('shows the Google-only Milo sign-in screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(enable3dPreview: false)),
    );

    expect(find.text('Meet Milo'), findsOneWidget);
    expect(find.byType(CompanionModelPreview), findsOneWidget);
    expect(find.text('A LITTLE COMPANION, A LOT OF WONDER'), findsOneWidget);
    expect(find.text('A friendly AI companion for curious minds.'),
        findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('password'), findsNothing);
  });

  testWidgets('lets a new user choose and save their companion',
      (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await state.loadPreferences();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MiloApp(
          home: CompanionSelectionScreen(enable3dPreviews: false),
        ),
      ),
    );

    expect(find.text('Choose your companion'), findsOneWidget);
    final selectionTitle = find.text('Choose your companion');
    expect(
      Theme.of(tester.element(selectionTitle)).colorScheme.primary,
      const Color(0xff8a5a00),
    );
    expect(find.text('Milo'), findsOneWidget);
    expect(find.text('Suzu'), findsOneWidget);
    expect(find.byType(CompanionModelPreview), findsNWidgets(2));

    await tester.tap(find.text('Suzu').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      Theme.of(tester.element(selectionTitle)).colorScheme.primary,
      const Color(0xffa83f69),
    );
    expect(
      Theme.of(tester.element(selectionTitle)).scaffoldBackgroundColor,
      const Color(0xfffffbfd),
    );
    await tester.tap(find.text('Enter Suzu’s World'));
    await tester.pumpAndSettle();

    expect(state.companionId, 'suzu');
    expect(
      Theme.of(tester.element(selectionTitle)).colorScheme.primary,
      const Color(0xffa83f69),
    );
  });

  testWidgets('opens the home screen directly with no demo conversations',
      (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await state.loadPreferences();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(home: HomeScreen(enable3dCharacter: false)),
    ));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('“Hi, there! 👋”'), findsOneWidget);
    expect(find.text('Ready for an adventure?'), findsOneWidget);
    final greeting = find.text('“Hi, there! 👋”');
    final greetingTop = tester.getTopLeft(greeting).dy;
    expect(
      find.ancestor(
        of: greeting,
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    final voiceButton = find.text('Tap & talk with Milo');
    final voiceButtonTop = tester.getTopLeft(voiceButton).dy;
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(greeting).dy, greetingTop);
    expect(tester.getTopLeft(voiceButton).dy, lessThan(voiceButtonTop));
    expect(find.text('WONDERWORLD'), findsNothing);
    expect(find.text('KIDS'), findsNothing);
    expect(find.text('Tap & talk with Milo'), findsOneWidget);
    expect(find.text('Pick an adventure!'), findsOneWidget);
    expect(find.text('Space & Stars'), findsOneWidget);
    expect(find.text('Dino Quiz'), findsOneWidget);
    expect(find.text('Magic Ideas'), findsOneWidget);
    expect(find.text('Story Time'), findsOneWidget);
    expect(find.text('RECENT CONVERSATIONS'), findsNothing);
    expect(state.conversations, isEmpty);
    expect(state.messages, isEmpty);
  });

  testWidgets('uses the selected companion name in chat', (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await state.loadPreferences();
    await state.setCompanion('suzu');
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(home: ChatScreen()),
    ));

    expect(find.text('Suzu'), findsOneWidget);
    expect(find.text('Start a conversation with Suzu'), findsOneWidget);
    expect(find.text('Ask Suzu anything...'), findsOneWidget);
  });

  testWidgets('uses the selected companion name on home', (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await state.loadPreferences();
    await state.setCompanion('suzu');
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(home: HomeScreen(enable3dCharacter: false)),
    ));

    expect(find.text('Tap & talk with Suzu'), findsOneWidget);
    expect(find.text('Ask Suzu anything...'), findsOneWidget);
  });

  testWidgets('switches the app palette when the companion changes',
      (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await state.loadPreferences();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(home: HomeScreen(enable3dCharacter: false)),
    ));

    final home = find.byType(HomeScreen);
    expect(Theme.of(tester.element(home)).colorScheme.primary,
        const Color(0xff8a5a00));

    await state.setCompanion('suzu');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(AppTheme.isSuzu, isTrue);
    expect(Theme.of(tester.element(home)).colorScheme.primary,
        const Color(0xffa83f69));
    expect(AppTheme.canvas, const Color(0xfffff6fa));
  });

  test('fits the full voice character to the available viewer area', () {
    expect(VoiceScreen.characterScale, '1 1 1');
    expect(VoiceScreen.characterCameraOrbit, '0deg 78deg 240%');
    expect(VoiceScreen.characterCameraTarget, 'auto auto auto');
    expect(VoiceScreen.characterFieldOfView, 'auto');
  });

  test('frames the Home companion relative to the loaded model bounds', () {
    expect(HomeScreen.characterCameraOrbit, '0deg 78deg 190%');
    expect(HomeScreen.characterCameraTarget, 'auto auto auto');
    expect(HomeScreen.characterFieldOfView, 'auto');
  });

  testWidgets('settings route can read the authenticated app state',
      (tester) async {
    final state = AppState(chatService: _RetryingChatService());
    await state.loadPreferences();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MiloApp(
          home: HomeScreen(
            enable3dCharacter: false,
            enable3dPreviews: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    final previews = tester
        .widgetList<CompanionModelPreview>(find.byType(CompanionModelPreview))
        .toList();
    expect(previews, hasLength(2));
    expect(previews.every((preview) => !preview.enabled), isTrue);
    final choices = tester
        .widgetList<CompanionChoiceCard>(find.byType(CompanionChoiceCard))
        .toList();
    expect(choices, hasLength(2));
    expect(choices.every((choice) => choice.previewUnselected), isTrue);
    expect(
      choices.every((choice) => !choice.useSharedPreviewCoordinator),
      isTrue,
    );
    expect(find.text('Backend & Server'), findsNothing);
    expect(find.text('Voice & Speech'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Microphone access'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Microphone access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry action when chat is unavailable', (tester) async {
    final service = _RetryingChatService();
    final state = AppState(chatService: service);
    await state.loadPreferences();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MiloApp(home: HomeScreen(enable3dCharacter: false)),
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
