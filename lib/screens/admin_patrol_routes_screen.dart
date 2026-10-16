import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../features/operations/domain/models.dart';
import '../features/operations/domain/repositories.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class AdminPatrolRoutesScreen extends StatefulWidget {
  final String? parkId;
  const AdminPatrolRoutesScreen({super.key, this.parkId});

  @override
  State<AdminPatrolRoutesScreen> createState() => _AdminPatrolRoutesScreenState();
}

class _AdminPatrolRoutesScreenState extends State<AdminPatrolRoutesScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  List<ParkInfo> _parks = [];
  String? _selectedParkId;
  String? _selectedAreaId;
  bool _loading = true;
  bool _saving = false;

  final List<LatLng> _points = [];
  List<Map<String, dynamic>> _existingRoutes = [];
  bool _loadingRoutes = false;

  @override
  void initState() {
    super.initState();
    _selectedParkId = widget.parkId;
    _initData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      final parks = await context.read<ParkRepository>().list();
      if (!mounted) return;
      _parks = parks;
      if (_parks.isNotEmpty) {
        _selectedParkId ??= _parks.first.id;
        _updateSelectedArea();
        await _fetchExistingRoutes();
      }
    } catch (e) {
      debugPrint('Error loading parks: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateSelectedArea() {
    final park = _parks.where((p) => p.id == _selectedParkId).firstOrNull;
    if (park != null && park.areas.isNotEmpty) {
      _selectedAreaId = park.areas.first.id;
    } else {
      _selectedAreaId = null;
    }
  }

  Future<void> _fetchExistingRoutes() async {
    if (_selectedParkId == null) return;
    setState(() => _loadingRoutes = true);
    try {
      final resp = await _apiService.get('/patrol-routes?parkId=$_selectedParkId');
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final data = body['data'];
        final items = data is Map ? (data['items'] as List<dynamic>? ?? []) : (data as List<dynamic>? ?? []);
        setState(() {
          _existingRoutes = items.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error fetching existing routes: $e');
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  double _calculateDistanceMeters() {
    if (_points.length < 2) return 0.0;
    const distance = Distance();
    double total = 0.0;
    for (int i = 0; i < _points.length - 1; i++) {
      total += distance.as(LengthUnit.Meter, _points[i], _points[i + 1]);
    }
    return total;
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    setState(() {
      _points.add(point);
    });
  }

  void _undoPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
    });
  }

  void _loadExistingRouteOnMap(Map<String, dynamic> route) {
    final rawPoints = route['pathPoints'] as List<dynamic>? ?? [];
    if (rawPoints.isEmpty) return;

    setState(() {
      _points.clear();
      for (final p in rawPoints) {
        _points.add(LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        ));
      }
      _nameController.text = route['name'] ?? '';
      _selectedAreaId = route['areaId'];
    });

    if (_points.isNotEmpty) {
      _mapController.move(_points.first, 14.0);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Displaying route "${route['name']}" on map.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedParkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a park first.')),
      );
      return;
    }

    if (_points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap at least 2 points on the map to define the route path.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final distance = _calculateDistanceMeters();
      final body = {
        'parkId': _selectedParkId,
        'areaId': _selectedAreaId,
        'name': _nameController.text.trim(),
        'plannedDistanceMeters': distance,
        'pathPoints': _points.map((p) => {
          'latitude': p.latitude,
          'longitude': p.longitude,
        }).toList(),
      };

      final response = await _apiService.post('/patrol-routes', body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patrol route created successfully!'),
            backgroundColor: AppConstants.primaryGreen,
          ),
        );
        _nameController.clear();
        _clearPoints();
        await _fetchExistingRoutes();
      } else {
        final err = jsonDecode(response.body);
        final msg = err['message'] ?? err['description'] ?? 'Failed to save patrol route.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patrol Routes'),
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedPark = _parks.where((p) => p.id == _selectedParkId).firstOrNull;
    final areas = selectedPark?.areas ?? [];
    final distanceKm = (_calculateDistanceMeters() / 1000).toStringAsFixed(2);

    // Initial map center
    final LatLng initialCenter = _points.isNotEmpty
        ? _points.first
        : const LatLng(6.37, 81.38); // Default near Yala National Park

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrol Routes'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh routes',
            onPressed: _fetchExistingRoutes,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Park & Route Form
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Park Selector Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedParkId,
                      decoration: const InputDecoration(
                        labelText: 'Park',
                        prefixIcon: Icon(Icons.park_outlined, color: AppConstants.primaryGreen),
                        border: OutlineInputBorder(),
                      ),
                      items: _parks.map((park) {
                        return DropdownMenuItem(
                          value: park.id,
                          child: Text(park.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedParkId = val;
                          _updateSelectedArea();
                          _clearPoints();
                        });
                        _fetchExistingRoutes();
                      },
                      validator: (v) => v == null ? 'Please select a park' : null,
                    ),
                    const SizedBox(height: 12),

                    // Area Selector Dropdown (if areas exist)
                    if (areas.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: areas.any((a) => a.id == _selectedAreaId) ? _selectedAreaId : areas.first.id,
                        decoration: const InputDecoration(
                          labelText: 'Park Area',
                          prefixIcon: Icon(Icons.map_outlined, color: AppConstants.primaryGreen),
                          border: OutlineInputBorder(),
                        ),
                        items: areas.map((area) {
                          return DropdownMenuItem(
                            value: area.id,
                            child: Text(area.name),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAreaId = val),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Route Name Input
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Route Name',
                        hintText: 'e.g., North Boundary Perimeter Trail',
                        prefixIcon: Icon(Icons.edit_road, color: AppConstants.primaryGreen),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Please enter a route name' : null,
                    ),
                  ],
                ),
              ),
            ),

            // Map Header & Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 20, color: AppConstants.primaryGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tap on map to plot route waypoints',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_points.length} points · $distanceKm km',
                      style: const TextStyle(
                        color: AppConstants.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Interactive Route Map
            Container(
              height: 320,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: 13.0,
                      onTap: _onMapTapped,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.wildlife.wildlife_conservation_mobile',
                      ),
                      if (_points.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _points,
                              color: AppConstants.primaryGreen,
                              strokeWidth: 4.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (int i = 0; i < _points.length; i++)
                            Marker(
                              point: _points[i],
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? Colors.green
                                      : (i == _points.length - 1 ? Colors.red : Colors.blue),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Map toolbar (Undo, Clear)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'undo_point',
                          onPressed: _points.isEmpty ? null : _undoPoint,
                          tooltip: 'Undo last point',
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.undo, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'clear_points',
                          onPressed: _points.isEmpty ? null : _clearPoints,
                          tooltip: 'Clear route',
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveRoute,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving route…' : 'Save Patrol Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            // Existing Routes Section
            const Divider(thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Existing Patrol Routes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_loadingRoutes)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            if (_existingRoutes.isEmpty && !_loadingRoutes)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No patrol routes configured for this park yet.'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingRoutes.length,
                itemBuilder: (context, index) {
                  final route = _existingRoutes[index];
                  final name = route['name'] ?? 'Route ${index + 1}';
                  final distanceM = (route['plannedDistanceMeters'] as num?)?.toDouble() ?? 0.0;
                  final distanceKmStr = (distanceM / 1000).toStringAsFixed(2);
                  final points = route['pathPoints'] as List<dynamic>? ?? [];

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.alt_route, color: AppConstants.primaryGreen),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('$distanceKmStr km · ${points.length} waypoints'),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('View'),
                        onPressed: () => _loadExistingRouteOnMap(route),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
