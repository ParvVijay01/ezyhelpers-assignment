class Job {
  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    this.scheduledAt,
  });

  final int id;
  final String title;
  final String description;
  final String location;
  final String status;
  final String? scheduledAt;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: json['status'] as String,
      scheduledAt: json['scheduled_at'] as String?,
    );
  }

  Job withStatus(String newStatus) {
    return Job(
      id: id,
      title: title,
      description: description,
      location: location,
      status: newStatus,
      scheduledAt: scheduledAt,
    );
  }
}
