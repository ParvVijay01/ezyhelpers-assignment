import 'package:flutter/foundation.dart';
import 'package:mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.apiService});

  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'username';

  final ApiService apiService;

  String? _token;
  String? _username;
  bool _isLoading = false;

  String? get token => _token;
  String? get username => _username;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);

    if (savedToken == null || savedToken.isEmpty) {
      return false;
    }

    _token = savedToken;
    _username = prefs.getString(_usernameKey);
    notifyListeners();
    return true;
  }

  Future<void> login(String username, String password) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await apiService.post(
        '/api/auth/login/',
        body: {'username': username.trim(), 'password': password},
      );

      final newToken = result is Map ? result['token'] : null;
      if (newToken is! String || newToken.isEmpty) {
        throw const ApiException('Invalid response from server.');
      }

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_tokenKey, newToken),
        prefs.setString(_usernameKey, username.trim()),
      ]);

      _token = newToken;
      _username = username.trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_tokenKey),
      prefs.remove(_usernameKey),
    ]);

    _token = null;
    _username = null;
    notifyListeners();
  }
}