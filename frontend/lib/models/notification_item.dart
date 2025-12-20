import 'package:frontend/models/user.dart';

class NotificationItem {
  final String id;
  final String type;
  final String message;
  final DateTime createdAt;
  final User? fromUser;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.fromUser,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final from = json['fromUser'];

    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fromUser: from is Map<String, dynamic>
          ? User.fromJson(from)
          : from is Map
          ? User.fromJson(from.cast<String, dynamic>())
          : null,
    );
  }
}
