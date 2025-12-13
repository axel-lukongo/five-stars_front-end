import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService.instance;

  bool _isAuthenticated = false;
  bool _isLoading = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

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
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    final res = await _service.login(email: email, password: password);
    if (res['ok'] == true) {
      _isAuthenticated = true;
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

  Future<void> logout() async {
    await _service.logout();
    _isAuthenticated = false;
    notifyListeners();
  }
}
