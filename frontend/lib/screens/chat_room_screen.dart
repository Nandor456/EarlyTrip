import 'package:flutter/material.dart';
import 'package:frontend/managers/chat_data_manager.dart';
import 'package:frontend/models/chat_group.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/models/message.dart';
import 'package:frontend/services/chat_api_service.dart';
import 'package:frontend/services/socket_service.dart';
import 'package:frontend/widgets/message_bubble.dart';
import 'package:frontend/utils/date_fomatter.dart';

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
      debugPrint(
        'Loaded ${messages.length} messages for group ${widget.group.id}',
      );
      debugPrint(
        'messages: ${messages.map((m) => [m.content, m.senderId, m.id, m.timestamp]).toList()}',
      );
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
        debugPrint('message added to chat room: ${message.content}');
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

                      // debugPrint('Message #$index');
                      // debugPrint('Sender ID: ${message.senderId}');
                      // debugPrint('Is Me: $isMe');
                      // debugPrint('Sender object: $sender\n');

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        sender: sender,
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
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
                _showErrorSnackBar('Gallery feature not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.iconTheme.color),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
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
                'Created: ${DateFormatter.formatDate(widget.group.createdAt)}',
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
              ..._groupMembers.map(
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
              ),
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
      _showErrorSnackBar('Delete group feature not yet implemented');
    } catch (e) {
      _showErrorSnackBar('Error deleting group: $e');
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
