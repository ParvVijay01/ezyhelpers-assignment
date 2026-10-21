import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> loginSuccess() async {
    debugPrint('Analytics: logging login_success');

    await _analytics.logEvent(name: 'login_success');

    debugPrint('Analytics: login_success logged');
  }

  static Future<void> jobViewed(int jobId) async {
    await _analytics.logEvent(
      name: 'job_viewed',
      parameters: {'job_id': jobId},
    );
  }

  static Future<void> jobStatusUpdated(int jobId, String newStatus) async {
    await _analytics.logEvent(
      name: 'job_status_updated',
      parameters: {'job_id': jobId, 'new_status': newStatus},
    );
  }
}
