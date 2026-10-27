import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/dashboard_stats.dart';
import '../models/assignment.dart';
import '../widgets/stat_card.dart';
import '../widgets/loading_view.dart';
import 'login_screen.dart';

class OverviewView extends StatefulWidget {
  final VoidCallback onNavigateToTopics;
  final VoidCallback onNavigateToTeams;
  final VoidCallback onNavigateToAssignments;

  const OverviewView({
    super.key,
    required this.onNavigateToTopics,
    required this.onNavigateToTeams,
    required this.onNavigateToAssignments,
  });

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  DashboardStats? _stats;
  List<Assignment> _recentAssignments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final statsFuture = api.getDashboardStats();
      final assignmentsFuture = api.getAssignments();

      final results = await Future.wait([statsFuture, assignmentsFuture]);

      final statsJson = results[0] as Map<String, dynamic>;
      final assignmentsList = results[1] as List<dynamic>;

      final assignments = assignmentsList
          .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _stats = DashboardStats.fromJson(statsJson);
          _recentAssignments = assignments;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 401) {
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          return;
        }
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView(message: 'Loading live dashboard statistics...');
    }

    if (_errorMessage != null) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    final stats = _stats ??
        DashboardStats(
          totalTeams: 0,
          totalTopics: 0,
          assignedTopics: 0,
          availableTopics: 0,
          teamsWaiting: 0,
        );

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final isTablet = screenWidth >= 700 && screenWidth < 1100;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Competition Overview',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live statistics and real-time team assignments',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh live data',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Statistics Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = isDesktop
                    ? (constraints.maxWidth - (4 * 16)) / 5
                    : isTablet
                        ? (constraints.maxWidth - (2 * 16)) / 3
                        : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: StatCard(
                        title: 'Total Teams',
                        value: '${stats.totalTeams}',
                        icon: Icons.groups_rounded,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: StatCard(
                        title: 'Total Topics',
                        value: '${stats.totalTopics}',
                        icon: Icons.auto_stories_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: StatCard(
                        title: 'Assigned Topics',
                        value: '${stats.assignedTopics}',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: StatCard(
                        title: 'Available Topics',
                        value: '${stats.availableTopics}',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: StatCard(
                        title: 'Teams Waiting',
                        value: '${stats.teamsWaiting}',
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),

            // Quick Actions & Recent Assignments Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Assignments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onNavigateToAssignments,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View All Assignments'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Assignments Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: _recentAssignments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: EmptyStateView(
                        icon: Icons.assignment_outlined,
                        title: 'No Assignments Yet',
                        subtitle:
                            'When teams spin and receive topics, their assignments will appear here live.',
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Team Name',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Team Code',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Assigned Topic',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Assigned Timestamp',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                          rows: _recentAssignments.take(8).map((a) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            const Color(0xFFEEF2FF),
                                        child: Text(
                                          a.teamName.isNotEmpty
                                              ? a.teamName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        a.teamName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      a.teamCode,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF10B981), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        a.topicTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    a.assignedAt.isNotEmpty
                                        ? a.assignedAt.replaceFirst('T', ' ')
                                        : '—',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
