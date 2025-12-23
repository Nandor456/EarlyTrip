import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/friends_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String _error = '';
  List<NotificationItem> _items = const [];
  final Set<String> _actioningNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await ApiService.authenticatedRequest(
        '/users/notifications',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final list = (decoded['notifications'] as List<dynamic>? ?? [])
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();

        if (!mounted) return;
        setState(() {
          _items = list;
          _isLoading = false;
        });
        return;
      }

      throw ApiException('Failed to load notifications', response.statusCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptFriendRequest(NotificationItem n) async {
    final fromUserId = n.fromUser?.id;
    if (fromUserId == null || fromUserId.isEmpty) return;

    setState(() => _actioningNotificationIds.add(n.id));
    try {
      await FriendsApiService.acceptFriendRequest(fromUserId);
      if (!mounted) return;
      setState(() {
        _items = _items.where((x) => x.id != n.id).toList();
        _actioningNotificationIds.remove(n.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request accepted')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _actioningNotificationIds.remove(n.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rejectFriendRequest(NotificationItem n) async {
    final fromUserId = n.fromUser?.id;
    if (fromUserId == null || fromUserId.isEmpty) return;

    setState(() => _actioningNotificationIds.add(n.id));
    try {
      await FriendsApiService.rejectFriendRequest(fromUserId);
      if (!mounted) return;
      setState(() {
        _items = _items.where((x) => x.id != n.id).toList();
        _actioningNotificationIds.remove(n.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request rejected')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _actioningNotificationIds.remove(n.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error.isNotEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(_error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : _items.isEmpty
        ? Center(
            child: Text('No notifications', style: theme.textTheme.bodyMedium),
          )
        : ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = _items[index];
              final isFriendRequest = n.type == 'FRIEND_REQUEST';
              final canAction = isFriendRequest && n.fromUser != null;
              final isActioning = _actioningNotificationIds.contains(n.id);

              return ListTile(
                leading: Icon(
                  n.type == 'FRIEND_REQUEST'
                      ? Icons.person_add_alt
                      : Icons.notifications,
                ),
                title: Text(n.message),
                subtitle: Text(
                  '${n.createdAt.toLocal()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: canAction
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: isActioning
                                ? null
                                : () => _rejectFriendRequest(n),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isActioning
                                ? null
                                : () => _acceptFriendRequest(n),
                            child: const Text('Accept'),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );

    if (!widget.showAppBar) {
      return SafeArea(child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: content,
    );
  }
}
