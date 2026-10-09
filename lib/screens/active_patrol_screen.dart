import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../providers/patrol_provider.dart';
import '../utils/constants.dart';
import '../features/operations/presentation/report_form_screen.dart';
import '../features/operations/domain/models.dart';

class ActivePatrolScreen extends StatefulWidget {
  final String assignmentId;
  final List<LatLng> plannedRoute;

  const ActivePatrolScreen({
    Key? key, 
    required this.assignmentId, 
    required this.plannedRoute
  }) : super(key: key);

  @override
  State<ActivePatrolScreen> createState() => _ActivePatrolScreenState();
}

class _ActivePatrolScreenState extends State<ActivePatrolScreen> {
  bool _isLoading = false;
  bool _isMapReady = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PatrolProvider>(context, listen: false).startPatrol(widget.assignmentId);
    });
  }

  Future<void> _endPatrol() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<PatrolProvider>(context, listen: false);
    final error = await provider.endPatrol();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patrol Completed!', style: TextStyle(color: Colors.white)), backgroundColor: AppConstants.primaryGreen));
        Navigator.pop(context, true);
      } else {
        showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Error Ending Patrol"), content: Text(error), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
      }
    }
  }

  void _markWaypoint() async {
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    // Simple dialog to get a label
    String? label = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('Mark Waypoint'),
          content: TextField(
            onChanged: (val) => input = val,
            decoration: const InputDecoration(hintText: "Enter waypoint label (e.g. Broken Fence)"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, input), child: const Text('Save')),
          ],
        );
      },
    );
    
    if (label != null && label.isNotEmpty) {
      Provider.of<PatrolProvider>(context, listen: false).markWaypoint(label, position);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waypoint marked!')));
    }
  }

  void _reportSighting() async {
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    String? sightingDetails = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('Report Sighting', style: TextStyle(color: AppConstants.primaryGreen)),
          content: TextField(
            onChanged: (val) => input = val,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Enter sighting details (e.g., Elephant herd spotted)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, input),
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryGreen, foregroundColor: Colors.white),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    
    if (sightingDetails != null && sightingDetails.isNotEmpty) {
      Provider.of<PatrolProvider>(context, listen: false).reportSighting(sightingDetails, position);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sighting Reported Successfully!'), backgroundColor: AppConstants.primaryGreen));
    }
  }
  
  void _emergencyAlert() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency Alert Triggered!'), backgroundColor: Colors.red));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatrolProvider>(
      builder: (context, patrol, child) {
        if (patrol.actualPath.isNotEmpty && _isMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _mapController.move(patrol.actualPath.last, 16.0);
              } catch (e) {
                // Ignore map controller not ready exceptions
              }
            }
          });
        }
        return Scaffold(
          backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text('GPS TRACKING ACTIVE'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt, color: AppConstants.primaryGreen),
            tooltip: 'Report Incident',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportFormScreen(
                    kind: ReportKind.incident,
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_fixed, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text('ACCURACY: HIGH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Header Stats (Elapsed Time / Distance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ELAPSED TIME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(_formatDuration(patrol.elapsedTime), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('COVERED DISTANCE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text('${patrol.coveredDistanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          // Map View
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.plannedRoute.isNotEmpty ? widget.plannedRoute.first : const LatLng(7.8731, 80.7718),
                initialZoom: 15,
                onMapReady: () {
                  if (mounted) {
                    setState(() {
                      _isMapReady = true;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.wildlife_conservation_mobile',
                ),
                // Planned Route (Grey)
                if (widget.plannedRoute.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: widget.plannedRoute, color: Colors.grey, strokeWidth: 4.0),
                    ],
                  ),
                // Actual Route (Blue)
                if (patrol.actualPath.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: patrol.actualPath, color: Colors.blue, strokeWidth: 5.0),
                    ],
                  ),
                // Waypoint Markers
                MarkerLayer(
                  markers: patrol.waypoints.map((wp) {
                    return Marker(
                      point: LatLng(wp['location']['latitude'], wp['location']['longitude']),
                      child: const Icon(Icons.location_on, color: Colors.orange, size: 30),
                    );
                  }).toList(),
                ),
                // Current Location Marker
                if (patrol.actualPath.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: patrol.actualPath.last,
                        child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Bottom Controls (4 Buttons grid)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reportSighting,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Report Sighting'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: AppConstants.primaryGreen,
                          side: const BorderSide(color: AppConstants.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _markWaypoint,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Mark Waypoint'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: AppConstants.primaryGreen,
                          side: const BorderSide(color: AppConstants.primaryGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _emergencyAlert,
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        label: const Text('Emergency Alert', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _endPatrol,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('End Patrol'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppConstants.primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
        );
      }
    );
  }
}
