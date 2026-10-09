import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/patrol_provider.dart';
import '../utils/constants.dart';
import 'active_patrol_screen.dart';

class MyPatrolsScreen extends StatefulWidget {
  const MyPatrolsScreen({Key? key}) : super(key: key);

  @override
  State<MyPatrolsScreen> createState() => _MyPatrolsScreenState();
}

class _MyPatrolsScreenState extends State<MyPatrolsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _assignments = [];
  Map<String, List<LatLng>> _routesCache = {};

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/patrol-assignments');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data']['items'] ?? [];
        setState(() {
          _assignments = items;
        });
        
        // Fetch route details for each assignment
        for (var assignment in _assignments) {
          final routeId = assignment['routeId'];
          if (routeId != null && !_routesCache.containsKey(routeId)) {
            _fetchRoute(routeId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching assignments: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchRoute(String routeId) async {
    try {
      final response = await _apiService.get('/patrol-routes/$routeId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pathPoints = data['data']['pathPoints'] as List<dynamic>? ?? [];
        List<LatLng> points = [];
        for (var p in pathPoints) {
          points.add(LatLng(p['latitude'], p['longitude']));
        }
        if (mounted) {
          setState(() {
            _routesCache[routeId] = points;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('My Assigned Patrols'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
              ? const Center(child: Text('No assigned patrols at this time.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    final routeId = assignment['routeId'];
                    final points = _routesCache[routeId];
                    final date = DateTime.parse(assignment['scheduledStartAt']).toLocal();

                    final activePatrolId = context.watch<PatrolProvider>().activeAssignmentId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              color: Colors.grey[200],
                            ),
                            child: points == null
                                ? const Center(child: CircularProgressIndicator())
                                : points.isEmpty
                                    ? const Center(child: Text('Route has no coordinates'))
                                    : ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: FlutterMap(
                                          options: MapOptions(
                                            initialCenter: points.first,
                                            initialZoom: 15,
                                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              userAgentPackageName: 'com.example.wildlife_conservation_mobile',
                                            ),
                                            if (points.length == 1)
                                              MarkerLayer(
                                                markers: [
                                                  Marker(
                                                    point: points.first,
                                                    child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                                                  ),
                                                ],
                                              )
                                            else
                                              PolylineLayer(
                                                polylines: [
                                                  Polyline(points: points, color: Colors.blue, strokeWidth: 4.0),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Scheduled: ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: (activePatrolId != null && activePatrolId != assignment['id']) ? null : () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ActivePatrolScreen(
                                          assignmentId: assignment['id'],
                                          plannedRoute: points ?? [],
                                        ),
                                      ),
                                    );
                                    // Refresh list when returned
                                    _fetchAssignments();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: (activePatrolId != null && activePatrolId != assignment['id']) ? Colors.grey : AppConstants.primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(activePatrolId == assignment['id'] ? 'Resume Patrol' : 'Confirm & Start', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
