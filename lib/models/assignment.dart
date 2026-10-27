class Assignment {
  final String teamName;
  final String teamCode;
  final String topicTitle;
  final String assignedAt;

  Assignment({
    required this.teamName,
    required this.teamCode,
    required this.topicTitle,
    required this.assignedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      teamName: json['team_name'] as String? ?? '',
      teamCode: json['team_code'] as String? ?? '',
      topicTitle: json['topic_title'] as String? ?? '',
      assignedAt: json['assigned_at'] as String? ?? '',
    );
  }
}
