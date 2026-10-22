import 'package:flutter/material.dart';
import 'package:mobile/model/job.dart';
import 'package:mobile/provider/jobs_provider.dart';
import 'package:mobile/services/analytic_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/theme/theme.dart';
import 'package:provider/provider.dart';

class JobDetailsScreen extends StatefulWidget {
  const JobDetailsScreen({super.key, required this.job});

  final Job job;

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
    AnalyticsService.jobViewed(widget.job.id);
  }

  String? get _nextStatus => switch (_status) {
    'ASSIGNED' => 'IN_PROGRESS',
    'IN_PROGRESS' => 'COMPLETED',
    _ => null,
  };

  String? get _actionLabel => switch (_status) {
    'ASSIGNED' => 'Start Job',
    'IN_PROGRESS' => 'Complete Job',
    _ => null,
  };

  Future<void> _updateStatus() async {
    final nextStatus = _nextStatus;
    if (nextStatus == null || _isUpdating) return;

    final jobsProvider = context.read<JobsProvider>();

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final updatedJob = await jobsProvider.updateJobStatus(
        widget.job.id,
        nextStatus,
      );

      final newStatus = updatedJob['status'];
      if (newStatus is! String) {
        throw const ApiException('Invalid response from server.');
      }

      if (!mounted) return;

      setState(() => _status = newStatus);

      await AnalyticsService.jobStatusUpdated(widget.job.id, newStatus);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Job updated to $newStatus')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final actionLabel = _actionLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
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
                        color: AppColors.icon,
                        letterSpacing: 0.8,
                      ),
                    ),
                    _StatusBadge(status: _status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProgressStepper(status: _status),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoTile(
                  icon: Icons.description_outlined,
                  title: 'Description',
                  value: job.description.isEmpty
                      ? 'No description provided'
                      : job.description,
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: job.location.isEmpty
                      ? 'No location provided'
                      : job.location,
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                _InfoTile(
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
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: 16),
          ],
          if (actionLabel != null)
            FilledButton.icon(
              onPressed: _isUpdating ? null : _updateStatus,
              icon: _isUpdating
                  ? const SizedBox.shrink()
                  : Icon(
                      _status == 'ASSIGNED'
                          ? Icons.play_arrow
                          : Icons.check_circle,
                      size: 20,
                    ),
              label: _isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            )
          else
            const _CompletedBanner(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (status) {
      'ASSIGNED' => (
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
        Icons.schedule,
        'Assigned',
      ),
      'IN_PROGRESS' => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
        Icons.pending_outlined,
        'In Progress',
      ),
      'COMPLETED' => (
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
        Icons.check_circle_outline,
        'Completed',
      ),
      _ => (
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        Icons.info_outline,
        status,
      ),
    };

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
}

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.status});

  final String status;

  static const _steps = ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED'];
  static const _labels = ['Assigned', 'In Progress', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(status);

    return _SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Workflow Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.icon,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final isDone = currentIndex > index ~/ 2;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isDone ? AppColors.primary : AppColors.border,
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
                      color: isPassed
                          ? AppColors.primary
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.seed
                            : (isPassed
                                  ? AppColors.primary
                                  : AppColors.borderStrong),
                        width: isCurrent ? 2.5 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: isPassed && !isCurrent
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '${stepIndex + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.white : AppColors.icon,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[stepIndex],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppColors.primary : AppColors.icon,
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
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
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
                  color: AppColors.icon,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              message,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
