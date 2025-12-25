import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'api_config.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  // Configuration pour macOS et iOS
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Utilise la configuration centralisée de l'API
  final String baseUrl = ApiConfig.authUrl;

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
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      // Le back-end retourne 'access' et 'refresh' (pas 'access_token' / 'refresh_token')
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;
      if (access != null && refresh != null) {
        await _storeTokens(access, refresh);
        return {'ok': true};
      }
      return {'ok': false, 'message': 'Missing tokens in response'};
    }

    // Extraire le message d'erreur du back-end
    try {
      final errorData = jsonDecode(resp.body);
      return {'ok': false, 'message': errorData['detail'] ?? resp.body};
    } catch (_) {
      return {'ok': false, 'message': resp.body};
    }
  }

  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
    String? phone,
    String? bio,
    String? preferredPosition,
    String? avatarUrl,
  }) async {
    final url = Uri.parse('$baseUrl/register');
    final body = {'username': username, 'email': email, 'password': password};

    // Ajouter les champs optionnels s'ils sont présents
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (bio != null && bio.isNotEmpty) body['bio'] = bio;
    if (preferredPosition != null && preferredPosition.isNotEmpty) {
      body['preferred_position'] = preferredPosition;
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty)
      body['avatar_url'] = avatarUrl;

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return {'ok': true};
    }

    // Extraire le message d'erreur du back-end
    try {
      final errorData = jsonDecode(resp.body);
      return {'ok': false, 'message': errorData['detail'] ?? resp.body};
    } catch (_) {
      return {'ok': false, 'message': resp.body};
    }
  }

  Future<bool> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    final url = Uri.parse('$baseUrl/refresh');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      // Le back-end retourne 'access' et 'refresh' (pas 'access_token' / 'refresh_token')
      final access = data['access'] as String?;
      final refreshNew = data['refresh'] as String?;
      if (access != null && refreshNew != null) {
        await _storeTokens(access, refreshNew);
        return true;
      }
    }
    await _clearTokens();
    return false;
  }

  Future<void> logout() async {
    // Révoquer le refresh token côté serveur
    final refresh = await getRefreshToken();
    if (refresh != null) {
      try {
        final url = Uri.parse('$baseUrl/revoke');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refresh}),
        );
      } catch (_) {
        // Ignore les erreurs de révocation
      }
    }
    await _clearTokens();
  }

  /// Récupère les informations de l'utilisateur connecté
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final authHeader = await getAuthHeader();
    if (authHeader == null) return null;

    final url = Uri.parse('$baseUrl/me');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Met à jour les informations de l'utilisateur connecté
  Future<Map<String, dynamic>> updateCurrentUser({
    String? email,
    String? phone,
    String? bio,
    String? preferredPosition,
    String? avatarUrl,
  }) async {
    final authHeader = await getAuthHeader();
    if (authHeader == null) {
      return {'ok': false, 'message': 'Non authentifié'};
    }

    final body = <String, dynamic>{};
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (bio != null) body['bio'] = bio;
    if (preferredPosition != null)
      body['preferred_position'] = preferredPosition;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final url = Uri.parse('$baseUrl/me');
    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      return {'ok': true, 'user': jsonDecode(resp.body)};
    }

    try {
      final errorData = jsonDecode(resp.body);
      return {'ok': false, 'message': errorData['detail'] ?? resp.body};
    } catch (_) {
      return {'ok': false, 'message': resp.body};
    }
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

  /// Récupère le profil public d'un utilisateur par son ID
  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    final authHeader = await getAuthHeader();
    if (authHeader == null) return null;

    final url = Uri.parse('$baseUrl/users/$userId');
    final resp = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
    );

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }
}
