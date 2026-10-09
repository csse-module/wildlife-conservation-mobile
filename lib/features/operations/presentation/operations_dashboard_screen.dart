import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/add_park_screen.dart';
import '../../../screens/add_staff_screen.dart';
import '../../../screens/assign_patrol_screen.dart';
import '../../../screens/change_password_screen.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/my_patrols_screen.dart';
import '../../../screens/rangers_list_screen.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import '../domain/role_capabilities.dart';
import 'alerts_screen.dart';
import 'camera_images_screen.dart';
import 'field_reports_screen.dart';
import 'report_form_screen.dart';
import 'reporting_screen.dart';
import 'widgets.dart';

class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({super.key});
  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen>
    with WidgetsBindingObserver {
  late Future<List<ParkInfo>> _parks;
  Future<ResultPage<FieldReport>>? _feed, _pending;
  Future<ResultPage<AlertInfo>>? _alerts;
  Future<ConservationAnalytics>? _analytics;
  String? _parkId;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadParks();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          _parkId != null) {
        setState(_load);
      }
    });
  }

  void _loadParks() {
    _parks = context.read<ParkRepository>().list().then((parks) {
      if (mounted) {
        _parkId ??= parks.isEmpty ? null : parks.first.id;
        if (_parkId != null) _load();
      }
      return parks;
    });
  }

  void _load() {
    final role = context.read<AuthProvider>().user?.role;
    if (_parkId == null) return;
    if (role == 'RESEARCHER') {
      final now = DateUtils.dateOnly(DateTime.now());
      _analytics = context.read<ReportingRepository>().analytics(
        _parkId!,
        now.subtract(const Duration(days: 29)),
        now,
      );
    } else {
      _feed = context.read<FieldReportRepository>().list(
        ReportKind.community,
        parkId: _parkId,
      );
      _pending = context.read<FieldReportRepository>().list(
        ReportKind.community,
        parkId: _parkId,
        status: 'SUBMITTED',
      );
      if (role != 'COMMUNITY_MEMBER') {
        _alerts = context.read<AlertRepository>().list(
          parkId: _parkId,
          status: 'NEW',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _parkId != null) {
      setState(_load);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open(OperationAction action) async {
    final page = switch (action) {
      OperationAction.reportConflict => const ReportFormScreen(),
      OperationAction.reportIncident => const ReportFormScreen(
        kind: ReportKind.incident,
      ),
      OperationAction.communityReports => FieldReportsScreen(parkId: _parkId),
      OperationAction.incidents => FieldReportsScreen(
        kind: ReportKind.incident,
        parkId: _parkId,
      ),
      OperationAction.alerts => AlertsScreen(parkId: _parkId),
      OperationAction.analytics => ReportingScreen(parkId: _parkId),
      OperationAction.cameras => CameraImagesScreen(parkId: _parkId),
      OperationAction.addStaff => const AddStaffScreen(),
      OperationAction.addPark => const AddParkScreen(),
      OperationAction.assignPatrol => const AssignPatrolScreen(),
      OperationAction.rangers => const RangersListScreen(),
      OperationAction.myPatrols => const MyPatrolsScreen(),
      OperationAction.outbox => const ReportOutboxScreen(),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() {
        if (action == OperationAction.addPark) {
          _loadParks();
        } else {
          _load();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Your session has ended. Please sign in again.'),
        ),
      );
    }
    final title = switch (user.role) {
      'PARK_MANAGER' => 'Park Manager Dashboard',
      'RESEARCHER' => 'Research Dashboard',
      'LIAISON_OFFICER' => 'Community Liaison Dashboard',
      'RANGER' => 'Ranger Dashboard',
      _ => 'Community Dashboard',
    };
    return OperationScaffold(
      title: title,
      actions: [
        IconButton(
          onPressed: _parkId == null ? null : () => setState(_load),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh dashboard',
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'password') {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
              return;
            }
            await context.read<AuthProvider>().logout();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'password',
              child: Text('Change password'),
            ),
            const PopupMenuItem(value: 'logout', child: Text('Sign out')),
          ],
        ),
      ],
      body: FutureBuilder<List<ParkInfo>>(
        future: _parks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return FailurePanel(
              snapshot.error.toString(),
              retry: () => setState(_loadParks),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              try {
                await _feed;
              } catch (_) {}
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  user.role == 'PARK_MANAGER'
                      ? 'Admin access · ${readable(user.role)}'
                      : readable(user.role),
                ),
                const SizedBox(height: 20),
                if (snapshot.data!.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _parkId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selected park',
                    ),
                    items: snapshot.data!
                        .map(
                          (park) => DropdownMenuItem(
                            value: park.id,
                            child: Text(park.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setState(() {
                      _parkId = id;
                      _load();
                    }),
                  ),
                if (snapshot.data!.isEmpty)
                  const Text(
                    'No parks are assigned to this account. Contact your park manager.',
                  ),
                const SizedBox(height: 16),
                const OutboxBanner(),
                if (user.role != 'RESEARCHER' && _parkId != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _countCard('Community reports', _feed),
                      _countCard('Awaiting response', _pending),
                      if (_alerts != null)
                        SizedBox(
                          width: 210,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: FutureBuilder<ResultPage<AlertInfo>>(
                                future: _alerts,
                                builder: (context, data) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('New conflict alerts'),
                                    Text(
                                      data.hasError
                                          ? 'Unavailable'
                                          : data.hasData
                                          ? '${data.data!.totalItems}'
                                          : '...',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (_feed != null &&
                    user.role != 'COMMUNITY_MEMBER' &&
                    user.role != 'RESEARCHER')
                  _communityFeed(user.role),
                const SizedBox(height: 16),
                Text(
                  'Quick actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: actionsForRole(user.role).map((action) {
                      final item = _action(
                        action,
                        community: user.role == 'COMMUNITY_MEMBER',
                      );
                      return SizedBox(
                        width: constraints.maxWidth >= 680
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth,
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(item.icon),
                            title: Text(item.title),
                            subtitle: Text(item.subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(action),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                if (_feed != null && user.role == 'COMMUNITY_MEMBER')
                  _communityFeed(user.role),
                if (user.role == 'RESEARCHER' && _analytics != null)
                  FutureBuilder<ConservationAnalytics>(
                    future: _analytics,
                    builder: (context, data) {
                      if (data.hasError) {
                        return FailurePanel(
                          data.error.toString(),
                          retry: () => setState(_load),
                        );
                      }
                      if (!data.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return SectionCard(
                        title: 'Conservation overview · last 30 days',
                        child: Text(
                          '${data.data!.totalIncidents} incidents · ${data.data!.communityReportCount} community reports\nOpen Analytics & reports to explore trends and download a report.',
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _communityFeed(String role) => SectionCard(
    title: role == 'COMMUNITY_MEMBER'
        ? 'My recent reports'
        : 'Incoming community reports',
    child: FutureBuilder<ResultPage<FieldReport>>(
      future: _feed,
      builder: (context, data) {
        if (data.hasError) {
          return FailurePanel(
            data.error.toString(),
            retry: () => setState(_load),
          );
        }
        if (!data.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.data!.items.isEmpty) {
          return const Text('No community reports received for this park.');
        }
        return Column(
          children: [
            ...data.data!.items
                .take(5)
                .map(
                  (report) => FieldReportTile(
                    report: report,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FieldReportDetailScreen(
                            id: report.id,
                            kind: ReportKind.community,
                          ),
                        ),
                      );
                      if (mounted) setState(_load);
                    },
                  ),
                ),
            TextButton(
              onPressed: () => _open(OperationAction.communityReports),
              child: const Text('View all reports'),
            ),
            if (role != 'COMMUNITY_MEMBER')
              const Text(
                'Refreshes every 30 seconds while this dashboard is open.',
              ),
          ],
        );
      },
    ),
  );

  Widget _countCard(String label, Future<ResultPage<FieldReport>>? future) =>
      SizedBox(
        width: 210,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<ResultPage<FieldReport>>(
              future: future,
              builder: (context, data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(
                    data.hasError
                        ? 'Unavailable'
                        : data.hasData
                        ? '${data.data!.totalItems}'
                        : '...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  ({IconData icon, String title, String subtitle}) _action(
    OperationAction action, {
    required bool community,
  }) => switch (action) {
    OperationAction.reportConflict => (
      icon: Icons.campaign_outlined,
      title: 'Report sighting or crop damage',
      subtitle: 'Share wildlife activity near your village',
    ),
    OperationAction.communityReports => (
      icon: Icons.forum_outlined,
      title: community ? 'My reports' : 'Community reports',
      subtitle: community
          ? 'Track delivery and officer responses'
          : 'Review sightings and crop-raiding reports',
    ),
    OperationAction.incidents => (
      icon: Icons.report_problem_outlined,
      title: 'Field incidents',
      subtitle: 'Review ranger evidence and locations',
    ),
    OperationAction.alerts => (
      icon: Icons.notifications_active_outlined,
      title: 'Conflict alerts',
      subtitle: 'View and respond to high-risk wildlife alerts',
    ),
    OperationAction.analytics => (
      icon: Icons.analytics_outlined,
      title: 'Analytics & reports',
      subtitle: 'Explore trends, coverage and export PDF reports',
    ),
    OperationAction.cameras => (
      icon: Icons.camera_outdoor_outlined,
      title: 'Camera traps',
      subtitle: 'Review species and possible poacher sightings',
    ),
    OperationAction.addStaff => (
      icon: Icons.person_add_alt,
      title: 'Add staff',
      subtitle: 'Create ranger, liaison and researcher accounts',
    ),
    OperationAction.addPark => (
      icon: Icons.park_outlined,
      title: 'Add park',
      subtitle: 'Configure a park and its areas',
    ),
    OperationAction.assignPatrol => (
      icon: Icons.route_outlined,
      title: 'Assign patrol',
      subtitle: 'Assign a route to a ranger',
    ),
    OperationAction.rangers => (
      icon: Icons.groups_outlined,
      title: 'Track rangers',
      subtitle: 'Review ranger patrol activity',
    ),
    OperationAction.myPatrols => (
      icon: Icons.directions_walk,
      title: 'My patrols',
      subtitle: 'View your assigned routes',
    ),
    OperationAction.reportIncident => (
      icon: Icons.add_location_alt_outlined,
      title: 'Report incident',
      subtitle: 'Record a photo, GPS location and description',
    ),
    OperationAction.outbox => (
      icon: Icons.cloud_upload_outlined,
      title: 'Pending sync',
      subtitle: 'Review field reports saved on this device',
    ),
  };
}
