import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/assignment.dart';
import '../widgets/loading_view.dart';
import 'login_screen.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<Assignment> _assignments = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (_autoRefreshEnabled) {
      _autoRefreshTimer =
          Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          _loadAssignments(silent: true);
        }
      });
    }
  }

  Future<void> _loadAssignments({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await api.getAssignments();
      if (mounted) {
        setState(() {
          _assignments = list
              .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 401) {
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          return;
        }
        if (!silent) {
          setState(() {
            _errorMessage = e.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = 'Failed to load assignments: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Assignment> get _filteredAssignments {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _assignments;

    return _assignments.where((a) {
      return a.teamName.toLowerCase().contains(query) ||
          a.teamCode.toLowerCase().contains(query) ||
          a.topicTitle.toLowerCase().contains(query);
    }).toList();
  }

  // --- Reset All Assignments Confirmation Flow ---
  void _showResetAssignmentsDialog() {
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isResetting = false;
    const requiredConfirmation = 'RESET ALL ASSIGNMENTS';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626), size: 28),
              SizedBox(width: 10),
              Text(
                'Reset All Team Assignments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action will clear all current team topic assignments in the competition database. '
                    'All topics will become available again and teams will need to spin anew.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'To prevent accidental resets, type "RESET ALL ASSIGNMENTS" below to confirm.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    decoration: InputDecoration(
                      labelText: 'Confirmation Text',
                      hintText: requiredConfirmation,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val != requiredConfirmation) {
                        return 'Type exact confirmation: $requiredConfirmation';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isResetting = true);
                      final api =
                          Provider.of<ApiService>(context, listen: false);
                      try {
                        await api.resetAssignments();
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All assignments have been reset!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                          _loadAssignments();
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => isResetting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: isResetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reset All Assignments'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssignments;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team Topic Assignments',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live monitor of assigned topics (${_assignments.length} assignments active)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showResetAssignmentsDialog,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset Assignments'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search Bar & Controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by team name, code or topic...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Auto-refresh Switch
              FilterChip(
                avatar: Icon(
                  _autoRefreshEnabled
                      ? Icons.sync_rounded
                      : Icons.sync_disabled_rounded,
                  size: 16,
                  color: _autoRefreshEnabled
                      ? const Color(0xFF6366F1)
                      : Colors.grey,
                ),
                label: Text(
                  _autoRefreshEnabled ? 'Auto-Refresh (10s)' : 'Auto-Refresh Off',
                  style: TextStyle(
                    fontSize: 12,
                    color: _autoRefreshEnabled
                        ? const Color(0xFF6366F1)
                        : Colors.grey,
                  ),
                ),
                selected: _autoRefreshEnabled,
                onSelected: (val) {
                  setState(() {
                    _autoRefreshEnabled = val;
                    _startAutoRefresh();
                  });
                },
              ),
              const SizedBox(width: 14),

              IconButton.filledTonal(
                onPressed: () => _loadAssignments(),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh assignments now',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Assignments Table
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: _isLoading
                  ? const LoadingView(message: 'Loading live assignments...')
                  : _errorMessage != null
                      ? ErrorView(
                          message: _errorMessage!,
                          onRetry: () => _loadAssignments(),
                        )
                      : filtered.isEmpty
                          ? EmptyStateView(
                              icon: Icons.assignment_turned_in_outlined,
                              title: 'No Assignments Recorded',
                              subtitle: _assignments.isEmpty
                                  ? 'Registered teams will appear here once they spin and are assigned a topic.'
                                  : 'No assignments match the search query.',
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SingleChildScrollView(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(
                                      const Color(0xFFF8FAFC),
                                    ),
                                    columns: const [
                                      DataColumn(
                                        label: Text('Team Name',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      DataColumn(
                                        label: Text('Access Code',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      DataColumn(
                                        label: Text('Assigned Topic',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      DataColumn(
                                        label: Text('Assigned Timestamp',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                    rows: filtered.map((a) {
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
                                                        ? a.teamName[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF6366F1),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  a.teamName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
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
                                                const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Color(0xFF10B981),
                                                    size: 16),
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
                                                  ? a.assignedAt
                                                      .replaceFirst('T', ' ')
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
            ),
          ),
        ],
      ),
    );
  }
}
