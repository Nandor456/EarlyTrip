import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String _error = '';
  List<NotificationItem> _items = const [];

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading
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
                        Text(
                          _error,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = _items[index];
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
                        );
                      },
                    ),
    );
  }
}
