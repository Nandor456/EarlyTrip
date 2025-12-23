import 'package:flutter/material.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/managers/chat_data_manager.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/friends_api_service.dart';
import 'package:frontend/services/socket_service.dart';

class CreateGroupDialog extends StatefulWidget {
  final VoidCallback onGroupCreated;

  const CreateGroupDialog({super.key, required this.onGroupCreated});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<int> _selectedMembers = [];
  final ChatDataManager _chatManager = ChatDataManager();

  List<User> _availableUsers = [];
  bool _isLoading = true;
  bool _isCreating = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      setState(() => _isLoading = true);
      final friends = await FriendsApiService.getFriends();
      final currentUserId = _chatManager.currentUser?.id;

      _availableUsers = friends
          .where((user) => currentUserId == null || user.id != currentUserId)
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
    final bool isGroupChat = _selectedMembers.length > 1;

    final filteredUsers = _searchQuery.trim().isEmpty
        ? _availableUsers
        : _availableUsers.where((user) {
            final q = _searchQuery.trim().toLowerCase();
            return user.fullName.toLowerCase().contains(q) ||
                user.email.toLowerCase().contains(q);
          }).toList();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Row(
        children: [
          Icon(Icons.group_add, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create chat',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _isCreating ? null : () => Navigator.pop(context),
            tooltip: 'Close',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _groupNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: isGroupChat
                      ? 'Group name'
                      : 'Group name (optional)',
                  helperText: isGroupChat
                      ? 'Required for group chats (2+ friends).'
                      : 'Optional for 1:1 chats.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                decoration: InputDecoration(
                  labelText: 'Search friends',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Friends',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Selected: ${_selectedMembers.length}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_availableUsers.isEmpty)
                        Text(
                          'No friends available',
                          style: theme.textTheme.bodyMedium,
                        )
                      else if (filteredUsers.isEmpty)
                        Text(
                          'No friends match your search',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final userId = int.tryParse(user.id);
                              final checked =
                                  userId != null &&
                                  _selectedMembers.contains(userId);

                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                secondary: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primary,
                                  backgroundImage: user.profilePicture != null
                                      ? NetworkImage(
                                          AppConfig.absoluteUrl(
                                            user.profilePicture!,
                                          ),
                                        )
                                      : null,
                                  child: user.profilePicture == null
                                      ? Text(
                                          user.getInitials(),
                                          style: TextStyle(
                                            color: theme.colorScheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName
                                      : user.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: user.fullName.isNotEmpty
                                    ? Text(
                                        user.email,
                                        style: theme.textTheme.bodySmall,
                                      )
                                    : null,
                                value: checked,
                                onChanged: userId != null && !_isCreating
                                    ? (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            if (!_selectedMembers.contains(
                                              userId,
                                            )) {
                                              _selectedMembers.add(userId);
                                            }
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createGroup,
          child: _isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_selectedMembers.isEmpty) {
      _showErrorSnackBar('Select at least one friend');
      return;
    }

    // Group name is only required for group chats (2+ selected friends).
    if (_selectedMembers.length > 1 &&
        _groupNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Group name is required');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final group = await _chatManager.createChatGroup(
        // For 1:1 chats, backend auto-names the group to the other user.
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
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
