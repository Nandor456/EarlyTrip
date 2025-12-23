import 'package:flutter/cupertino.dart';
import 'package:frontend/models/chat_group.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/models/message.dart';
import 'package:frontend/services/chat_api_service.dart';

class ChatDataManager {
  static final ChatDataManager _instance = ChatDataManager._internal();
  factory ChatDataManager() => _instance;
  ChatDataManager._internal();

  User? _currentUser;
  List<ChatGroup> _chatGroups = [];
  List<User> _allUsers = [];
  final Map<String, List<Message>> _groupMessages = {};
  final Map<String, List<User>> _groupMembersCache = {};

  User? get currentUser => _currentUser;
  List<ChatGroup> get chatGroups => List.unmodifiable(_chatGroups);
  List<User> get allUsers => List.unmodifiable(_allUsers);

  void updateCurrentUser(User user) {
    _currentUser = user;

    final idx = _allUsers.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _allUsers[idx] = user;
    }

    for (final members in _groupMembersCache.values) {
      final i = members.indexWhere((u) => u.id == user.id);
      if (i != -1) {
        members[i] = user;
      }
    }
  }

  Future<void> initializeCurrentUser() async {
    try {
      debugPrint('getting current user...');
      final userData = await ChatApiService.getUserData();
      debugPrint("current user: ${userData.firstName}");
      _currentUser = userData;
    } catch (e) {
      throw Exception('Failed to initialize current user: $e');
    }
  }

  Future<void> loadChatGroups() async {
    _chatGroups = await ChatApiService.getUserChatGroups();
  }

  Future<void> loadAllUsers() async {
    try {
      _allUsers = await ChatApiService.getAllUsers();
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  Future<List<Message>> getGroupMessages(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _groupMessages.containsKey(groupId)) {
      return _groupMessages[groupId]!;
    }

    try {
      final messages = await ChatApiService.getGroupMessages(groupId);
      _groupMessages[groupId] = messages;
      return messages;
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<List<User>> getGroupMembers(
    String groupId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _groupMembersCache.containsKey(groupId)) {
      return _groupMembersCache[groupId]!;
    }

    try {
      final members = await ChatApiService.getGroupMembers(groupId);
      _groupMembersCache[groupId] = members;
      return members;
    } catch (e) {
      throw Exception('Failed to load group members: $e');
    }
  }

  // Get user by ID from cached data
  User? getUserById(String userId) {
    // First check current user
    if (_currentUser?.id == userId) return _currentUser;

    // Then check all users cache
    try {
      return _allUsers.firstWhere((user) => user.id == userId);
    } catch (e) {
      // Check in group members cache
      for (final members in _groupMembersCache.values) {
        try {
          return members.firstWhere((user) => user.id == userId);
        } catch (e) {
          continue;
        }
      }
      return null;
    }
  }

  // Add message to local cache (used by Socket.IO listener)
  void addMessageToCache(String groupId, Message message) {
    if (!_groupMessages.containsKey(groupId)) {
      _groupMessages[groupId] = [];
    }

    // Avoid duplicates
    if (!_groupMessages[groupId]!.any((m) => m.id == message.id)) {
      _groupMessages[groupId]!.add(message);
    }
  }

  Future<ChatGroup?> createChatGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    try {
      final group = await ChatApiService.createChatGroup(
        name: name,
        memberIds: memberIds,
      );
      _chatGroups.add(group);
      return group;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  void clearCache() {
    _chatGroups.clear();
    _allUsers.clear();
    _groupMessages.clear();
    _groupMembersCache.clear();
    _currentUser = null;
  }
}
