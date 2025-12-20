import 'package:flutter/material.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/friends_api_service.dart';
import 'package:frontend/config/app_config.dart';
import 'dart:async';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  String _error = '';
  List<UserSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _error = '';
        _results = const [];
      });
      return;
    }

    _debounce = Timer(const Duration(seconds: 2), () {
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _error = '';
        _results = const [];
      });
      return;
    }

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

    final index = _results.indexWhere((r) => r.user.id == userId);
    if (index == -1) return;
    final currentStatus = _results[index].friendshipStatus;
    if (currentStatus != FriendshipStatus.none) return;

    // Optimistic UI: immediately show Pending.
    setState(() {
      _results = List<UserSearchResult>.from(_results);
      _results[index] = UserSearchResult(
        user: _results[index].user,
        friendshipStatus: FriendshipStatus.pending,
      );
    });

    try {
      await FriendsApiService.sendFriendRequest(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Revert optimistic update on failure.
        final idx = _results.indexWhere((r) => r.user.id == userId);
        if (idx != -1) {
          _results = List<UserSearchResult>.from(_results);
          _results[idx] = UserSearchResult(
            user: _results[idx].user,
            friendshipStatus: FriendshipStatus.none,
          );
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _buttonLabel(FriendshipStatus status) {
    return switch (status) {
      FriendshipStatus.accepted => 'Friends',
      FriendshipStatus.pending => 'Pending',
      FriendshipStatus.none => 'Add',
    };
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
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _runSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Search users',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                      _isSearching ? 'Searching...' : 'Search for users to add',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final user = result.user;
                      final status = result.friendshipStatus;

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
                          onPressed: status == FriendshipStatus.none
                              ? () => _sendRequest(user)
                              : null,
                          child: Text(_buttonLabel(status)),
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
