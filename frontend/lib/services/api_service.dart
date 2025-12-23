import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/config/app_config.dart';
import 'token_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const Duration _defaultTimeout = Duration(seconds: 15);

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

    final safeHeaders = Map<String, String>.from(headers);
    if (safeHeaders.containsKey('Authorization')) {
      safeHeaders['Authorization'] = 'Bearer ***';
    }
    debugPrint(
      'Making $method request to $endpoint with headers: $safeHeaders and body: $body',
    );
    http.Response response = await _makeHttpRequest(
      endpoint,
      method,
      headers,
      body,
    );

    // If token expired, try to refresh
    if (response.statusCode == 401) {
      debugPrint('Access token expired, attempting to refresh...');
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
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    return response;
  }

  static Future<http.Response> authenticatedMultipartRequest(
    String endpoint, {
    required http.MultipartFile file,
    Map<String, String>? fields,
    Map<String, String>? additionalHeaders,
  }) async {
    String? accessToken = await TokenService.getAccessToken();
    if (accessToken == null) {
      throw AuthException('No access token found. Please login again.');
    }

    Future<http.Response> sendWithToken(String token) async {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        ...?additionalHeaders,
      });
      request.fields.addAll(fields ?? const {});
      request.files.add(file);

      final streamed = await request.send().timeout(_defaultTimeout);
      return http.Response.fromStream(streamed);
    }

    http.Response response = await sendWithToken(accessToken);

    if (response.statusCode == 401) {
      try {
        final responseBody = json.decode(response.body);
        final errorCode = responseBody is Map ? responseBody['code'] : null;

        if (errorCode == 'TOKEN_EXPIRED') {
          final refreshed = await _refreshToken();
          if (refreshed) {
            accessToken = await TokenService.getAccessToken();
            if (accessToken == null) {
              throw AuthException('Session expired. Please login again.');
            }
            response = await sendWithToken(accessToken);
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
          return await http
              .post(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(_defaultTimeout);
        case 'PUT':
          return await http
              .put(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(_defaultTimeout);
        case 'DELETE':
          if (body == null) {
            return await http
                .delete(uri, headers: headers)
                .timeout(_defaultTimeout);
          }

          final request = http.Request('DELETE', uri);
          request.headers.addAll(headers);
          request.body = json.encode(body);
          final streamed = await request.send().timeout(_defaultTimeout);
          return await http.Response.fromStream(streamed);
        case 'PATCH':
          return await http
              .patch(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(_defaultTimeout);
        case 'GET':
        default:
          return await http.get(uri, headers: headers).timeout(_defaultTimeout);
      }
    } on TimeoutException {
      throw NetworkException(
        'Request timed out after ${_defaultTimeout.inSeconds}s: $uri',
      );
    } catch (e) {
      throw NetworkException('Network error calling $uri: ${e.toString()}');
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

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refreshToken': refreshToken}),
          )
          .timeout(_defaultTimeout);

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
    final status = response.statusCode;
    final body = response.body;

    if (status >= 200 && status < 300) {
      if (status == 204 || body.trim().isEmpty) {
        return fromJson(<String, dynamic>{});
      }

      try {
        final data = json.decode(body);
        return fromJson((data as Map).cast<String, dynamic>());
      } catch (e) {
        throw ApiException('Invalid server response', status);
      }
    }

    Map<String, dynamic> errorData = <String, dynamic>{};
    if (body.trim().isNotEmpty) {
      try {
        errorData = (json.decode(body) as Map).cast<String, dynamic>();
      } catch (_) {
        // Keep fallback empty map
      }
    }

    final message = (errorData['message'] as String?) ?? 'An error occurred';
    throw ApiException(message, status);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException ($statusCode): $message';
}
