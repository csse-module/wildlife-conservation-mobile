import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../services/db_helper.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class IncidentProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  String? _errorMessage;
  int _pendingReports = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pendingReports => _pendingReports;

  IncidentProvider(this.authProvider) {
    _loadPendingCount();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (result.isNotEmpty && result.first != ConnectivityResult.none) {
        _syncPendingIncidents();
      }
    });
  }

  Future<void> _loadPendingCount() async {
    final pendingList = await DBHelper.instance.getTasks();
    _pendingReports = pendingList.where((task) => task['type'] == 'INCIDENT').length;
    notifyListeners();
  }

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Location services are disabled.';
      notifyListeners();
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permissions are denied';
        notifyListeners();
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permissions are permanently denied.';
      notifyListeners();
      return null;
    } 

    try {
      // High accuracy can be slow/fail if signal is weak, we try briefly
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      // If signal is weak, fallback to manual or last known
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<bool> reportIncident({
    required String type,
    required double lat,
    required double lng,
    required String description,
    String? localImagePath, // Will upload to supabase later
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final connectivityResult = await (Connectivity().checkConnectivity());
    final hasInternet = connectivityResult.isNotEmpty && connectivityResult.first != ConnectivityResult.none;

    final reportData = {
      'id': const Uuid().v4(),
      'type': type,
      'latitude': lat,
      'longitude': lng,
      'description': description,
      'imagePath': localImagePath ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (hasInternet) {
      // Try to send immediately
      final success = await _sendToServer(reportData);
      if (success) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    }
    
    // If no internet or send failed, save locally
    await _saveLocally(reportData);
    _isLoading = false;
    notifyListeners();
    return true; // Return true because it is safely stored
  }

  Future<void> _saveLocally(Map<String, dynamic> data) async {
    // Add mapping for DBHelper
    await DBHelper.instance.insertTask({
      'type': 'INCIDENT',
      'url': '/incidents/${data['id']}',
      'method': 'PUT',
      'body': jsonEncode({
        'type': data['type'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'description': data['description'],
        'imageUrl': '', // Supabase will be uploaded during sync
      }),
      'imagePath': data['imagePath'],
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _loadPendingCount();
  }

  Future<bool> _sendToServer(Map<String, dynamic> data) async {
    try {
      if (!authProvider.isAuthenticated) return false;

      String uploadedUrl = '';
      
      // Upload image to Supabase
      if (data['imagePath'] != null && data['imagePath'].toString().isNotEmpty) {
        final File imageFile = File(data['imagePath']);
        if (await imageFile.exists()) {
          final bucketName = dotenv.env['SUPABASE_BUCKET_NAME'] ?? 'CSSE';
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${data['id']}.jpg';
          
          await Supabase.instance.client.storage
              .from(bucketName)
              .upload(fileName, imageFile);
              
          uploadedUrl = Supabase.instance.client.storage
              .from(bucketName)
              .getPublicUrl(fileName);
        }
      }

      final response = await _apiService.put('/incidents/${data['id']}', {
        'type': data['type'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'description': data['description'],
        'imageUrl': uploadedUrl,
      });

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _syncPendingIncidents() async {
    // Handled by SyncScreen now.
  }
}
