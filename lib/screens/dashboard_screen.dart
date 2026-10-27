import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/sidebar.dart';
import 'overview_view.dart';
import 'topics_screen.dart';
import 'teams_screen.dart';
import 'assignments_screen.dart';
import 'team_spin_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to end your admin session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = OverviewView(
          onNavigateToTopics: () => setState(() => _selectedIndex = 1),
          onNavigateToTeams: () => setState(() => _selectedIndex = 2),
          onNavigateToAssignments: () => setState(() => _selectedIndex = 3),
        );
        break;
      case 1:
        body = const TopicsScreen();
        break;
      case 2:
        body = const TeamsScreen();
        break;
      case 3:
        body = const AssignmentsScreen();
        break;
      case 4:
        body = const TeamSpinScreen();
        break;
      default:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              title: const Text(
                'SPIN2BUILD Admin',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (idx) {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = idx);
                },
                onLogout: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Sidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (idx) => setState(() => _selectedIndex = idx),
              onLogout: _handleLogout,
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
