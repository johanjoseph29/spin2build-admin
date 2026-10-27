class DashboardStats {
  final int totalTeams;
  final int totalTopics;
  final int assignedTopics;
  final int availableTopics;
  final int teamsWaiting;

  DashboardStats({
    required this.totalTeams,
    required this.totalTopics,
    required this.assignedTopics,
    required this.availableTopics,
    required this.teamsWaiting,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final totalTeams = json['total_teams'] as int? ?? 0;
    final assigned = json['assigned_topics'] as int? ?? 0;
    final waiting = json['teams_waiting'] as int? ??
        ((totalTeams - assigned) > 0 ? (totalTeams - assigned) : 0);

    return DashboardStats(
      totalTeams: totalTeams,
      totalTopics: json['total_topics'] as int? ?? 0,
      assignedTopics: assigned,
      availableTopics: json['available_topics'] as int? ?? 0,
      teamsWaiting: waiting,
    );
  }
}
