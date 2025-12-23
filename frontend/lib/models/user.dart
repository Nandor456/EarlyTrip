class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePicture;
  final bool isDarkTheme;

  User({
    required this.id,
    required this.email,
    this.profilePicture,
    this.firstName = '',
    this.lastName = '',
    this.isDarkTheme = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawTheme = json['is_dark_theme'];
    final parsedIsDark = rawTheme is bool
        ? rawTheme
        : rawTheme is String
        ? rawTheme.toLowerCase() == 'true'
        : true;

    return User(
      id: json['user_id'].toString(),
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      profilePicture: json['profile_pic_url'],
      isDarkTheme: parsedIsDark,
    );
  }

  String getInitials() {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  String get fullName => '$firstName $lastName'.trim();
}
