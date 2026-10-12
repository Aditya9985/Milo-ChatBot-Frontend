import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

class LiveVoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool isListening = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (err) {
          debugPrint('LiveVoice STT Error: ${err.errorMsg}');
          isListening = false;
        },
        onStatus: (status) {
          debugPrint('LiveVoice STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            isListening = false;
          }
        },
      );
    } catch (e) {
      debugPrint('LiveVoice STT Exception: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String words, bool isFinal) onResult,
    required VoidCallback onDone,
  }) async {
    final ready = await initialize();
    if (!ready) {
      debugPrint('Speech recognition not available on this platform/device');
      onDone();
      return;
    }

    try {
      isListening = true;
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            isListening = false;
            onDone();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(milliseconds: 2200),
          cancelOnError: true,
        ),
      );
    } catch (e) {
      debugPrint('LiveVoice listen error: $e');
      isListening = false;
      onDone();
    }
  }

  Future<void> stopListening() async {
    isListening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
