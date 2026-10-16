import 'package:flutter_test/flutter_test.dart';
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
}
