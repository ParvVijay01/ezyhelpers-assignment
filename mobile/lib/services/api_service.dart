import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/model/job.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final String baseUrl = dotenv.env['BASE_URL'] ?? '';

  String? _token;
  String? _username;

  String? get token => _token;
  String? get username => _username;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setToken(String token) {
    _token = token;
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUsername = prefs.getString('username');
    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      _username = savedUsername;
      return true;
    }
    return false;
  }

  Future<void> _saveSession(String token, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('username', username);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('username');
    _token = null;
    _username = null;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Token $_token',
  };

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Login failed');
    }

    final token = data['token'] as String;

    setToken(token);
    _username = username;
    await _saveSession(token, username);

    return Map<String, dynamic>.from(data);
  }

  Future<List<Job>> getJobs() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/jobs/'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Unable to load jobs');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) => Job.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> getJobDetails(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jobs/$id/'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Unable to load job details');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> updateJobStatus(int id, String newStatus) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/jobs/$id/status/'),
      headers: _headers,
      body: jsonEncode({'status': newStatus}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Unable to update job status');
    }

    return Map<String, dynamic>.from(data);
  }
}
