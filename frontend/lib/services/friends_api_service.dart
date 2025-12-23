import 'dart:convert';

import 'package:frontend/models/user.dart';
import 'package:frontend/services/api_service.dart';

class FriendsApiService {
  static Future<List<User>> getFriends() async {
    final response = await ApiService.authenticatedRequest('/users/friends');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final friends = (data['friends'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();
      return friends;
    }

    final message = _tryReadMessage(response.body) ?? 'Failed to load friends';
    throw ApiException(message, response.statusCode);
  }

  static Future<List<UserSearchResult>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final encoded = Uri.encodeQueryComponent(trimmed);
    final response = await ApiService.authenticatedRequest(
      '/users/search?query=$encoded',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = (data['users'] as List<dynamic>? ?? [])
          .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
      return results;
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

  static Future<void> acceptFriendRequest(String fromUserId) async {
    final response = await ApiService.authenticatedRequest(
      '/users/$fromUserId/friend-requests/accept',
      method: 'POST',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message =
        _tryReadMessage(response.body) ?? 'Failed to accept request';
    throw ApiException(message, response.statusCode);
  }

  static Future<void> rejectFriendRequest(String fromUserId) async {
    final response = await ApiService.authenticatedRequest(
      '/users/$fromUserId/friend-requests/reject',
      method: 'POST',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message =
        _tryReadMessage(response.body) ?? 'Failed to reject request';
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

enum FriendshipStatus { none, pending, accepted }

class UserSearchResult {
  final User user;
  final FriendshipStatus friendshipStatus;

  const UserSearchResult({required this.user, required this.friendshipStatus});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['friendship_status'] ?? 'none').toString();
    final status = switch (raw) {
      'accepted' => FriendshipStatus.accepted,
      'pending' => FriendshipStatus.pending,
      _ => FriendshipStatus.none,
    };

    return UserSearchResult(
      user: User.fromJson(json),
      friendshipStatus: status,
    );
  }
}
