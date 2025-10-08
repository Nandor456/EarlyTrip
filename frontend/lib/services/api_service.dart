import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

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
