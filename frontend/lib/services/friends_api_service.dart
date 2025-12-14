import 'dart:convert';

import 'package:frontend/models/user.dart';
import 'package:frontend/services/api_service.dart';

class FriendsApiService {
  static Future<List<User>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final encoded = Uri.encodeQueryComponent(trimmed);
    final response = await ApiService.authenticatedRequest(
      '/users/search?query=$encoded',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final users = (data['users'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();
      return users;
    }

    throw ApiException('Failed to search users', response.statusCode);
  }

  static Future<void> sendFriendRequest(String targetUserId) async {
    final response = await ApiService.authenticatedRequest(
      '/users/$targetUserId/friend-requests',
      method: 'POST',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = _tryReadMessage(response.body) ?? 'Failed to send request';
    throw ApiException(message, response.statusCode);
  }

  static String? _tryReadMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return null;
  }
}
