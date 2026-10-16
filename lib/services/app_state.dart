import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import 'api_chat_service.dart';
import 'service_contracts.dart';

class AppState extends ChangeNotifier {
  static const _conversationStorageKey = 'milo_conversations';

  AppState({
    ChatService? chatService,
    this.onSignOut,
  }) : chatService = chatService ?? ApiChatService() {
    _initTts();
  }

  final ChatService chatService;
  final Future<void> Function()? onSignOut;
  final FlutterTts flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<Conversation> conversations = [];
  List<ChatMessage> messages = [];
  bool isBusy = false;
  bool isOffline = false;
  bool isReady = false;
  bool isSpeaking = false;
  String spokenWord = '';
  bool ttsEnabled = true;
  bool isServerConnected = false;
  String serverModel = 'gpt-5.4-nano';
  String backendUrl = ApiChatService.defaultBaseUrl;
  CompanionMood mood = CompanionMood.happy;
  String? chatError;
  String? _failedPrompt;
  Future<void>? _readyFuture;
  bool _disposed = false;

  ApiChatService? get _apiService =>
      chatService is ApiChatService ? (chatService as ApiChatService) : null;

  Future<void> _initTts() async {
    try {
      await flutterTts.setPitch(1.12);
      await flutterTts.setSpeechRate(0.44);
      flutterTts.setProgressHandler((text, start, end, word) {
        spokenWord = word;
        isSpeaking = true;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('TTS initialization notice: $e');
    }
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

    try {
      final api = _apiService;
      if (api == null) {
        throw const ChatServiceException(
          'The configured chat service does not support speech generation.',
        );
      }
      final audio = await api.synthesizeSpeech(text);
      await _audioPlayer.stop();
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(audio, mimeType: 'audio/mpeg')),
      );
      isSpeaking = true;
      setMood(CompanionMood.talking);
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
      if (!_disposed) setMood(CompanionMood.happy);
      onComplete?.call();
    }
  }

  Future<void> _speakOnDevice(String text) async {
    final completed = Completer<void>();
    flutterTts.setStartHandler(() {
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
    try {
      await _audioPlayer.stop();
      await flutterTts.stop();
    } catch (error) {
      debugPrint('Could not stop speech playback: $error');
    }
    isSpeaking = false;
    spokenWord = '';
    setMood(CompanionMood.happy);
  }

  Future<void> checkServerHealth() async {
    final api = _apiService;
    if (api != null) {
      final info = await api.checkHealth();
      if (info != null && info['status'] == 'ok') {
        isServerConnected = true;
        serverModel = info['model']?.toString() ?? 'gpt-5.4-nano';
        isOffline = false;
      } else {
        isServerConnected = false;
        isOffline = true;
      }
      notifyListeners();
    }
  }

  Future<void> setBackendUrl(String url) async {
    backendUrl = url.trim();
    final api = _apiService;
    if (api != null) {
      api.setBaseUrl(backendUrl);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', backendUrl);
    await checkServerHealth();
  }

  Future<void> sendMessage(String text, {bool readAloud = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isBusy) return;

    messages = [
      ...messages,
      ChatMessage(text: trimmed, author: MessageAuthor.user)
    ];
    isBusy = true;
    mood = CompanionMood.thinking;
    notifyListeners();

    chatError = null;
    _failedPrompt = null;
    String reply;
    try {
      reply = await chatService.replyTo(trimmed);
    } on ChatServiceException catch (error) {
      chatError = error.message;
      _failedPrompt = trimmed;
      isBusy = false;
      mood = CompanionMood.happy;
      notifyListeners();
      return;
    }
    messages = [
      ...messages,
      ChatMessage(text: reply, author: MessageAuthor.assistant)
    ];

    _recordActiveConversation(trimmed);

    isBusy = false;
    notifyListeners();

    if (readAloud && ttsEnabled) {
      await speak(reply);
    } else {
      mood = CompanionMood.talking;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mood == CompanionMood.talking) {
        mood = CompanionMood.happy;
        notifyListeners();
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
    messages = List.from(conv.messages);
    mood = CompanionMood.happy;
    notifyListeners();
  }

  void newConversation() {
    stopSpeaking();
    messages = [];
    chatError = null;
    _failedPrompt = null;
    mood = CompanionMood.happy;
    notifyListeners();
  }

  Future<void> retryLastMessage() async {
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
    mood = value;
    notifyListeners();
  }

  void deleteConversation(String id) {
    conversations.removeWhere((item) => item.id == id);
    notifyListeners();
    unawaited(_persistConversations());
  }

  Future<void> loadPreferences() => _readyFuture ??= _loadPreferences();

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restoreConversations(prefs.getString(_conversationStorageKey));
      ttsEnabled = prefs.getBool('tts_enabled') ?? true;
      final savedUrl = prefs.getString('backend_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        backendUrl = _isLegacyLocalBackendUrl(savedUrl)
            ? ApiChatService.defaultBaseUrl
            : savedUrl;
        _apiService?.setBaseUrl(backendUrl);
        if (backendUrl != savedUrl) {
          await prefs.setString('backend_url', backendUrl);
        }
      } else {
        backendUrl =
            _apiService?.currentBaseUrl ?? ApiChatService.defaultBaseUrl;
      }
      await checkServerHealth();
    } catch (error, stackTrace) {
      debugPrint('Could not load Milo preferences: $error\n$stackTrace');
    } finally {
      isReady = true;
      notifyListeners();
    }
  }

  bool _isLegacyLocalBackendUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.port == 8000 &&
        const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
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
    ttsEnabled = value;
    if (!value) {
      await stopSpeaking();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled', value);
  }

  Future<void> signOut() async {
    await onSignOut?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_audioPlayer.dispose());
    unawaited(flutterTts.stop());
    super.dispose();
  }
}
