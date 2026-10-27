import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/topic.dart';
import '../widgets/loading_view.dart';
import 'login_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({super.key});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  List<Topic> _topics = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all'; // 'all', 'available', 'assigned'

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await api.getTopics(search: _searchController.text);
      if (mounted) {
        setState(() {
          _topics = list
              .map((e) => Topic.fromJson(e as Map<String, dynamic>))
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
          _errorMessage = 'Failed to load topics: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Topic> get _filteredTopics {
    if (_filter == 'available') {
      return _topics.where((t) => t.isAvailable).toList();
    } else if (_filter == 'assigned') {
      return _topics.where((t) => t.isAssigned).toList();
    }
    return _topics;
  }

  // --- Add Topic Dialog ---
  void _showAddTopicDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Topic',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Topic Title *',
                      hintText: 'e.g. AI-powered Resume Analyzer',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Topic title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Brief instructions or rules for this topic...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      final api =
                          Provider.of<ApiService>(context, listen: false);
                      try {
                        await api.addTopic(titleCtrl.text,
                            description: descCtrl.text);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Topic added successfully!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                          _loadTopics();
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => isSubmitting = false);
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
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Topic'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Edit Topic Dialog ---
  void _showEditTopicDialog(Topic topic) {
    if (topic.isAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assigned topics cannot be edited directly.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: topic.title);
    final descCtrl = TextEditingController(text: topic.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Topic',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Topic Title *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Topic title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      final api =
                          Provider.of<ApiService>(context, listen: false);
                      try {
                        await api.editTopic(
                          topic.id,
                          title: titleCtrl.text,
                          description: descCtrl.text,
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Topic updated successfully!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                          _loadTopics();
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => isSubmitting = false);
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
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Delete Topic Confirmation ---
  void _confirmDeleteTopic(Topic topic) {
    if (topic.isAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete topic: it is currently assigned to a team.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Delete Topic?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${topic.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiService>(context, listen: false);
              try {
                await api.deleteTopic(topic.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Topic deleted'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                  _loadTopics();
                }
              } on ApiException catch (e) {
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Bulk Import Dialog ---
  void _showBulkImportDialog() {
    final textCtrl = TextEditingController();
    bool isSubmitting = false;
    Map<String, dynamic>? importResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final lines = textCtrl.text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Bulk Import Topics',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste multiple topic names, one per line:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textCtrl,
                      maxLines: 8,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText:
                            "AI Healthcare Diagnosis\nDecentralized Identity Vault\nCampus Food Waste Reducer\nSmart Home Energy Manager",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Valid lines detected: ${lines.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: lines.isNotEmpty
                                ? const Color(0xFF6366F1)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (importResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Summary:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Added: ${(importResult!['added'] as List?)?.length ?? 0}',
                              style: TextStyle(color: Colors.green.shade800),
                            ),
                            Text(
                              '• Duplicates Rejected: ${(importResult!['duplicates'] as List?)?.length ?? 0}',
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting || lines.isEmpty
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        final api =
                            Provider.of<ApiService>(context, listen: false);
                        try {
                          final res =
                              await api.bulkAddTopics(textCtrl.text);
                          setDialogState(() {
                            importResult = res;
                            isSubmitting = false;
                          });
                          _loadTopics();
                        } on ApiException catch (e) {
                          setDialogState(() => isSubmitting = false);
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
                icon: isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Import All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTopics;

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
                    'Topic Management',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total ${_topics.length} topics (${_topics.where((t) => t.isAvailable).length} available, ${_topics.where((t) => t.isAssigned).length} assigned)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showBulkImportDialog,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Bulk Import'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddTopicDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Topic'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search Bar
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadTopics(),
                  decoration: InputDecoration(
                    hintText: 'Search topics by title...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadTopics();
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

              // Filter Chips
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'available', label: Text('Available')),
                  ButtonSegment(value: 'assigned', label: Text('Assigned')),
                ],
                selected: {_filter},
                onSelectionChanged: (val) {
                  setState(() => _filter = val.first);
                },
              ),
              const SizedBox(width: 14),

              IconButton.filledTonal(
                onPressed: _loadTopics,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh list',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Table Content
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: _isLoading
                  ? const LoadingView(message: 'Loading topics...')
                  : _errorMessage != null
                      ? ErrorView(
                          message: _errorMessage!,
                          onRetry: _loadTopics,
                        )
                      : filtered.isEmpty
                          ? EmptyStateView(
                              icon: Icons.auto_stories_outlined,
                              title: 'No Topics Found',
                              subtitle: _topics.isEmpty
                                  ? 'Get started by adding your first topic or using bulk import.'
                                  : 'No topics match the current filter or search query.',
                              action: _topics.isEmpty
                                  ? ElevatedButton.icon(
                                      onPressed: _showAddTopicDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add First Topic'),
                                    )
                                  : null,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(
                                      const Color(0xFFF8FAFC),
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('ID')),
                                      DataColumn(
                                          label: Text('Topic Title',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      DataColumn(label: Text('Description')),
                                      DataColumn(
                                          label: Text('Status',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      DataColumn(
                                          label: Text('Actions',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    ],
                                    rows: filtered.map((topic) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text('#${topic.id}',
                                              style: const TextStyle(
                                                  color: Color(0xFF64748B)))),
                                          DataCell(
                                            Text(
                                              topic.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              topic.description?.isNotEmpty ==
                                                      true
                                                  ? topic.description!
                                                  : '—',
                                              style: TextStyle(
                                                  color: Colors.grey.shade600),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: topic.isAssigned
                                                    ? const Color(0xFFFEF3C7)
                                                    : const Color(0xFFD1FAE5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                topic.isAssigned
                                                    ? 'Assigned'
                                                    : 'Available',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: topic.isAssigned
                                                      ? const Color(0xFFB45309)
                                                      : const Color(0xFF047857),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18),
                                                  tooltip: topic.isAssigned
                                                      ? 'Cannot edit assigned topic'
                                                      : 'Edit topic',
                                                  color: topic.isAssigned
                                                      ? Colors.grey.shade300
                                                      : const Color(0xFF6366F1),
                                                  onPressed: topic.isAssigned
                                                      ? null
                                                      : () =>
                                                          _showEditTopicDialog(
                                                              topic),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 18),
                                                  tooltip: topic.isAssigned
                                                      ? 'Cannot delete assigned topic'
                                                      : 'Delete topic',
                                                  color: topic.isAssigned
                                                      ? Colors.grey.shade300
                                                      : Colors.red.shade400,
                                                  onPressed: topic.isAssigned
                                                      ? null
                                                      : () =>
                                                          _confirmDeleteTopic(
                                                              topic),
                                                ),
                                              ],
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
