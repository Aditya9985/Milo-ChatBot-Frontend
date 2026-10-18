import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'service_contracts.dart';

typedef SessionTokenProvider = Future<String?> Function();

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiChatService implements ChatService {
  static const defaultBaseUrl = 'https://milo-chatbot-backend.onrender.com';

  ApiChatService({String? baseUrl, this.sessionTokenProvider})
      : _customBaseUrl = baseUrl;

  String? _customBaseUrl;
  final SessionTokenProvider? sessionTokenProvider;

  void setBaseUrl(String url) {
    _customBaseUrl = url.trim();
  }

  String get currentBaseUrl {
    final custom = _customBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return defaultBaseUrl;
  }

  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final uri = Uri.parse('$currentBaseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Health check failed: $e');
    }
    return null;
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await sessionTokenProvider?.call();
    if (token == null || token.isEmpty) {
      throw const ChatServiceException('Sign in to use your companion.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<String> replyTo(String prompt, {String companion = 'milo'}) async {
    try {
      final uri = Uri.parse('$currentBaseUrl/chat');
      final response = await http
          .post(
            uri,
            headers: await _authorizedHeaders(),
            body: jsonEncode({'message': prompt, 'companion': companion}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('response') && data['response'] != null) {
          return data['response'].toString();
        }
      }
      throw ChatServiceException(
        'The AI service returned an unexpected response '
        '(HTTP ${response.statusCode}). Please try again.',
      );
    } on ChatServiceException {
      rethrow;
    } catch (error) {
      debugPrint('ApiChatService request failed: $error');
      throw const ChatServiceException(
        'Could not reach the AI service. Check your connection and try again.',
      );
    }
  }

  Future<Uint8List> synthesizeSpeech(
    String text, {
    String companion = 'milo',
  }) async {
    try {
      final uri = Uri.parse('$currentBaseUrl/tts');
      final response = await http
          .post(
            uri,
            headers: await _authorizedHeaders(),
            body: jsonEncode({'text': text, 'companion': companion}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 &&
          response.headers['content-type']?.startsWith('audio/') == true &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      throw ChatServiceException(
        'The companion voice service returned an unexpected response '
        '(HTTP ${response.statusCode}).',
      );
    } on ChatServiceException {
      rethrow;
    } catch (error) {
      debugPrint('ApiChatService speech request failed: $error');
      throw const ChatServiceException(
        'Could not generate the companion’s voice. Check your connection and try again.',
      );
    }
  }
}
