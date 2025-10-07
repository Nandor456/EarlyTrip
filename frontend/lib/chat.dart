// chat_system.dart - Updated with Socket.IO integration
import 'package:flutter/material.dart';
import 'dart:convert';
import 'tokenService.dart';
import 'theme.dart';
import 'package:provider/provider.dart';
import 'socket.io.dart';

// First, let's fix the missing imports and classes that seem to be referenced
// You'll need to make sure these are available in your project:
// import 'api_service.dart'; // Your centralized API service
// class ApiService { ... }
// class ApiResponseHandler { ... }
// class AuthException extends Exception { ... }
// class NetworkException extends Exception { ... }
// class ApiException extends Exception { ... }

// Updated API Service for chat operations using the centralized ApiService
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

// Models
enum MessageType { text, image, document }

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

class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.mediaUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    MessageType messageType;
    switch (json['type']) {
      case 'image':
        messageType = MessageType.image;
        break;
      case 'document':
        messageType = MessageType.document;
        break;
      default:
        messageType = MessageType.text;
    }

    return Message(
      id: json['message_id'].toString(),
      senderId: json['user_id'].toString(),
      content: json['content'] ?? '',
      type: messageType,
      timestamp: DateTime.parse(json['timestamp']),
      mediaUrl: json['media_url'],
    );
  }
}

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

// Chat Data Manager with Socket.IO integration
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

  Future<void> initializeCurrentUser() async {
    try {
      final userData = await ChatApiService.getUserData();
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

// Main Chat Screen
class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {
  final ChatDataManager _chatManager = ChatDataManager();
  final SocketService _socketService = SocketService();
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isSocketConnected = false;

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

      // Initialize Socket.IO connection
      await _initializeSocket();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      if (e.toString().contains('Authentication failed')) {
        _handleAuthenticationFailure();
      }
    }
  }

  Future<void> _initializeSocket() async {
    try {
      _socketService.connect('http://10.0.2.2:3000', path: '/ws');

      _socketService.socket.on("connect", (_) {
        setState(() => _isSocketConnected = true);
        print('Connected to Socket.IO server');
      });

      _socketService.socket.on("disconnect", (_) {
        setState(() => _isSocketConnected = false);
        print('Disconnected from Socket.IO server');
      });
    } catch (e) {
      print('Socket connection failed: $e');
    }
  }

  void _handleAuthenticationFailure() {
    _chatManager.clearCache();
    _socketService.disconnect();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session expired. Please login again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 12.0),
          child: Text('Chats'),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Socket.IO status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              _isSocketConnected ? Icons.circle : Icons.circle_outlined,
              color: _isSocketConnected ? Colors.green : Colors.red,
              size: 12,
            ),
          ),
          GestureDetector(
            onTap: () => _showProfileSettings(context),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                backgroundImage:
                    _chatManager.currentUser?.profilePicture != null
                    ? NetworkImage(
                        'http://10.0.2.2:3000/${_chatManager.currentUser!.profilePicture}',
                      )
                    : null,
                child: _chatManager.currentUser?.profilePicture == null
                    ? Text(
                        _chatManager.currentUser?.getInitials() ?? 'U',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
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
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading chats', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage.contains('Authentication failed')
                    ? 'Your session has expired. Please login again.'
                    : _errorMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (!_errorMessage.contains('Authentication failed'))
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
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
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 16),
            Text('No chats yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create a group to start chatting',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _chatManager.chatGroups.length,
        itemBuilder: (context, index) {
          final group = _chatManager.chatGroups[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                backgroundImage: group.groupImage != null
                    ? NetworkImage('http://10.0.2.2:3000/${group.groupImage}')
                    : null,
                child: group.groupImage == null
                    ? Text(
                        group.name[0].toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : null,
              ),
              title: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => _openChatRoom(context, group),
            ),
          );
        },
      ),
    );
  }

  void _openChatRoom(BuildContext context, ChatGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatRoomScreen(group: group, socketService: _socketService),
      ),
    ).then((_) => _refreshData());
  }

  void _showProfileSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
    ).then((_) => setState(() {}));
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(onGroupCreated: _refreshData),
    );
  }

  @override
  void dispose() {
    // Don't disconnect socket here as it might be used by other screens
    super.dispose();
  }
}

// Improved ChatRoomScreen with Socket.IO integration
class ChatRoomScreen extends StatefulWidget {
  final ChatGroup group;
  final SocketService socketService;

  const ChatRoomScreen({
    super.key,
    required this.group,
    required this.socketService,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatDataManager _chatManager = ChatDataManager();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  List<User> _groupMembers = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _typingIndicator = '';
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
    _messageController.addListener(_onTextChanged);
  }

  Future<void> _initializeChatRoom() async {
    try {
      setState(() => _isLoading = true);

      // Join the group room
      widget.socketService.joinGroup(widget.group.id);

      // Set up Socket.IO listeners
      _setupSocketListeners();

      // Load initial data
      await Future.wait([_loadMessages(), _loadGroupMembers()]);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to initialize chat: $e');
    }
  }

  void _setupSocketListeners() {
    // Listen for new messages
    widget.socketService.onNewMessage((data) {
      try {
        final messageData = data as Map<String, dynamic>;
        final groupId = messageData['groupId']?.toString();

        if (groupId == widget.group.id) {
          final message = Message.fromJson(messageData['message']);
          _onNewMessage(message);
        }
      } catch (e) {
        print('Error parsing new message: $e');
      }
    });

    // Listen for typing indicators
    widget.socketService.socket.on('typing_update', (data) {
      try {
        final typingData = data as Map<String, dynamic>;
        final groupId = typingData['groupId']?.toString();
        final userName = typingData['userName']?.toString() ?? 'Someone';
        final isTyping = typingData['isTyping'] as bool? ?? false;

        if (groupId == widget.group.id) {
          final typingText = isTyping ? '$userName is typing...' : '';
          _onTypingUpdate(typingText);
        }
      } catch (e) {
        print('Error parsing typing update: $e');
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatManager.getGroupMessages(widget.group.id);
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar('Failed to load messages: $e');
      if (e.toString().contains('Authentication failed')) {
        _handleAuthenticationFailure();
      }
    }
  }

  Future<void> _loadGroupMembers() async {
    try {
      final members = await _chatManager.getGroupMembers(widget.group.id);
      setState(() {
        _groupMembers = members;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load group members: $e');
    }
  }

  void _onNewMessage(Message message) {
    // Only add if it's not already in the list (avoid duplicates)
    if (!_messages.any((m) => m.id == message.id)) {
      setState(() {
        _messages.add(message);
      });
      _chatManager.addMessageToCache(widget.group.id, message);
      _scrollToBottom();
    }
  }

  void _onTypingUpdate(String typingText) {
    setState(() {
      _typingIndicator = typingText;
    });
  }

  void _onTextChanged() {
    final isCurrentlyTyping = _messageController.text.trim().isNotEmpty;

    if (isCurrentlyTyping != _isTyping) {
      _isTyping = isCurrentlyTyping;
      _sendTypingIndicator(_isTyping);
    }
  }

  void _sendTypingIndicator(bool isTyping) {
    widget.socketService.socket.emit('typing', {
      'groupId': widget.group.id,
      'isTyping': isTyping,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleAuthenticationFailure() {
    _chatManager.clearCache();
    widget.socketService.disconnect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name),
            if (_typingIndicator.isNotEmpty)
              Text(
                _typingIndicator,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              )
            else
              Text(
                '${_groupMembers.length} members',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Icon(
              widget.socketService.socket.connected
                  ? Icons.circle
                  : Icons.circle_outlined,
              color: widget.socketService.socket.connected
                  ? Colors.green
                  : Colors.red,
              size: 12,
            ),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'info', child: Text('Group Info')),
              if (widget.group.adminId == _chatManager.currentUser?.id)
                const PopupMenuItem(
                  value: 'manage',
                  child: Text('Manage Group'),
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
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe =
                          message.senderId == _chatManager.currentUser?.id;
                      final sender = _chatManager.getUserById(message.senderId);
                      return _buildMessageBubble(message, isMe, sender);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, User? sender) {
    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && sender != null)
              Text(
                sender.fullName.isNotEmpty ? sender.fullName : sender.email,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isMe && sender != null) const SizedBox(height: 4),
            if (message.type == MessageType.image)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: message.mediaUrl != null
                      ? DecorationImage(
                          image: NetworkImage(
                            'http://10.0.2.2:3000/${message.mediaUrl}',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: message.mediaUrl == null
                    ? Center(
                        child: Icon(
                          Icons.image,
                          color: textColor.withOpacity(0.7),
                        ),
                      )
                    : null,
              ),
            if (message.type == MessageType.text)
              Text(message.content, style: TextStyle(color: textColor)),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.timestamp),
              style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showMediaOptions(context),
            icon: Icon(Icons.attach_file, color: theme.iconTheme.color),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.send, color: theme.colorScheme.primary),
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

    // Stop typing indicator
    _isTyping = false;
    _sendTypingIndicator(false);

    setState(() => _isSending = true);

    try {
      // Try Socket.IO first for real-time delivery
      if (widget.socketService.socket.connected) {
        final messageData = {
          'content': content,
          'type': MessageType.text.toString().split('.').last,
          'timestamp': DateTime.now().toIso8601String(),
        };

        widget.socketService.sendMessage(widget.group.id, messageData);
      } else {
        // Fallback to HTTP API if Socket.IO is not connected
        final message = await ChatApiService.sendMessage(
          widget.group.id,
          content,
          MessageType.text,
        );

        // Add to local cache and UI
        setState(() {
          _messages.add(message);
        });
        _chatManager.addMessageToCache(widget.group.id, message);
        _scrollToBottom();
      }
    } catch (e) {
      // Restore message on error
      _messageController.text = content;
      _showErrorSnackBar('Failed to send message: $e');

      // Handle authentication failure
      if (e.toString().contains('Authentication failed')) {
        _handleAuthenticationFailure();
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showMediaOptions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: theme.iconTheme.color),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement gallery selection
                _showErrorSnackBar('Gallery feature not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.iconTheme.color),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement camera capture
                _showErrorSnackBar('Camera feature not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.insert_drive_file,
                color: theme.iconTheme.color,
              ),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement document selection
                _showErrorSnackBar('Document feature not yet implemented');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.group.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created: ${_formatDate(widget.group.createdAt)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Members (${_groupMembers.length}):',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._groupMembers
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: theme.colorScheme.primary,
                            backgroundImage: member.profilePicture != null
                                ? NetworkImage(
                                    'http://10.0.2.2:3000/${member.profilePicture}',
                                  )
                                : null,
                            child: member.profilePicture == null
                                ? Text(
                                    member.getInitials(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              member.fullName.isNotEmpty
                                  ? member.fullName
                                  : member.email,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (member.id == widget.group.adminId)
                            Icon(
                              Icons.admin_panel_settings,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  )
                  ,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupManagement(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_add, color: theme.iconTheme.color),
              title: const Text('Add Members'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Add members feature not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove, color: theme.iconTheme.color),
              title: const Text('Remove Members'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar(
                  'Remove members feature not yet implemented',
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: theme.iconTheme.color),
              title: const Text('Edit Group Info'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Edit group feature not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: theme.colorScheme.error),
              title: Text(
                'Delete Group',
                style: TextStyle(color: theme.colorScheme.error),
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
            child: Text(
              'Close',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      // TODO: Implement delete group API call
      // final success = await ChatApiService.deleteGroup(widget.group.id);
      // if (success && mounted) {
      //   Navigator.pop(context);
      //   _showSuccessSnackBar('Group deleted successfully');
      // } else {
      //   _showErrorSnackBar('Failed to delete group');
      // }
      _showErrorSnackBar('Delete group feature not yet implemented');
    } catch (e) {
      _showErrorSnackBar('Error deleting group: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    // Clean up and leave group
    widget.socketService.socket.emit('leave_group', widget.group.id);

    // Stop typing indicator before leaving
    if (_isTyping) {
      _sendTypingIndicator(false);
    }

    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Profile Settings Screen
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _emailController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  final ChatDataManager _chatManager = ChatDataManager();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = _chatManager.currentUser;
    _emailController = TextEditingController(text: user?.email ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
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
                    backgroundColor: theme.colorScheme.primary,
                    backgroundImage:
                        _chatManager.currentUser?.profilePicture != null
                        ? NetworkImage(
                            'http://10.0.2.2:3000/${_chatManager.currentUser!.profilePicture}',
                          )
                        : null,
                    child: _chatManager.currentUser?.profilePicture == null
                        ? Text(
                            _chatManager.currentUser?.getInitials() ?? 'U',
                            style: TextStyle(
                              fontSize: 30,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.secondary,
                      child: IconButton(
                        onPressed: _changeProfilePicture,
                        icon: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: theme.colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: false,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Dark Theme'),
                      value: themeProvider.isDarkTheme,
                      onChanged: (value) => themeProvider.setTheme(value),
                      activeThumbColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: theme.iconTheme.color),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Gallery selection not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.iconTheme.color),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Camera capture not yet implemented');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      // TODO: Implement profile update API call
      // final updatedUser = await ChatApiService.updateUserProfile(
      //   firstName: _firstNameController.text.trim(),
      //   lastName: _lastNameController.text.trim(),
      // );
      // if (updatedUser != null) {
      //   _showSuccessSnackBar('Profile updated successfully');
      // } else {
      //   _showErrorSnackBar('Failed to update profile');
      // }
      _showErrorSnackBar('Profile update not yet implemented');
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final theme = Theme.of(context);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // Use the centralized ApiService logout method
        await ApiService.logout();
        _chatManager.clearCache();
        SocketService().disconnect();

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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
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

      if (e.toString().contains('Authentication failed')) {
        _handleAuthenticationFailure();
      }
    }
  }

  void _handleAuthenticationFailure() {
    _chatManager.clearCache();
    SocketService().disconnect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Create Group'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Members:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_availableUsers.isEmpty)
                const Text('No users available')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableUsers.length,
                    itemBuilder: (context, index) {
                      final user = _availableUsers[index];
                      final userId = int.tryParse(user.id);
                      return CheckboxListTile(
                        title: Text(
                          user.fullName.isNotEmpty ? user.fullName : user.email,
                        ),
                        subtitle: user.fullName.isNotEmpty
                            ? Text(user.email)
                            : null,
                        value:
                            userId != null && _selectedMembers.contains(userId),
                        onChanged: userId != null
                            ? (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedMembers.add(userId);
                                  } else {
                                    _selectedMembers.remove(userId);
                                  }
                                });
                              }
                            : null,
                        activeColor: theme.colorScheme.primary,
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isCreating ? null : _createGroup,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Create',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
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

      if (group != null && mounted) {
        widget.onGroupCreated();
        Navigator.pop(context);
        _showSuccessSnackBar('Group created successfully');
      } else {
        _showErrorSnackBar('Failed to create group');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating group: $e');

      if (e.toString().contains('Authentication failed')) {
        _handleAuthenticationFailure();
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}
