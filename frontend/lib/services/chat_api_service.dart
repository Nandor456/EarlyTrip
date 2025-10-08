import 'package:frontend/models/chat_group.dart';
import 'api_service.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/models/message.dart';

class ChatApiService {
  // Get user's chat groups
  static Future<List<ChatGroup>> getUserChatGroups() async {
    try {
      final response = await ApiService.authenticatedRequest('/groups');
      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return (data['groups'] as List)
          .map((group) => ChatGroup.fromJson(group))
          .toList();
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error loading chat groups: $e');
    }
  }

  static Future<User> getUserData() async {
    try {
      final response = await ApiService.authenticatedRequest('/users/profile');
      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return User.fromJson(data['user']);
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error loading user data: $e');
    }
  }

  // Get messages for a specific group
  static Future<List<Message>> getGroupMessages(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await ApiService.authenticatedRequest(
        '/groups/$groupId/messages?limit=$limit&offset=$offset',
      );
      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return (data['messages'] as List)
          .map((message) => Message.fromJson(message))
          .toList();
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error loading messages: $e');
    }
  }

  // Send a message to a group (this will be used as fallback if Socket.IO fails)
  static Future<Message> sendMessage(
    String groupId,
    String content,
    MessageType type, {
    String? mediaUrl,
  }) async {
    try {
      final body = {
        'content': content,
        'type': type.toString().split('.').last,
        'mediaUrl': mediaUrl,
      };

      final response = await ApiService.authenticatedRequest(
        '/groups/$groupId/messages',
        method: 'POST',
        body: body,
      );

      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return Message.fromJson(data['message']);
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error sending message: $e');
    }
  }

  // Create a new chat group
  static Future<ChatGroup> createChatGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    try {
      final body = {'groupName': name, 'memberIds': memberIds};

      final response = await ApiService.authenticatedRequest(
        '/groups',
        method: 'POST',
        body: body,
      );

      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return ChatGroup.fromJson(data['groups']);
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error creating group: $e');
    }
  }

  // Get all users for group creation
  static Future<List<User>> getAllUsers() async {
    try {
      final response = await ApiService.authenticatedRequest('/users');
      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return (data['users'] as List)
          .map((user) => User.fromJson(user))
          .toList();
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error loading users: $e');
    }
  }

  // Get group members with user details
  static Future<List<User>> getGroupMembers(String groupId) async {
    try {
      final response = await ApiService.authenticatedRequest(
        '/groups/$groupId/members',
      );
      final data = ApiResponseHandler.handleResponse(response, (data) => data);
      return (data['members'] as List)
          .map((user) => User.fromJson(user))
          .toList();
    } catch (e) {
      if (e is AuthException) {
        throw Exception('Authentication failed: ${e.message}');
      } else if (e is NetworkException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is ApiException) {
        throw Exception('API error: ${e.message}');
      }
      throw Exception('Error loading group members: $e');
    }
  }
}
