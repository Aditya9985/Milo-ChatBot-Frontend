import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import 'api_chat_service.dart';
import 'service_contracts.dart';

class AppState extends ChangeNotifier {
  static const _legacyConversationStorageKey = 'milo_conversations';
  static const _conversationStorageKeyPrefix = 'milo_conversations_';
  static const _companionPreferenceKeyPrefix = 'milo_companion_character_';
  static const availableCompanions = {'milo', 'suzu'};

  AppState({
    ChatService? chatService,
    this.onSignOut,
    this.accountUser,
    this.userId,
  }) : chatService = chatService ?? ApiChatService() {
    _initTts();
    _audioPositionSubscription =
        _audioPlayer.positionStream.listen(_updateSpeechProgress);
  }

  final ChatService chatService;
  final Future<void> Function()? onSignOut;
  final User? accountUser;
  final String? userId;
  final FlutterTts flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final StreamSubscription<Duration> _audioPositionSubscription;

  final List<Conversation> conversations = [];
  List<ChatMessage> messages = [];
  bool isBusy = false;
  bool isReady = false;
  bool isSpeaking = false;
  String spokenWord = '';
  String speechText = '';
  double speechProgress = 0;
  String? companionId;
  bool ttsEnabled = true;
  CompanionMood mood = CompanionMood.happy;
  String? chatError;
  String? _failedPrompt;
  Future<void>? _readyFuture;
  bool _disposed = false;

  ApiChatService? get _apiService =>
      chatService is ApiChatService ? (chatService as ApiChatService) : null;

  String get _conversationStorageKey => conversationStorageKeyForUser(
        userId ?? accountUser?.uid ?? 'guest',
      );

  String get _companionPreferenceKey =>
      '$_companionPreferenceKeyPrefix${userId ?? accountUser?.uid ?? 'guest'}';

  String get companionName => companionId == 'suzu' ? 'Suzu' : 'Milo';

  String get companionModelAsset => companionId == 'suzu'
      ? 'assets/grab3d-cozy-character-girl.glb'
      : 'assets/grab3d-cozy-character.glb';

  @visibleForTesting
  static String conversationStorageKeyForUser(String userId) =>
      '$_conversationStorageKeyPrefix$userId';

  void _notifyListenersIfAlive() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _initTts() async {
    try {
      await flutterTts.setPitch(1.12);
      await flutterTts.setSpeechRate(0.44);
      if (_disposed) return;
      flutterTts.setProgressHandler((text, start, end, word) {
        if (_disposed) return;
        spokenWord = word;
        isSpeaking = true;
        _notifyListenersIfAlive();
      });
    } catch (e) {
      debugPrint('TTS initialization notice: $e');
    }
  }

  void _updateSpeechProgress(Duration position) {
    if (_disposed || !isSpeaking) return;
    final duration = _audioPlayer.duration;
    if (duration == null || duration.inMilliseconds <= 0) return;
    final progress =
        (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    if ((progress - speechProgress).abs() < 0.01) return;
    speechProgress = progress;
    _notifyListenersIfAlive();
  }

  Future<void> speak(String text) async {
    if (!ttsEnabled) return;
    await _speakWithFallback(_cleanSpeechText(text));
  }

  Future<void> speakWithCallback(String text,
      {required VoidCallback onComplete}) async {
    if (!ttsEnabled) {
      onComplete();
      return;
    }
    await _speakWithFallback(
      _cleanSpeechText(text),
      onComplete: onComplete,
    );
  }

  String _cleanSpeechText(String text) => text
      .replaceAll(RegExp(r'[*#_`~>\[\]]'), '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .trim();

  Future<void> _speakWithFallback(
    String text, {
    VoidCallback? onComplete,
  }) async {
    if (text.isEmpty) {
      onComplete?.call();
      return;
    }
    if (_disposed) return;

    speechText = text;
    speechProgress = 0;
    spokenWord = '';
    try {
      final api = _apiService;
      if (api == null) {
        throw const ChatServiceException(
          'The configured chat service does not support speech generation.',
        );
      }
      final audio =
          await api.synthesizeSpeech(text, companion: companionId ?? 'milo');
      if (_disposed) return;
      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(audio, mimeType: 'audio/mpeg')),
      );
      if (_disposed) return;
      isSpeaking = true;
      setMood(CompanionMood.talking);
      _notifyListenersIfAlive();
      await _audioPlayer.play();
    } catch (error) {
      debugPrint('Backend speech generation failed; using device TTS: $error');
      try {
        await _speakOnDevice(text);
      } catch (fallbackError) {
        debugPrint('Device speech fallback failed: $fallbackError');
      }
    } finally {
      isSpeaking = false;
      spokenWord = '';
      speechProgress = 1;
      if (!_disposed) setMood(CompanionMood.happy);
      if (!_disposed) onComplete?.call();
    }
  }

  Future<void> _speakOnDevice(String text) async {
    final completed = Completer<void>();
    await flutterTts.setPitch(companionId == 'suzu' ? 1.18 : 1.12);
    if (_disposed) return;
    flutterTts.setStartHandler(() {
      if (_disposed) return;
      isSpeaking = true;
      setMood(CompanionMood.talking);
    });
    flutterTts.setCompletionHandler(() {
      if (!completed.isCompleted) completed.complete();
    });
    flutterTts.setErrorHandler((message) {
      if (!completed.isCompleted) {
        completed.completeError(
          StateError('Device speech failed: $message'),
        );
      }
    });
    await flutterTts.stop();
    await flutterTts.speak(text);
    await completed.future;
  }

  Future<void> stopSpeaking() async {
    if (_disposed) return;
    try {
      await _audioPlayer.stop();
      await flutterTts.stop();
    } catch (error) {
      debugPrint('Could not stop speech playback: $error');
    }
    if (_disposed) return;
    isSpeaking = false;
    spokenWord = '';
    speechProgress = 0;
    setMood(CompanionMood.happy);
  }

  Future<void> sendMessage(String text, {bool readAloud = false}) async {
    final trimmed = text.trim();
    if (_disposed || trimmed.isEmpty || isBusy) return;

    messages = [
      ...messages,
      ChatMessage(text: trimmed, author: MessageAuthor.user)
    ];
    isBusy = true;
    mood = CompanionMood.thinking;
    _notifyListenersIfAlive();

    chatError = null;
    _failedPrompt = null;
    String reply;
    try {
      reply = await chatService.replyTo(
        trimmed,
        companion: companionId ?? 'milo',
      );
      if (_disposed) return;
    } on ChatServiceException catch (error) {
      if (_disposed) return;
      chatError = error.message;
      _failedPrompt = trimmed;
      isBusy = false;
      mood = CompanionMood.happy;
      _notifyListenersIfAlive();
      return;
    }
    messages = [
      ...messages,
      ChatMessage(text: reply, author: MessageAuthor.assistant)
    ];

    _recordActiveConversation(trimmed);

    isBusy = false;
    _notifyListenersIfAlive();

    if (readAloud && ttsEnabled) {
      await speak(reply);
    } else {
      if (_disposed) return;
      mood = CompanionMood.talking;
      _notifyListenersIfAlive();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!_disposed && mood == CompanionMood.talking) {
        mood = CompanionMood.happy;
        _notifyListenersIfAlive();
      }
    }
  }

  void _recordActiveConversation(String userPrompt) {
    final title = userPrompt.length > 32
        ? '${userPrompt.substring(0, 32)}...'
        : userPrompt;
    final conv = Conversation(
      id: 'conv-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      updatedAt: DateTime.now(),
      messages: List.from(messages),
    );
    conversations.insert(0, conv);
    unawaited(_persistConversations());
  }

  void openConversation(Conversation conv) {
    if (_disposed) return;
    messages = List.from(conv.messages);
    mood = CompanionMood.happy;
    _notifyListenersIfAlive();
  }

  void newConversation() {
    if (_disposed) return;
    stopSpeaking();
    messages = [];
    chatError = null;
    _failedPrompt = null;
    mood = CompanionMood.happy;
    _notifyListenersIfAlive();
  }

  Future<void> retryLastMessage() async {
    if (_disposed) return;
    final prompt = _failedPrompt;
    if (prompt != null && !isBusy) {
      if (messages.isNotEmpty &&
          messages.last.author == MessageAuthor.user &&
          messages.last.text == prompt) {
        messages.removeLast();
      }
      await sendMessage(prompt);
    }
  }

  void setMood(CompanionMood value) {
    if (_disposed) return;
    mood = value;
    _notifyListenersIfAlive();
  }

  void deleteConversation(String id) {
    if (_disposed) return;
    conversations.removeWhere((item) => item.id == id);
    _notifyListenersIfAlive();
    unawaited(_persistConversations());
  }

  Future<void> loadPreferences() => _readyFuture ??= _loadPreferences();

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyConversationStorageKey);
      _restoreConversations(prefs.getString(_conversationStorageKey));
      ttsEnabled = prefs.getBool('tts_enabled') ?? true;
      final savedCompanion = prefs.getString(_companionPreferenceKey);
      if (savedCompanion != null &&
          availableCompanions.contains(savedCompanion)) {
        companionId = savedCompanion;
      }
      await prefs.remove('backend_url');
    } catch (error, stackTrace) {
      debugPrint('Could not load Milo preferences: $error\n$stackTrace');
    } finally {
      if (!_disposed) {
        isReady = true;
        _notifyListenersIfAlive();
      }
    }
  }

  void _restoreConversations(String? serialized) {
    if (serialized == null || serialized.isEmpty) return;
    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! List) {
        throw const FormatException('Conversation history is not a list.');
      }
      conversations
        ..clear()
        ..addAll(decoded.map(_conversationFromJson));
    } on FormatException catch (error) {
      debugPrint('Saved conversation history could not be loaded: $error');
    } catch (error) {
      debugPrint('Saved conversation history could not be loaded: $error');
    }
  }

  Conversation _conversationFromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Conversation entry is not an object.');
    }
    final entry = Map<String, dynamic>.from(value);
    final id = entry['id'];
    final title = entry['title'];
    final updatedAtText = entry['updatedAt'];
    final rawMessages = entry['messages'];
    final updatedAt =
        updatedAtText is String ? DateTime.tryParse(updatedAtText) : null;
    if (id is! String ||
        title is! String ||
        updatedAt == null ||
        rawMessages is! List) {
      throw const FormatException('Conversation entry has invalid fields.');
    }
    final restoredMessages = rawMessages.map((rawMessage) {
      if (rawMessage is! Map) {
        throw const FormatException('Chat message is not an object.');
      }
      final message = Map<String, dynamic>.from(rawMessage);
      final text = message['text'];
      final authorName = message['author'];
      final author = switch (authorName) {
        'user' => MessageAuthor.user,
        'assistant' => MessageAuthor.assistant,
        _ => null,
      };
      if (text is! String || author == null) {
        throw const FormatException('Chat message has invalid fields.');
      }
      return ChatMessage(text: text, author: author);
    }).toList();
    return Conversation(
      id: id,
      title: title,
      updatedAt: updatedAt,
      messages: restoredMessages,
    );
  }

  Future<void> _persistConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _conversationStorageKey,
        jsonEncode(conversations
            .map((conversation) => {
                  'id': conversation.id,
                  'title': conversation.title,
                  'updatedAt': conversation.updatedAt.toIso8601String(),
                  'messages': conversation.messages
                      .map((message) => {
                            'text': message.text,
                            'author': message.author.name,
                          })
                      .toList(),
                })
            .toList()),
      );
    } catch (error) {
      debugPrint('Could not save conversation history: $error');
    }
  }

  Future<void> setTtsEnabled(bool value) async {
    if (_disposed) return;
    ttsEnabled = value;
    if (!value) {
      await stopSpeaking();
    }
    if (_disposed) return;
    _notifyListenersIfAlive();
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.setBool('tts_enabled', value);
  }

  Future<void> setCompanion(String value) async {
    if (_disposed) return;
    if (!availableCompanions.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unknown Milo companion.');
    }
    if (companionId == value) return;

    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.setString(_companionPreferenceKey, value);
    if (_disposed) return;
    companionId = value;
    _notifyListenersIfAlive();
  }

  Future<void> signOut() async {
    if (_disposed) return;
    await onSignOut?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_audioPositionSubscription.cancel());
    unawaited(_audioPlayer.dispose());
    unawaited(flutterTts.stop());
    super.dispose();
  }
}
