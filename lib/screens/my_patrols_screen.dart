import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/patrol_provider.dart';
import '../utils/constants.dart';
import 'active_patrol_screen.dart';
import 'sync_screen.dart';

class MyPatrolsScreen extends StatefulWidget {
  const MyPatrolsScreen({super.key});

  @override
  State<MyPatrolsScreen> createState() => _MyPatrolsScreenState();
}

class _MyPatrolsScreenState extends State<MyPatrolsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _assignments = [];
  final Map<String, List<LatLng>> _routesCache = {};
  final Map<String, Map<String, String>> _routeMetadataCache = {};

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

        // Auto-clear active patrol state if assignment is completed or not present
        if (mounted) {
          final patrolProvider = context.read<PatrolProvider>();
          final activeId = patrolProvider.activeAssignmentId;
          if (activeId != null) {
            final activeItem = items.cast<Map<String, dynamic>?>().firstWhere(
              (item) => item?['id'] == activeId,
              orElse: () => null,
            );
            if (activeItem == null || activeItem['status'] == 'COMPLETED') {
              await patrolProvider.clearState();
            }
          }
        }

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
        final routeData = data['data'];
        final parkId = routeData?['parkId']?.toString();
        final areaId = routeData?['areaId']?.toString();
        if (parkId != null || areaId != null) {
          _routeMetadataCache[routeId] = {
            if (parkId != null) 'parkId': parkId,
            if (areaId != null) 'areaId': areaId,
          };
        }
        final pathPoints = routeData?['pathPoints'] as List<dynamic>? ?? [];
        List<LatLng> points = [];
        for (var p in pathPoints) {
          final lat = (p['latitude'] as num?)?.toDouble();
          final lng = (p['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
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
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Sync saved patrols',
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
          ? const Center(child: Text('No assigned patrols at this time.'))
          : Builder(
              builder: (context) {
                final activePatrolId =
                    context.watch<PatrolProvider>().activeAssignmentId;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (activePatrolId != null)
                      Card(
                        color: Colors.amber.shade50,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.amber.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                color: Colors.orange,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Patrol session in progress',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'A patrol tracking session is currently active.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Reset Active Patrol?'),
                                      content: const Text(
                                        'This will clear the active patrol tracking session and allow you to start a new patrol.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Reset Session'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && mounted) {
                                    await context
                                        .read<PatrolProvider>()
                                        .clearState();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Patrol session reset. You can now start any assigned patrol.',
                                          ),
                                          backgroundColor:
                                              AppConstants.primaryGreen,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ..._assignments.map((assignment) {
                      final routeId = assignment['routeId'];
                      final points = _routesCache[routeId];
                      final startAtStr = assignment['scheduledStartAt'];
                      final date = startAtStr != null
                          ? DateTime.parse(startAtStr).toLocal()
                          : DateTime.now();
                      final isCompleted = assignment['status'] == 'COMPLETED';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                color: Colors.grey[200],
                              ),
                              child: points == null
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : points.isEmpty
                                  ? const Center(
                                      child: Text('Route has no coordinates'),
                                    )
                                  : ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: points.first,
                                          initialZoom: 15,
                                          interactionOptions:
                                              const InteractionOptions(
                                            flags: InteractiveFlag.none,
                                          ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.example.wildlife_conservation_mobile',
                                          ),
                                          if (points.length == 1)
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: points.first,
                                                  child: const Icon(
                                                    Icons.location_pin,
                                                    color: Colors.red,
                                                    size: 40,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            PolylineLayer(
                                              polylines: [
                                                Polyline(
                                                  points: points,
                                                  color: Colors.blue,
                                                  strokeWidth: 4.0,
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Scheduled: ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.green.shade300,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Completed',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (isCompleted)
                                    ElevatedButton(
                                      onPressed: null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade200,
                                        foregroundColor: Colors.grey.shade600,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Patrol Completed',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (activePatrolId != null &&
                                            activePatrolId !=
                                                assignment['id']) {
                                          final switchConfirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Switch Active Patrol?',
                                              ),
                                              content: const Text(
                                                'Another patrol session is currently recorded as active. Starting this patrol will reset the previous session. Do you want to continue?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppConstants.primaryGreen,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text(
                                                    'Start This Patrol',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (switchConfirm != true || !mounted) {
                                            return;
                                          }
                                          await context
                                              .read<PatrolProvider>()
                                              .clearState();
                                        }

                                        if (!mounted) return;
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ActivePatrolScreen(
                                              assignmentId: assignment['id'],
                                              plannedRoute: points ?? [],
                                              parkId: assignment['parkId'] ?? _routeMetadataCache[routeId]?['parkId'],
                                              areaId: _routeMetadataCache[routeId]?['areaId'],
                                            ),
                                          ),
                                        );
                                        _fetchAssignments();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppConstants.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        activePatrolId == assignment['id']
                                            ? 'Resume Patrol'
                                            : 'Confirm & Start',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}
