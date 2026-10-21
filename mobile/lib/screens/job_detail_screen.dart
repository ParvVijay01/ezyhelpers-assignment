import 'package:flutter/material.dart';
import 'package:mobile/model/job.dart';
import 'package:mobile/services/analytic_service.dart';

import '../services/api_service.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;
  final ApiService apiService;

  const JobDetailsScreen({
    super.key,
    required this.job,
    required this.apiService,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  late String _status;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _status = widget.job.status;

    // Log once when this details screen is opened.
    _logJobViewed();
  }

  Future<void> _logJobViewed() async {
    try {
      await AnalyticsService.jobViewed(widget.job.id);
    } catch (error) {
      debugPrint('Failed to log job_viewed: $error');
    }
  }

  String? get _nextStatus {
    switch (_status) {
      case 'ASSIGNED':
        return 'IN_PROGRESS';
      case 'IN_PROGRESS':
        return 'COMPLETED';
      default:
        return null;
    }
  }

  String? get _actionLabel {
    switch (_status) {
      case 'ASSIGNED':
        return 'Start Job';
      case 'IN_PROGRESS':
        return 'Complete Job';
      default:
        return null;
    }
  }

  Future<void> _updateStatus() async {
    final nextStatus = _nextStatus;
    if (nextStatus == null || _isUpdating) return;

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final updatedJob = await widget.apiService.updateJobStatus(
        widget.job.id,
        nextStatus,
      );

      final newStatus = updatedJob['status'] as String;

      if (!mounted) return;

      setState(() {
        _status = newStatus;
      });

      // The backend update succeeded, so log the event.
      try {
        await AnalyticsService.jobStatusUpdated(widget.job.id, newStatus);
      } catch (error) {
        // Analytics failures should not make a successful job update
        // appear to have failed.
        debugPrint('Failed to log job_status_updated: $error');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Job updated to $_status')));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(job.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          _detailRow('Description', job.description),
          _detailRow('Location', job.location),
          _detailRow('Scheduled At', job.scheduledAt ?? 'Not scheduled'),
          _detailRow('Current Status', _status),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          if (_actionLabel != null)
            FilledButton(
              onPressed: _isUpdating ? null : _updateStatus,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_actionLabel!),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This job has been completed.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(value.isEmpty ? 'Not provided' : value),
        ],
      ),
    );
  }
}
