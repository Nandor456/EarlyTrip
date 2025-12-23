import 'package:flutter/material.dart';
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

    final filteredUsers = _searchQuery.trim().isEmpty
        ? _availableUsers
        : _availableUsers.where((user) {
            final q = _searchQuery.trim().toLowerCase();
            return user.fullName.toLowerCase().contains(q) ||
                user.email.toLowerCase().contains(q);
          }).toList();

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
                const Text('No friends available')
              else if (filteredUsers.isEmpty)
                const Text('No friends match your search')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
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
    _searchController.dispose();
    super.dispose();
  }
}
