abstract class ChatService {
  Future<String> replyTo(String prompt, {String companion = 'milo'});
}
