import 'package:flutter/material.dart';
import 'package:mobile/model/job.dart';
import 'package:mobile/screens/job_detail_screen.dart';

import '../services/api_service.dart';

class JobsScreen extends StatefulWidget {
  final ApiService apiService;

  const JobsScreen({super.key, required this.apiService});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late Future<List<Job>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  void _loadJobs() {
    _jobsFuture = widget.apiService.getJobs();
  }

  Future<void> _refreshJobs() async {
    setState(_loadJobs);
    await _jobsFuture;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Jobs'),
        actions: [
          IconButton(
            onPressed: () => setState(_loadJobs),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh jobs',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshJobs,
        child: FutureBuilder<List<Job>>(
          future: _jobsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Unable to load jobs: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(_loadJobs),
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }

            final jobs = snapshot.data ?? [];

            if (jobs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 140),
                  Icon(Icons.work_outline, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('No jobs assigned yet.')),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      job.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.description),
                          const SizedBox(height: 8),
                          Text('Location: ${job.location}'),
                          const SizedBox(height: 8),
                          Text(
                            job.status,
                            style: TextStyle(
                              color: _statusColor(job.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => JobDetailsScreen()),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
