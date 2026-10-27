import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/team.dart';
import '../widgets/loading_view.dart';
import 'login_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<Team> _teams = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Last registered team details (with generated access code)
  Map<String, dynamic>? _justRegisteredTeam;

  final TextEditingController _teamNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await api.getTeams();
      if (mounted) {
        setState(() {
          _teams = list
              .map((e) => Team.fromJson(e as Map<String, dynamic>))
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
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load teams: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final result =
          await api.registerTeam(_teamNameController.text.trim());

      if (mounted) {
        setState(() {
          _justRegisteredTeam = result;
          _teamNameController.clear();
          _isRegistering = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team registered successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        _loadTeams();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'Team Registration',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Register participating teams and generate their unique access codes',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: _loadTeams,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh list',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Registration Form Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Register a New Team',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _teamNameController,
                            decoration: InputDecoration(
                              labelText: 'Team Name',
                              hintText: 'e.g. CyberKnights, ByteBusters 01',
                              prefixIcon:
                                  const Icon(Icons.groups_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter team name';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          onPressed: _isRegistering ? null : _handleRegister,
                          icon: _isRegistering
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1_rounded,
                                  size: 18),
                          label: const Text('Register Team'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Newly Created Access Code Display Banner
                    if (_justRegisteredTeam != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          border: Border.all(
                              color: const Color(0xFF86EFAC), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF16A34A), size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  'Team "${_justRegisteredTeam!['name']}" Successfully Registered!',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Access Code:  ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  SelectableText(
                                    '${_justRegisteredTeam!['code']}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  ElevatedButton.icon(
                                    onPressed: () => _copyToClipboard(
                                      '${_justRegisteredTeam!['code']}',
                                      'Access Code',
                                    ),
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 16),
                                    label: const Text('Copy Code'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16, color: Color(0xFF15803D)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Please save this access code and share it with the team. For security, previously registered team codes are not displayed in readable form.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Registered Teams List
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: _isLoading
                  ? const LoadingView(message: 'Loading registered teams...')
                  : _errorMessage != null
                      ? ErrorView(
                          message: _errorMessage!,
                          onRetry: _loadTeams,
                        )
                      : _teams.isEmpty
                          ? const EmptyStateView(
                              icon: Icons.group_off_outlined,
                              title: 'No Teams Registered',
                              subtitle:
                                  'Use the form above to register your first team and generate an access code.',
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
                                      DataColumn(label: Text('ID')),
                                      DataColumn(
                                          label: Text('Team Name',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      DataColumn(
                                          label: Text('Assignment Status',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    ],
                                    rows: _teams.map((t) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('#${t.id}',
                                              style: const TextStyle(
                                                  color: Color(0xFF64748B)))),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor:
                                                      const Color(0xFFEEF2FF),
                                                  child: Text(
                                                    t.name.isNotEmpty
                                                        ? t.name[0]
                                                            .toUpperCase()
                                                        : 'T',
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
                                                  t.name,
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
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: t.hasAssignment
                                                    ? const Color(0xFFD1FAE5)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                t.hasAssignment
                                                    ? 'Topic Assigned'
                                                    : 'Waiting for Topic',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: t.hasAssignment
                                                      ? const Color(0xFF047857)
                                                      : const Color(0xFFB45309),
                                                ),
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
