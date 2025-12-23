import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/managers/chat_data_manager.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/socket_service.dart';
import 'package:frontend/utils/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/services/user_api_service.dart';
import 'package:frontend/models/user.dart';

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

  bool _themeInitialized = false;
  bool _pendingIsDarkTheme = false;

  final ImagePicker _picker = ImagePicker();
  File? _pendingProfileImage;

  bool _isForcingLogout = false;

  @override
  void initState() {
    super.initState();
    final user = _chatManager.currentUser;
    _emailController = TextEditingController(text: user?.email ?? '');
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_themeInitialized) {
      final themeProvider = Provider.of<ThemeProvider>(context);
      _pendingIsDarkTheme = themeProvider.isDarkTheme;
      _themeInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _chatManager.currentUser;

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
                    backgroundImage: _pendingProfileImage != null
                        ? FileImage(_pendingProfileImage!)
                        : currentUser?.profilePicture != null
                        ? NetworkImage(
                            AppConfig.absoluteUrl(currentUser!.profilePicture!),
                          )
                        : null,
                    child:
                        (_pendingProfileImage == null &&
                            currentUser?.profilePicture == null)
                        ? Text(
                            currentUser?.getInitials() ?? 'U',
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
                      value: _pendingIsDarkTheme,
                      onChanged: (value) {
                        setState(() => _pendingIsDarkTheme = value);
                      },
                      activeThumbColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.all(12),
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
              onTap: () async {
                Navigator.pop(context);
                await _pickProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.iconTheme.color),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickProfileImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 75);
      if (picked == null) return;

      setState(() {
        _pendingProfileImage = File(picked.path);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final userApi = UserApiService();

      if (_pendingProfileImage != null) {
        final uploaded = await userApi.uploadProfilePicture(
          _pendingProfileImage!,
        );
        final updatedUserJson = uploaded['user'];
        if (updatedUserJson is Map) {
          _chatManager.updateCurrentUser(
            User.fromJson(updatedUserJson.cast<String, dynamic>()),
          );
        }
      }

      final updated = await userApi.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        isDarkTheme: _pendingIsDarkTheme,
      );

      final updatedUserJson = updated['user'];
      if (updatedUserJson is Map) {
        final user = User.fromJson(updatedUserJson.cast<String, dynamic>());
        _chatManager.updateCurrentUser(user);
        _firstNameController.text = user.firstName;
        _lastNameController.text = user.lastName;
      }

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.setTheme(_pendingIsDarkTheme);

      if (mounted) {
        setState(() => _pendingProfileImage = null);
      }

      _showSuccessSnackBar('Settings saved');
    } catch (e) {
      await _forceLogout();
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _forceLogout() async {
    if (_isForcingLogout) return;
    _isForcingLogout = true;

    try {
      await ApiService.logout();
    } catch (_) {
      // Ignore; still proceed.
    }

    _chatManager.clearCache();
    SocketService().disconnect();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    });
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
