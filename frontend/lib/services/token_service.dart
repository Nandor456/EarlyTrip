import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    final refreshToken = await getRefreshToken();
    return refreshToken != null && refreshToken.isNotEmpty;
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
