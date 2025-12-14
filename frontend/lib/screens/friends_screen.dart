import 'package:flutter/material.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/friends_api_service.dart';
import 'package:frontend/config/app_config.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();

  bool _isSearching = false;
  String _error = '';
  List<User> _results = const [];
  final Set<String> _requestedUserIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text;

    setState(() {
      _isSearching = true;
      _error = '';
    });

    try {
      final users = await FriendsApiService.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = users;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _sendRequest(User user) async {
    final userId = user.id;
    if (_requestedUserIds.contains(userId)) return;

    setState(() {
      _requestedUserIds.add(userId);
    });

    try {
      await FriendsApiService.sendFriendRequest(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requestedUserIds.remove(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _runSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Search users',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _runSearch,
                  child: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _isSearching
                          ? 'Searching...'
                          : 'Search for users to add',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final requested = _requestedUserIds.contains(user.id);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profilePicture != null
                              ? NetworkImage(
                                  AppConfig.absoluteUrl(user.profilePicture!),
                                )
                              : null,
                          child: user.profilePicture == null
                              ? Text(user.getInitials())
                              : null,
                        ),
                        title: Text('${user.firstName} ${user.lastName}'),
                        subtitle: Text(user.email),
                        trailing: ElevatedButton(
                          onPressed: requested ? null : () => _sendRequest(user),
                          child: Text(requested ? 'Sent' : 'Add'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
