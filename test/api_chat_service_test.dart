import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:milo_companion/services/api_chat_service.dart';

void main() {
  test('uses the deployed backend URL by default', () {
    expect(
      ApiChatService().currentBaseUrl,
      'https://milo-chatbot-backend.onrender.com',
    );
  });

  test('allows a custom backend URL', () {
    final service = ApiChatService(baseUrl: 'https://example.com');

    expect(service.currentBaseUrl, 'https://example.com');
  });

  test('sends Suzu selection to backend speech generation', () async {
    Map<String, dynamic>? receivedBody;
    final audio = await http.runWithClient(
      () => ApiChatService(
        sessionTokenProvider: () async => 'firebase-token',
      ).synthesizeSpeech('Hello there', companion: 'suzu'),
      () => MockClient((request) async {
        receivedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      }),
    );

    expect(receivedBody, {'text': 'Hello there', 'companion': 'suzu'});
    expect(audio, [1, 2, 3]);
  });
}
