import 'package:flutter/material.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/models/chat_group.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/services/chat_api_service.dart';
import 'package:frontend/services/friends_api_service.dart';
import 'package:frontend/utils/date_fomatter.dart';

class GroupInfoDialog extends StatefulWidget {
  final ChatGroup group;
  final List<User> initialMembers;
  final bool isAdmin;
  final bool showAdminControls;
  final ValueChanged<List<User>>? onMembersChanged;
  final VoidCallback? onGroupDeleted;

  const GroupInfoDialog({
    super.key,
    required this.group,
    required this.initialMembers,
    required this.isAdmin,
    required this.showAdminControls,
    this.onMembersChanged,
    this.onGroupDeleted,
  });

  @override
  State<GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<GroupInfoDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<User> _members = [];
  List<User> _friends = [];
  final Set<int> _selectedToAdd = <int>{};

  bool _isLoading = true;
  bool _isUpdating = false;
  String _searchQuery = '';

  bool get _isAdmin => widget.isAdmin;
  bool get _showAdminControls => _isAdmin && widget.showAdminControls;

  @override
  void initState() {
    super.initState();
    _members = List<User>.from(widget.initialMembers);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _isLoading = true);
      final members = await ChatApiService.getGroupMembers(widget.group.id);
      final friends = await FriendsApiService.getFriends();

      if (!mounted) return;
      setState(() {
        _members = members;
        _friends = friends;
        _isLoading = false;
      });

      widget.onMembersChanged?.call(_members);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load group info: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
      ),
    );
  }

  List<User> get _memberCandidates {
    final memberIdSet = _members.map((u) => u.id).toSet();
    final candidates = _friends
        .where((f) => !memberIdSet.contains(f.id))
        .toList();

    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return candidates;

    return candidates
        .where(
          (u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedToAdd.isEmpty || _isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      await ChatApiService.addGroupMembers(
        widget.group.id,
        _selectedToAdd.toList(),
      );

      final members = await ChatApiService.getGroupMembers(widget.group.id);
      if (!mounted) return;

      setState(() {
        _members = members;
        _selectedToAdd.clear();
        _isUpdating = false;
      });

      widget.onMembersChanged?.call(_members);
      _showSnackBar('Members added', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showSnackBar('Failed to add members: $e', isError: true);
    }
  }

  Future<void> _kickMember(User member) async {
    if (_isUpdating) return;

    final memberId = int.tryParse(member.id);
    if (memberId == null) {
      _showSnackBar('Invalid member id', isError: true);
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await ChatApiService.removeGroupMembers(widget.group.id, [memberId]);
      final members = await ChatApiService.getGroupMembers(widget.group.id);
      if (!mounted) return;

      setState(() {
        _members = members;
        _isUpdating = false;
      });

      widget.onMembersChanged?.call(_members);
      _showSnackBar('Member removed', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showSnackBar('Failed to remove member: $e', isError: true);
    }
  }

  Future<void> _deleteGroup() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      await ChatApiService.deleteGroup(widget.group.id);
      if (!mounted) return;

      widget.onGroupDeleted?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showSnackBar('Failed to delete group: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String titleText = widget.group.title;
    final ImageProvider<Object>? headerImage = widget.group.groupImage != null
        ? NetworkImage(AppConfig.absoluteUrl(widget.group.groupImage!))
        : (widget.group.directProfilePicUrl != null &&
              widget.group.directProfilePicUrl!.trim().isNotEmpty)
        ? NetworkImage(AppConfig.absoluteUrl(widget.group.directProfilePicUrl!))
        : null;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: headerImage,
            child: headerImage == null
                ? Text(
                    titleText.isNotEmpty
                        ? titleText.trim().characters.first.toUpperCase()
                        : 'G',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Created: ${DateFormatter.formatDate(widget.group.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isUpdating ? null : () => Navigator.pop(context),
            tooltip: 'Close',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  'Members',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_members.length})',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _members.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final member = _members[index];
                                  final isAdmin =
                                      member.id == widget.group.adminId;

                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      backgroundImage:
                                          member.profilePicture != null
                                          ? NetworkImage(
                                              AppConfig.absoluteUrl(
                                                member.profilePicture!,
                                              ),
                                            )
                                          : null,
                                      child: member.profilePicture == null
                                          ? Text(
                                              member.getInitials(),
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      member.fullName.isNotEmpty
                                          ? member.fullName
                                          : member.email,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    subtitle: member.fullName.isNotEmpty
                                        ? Text(
                                            member.email,
                                            style: theme.textTheme.bodySmall,
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isAdmin)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            child: Chip(
                                              label: const Text('Admin'),
                                              labelStyle:
                                                  theme.textTheme.bodySmall,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ),
                                        if (_showAdminControls && !isAdmin)
                                          IconButton(
                                            onPressed: _isUpdating
                                                ? null
                                                : () => _kickMember(member),
                                            icon: Icon(
                                              Icons.person_remove,
                                              color: theme.colorScheme.error,
                                            ),
                                            tooltip: 'Remove from group',
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showAdminControls) ...[
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add friends',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                onChanged: (value) {
                                  setState(() => _searchQuery = value);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search friends',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchQuery.trim().isEmpty
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
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: _memberCandidates.isEmpty
                                    ? Text(
                                        'No friends to add',
                                        style: theme.textTheme.bodySmall,
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: _memberCandidates.length,
                                        itemBuilder: (context, index) {
                                          final user = _memberCandidates[index];
                                          final id = int.tryParse(user.id);
                                          final checked =
                                              id != null &&
                                              _selectedToAdd.contains(id);

                                          return CheckboxListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            value: checked,
                                            title: Text(
                                              user.fullName.isNotEmpty
                                                  ? user.fullName
                                                  : user.email,
                                            ),
                                            subtitle: user.fullName.isNotEmpty
                                                ? Text(user.email)
                                                : null,
                                            onChanged:
                                                (id == null || _isUpdating)
                                                ? null
                                                : (selected) {
                                                    setState(() {
                                                      if (selected == true) {
                                                        _selectedToAdd.add(id);
                                                      } else {
                                                        _selectedToAdd.remove(
                                                          id,
                                                        );
                                                      }
                                                    });
                                                  },
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
      actions: [
        if (_showAdminControls)
          FilledButton(
            onPressed: (_isUpdating || _selectedToAdd.isEmpty)
                ? null
                : _addSelectedMembers,
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Add selected'),
          ),
        if (_showAdminControls)
          TextButton(
            onPressed: _isUpdating ? null : _deleteGroup,
            child: Text(
              'Delete group',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
