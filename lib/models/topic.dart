class Topic {
  final int id;
  final String title;
  final String? description;
  final bool assigned;
  final String? assignedTeam;

  Topic({
    required this.id,
    required this.title,
    this.description,
    required this.assigned,
    this.assignedTeam,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      assigned: json['assigned'] == true ||
          (json['status'] != null &&
              json['status'].toString().toLowerCase() == 'assigned'),
      assignedTeam: json['assigned_team'] as String?,
    );
  }

  bool get isAvailable => !assigned;
  bool get isAssigned => assigned;
}
