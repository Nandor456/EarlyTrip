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
    MessageType messageType;
    switch (json['type']) {
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
      id: json['message_id'].toString(),
      senderId: json['sender_id'].toString(),
      content: json['content'] ?? '',
      type: messageType,
      timestamp: DateTime.parse(json['timestamp']),
      mediaUrl: json['media_url'],
    );
  }
}

enum MessageType { text, image, document }
