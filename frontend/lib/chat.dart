// chat_system.dart - Database integrated chat system
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tokenService.dart'; // Import your existing token service

// API Service for chat operations
class ChatApiService {
  static const String baseUrl =
      'http://10.0.2.2:3000/api'; // Replace with your API base URL

  static Future<Map<String, String>> _getHeaders() async {
    final token = await TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get user's chat groups
  static Future<List<ChatGroup>> getUserChatGroups() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/chat/groups'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['groups'] as List)
            .map((group) => ChatGroup.fromJson(group))
            .toList();
      } else {
        throw Exception('Failed to load chat groups');
      }
    } catch (e) {
      throw Exception('Error loading chat groups: $e');
    }
  }

  static Future<User> getUserData() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data['user']);
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
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
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/chat/groups/$groupId/messages?limit=$limit&offset=$offset',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['messages'] as List)
            .map((message) => Message.fromJson(message))
            .toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      throw Exception('Error loading messages: $e');
    }
  }

  // Send a message to a group
  static Future<Message> sendMessage(
    String groupId,
    String content,
    MessageType type, {
    String? mediaUrl,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'content': content,
        'type': type.toString().split('.').last,
        'mediaUrl': mediaUrl,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/chat/groups/$groupId/messages'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Message.fromJson(data['message']);
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  // Create a new chat group
  static Future<ChatGroup> createChatGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'groupName': name, 'memberIds': memberIds});

      final response = await http.post(
        Uri.parse('$baseUrl/chat/groups'),
        headers: headers,
        body: body,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        return ChatGroup.fromJson(data['groups']);
      } else {
        throw Exception(data['message'] ?? 'Failed to create group');
      }
    } catch (e) {
      throw Exception('Error creating group: $e');
    }
  }

  // Get all users for group creation
  static Future<List<User>> getAllUsers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['users'] as List)
            .map((user) => User.fromJson(user))
            .toList();
      } else if (response.statusCode == 401) {
        final body = json.decode(response.body);
        if (body['code'] == 'TOKEN_EXPIRED') {
          // Refresh token
          final newAccessToken = await _refreshToken();
          if (newAccessToken != null) {
            // Retry request with new token
            final retryHeaders = await _getHeaders(newAccessToken);
            final retryResponse = await http.get(
              Uri.parse('$baseUrl/users'),
              headers: retryHeaders,
            );

            if (retryResponse.statusCode == 200) {
              final data = json.decode(retryResponse.body);
              return (data['users'] as List)
                  .map((user) => User.fromJson(user))
                  .toList();
            }
          }
        }
        throw Exception('Failed to load users');
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      throw Exception('Error loading users: $e');
    }
  }

  // Get group members
  static Future<List<User>> getGroupMembers(String groupId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/chat/groups/$groupId/members'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['members'] as List)
            .map((user) => User.fromJson(user))
            .toList();
      } else {
        throw Exception('Failed to load group members');
      }
    } catch (e) {
      throw Exception('Error loading group members: $e');
    }
  }

  // Add members to group
  static Future<bool> addMembersToGroup(
    String groupId,
    List<String> memberIds,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'memberIds': memberIds});

      final response = await http.post(
        Uri.parse('$baseUrl/chat/groups/$groupId/members'),
        headers: headers,
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Remove member from group
  static Future<bool> removeMemberFromGroup(
    String groupId,
    String memberId,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/chat/groups/$groupId/members/$memberId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Update group info
  static Future<ChatGroup?> updateGroupInfo(
    String groupId, {
    String? name,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      });

      final response = await http.put(
        Uri.parse('$baseUrl/chat/groups/$groupId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChatGroup.fromJson(data['group']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Delete group
  static Future<bool> deleteGroup(String groupId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/chat/groups/$groupId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Update user profile
  static Future<User?> updateUserProfile({String? profilePicture}) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        if (profilePicture != null) 'profilePicture': profilePicture,
      });

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

// Models with JSON serialization
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
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.mediaUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      senderId: json['sender_id'].toString(),
      senderName: json['sender_name'] ?? 'Unknown',
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      mediaUrl: json['media_url'],
    );
  }
}

enum MessageType { text, image, file }

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
      name: json['group_name'] ?? '',
      groupImage: json['group_image'],
      adminId: json['admin_id'].toString(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// Chat Data Manager with API integration
class ChatDataManager {
  static final ChatDataManager _instance = ChatDataManager._internal();
  factory ChatDataManager() => _instance;
  ChatDataManager._internal();

  User? _currentUser;
  List<ChatGroup> _chatGroups = [];
  List<User> _allUsers = [];
  Map<String, List<Message>> _groupMessages = {};

  User? get currentUser => _currentUser;
  List<ChatGroup> get chatGroups => List.unmodifiable(_chatGroups);
  List<User> get allUsers => List.unmodifiable(_allUsers);

  Future<void> initializeCurrentUser() async {
    try {
      final userData = await ChatApiService.getUserData();
      _currentUser = User(
        id: userData.id,
        firstName: userData.firstName,
        lastName: userData.lastName,
        email: userData.email,
        profilePicture: userData.profilePicture,
      );
    } catch (e) {
      throw Exception('Failed to initialize current user: $e');
    }
  }

  Future<void> loadChatGroups() async {
    try {
      _chatGroups = await ChatApiService.getUserChatGroups();
    } catch (e) {
      throw Exception('Failed to load chat groups: $e');
    }
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

  Future<Message?> sendMessage(
    String groupId,
    String content,
    MessageType type, {
    String? mediaUrl,
  }) async {
    try {
      final message = await ChatApiService.sendMessage(
        groupId,
        content,
        type,
        mediaUrl: mediaUrl,
      );

      // Add to local cache
      if (_groupMessages.containsKey(groupId)) {
        _groupMessages[groupId]!.add(message);
      }

      return message;
    } catch (e) {
      throw Exception('Failed to send message: $e');
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

  Future<User?> updateUserProfile({
    String? profilePicture,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final updatedUser = await ChatApiService.updateUserProfile(
        profilePicture: profilePicture,
      );
      if (updatedUser != null) {
        _currentUser = updatedUser;
      }
      return updatedUser;
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  void clearCache() {
    _chatGroups.clear();
    _allUsers.clear();
    _groupMessages.clear();
    _currentUser = null;
  }
}

// Main Chat Screen
class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {
  final ChatDataManager _chatManager = ChatDataManager();
  bool _isDarkTheme = true;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      await _chatManager.initializeCurrentUser();
      await _chatManager.loadChatGroups();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          GestureDetector(
            onTap: () => _showProfileSettings(context),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage:
                    _chatManager.currentUser?.profilePicture != null
                    ? NetworkImage(
                        'http://10.0.2.2:3000/${_chatManager.currentUser!.profilePicture}',
                      )
                    : null,
                child: _chatManager.currentUser?.profilePicture == null
                    ? Text(
                        _chatManager.currentUser?.lastName.isNotEmpty == true
                            ? _chatManager.currentUser!.lastName[0]
                                  .toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading chats',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_chatManager.chatGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to start chatting',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.blue,
      backgroundColor: Colors.grey[800],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _chatManager.chatGroups.length,
        itemBuilder: (context, index) {
          final group = _chatManager.chatGroups[index];
          return Card(
            color: Colors.grey[800],
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage: group.groupImage != null
                    ? NetworkImage(group.groupImage!)
                    : null,
                child: group.groupImage == null
                    ? Text(
                        group.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Text(
                group.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _openChatRoom(context, group),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _openChatRoom(BuildContext context, ChatGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatRoomScreen(group: group)),
    ).then((_) => _refreshData());
  }

  void _showProfileSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          onThemeChanged: (isDark) => setState(() => _isDarkTheme = isDark),
          isDarkTheme: _isDarkTheme,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(onGroupCreated: _refreshData),
    );
  }
}

// Chat Room Screen
class ChatRoomScreen extends StatefulWidget {
  final ChatGroup group;

  const ChatRoomScreen({super.key, required this.group});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatDataManager _chatManager = ChatDataManager();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _isLoading = true);
      final messages = await _chatManager.getGroupMessages(widget.group.id);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'members',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            color: Colors.grey[800],
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Text(
                  'Group Info',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              if (widget.group.adminId == _chatManager.currentUser?.id)
                const PopupMenuItem(
                  value: 'manage',
                  child: Text(
                    'Manage Group',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
            onSelected: (value) {
              if (value == 'info') {
                _showGroupInfo(context);
              } else if (value == 'manage') {
                _showGroupManagement(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe =
                          message.senderId == _chatManager.currentUser?.id;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[700],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            if (message.type == MessageType.image)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[600],
                  image: message.mediaUrl != null
                      ? DecorationImage(
                          image: NetworkImage(message.mediaUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: message.mediaUrl == null
                    ? const Center(
                        child: Icon(Icons.image, color: Colors.white70),
                      )
                    : null,
              ),
            if (message.type == MessageType.text)
              Text(
                message.content,
                style: const TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[850],
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showMediaOptions(context),
            icon: const Icon(Icons.attach_file, color: Colors.white70),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
            ),
          ),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final message = await _chatManager.sendMessage(
        widget.group.id,
        content,
        MessageType.text,
      );

      if (message != null) {
        setState(() {
          _messages.add(message);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
      // Restore the message in the text field
      _messageController.text = content;
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[800],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text(
                'Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement gallery selection
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text(
                'Camera',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement camera capture
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: Colors.white70,
              ),
              title: const Text(
                'Document',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement document selection
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: Text(
          widget.group.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Created: ${_formatDate(widget.group.createdAt)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Admin ID: ${widget.group.adminId}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showGroupManagement(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Group Management',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.white70),
              title: const Text(
                'Add Members',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showAddMembersDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.white70),
              title: const Text(
                'Remove Members',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRemoveMembersDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white70),
              title: const Text(
                'Edit Group Info',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditGroupDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Group',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteGroupDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showAddMembersDialog(BuildContext context) {
    // TODO: Implement add members dialog
    _showErrorSnackBar('Add members feature not yet implemented');
  }

  void _showRemoveMembersDialog(BuildContext context) {
    // TODO: Implement remove members dialog
    _showErrorSnackBar('Remove members feature not yet implemented');
  }

  void _showEditGroupDialog(BuildContext context) {
    // TODO: Implement edit group dialog
    _showErrorSnackBar('Edit group feature not yet implemented');
  }

  void _showDeleteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Delete Group',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      final success = await ChatApiService.deleteGroup(widget.group.id);
      if (success) {
        Navigator.pop(context);
        _showSuccessSnackBar('Group deleted successfully');
      } else {
        _showErrorSnackBar('Failed to delete group');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting group: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// Profile Settings Screen
class ProfileSettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkTheme;

  const ProfileSettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkTheme,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  final ChatDataManager _chatManager = ChatDataManager();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = _chatManager.currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  )
                : const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue,
                    backgroundImage:
                        _chatManager.currentUser?.profilePicture != null
                        ? NetworkImage(
                            _chatManager.currentUser!.profilePicture!,
                          )
                        : null,
                    child: _chatManager.currentUser?.profilePicture == null
                        ? Text(
                            _chatManager.currentUser?.getInitials() ?? 'U',
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        onPressed: _changeProfilePicture,
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _lastNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
              enabled: false,
            ),
            const SizedBox(height: 32),
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Dark Theme',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: widget.isDarkTheme,
                      onChanged: widget.onThemeChanged,
                      activeThumbColor: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeProfilePicture() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[800],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement gallery selection for profile picture
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text(
                'Take Photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement camera capture for profile picture
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_lastNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Username cannot be empty');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedUser = await _chatManager.updateUserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (updatedUser != null) {
        _showSuccessSnackBar('Profile updated successfully');
        Navigator.pop(context);
      } else {
        _showErrorSnackBar('Failed to update profile');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await TokenService.clearTokens();
        _chatManager.clearCache();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error logging out: $e');
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

// Create Group Dialog
class CreateGroupDialog extends StatefulWidget {
  final VoidCallback onGroupCreated;

  const CreateGroupDialog({super.key, required this.onGroupCreated});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<int> _selectedMembers = [];
  final ChatDataManager _chatManager = ChatDataManager();
  List<User> _availableUsers = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      setState(() => _isLoading = true);
      await _chatManager.loadAllUsers();
      _availableUsers = _chatManager.allUsers
          .where((user) => user.id != _chatManager.currentUser?.id)
          .toList();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[800],
      title: const Text('Create Group', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _groupNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Members:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.blue)
              else if (_availableUsers.isEmpty)
                const Text(
                  'No users available',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableUsers.length,
                    itemBuilder: (context, index) {
                      final user = _availableUsers[index];
                      return CheckboxListTile(
                        title: Text(
                          '${user.firstName} ${user.lastName}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          user.email,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        value: _selectedMembers.contains(user.id),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedMembers.add(user.id);
                            } else {
                              _selectedMembers.remove(user.id);
                            }
                          });
                        },
                        activeColor: Colors.blue,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _isCreating ? null : _createGroup,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                )
              : const Text('Create', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Group name is required');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final group = await _chatManager.createChatGroup(
        name: _groupNameController.text.trim(),
        memberIds: _selectedMembers,
      );

      if (group != null) {
        widget.onGroupCreated();
        Navigator.pop(context);
        _showSuccessSnackBar('Group created successfully');
      } else {
        _showErrorSnackBar('Failed to create group');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating group: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
