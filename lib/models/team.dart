class Team {
  final int id;
  final String name;
  final String code;
  final bool hasAssignment;

  Team({
    required this.id,
    required this.name,
    required this.code,
    required this.hasAssignment,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? json['access_code'] as String? ?? '',
      hasAssignment: json['has_assignment'] == true,
    );
  }
}
