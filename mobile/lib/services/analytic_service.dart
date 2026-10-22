import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logging/logging.dart';

class AnalyticsService {
  AnalyticsService._();

  static final _log = Logger('Analytics');

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> loginSuccess() => _logEvent('login_success');

  static Future<void> jobViewed(int jobId) =>
      _logEvent('job_viewed', {'job_id': jobId});

  static Future<void> jobStatusUpdated(int jobId, String newStatus) =>
      _logEvent('job_status_updated', {
        'job_id': jobId,
        'new_status': newStatus,
      });

  static Future<void> _logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      _log.fine('Logged $name ${parameters ?? ''}');
    } catch (error, stackTrace) {
      _log.warning('Failed to log $name', error, stackTrace);
    }
  }
}
