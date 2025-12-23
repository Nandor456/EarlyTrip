import 'package:flutter/material.dart';
import 'package:frontend/managers/chat_data_manager.dart';
import 'package:frontend/models/chat_group.dart';
import 'package:frontend/screens/chat_room_screen.dart';
import 'package:frontend/screens/profile_settings_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/token_service.dart';
import 'package:frontend/widgets/create_group_dialog.dart';
import 'package:frontend/services/socket_service.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/screens/friends_screen.dart';
import 'package:frontend/screens/notifications_screen.dart';
import 'package:frontend/utils/theme.dart';
import 'package:provider/provider.dart';

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

  bool _isForcingLogout = false;

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

      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        final userTheme = _chatManager.currentUser?.isDarkTheme;
        if (userTheme != null) {
          themeProvider.setTheme(userTheme);
        }
      }

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

      // Fail closed: any exception forces logout, but only once.
      await _forceLogout();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forceLogout() async {
    if (_isForcingLogout) return;
    _isForcingLogout = true;

    try {
      await ApiService.logout();
    } catch (_) {
      // Ignore token clearing errors; still navigate away.
    }

    _chatManager.clearCache();
    _socketService.disconnect();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    });
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
      _socketService.socket.off("group_created");
      _socketService.socket.off("group_added");
      _socketService.socket.off("group_deleted");

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

      Future<void> refreshGroups() async {
        try {
          await _chatManager.loadChatGroups();
          if (!mounted) return;
          setState(() {});
        } catch (e) {
          debugPrint('Failed to refresh groups after socket event: $e');
        }
      }

      _socketService.socket.on("group_created", (_) => refreshGroups());
      _socketService.socket.on("group_added", (_) => refreshGroups());
      _socketService.socket.on("group_deleted", (_) => refreshGroups());
    } catch (e) {
      debugPrint('Socket connection failed: $e');
    }
  }

  Future<void> _refreshData() async {
    await _initializeData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String title = switch (_selectedTabIndex) {
      0 => 'Chats',
      1 => 'Friends',
      2 => 'Notifications',
      _ => 'Chats',
    };

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(title),
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
      body: switch (_selectedTabIndex) {
        0 => _buildBody(),
        1 => const FriendsScreen(),
        2 => const NotificationsScreen(showAppBar: false),
        _ => _buildBody(),
      },
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showCreateGroupDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
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
                    : (group.directProfilePicUrl != null &&
                          group.directProfilePicUrl!.trim().isNotEmpty)
                    ? NetworkImage(
                        AppConfig.absoluteUrl(group.directProfilePicUrl!),
                      )
                    : null,
                child:
                    (group.memberCount == 2 ||
                        group.groupImage != null ||
                        (group.directProfilePicUrl != null &&
                            group.directProfilePicUrl!.trim().isNotEmpty))
                    ? null
                    : Text(
                        (group.title.isNotEmpty ? group.title : group.name)
                            .trim()
                            .characters
                            .first
                            .toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
              ),
              title: Text(
                group.title,
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
