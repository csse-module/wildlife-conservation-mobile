import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'completed_patrol_map_screen.dart';

class RangerDetailsScreen extends StatefulWidget {
  final String rangerId;
  final String rangerName;
  final ApiService? apiService;

  const RangerDetailsScreen({
    super.key,
    required this.rangerId,
    required this.rangerName,
    this.apiService,
  });

  @override
  State<RangerDetailsScreen> createState() => _RangerDetailsScreenState();
}

class _RangerDetailsScreenState extends State<RangerDetailsScreen> with SingleTickerProviderStateMixin {
  late final ApiService _apiService = widget.apiService ?? ApiService();
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
    try {
      List<dynamic> allPatrols = [];
      int patrolPage = 0;
      int patrolTotalPages = 1;
      while (patrolPage < patrolTotalPages && patrolPage < 5) {
        final patrolResp = await _apiService.get('/patrols?page=$patrolPage&size=100');
        if (patrolResp.statusCode == 200) {
          final data = jsonDecode(patrolResp.body);
          final items = data['data']?['items'] as List<dynamic>? ?? [];
          allPatrols.addAll(items);
          patrolTotalPages = (data['data']?['totalPages'] as num?)?.toInt() ?? 1;
          patrolPage++;
        } else {
          break;
        }
      }
      _patrols = allPatrols.where((p) => p['rangerId'] == widget.rangerId).toList();

      List<dynamic> allIncidents = [];
      int incidentPage = 0;
      int incidentTotalPages = 1;
      while (incidentPage < incidentTotalPages && incidentPage < 5) {
        final incidentResp = await _apiService.get('/incidents?page=$incidentPage&size=100');
        if (incidentResp.statusCode == 200) {
          final data = jsonDecode(incidentResp.body);
          final items = data['data']?['items'] as List<dynamic>? ?? [];
          allIncidents.addAll(items);
          incidentTotalPages = (data['data']?['totalPages'] as num?)?.toInt() ?? 1;
          incidentPage++;
        } else {
          break;
        }
      }
      _incidents = allIncidents.where((i) => i['reportedBy'] == widget.rangerId).toList();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchRangerData,
          ),
        ],
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
    if (_patrols.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRangerData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No completed patrols.')),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchRangerData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _patrols.length,
        itemBuilder: (context, index) {
          final patrol = _patrols[index];
          final endedAtStr = patrol['endedAt'];
          final date = endedAtStr != null ? DateTime.parse(endedAtStr).toLocal() : DateTime.now();
          final distanceMeters = (patrol['recordedDistanceMeters'] as num?)?.toDouble() ?? 0.0;
          final distanceKm = distanceMeters / 1000.0;
          final waypointCount = patrol['waypointCount'] ?? 0;
          final sightingCount = patrol['observationCount'] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.map, color: Colors.white)),
              title: Text('Patrol on ${date.day}/${date.month}/${date.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Distance: ${distanceKm.toStringAsFixed(2)} km\nWaypoints: $waypointCount | Sightings: $sightingCount'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CompletedPatrolMapScreen(patrolId: patrol['id'] ?? '')),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncidentsList() {
    if (_incidents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchRangerData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No incidents reported.')),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchRangerData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _incidents.length,
        itemBuilder: (context, index) {
          final incident = _incidents[index];
          final detectedAtStr = incident['detectedAt'];
          final date = detectedAtStr != null ? DateTime.parse(detectedAtStr).toLocal() : DateTime.now();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
              title: Text((incident['type'] ?? 'UNKNOWN').toString().replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${incident['description'] ?? 'No description'}\nOn: ${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
