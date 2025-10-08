class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePicture;

  User({
    required this.id,
    required this.email,
    this.profilePicture,
    this.firstName = '',
    this.lastName = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'].toString(),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      profilePicture: json['profile_pic_url'],
    );
  }

  String getInitials() {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  String get fullName => '$firstName $lastName'.trim();
}
