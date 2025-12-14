import 'package:flutter/material.dart';
import 'package:frontend/managers/chat_data_manager.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/socket_service.dart';
import 'package:frontend/utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_config.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _emailController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  final ChatDataManager _chatManager = ChatDataManager();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = _chatManager.currentUser;
    _emailController = TextEditingController(text: user?.email ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
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
                              fontSize: 30,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.secondary,
                      child: IconButton(
                        onPressed: _changeProfilePicture,
                        icon: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: theme.colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              enabled: false,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Dark Theme'),
                      value: themeProvider.isDarkTheme,
                      onChanged: (value) => themeProvider.setTheme(value),
                      activeThumbColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeProfilePicture() {
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
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Gallery selection not yet implemented');
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.iconTheme.color),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _showErrorSnackBar('Camera capture not yet implemented');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      // TODO: Implement profile update API call
      // final updatedUser = await ChatApiService.updateUserProfile(
      //   firstName: _firstNameController.text.trim(),
      //   lastName: _lastNameController.text.trim(),
      // );
      // if (updatedUser != null) {
      //   _showSuccessSnackBar('Profile updated successfully');
      // } else {
      //   _showErrorSnackBar('Failed to update profile');
      // }
      _showErrorSnackBar('Profile update not yet implemented');
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final theme = Theme.of(context);
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // Use the centralized ApiService logout method
        await ApiService.logout();
        _chatManager.clearCache();
        SocketService().disconnect();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error logging out: $e');
        }
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
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
