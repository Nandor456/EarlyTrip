class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.mediaUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? json['message_type'])?.toString();

    MessageType messageType;
    switch (rawType) {
      case 'image':
        messageType = MessageType.image;
        break;
      case 'document':
        messageType = MessageType.document;
        break;
      default:
        messageType = MessageType.text;
    }

    return Message(
      id: (json['message_id'] ?? json['id']).toString(),
      senderId: (json['sender_id'] ?? json['senderId']).toString(),
      content: json['content'] ?? '',
      type: messageType,
      timestamp: DateTime.parse(json['timestamp']),
      mediaUrl: (json['media_url'] ?? json['mediaUrl'])?.toString(),
    );
  }
}

enum MessageType { text, image, document }
