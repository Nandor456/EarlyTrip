import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TokenService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _accessTokenKey = 'accessToken';
  static const String _refreshTokenKey = 'refreshToken';

  // Store tokens securely
  static Future<void> storeTokens(
    String accessToken,
    String refreshToken,
  ) async {
    try {
      await Future.wait([
        _secureStorage.write(key: _accessTokenKey, value: accessToken),
        _secureStorage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    } catch (e) {
      print('Error storing tokens: $e');
      throw Exception('Failed to store tokens securely');
    }
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      print('Error reading access token: $e');
      return null;
    }
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      print('Error reading refresh token: $e');
      return null;
    }
  }

  // Clear all tokens (for logout)
  static Future<void> clearTokens() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _accessTokenKey),
        _secureStorage.delete(key: _refreshTokenKey),
      ]);
    } catch (e) {
      print('Error clearing tokens: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // Check if access token is expired (client-side check)
  static Future<bool> isTokenExpired() async {
    final token = await getAccessToken();
    if (token == null) return true;

    try {
      // Decode JWT payload (basic check without verification)
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      final exp = payload['exp'];
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      print('Error checking token expiry: $e');
      return true; // Assume expired if we can't parse
    }
  }
}

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  // Prevent multiple simultaneous refresh attempts
  static bool _isRefreshing = false;

  static Future<http.Response> authenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    String? accessToken = await TokenService.getAccessToken();

    if (accessToken == null) {
      throw AuthException('No access token found. Please login again.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      ...?additionalHeaders, // Spread additional headers if provided
    };

    http.Response response = await _makeHttpRequest(
      endpoint,
      method,
      headers,
      body,
    );

    // If token expired, try to refresh
    if (response.statusCode == 401) {
      try {
        final responseBody = json.decode(response.body);
        final errorCode = responseBody['code'];

        // Only attempt refresh if it's specifically a token expiry
        if (errorCode == 'TOKEN_EXPIRED') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request with new token
            accessToken = await TokenService.getAccessToken();
            headers['Authorization'] = 'Bearer $accessToken';
            response = await _makeHttpRequest(endpoint, method, headers, body);
          } else {
            throw AuthException('Session expired. Please login again.');
          }
        } else {
          throw AuthException('Authentication failed. Please login again.');
        }
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Authentication error occurred.');
      }
    }

    return response;
  }

  static Future<http.Response> _makeHttpRequest(
    String endpoint,
    String method,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      switch (method.toUpperCase()) {
        case 'POST':
          return await http.post(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
        case 'PUT':
          return await http.put(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
        case 'DELETE':
          return await http.delete(uri, headers: headers);
        case 'PATCH':
          return await http.patch(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
        case 'GET':
        default:
          return await http.get(uri, headers: headers);
      }
    } catch (e) {
      throw NetworkException('Network error: ${e.toString()}');
    }
  }

  static Future<bool> _refreshToken() async {
    // Prevent multiple refresh attempts
    if (_isRefreshing) {
      // Wait for ongoing refresh to complete
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return await TokenService.getAccessToken() != null;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await TokenService.getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['accessToken'];
        final newRefreshToken = data['refreshToken'];

        if (newAccessToken != null) {
          await TokenService.storeTokens(
            newAccessToken,
            newRefreshToken ?? refreshToken,
          );
          return true;
        }
      } else if (response.statusCode == 401) {
        // Refresh token is invalid/expired
        await TokenService.clearTokens();
        return false;
      }
    } catch (e) {
      print('Token refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }

    return false;
  }

  // Logout method
  static Future<bool> logout() async {
    try {
      // Optional: Call server logout endpoint
      final refreshToken = await TokenService.getRefreshToken();
      if (refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'refreshToken': refreshToken}),
        );
      }
    } catch (e) {
      print('Server logout failed: $e');
      // Continue with local logout even if server call fails
    }

    // Always clear local tokens
    await TokenService.clearTokens();
    return true;
  }
}

// Custom exception classes for better error handling
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

// Usage example helper class
class ApiResponseHandler {
  static T handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json.decode(response.body);
      return fromJson(data);
    } else {
      final errorData = json.decode(response.body);
      final message = errorData['message'] ?? 'An error occurred';
      throw ApiException(message, response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException ($statusCode): $message';
}
