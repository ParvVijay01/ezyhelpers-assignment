import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.apiService}) {
    apiService.onUnauthorized = _handleUnauthorized;
  }

  static final _log = Logger('AuthProvider');
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
      _log.fine('No saved session');
      return false;
    }

    _token = savedToken;
    _username = prefs.getString(_usernameKey);
    _log.info('Restored saved session');
    notifyListeners();
    return true;
  }

  Future<void> login(String username, String password) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final cleanUsername = username.trim();
      final result = await apiService.post(
        '/api/auth/login/',
        body: {'username': cleanUsername, 'password': password},
      );

      final newToken = result is Map ? result['token'] : null;
      if (newToken is! String || newToken.isEmpty) {
        throw const ApiException('Invalid response from server.');
      }

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_tokenKey, newToken),
        prefs.setString(_usernameKey, cleanUsername),
      ]);

      _token = newToken;
      _username = cleanUsername;
      _log.info('Login succeeded');
    } on ApiException catch (error) {
      _log.info('Login failed: ${error.message}');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final previousToken = _token;
    await _clearSession();
    _log.info('Logged out');

    if (previousToken == null) return;

    try {
      await apiService.post('/api/auth/logout/', token: previousToken);
    } on ApiException catch (error) {
      _log.info('Server-side logout skipped: ${error.message}');
    }
  }

  void _handleUnauthorized() {
    if (!isAuthenticated) return;
    _log.warning('Session expired or revoked; signing out');
    unawaited(_clearSession());
  }

  Future<void> _clearSession() async {
    _token = null;
    _username = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove(_tokenKey), prefs.remove(_usernameKey)]);
  }

  @override
  void dispose() {
    apiService.onUnauthorized = null;
    super.dispose();
  }
}
