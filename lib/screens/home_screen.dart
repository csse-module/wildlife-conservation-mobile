import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'report_incident_screen.dart';
import 'my_patrols_screen.dart';
import 'sync_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('Wildlife Dashboard'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: AppConstants.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncScreen()),
              );
            },
            tooltip: 'Sync Offline Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, user.role, user.name),
    );
  }

  Widget _buildBody(BuildContext context, String role, String name) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppConstants.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppConstants.lightGreen.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    size: 36,
                    color: AppConstants.primaryGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppConstants.textLight,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          role.replaceAll('_', ' '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Role-based Content
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppConstants.textDark,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildRoleBasedActions(context, role),
        ],
      ),
    );
  }

  Widget _buildRoleBasedActions(BuildContext context, String role) {
    List<Widget> actions = [];

    // Define complex actions based on user role
    // This perfectly encapsulates Role-Based Access Control (RBAC) in UI
    switch (role) {
      case 'PARK_MANAGER':
        actions = [
          _buildActionCard(context, Icons.map, 'Park Map', 'View detailed park map'),
          _buildActionCard(context, Icons.analytics, 'Analytics', 'View park statistics'),
          _buildActionCard(context, Icons.group, 'Manage Staff', 'Assign patrols and roles'),
        ];
        break;
      case 'RANGER':
        actions = [
          _buildActionCard(context, Icons.directions_walk, 'My Patrols', 'View assigned routes'),
          _buildActionCard(context, Icons.report_problem, 'Report Incident', 'Log a new incident'),
          _buildActionCard(context, Icons.camera_alt, 'Camera Traps', 'Check trap images'),
        ];
        break;
      case 'RESEARCHER':
        actions = [
          _buildActionCard(context, Icons.pets, 'Wildlife Data', 'View tracking data'),
          _buildActionCard(context, Icons.library_books, 'Reports', 'Access research reports'),
        ];
        break;
      case 'LIAISON_OFFICER':
        actions = [
          _buildActionCard(context, Icons.campaign, 'Alerts', 'Broadcast community alerts'),
          _buildActionCard(context, Icons.forum, 'Community Reports', 'Review feedback'),
        ];
        break;
      case 'COMMUNITY_MEMBER':
        actions = [
          _buildActionCard(context, Icons.warning, 'Report Sighting', 'Report wildlife sighting'),
          _buildActionCard(context, Icons.notifications, 'Alerts', 'View local alerts'),
        ];
        break;
      default:
        actions = [
          _buildActionCard(context, Icons.info, 'Information', 'General information'),
        ];
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions,
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (title == 'Report Incident') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportIncidentScreen()),
            );
          } else if (title == 'My Patrols') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyPatrolsScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppConstants.primaryGreen),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: AppConstants.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
