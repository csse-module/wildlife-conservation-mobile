import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class CompletedPatrolMapScreen extends StatefulWidget {
  final String patrolId;

  const CompletedPatrolMapScreen({super.key, required this.patrolId});

  @override
  State<CompletedPatrolMapScreen> createState() => _CompletedPatrolMapScreenState();
}

class _CompletedPatrolMapScreenState extends State<CompletedPatrolMapScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  
  List<LatLng> _trackPoints = [];
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _fetchPatrolDetails();
  }

  Future<void> _fetchPatrolDetails() async {
    try {
      final response = await _apiService.get('/patrols/${widget.patrolId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        
        final rawTrackPoints = data['trackPoints'] as List<dynamic>? ?? [];
        _trackPoints = rawTrackPoints.map((tp) => LatLng(tp['latitude'], tp['longitude'])).toList();

        final rawWaypoints = data['waypoints'] as List<dynamic>? ?? [];
        for (var wp in rawWaypoints) {
          _markers.add(
            Marker(
              point: LatLng(wp['location']['latitude'], wp['location']['longitude']),
              child: const Icon(Icons.location_on, color: Colors.orange, size: 30),
            )
          );
        }

        final rawObservations = data['observations'] as List<dynamic>? ?? [];
        for (var obs in rawObservations) {
          _markers.add(
            Marker(
              point: LatLng(obs['location']['latitude'], obs['location']['longitude']),
              child: const Icon(Icons.visibility, color: Colors.purple, size: 30),
            )
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching patrol details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrol Route'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _trackPoints.isEmpty
            ? const Center(child: Text('No GPS track recorded for this patrol.'))
            : FlutterMap(
                options: MapOptions(
                  initialCenter: _trackPoints.first,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.wildlife_conservation_mobile',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(points: _trackPoints, color: Colors.blue, strokeWidth: 5.0),
                    ],
                  ),
                  MarkerLayer(markers: _markers),
                ],
              ),
    );
  }
}
