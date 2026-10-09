import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';

class PatrolProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  String? _activeAssignmentId;
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  double _coveredDistanceKm = 0.0;
  
  List<LatLng> _actualPath = [];
  List<Map<String, dynamic>> _trackPoints = [];
  List<Map<String, dynamic>> _waypoints = [];
  List<Map<String, dynamic>> _observations = [];
  
  StreamSubscription<Position>? _positionStreamSubscription;

  bool get isTracking => _activeAssignmentId != null;
  String? get activeAssignmentId => _activeAssignmentId;
  Duration get elapsedTime => _elapsedTime;
  double get coveredDistanceKm => _coveredDistanceKm;
  List<LatLng> get actualPath => _actualPath;
  List<Map<String, dynamic>> get waypoints => _waypoints;

  Future<void> startPatrol(String assignmentId) async {
    if (_activeAssignmentId != null) return;
    
    _activeAssignmentId = assignmentId;
    _startTime = DateTime.now();
    _elapsedTime = Duration.zero;
    _coveredDistanceKm = 0.0;
    _actualPath.clear();
    _trackPoints.clear();
    _waypoints.clear();
    _observations.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_patrol_id', assignmentId);
    await prefs.setString('active_patrol_start_time', _startTime!.toUtc().toIso8601String());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTime = DateTime.now().difference(_startTime!);
      notifyListeners();
    });

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final newPoint = LatLng(position.latitude, position.longitude);
        
        if (_actualPath.isNotEmpty) {
          final lastPoint = _actualPath.last;
          final distanceInMeters = Geolocator.distanceBetween(
            lastPoint.latitude, lastPoint.longitude,
            newPoint.latitude, newPoint.longitude,
          );
          _coveredDistanceKm += (distanceInMeters / 1000);
        }

        _actualPath.add(newPoint);
        _trackPoints.add({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'recordedAt': DateTime.now().toUtc().toIso8601String(),
          'accuracyMeters': position.accuracy,
        });
        
        notifyListeners();
      }
    );
    notifyListeners();
  }

  void markWaypoint(String label, Position position) {
    _waypoints.add({
      'id': const Uuid().v4().toLowerCase(),
      'label': label,
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'location': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'notes': 'Manual Waypoint',
    });
    notifyListeners();
  }

  void reportSighting(String details, Position position) {
    _observations.add({
      'id': const Uuid().v4().toLowerCase(),
      'text': details,
      'observedAt': DateTime.now().toUtc().toIso8601String(),
      'location': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      }
    });
    notifyListeners();
  }

  Future<String?> endPatrol() async {
    if (_activeAssignmentId == null) return "No active patrol.";
    
    // We intentionally do NOT cancel the timer and stream here.
    // They will continue running in case the backend rejects the end patrol request.
    
    try {
      var endTime = DateTime.now();
      // FIX: Ensure endTime is strictly after startTime even if they double-clicked quickly.
      if (endTime.isBefore(_startTime!.add(const Duration(seconds: 2)))) {
        endTime = _startTime!.add(const Duration(seconds: 2));
      }
      
      final Map<String, dynamic> requestBody = {
        'assignmentId': _activeAssignmentId,
        'startedAt': _startTime!.toUtc().toIso8601String(),
        'endedAt': endTime.toUtc().toIso8601String(),
        'trackPoints': _trackPoints,
        'waypoints': _waypoints,
        'observations': _observations,
      };

      final connectivityResult = await (Connectivity().checkConnectivity());
      final hasInternet = connectivityResult.isNotEmpty && connectivityResult.first != ConnectivityResult.none;

      if (!hasInternet) {
        await DBHelper.instance.insertTask({
          'type': 'PATROL',
          'url': '/patrols/$_activeAssignmentId',
          'method': 'PUT',
          'body': jsonEncode(requestBody),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        await _clearState();
        return null; // Null means success
      }

      final response = await _apiService.put('/patrols/$_activeAssignmentId', requestBody);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _clearState();
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        String errorMsg = data['description'] ?? 'Failed to end patrol.';
        if (data['error'] != null) {
          final errData = data['error'];
          if (errData['errorDescription'] != null) {
             errorMsg += ' - ${errData['errorDescription']}';
          }
          if (errData['fieldErrors'] != null && (errData['fieldErrors'] as Map).isNotEmpty) {
             errorMsg += ' (${jsonEncode(errData['fieldErrors'])})';
          }
        }
        return "FAIL: $errorMsg \nRaw Response: ${response.body}"; // Detailed failure message
      }
    } catch (e) {
      return "Network error: $e";
    }
  }
  
  Future<void> _clearState() async {
    _activeAssignmentId = null;
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_patrol_id');
    await prefs.remove('active_patrol_start_time');
    notifyListeners();
  }
}
