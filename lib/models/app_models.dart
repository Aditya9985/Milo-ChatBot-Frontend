enum CompanionMood { happy, listening, thinking, talking }

enum MessageAuthor { user, assistant }

class ChatMessage {
  const ChatMessage({required this.text, required this.author, this.time});
  final String text;
  final MessageAuthor author;
  final DateTime? time;
}

class Conversation {
  Conversation(
      {required this.id,
      required this.title,
      required this.messages,
      required this.updatedAt});
  final String id;
  final String title;
  final List<ChatMessage> messages;
  DateTime updatedAt;
}
