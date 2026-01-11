import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService.instance;

  bool _isAuthenticated = false;
  bool _isLoading = true;
  UserModel? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  UserModel? get currentUser => _currentUser;

  AuthProvider() {
    // lance l'initialisation
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    final valid = await _service.isAccessTokenValid();
    if (!valid) {
      final refreshed = await _service.refreshToken();
      _isAuthenticated = refreshed;
    } else {
      _isAuthenticated = true;
    }

    // Charger les infos utilisateur si authentifié
    if (_isAuthenticated) {
      await _loadCurrentUser();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    final userData = await _service.getCurrentUser();
    if (userData != null) {
      _currentUser = UserModel.fromJson(userData);
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await _service.login(username: username, password: password);
    if (res['ok'] == true) {
      _isAuthenticated = true;
      await _loadCurrentUser();
    }
    _isLoading = false;
    notifyListeners();
    return res;
  }

  Future<Map<String, dynamic>> signup(
    String username,
    String email,
    String password,
  ) async {
    _isLoading = true;
    notifyListeners();
    final res = await _service.signup(
      username: username,
      email: email,
      password: password,
    );
    _isLoading = false;
    notifyListeners();
    return res;
  }

  /// Recharge les informations de l'utilisateur depuis le serveur
  Future<void> refreshCurrentUser() async {
    await _loadCurrentUser();
    notifyListeners();
  }

  /// Supprime le compte de l'utilisateur
  Future<bool> deleteAccount() async {
    try {
      final success = await _service.deleteAccount();
      if (success) {
        _isAuthenticated = false;
        _currentUser = null;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Erreur deleteAccount: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }
}
