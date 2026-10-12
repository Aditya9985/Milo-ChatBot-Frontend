import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'service_contracts.dart';

class ChatServiceException implements Exception {
  const ChatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiChatService implements ChatService {
  ApiChatService({String? baseUrl}) : _customBaseUrl = baseUrl;

  String? _customBaseUrl;

  void setBaseUrl(String url) {
    _customBaseUrl = url.trim();
  }

  String get currentBaseUrl {
    final custom = _customBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    // Android emulator loops back to host machine via 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    // iOS simulator or macOS desktop or web
    return 'http://127.0.0.1:8000';
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

  @override
  Future<String> replyTo(String prompt) async {
    try {
      final uri = Uri.parse('$currentBaseUrl/chat');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': prompt}),
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
}
