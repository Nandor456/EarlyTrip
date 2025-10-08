class ChatGroup {
  final String id;
  final String name;
  final String? groupImage;
  final String adminId;
  final DateTime createdAt;

  ChatGroup({
    required this.id,
    required this.name,
    this.groupImage,
    required this.adminId,
    required this.createdAt,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['group_id'].toString(),
      name: json['name'] ?? '',
      groupImage: json['group_image'],
      adminId: json['admin_id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
