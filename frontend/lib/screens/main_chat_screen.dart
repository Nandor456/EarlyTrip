import 'package:flutter/material.dart';
import 'package:frontend/managers/chat_data_manager.dart';
import 'package:frontend/models/chat_group.dart';
import 'package:frontend/screens/chat_room_screen.dart';
import 'package:frontend/screens/profile_settings_screen.dart';
import 'package:frontend/services/token_service.dart';
import 'package:frontend/widgets/create_group_dialog.dart';
import 'package:frontend/services/socket_service.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/screens/friends_screen.dart';
import 'package:frontend/screens/notifications_screen.dart';

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
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      debugPrint('Initializing current user...');
      await _chatManager.initializeCurrentUser();
      debugPrint(
        'Current user initialized: ${_chatManager.currentUser?.firstName}',
      );
      await _chatManager.loadChatGroups();
      debugPrint(
        'Chat groups loaded: ${_chatManager.chatGroups.length} groups',
      );

      // Initialize Socket.IO connection
      await _initializeSocket();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }

      if (e.toString().contains('Authentication failed')) {
        _handleAuthenticationFailure();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeSocket() async {
    try {
      String accessToken = await TokenService.getAccessToken() ?? '';
      _socketService.connect(
        AppConfig.serverBaseUrl,
        accessToken,
        path: AppConfig.socketPath,
      );
      debugPrint("Socket connecting...");

      // Prevent duplicate handlers if this screen is recreated.
      _socketService.socket.off("connect");
      _socketService.socket.off("disconnect");
      _socketService.socket.off("connect_error");

      _socketService.socket.on("connect", (_) {
        if (!mounted) return;
        setState(() => _isSocketConnected = true);
        debugPrint('Connected to Socket.IO server');
      });

      _socketService.socket.on("disconnect", (_) {
        if (!mounted) return;
        setState(() => _isSocketConnected = false);
        debugPrint('Disconnected from Socket.IO server');
      });

      _socketService.socket.on("connect_error", (err) {
        if (!mounted) return;
        setState(() => _isSocketConnected = false);
        debugPrint('Socket connect_error: $err');
      });
    } catch (e) {
      debugPrint('Socket connection failed: $e');
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
                        AppConfig.absoluteUrl(
                          _chatManager.currentUser!.profilePicture!,
                        ),
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
      body: _selectedTabIndex == 0 ? _buildBody() : const FriendsScreen(),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showCreateGroupDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            return;
          }

          if (index == _selectedTabIndex) return;
          setState(() => _selectedTabIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Notifications',
          ),
        ],
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
                    ? NetworkImage(AppConfig.absoluteUrl(group.groupImage!))
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
