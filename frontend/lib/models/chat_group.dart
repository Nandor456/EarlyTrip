class ChatGroup {
  final String id;
  final String name;
  final String? displayName;
  final int? memberCount;
  final String? groupImage;
  final String? directProfilePicUrl;
  final String adminId;
  final DateTime createdAt;

  ChatGroup({
    required this.id,
    required this.name,
    this.displayName,
    this.memberCount,
    this.groupImage,
    this.directProfilePicUrl,
    required this.adminId,
    required this.createdAt,
  });

  String get title {
    final v = (displayName ?? '').trim();
    return v.isNotEmpty ? v : name;
  }

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['group_id'].toString(),
      name: json['name'] ?? '',
      displayName: json['display_name']?.toString(),
      memberCount: json['member_count'] is int
          ? json['member_count'] as int
          : int.tryParse(json['member_count']?.toString() ?? ''),
      groupImage: json['group_image'],
      directProfilePicUrl: json['direct_profile_pic_url']?.toString(),
      adminId: json['admin_id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
