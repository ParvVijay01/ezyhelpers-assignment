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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'ASSIGNED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        icon = Icons.schedule;
        label = 'Assigned';
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        icon = Icons.pending_outlined;
        label = 'In Progress';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.check_circle_outline;
        label = 'Completed';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.info_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    final steps = ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'];
    final labels = ['Assigned', 'In Progress', 'Completed'];
    final currentIndex = steps.indexOf(_status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Workflow Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepBefore = index ~/ 2;
                final isDone = currentIndex > stepBefore;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isDone ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final isPassed = currentIndex >= stepIndex;
              final isCurrent = currentIndex == stepIndex;

              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isPassed ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFF0D9488)
                            : (isPassed ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1)),
                        width: isCurrent ? 2.5 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: isPassed && !isCurrent
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${stepIndex + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[stepIndex],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'JOB #${job.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    _buildStatusBadge(_status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressStepper(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _infoTile(
                  icon: Icons.description_outlined,
                  title: 'Description',
                  value: job.description.isEmpty ? 'No description provided' : job.description,
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                _infoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: job.location.isEmpty ? 'No location provided' : job.location,
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                _infoTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Scheduled At',
                  value: job.scheduledAt == null || job.scheduledAt!.isEmpty
                      ? 'Not scheduled'
                      : job.scheduledAt!,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_actionLabel != null)
            FilledButton.icon(
              onPressed: _isUpdating ? null : _updateStatus,
              icon: _isUpdating
                  ? const SizedBox.shrink()
                  : Icon(
                      _status == 'ASSIGNED' ? Icons.play_arrow : Icons.check_circle,
                      size: 20,
                    ),
              label: _isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _actionLabel!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Color(0xFF16A34A), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'This job is completed',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0F766E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
