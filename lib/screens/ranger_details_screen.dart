import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'completed_patrol_map_screen.dart';

class RangerDetailsScreen extends StatefulWidget {
  final String rangerId;
  final String rangerName;

  const RangerDetailsScreen({Key? key, required this.rangerId, required this.rangerName}) : super(key: key);

  @override
  State<RangerDetailsScreen> createState() => _RangerDetailsScreenState();
}

class _RangerDetailsScreenState extends State<RangerDetailsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  bool _isLoading = true;
  List<dynamic> _patrols = [];
  List<dynamic> _incidents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRangerData();
  }

  Future<void> _fetchDataForUser() async {
    // We fetch all records and filter client side since backend doesn't support rangerId filter for Admin
    try {
      final patrolResp = await _apiService.get('/patrols?size=500');
      if (patrolResp.statusCode == 200) {
        final data = jsonDecode(patrolResp.body);
        final allPatrols = data['data']['items'] ?? [];
        _patrols = allPatrols.where((p) => p['rangerId'] == widget.rangerId).toList();
      }

      final incidentResp = await _apiService.get('/incidents?size=500');
      if (incidentResp.statusCode == 200) {
        final data = jsonDecode(incidentResp.body);
        final allIncidents = data['data']['items'] ?? [];
        _incidents = allIncidents.where((i) => i['reportedBy'] == widget.rangerId).toList();
      }
    } catch (e) {
      debugPrint('Error fetching ranger details: $e');
    }
  }

  Future<void> _fetchRangerData() async {
    setState(() => _isLoading = true);
    await _fetchDataForUser();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: Text(widget.rangerName),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Completed Patrols'),
            Tab(text: 'Reported Incidents'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPatrolsList(),
                _buildIncidentsList(),
              ],
            ),
    );
  }

  Widget _buildPatrolsList() {
    if (_patrols.isEmpty) return const Center(child: Text('No completed patrols.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patrols.length,
      itemBuilder: (context, index) {
        final patrol = _patrols[index];
        final date = DateTime.parse(patrol['endedAt']).toLocal();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.map, color: Colors.white)),
            title: Text('Patrol on ${date.day}/${date.month}/${date.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Distance: ${(patrol['recordedDistanceMeters'] / 1000).toStringAsFixed(2)} km\nWaypoints: ${patrol['waypointCount']} | Sightings: ${patrol['observationCount']}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CompletedPatrolMapScreen(patrolId: patrol['id'])),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildIncidentsList() {
    if (_incidents.isEmpty) return const Center(child: Text('No incidents reported.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _incidents.length,
      itemBuilder: (context, index) {
        final incident = _incidents[index];
        final date = DateTime.parse(incident['detectedAt']).toLocal();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
            title: Text((incident['type'] ?? 'UNKNOWN').toString().replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${incident['description'] ?? 'No description'}\nOn: ${date.day}/${date.month}/${date.year}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
