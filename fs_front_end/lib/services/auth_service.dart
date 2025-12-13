import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Ajuste cette URL vers ton API back-end
  final String baseUrl = 'https://your-api.example.com';

  static const String _keyAccess = 'access_token';
  static const String _keyRefresh = 'refresh_token';

  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _keyAccess, value: accessToken);
    await _storage.write(key: _keyRefresh, value: refreshToken);
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccess);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefresh);
  }

  Future<bool> isAccessTokenValid() async {
    final token = await getAccessToken();
    if (token == null) return false;
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access != null && refresh != null) {
        await _storeTokens(access, refresh);
        return {'ok': true};
      }
      return {'ok': false, 'message': 'Missing tokens in response'};
    }

    return {'ok': false, 'message': resp.body};
  }

  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return {'ok': true};
    }

    return {'ok': false, 'message': resp.body};
  }

  Future<bool> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    final url = Uri.parse('$baseUrl/auth/refresh');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refresh}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final access = data['access_token'] as String?;
      final refreshNew = data['refresh_token'] as String?;
      if (access != null && refreshNew != null) {
        await _storeTokens(access, refreshNew);
        return true;
      }
    }
    await _clearTokens();
    return false;
  }

  Future<void> logout() async {
    // Optionnel: appeler endpoint de logout côté serveur
    await _clearTokens();
  }

  /// Retourne l'en-tête Authorization si possible (essaie de rafraîchir si nécessaire)
  Future<String?> getAuthHeader() async {
    var access = await getAccessToken();
    if (access == null) return null;
    if (JwtDecoder.isExpired(access)) {
      final ok = await refreshToken();
      if (!ok) return null;
      access = await getAccessToken();
    }
    if (access == null) return null;
    return 'Bearer $access';
  }
}
