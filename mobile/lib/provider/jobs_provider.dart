import 'package:flutter/foundation.dart';
import 'package:mobile/model/job.dart';
import 'package:mobile/services/api_service.dart';

class JobsProvider extends ChangeNotifier {
  JobsProvider({required this.apiService});

  final ApiService apiService;

  String? _token;
  List<Job> _jobs = [];
  bool _isLoading = false;
  bool _disposed = false;
  String? _error;

  List<Job> get jobs => List.unmodifiable(_jobs);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String? token) {
    _token = token;
  }

  Future<void> loadJobs() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final result = await apiService.get('/api/jobs/', token: _token);
      final items = result is Map ? result['results'] : result;

      if (items is! List) {
        throw const ApiException('Invalid response from server.');
      }

      _jobs = items
          .map((item) => Job.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void clear() {
    _jobs = [];
    _error = null;
    _notify();
  }

  Future<Map<String, dynamic>> getJobDetails(int id) async {
    final result = await apiService.get('/api/jobs/$id/', token: _token);
    return _asMap(result);
  }

  Future<Map<String, dynamic>> updateJobStatus(
    int id,
    String newStatus,
  ) async {
    final result = await apiService.patch(
      '/api/jobs/$id/status/',
      body: {'status': newStatus},
      token: _token,
    );
    return _asMap(result);
  }

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is! Map) {
      throw const ApiException('Invalid response from server.');
    }
    return Map<String, dynamic>.from(result);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}