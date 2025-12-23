import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class UserApiService {
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    bool? isDarkTheme,
  }) async {
    final response = await ApiService.authenticatedRequest(
      '/users/profile',
      method: 'PUT',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        if (isDarkTheme != null) 'isDarkTheme': isDarkTheme,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to update profile: ${response.body}');
  }

  Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    final multipartFile = await http.MultipartFile.fromPath(
      'profilePic',
      imageFile.path,
    );

    final response = await ApiService.authenticatedMultipartRequest(
      '/users/profile/picture',
      file: multipartFile,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to upload profile picture: ${response.body}');
  }
}
