import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mobile/model/job.dart';
import 'package:mobile/services/api_service.dart';

class JobsProvider extends ChangeNotifier {
  JobsProvider({required this.apiService});

  static final _log = Logger('JobsProvider');

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
    if (token == null) {
      _jobs = [];
      _error = null;
    }
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
      _log.info('Loaded ${_jobs.length} jobs');
    } catch (error) {
      _error = error.toString();
      _log.warning('Failed to load jobs: $_error');
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

  Future<Map<String, dynamic>> updateJobStatus(int id, String newStatus) async {
    final result = await apiService.patch(
      '/api/jobs/$id/status/',
      body: {'status': newStatus},
      token: _token,
    );
    final updated = _asMap(result);

    final confirmedStatus = updated['status'];
    final index = _jobs.indexWhere((job) => job.id == id);
    if (confirmedStatus is String && index != -1) {
      _jobs = List.of(_jobs)
        ..[index] = _jobs[index].withStatus(confirmedStatus);
      _notify();
    }
    _log.info('Job $id status -> ${updated['status']}');

    return updated;
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
