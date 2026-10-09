import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';

class AdminProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Add Staff Method
  Future<bool> addStaff({
    required String name,
    required String email,
    required String temporaryPassword,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/users', {
        'name': name,
        'email': email,
        'temporaryPassword': temporaryPassword,
        'role': role,
        'parkIds': [], // Sent as empty array since parks are allocated later
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        if (data['error'] != null && data['error']['errorDescription'] != null) {
          _errorMessage = data['error']['errorDescription'];
          
          if (data['error']['fieldErrors'] != null) {
            final Map<String, dynamic> fieldErrors = data['error']['fieldErrors'];
            if (fieldErrors.isNotEmpty) {
               _errorMessage = '$_errorMessage (${fieldErrors.values.first})';
            }
          }
        } else {
          _errorMessage = data['description'] ?? 'Failed to add staff.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'A network error occurred while adding staff.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Add Park Method
  Future<bool> addPark({
    required String id,
    required String name,
    required String timezone,
    required List<Map<String, String>> areas,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/parks', {
        'id': id,
        'name': name,
        'timezone': timezone,
        'areas': areas,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        if (data['error'] != null && data['error']['errorDescription'] != null) {
          _errorMessage = data['error']['errorDescription'];
          if (data['error']['fieldErrors'] != null) {
            final Map<String, dynamic> fieldErrors = data['error']['fieldErrors'];
            if (fieldErrors.isNotEmpty) {
               _errorMessage = '$_errorMessage (${fieldErrors.values.first})';
            }
          }
        } else {
          _errorMessage = data['description'] ?? 'Failed to add park.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'A network error occurred while adding park.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch Rangers Method
  Future<List<Map<String, String>>> fetchRangers() async {
    try {
      final response = await _apiService.get('/users?role=RANGER');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseData = data['data'] ?? data;
        final content = responseData['items'] as List<dynamic>? ?? [];
        
        return content.map((item) {
          return {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          };
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Assign Patrol Method
  Future<bool> assignPatrol({
    required String rangerId,
    required String routeId, // Actually GPS coordinates
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. First, create a route from the GPS coordinates
      final String routeName = "Custom Assignment ${DateTime.now().toIso8601String().substring(0, 10)}";
      
      // parse lat, lng
      List<String> parts = routeId.split(',');
      double lat = double.tryParse(parts[0].trim()) ?? 0.0;
      double lng = double.tryParse(parts[1].trim()) ?? 0.0;

      final routeResponse = await _apiService.post('/patrol-routes', {
        'parkId': '', 
        'name': routeName,
        'plannedDistanceMeters': 0,
        'pathPoints': [
          {'latitude': lat, 'longitude': lng}
        ]
      });

      String actualRouteId = routeId; // fallback
      if (routeResponse.statusCode == 201 || routeResponse.statusCode == 200) {
        final routeData = jsonDecode(routeResponse.body);
        actualRouteId = routeData['data']['id'];
      } else {
        final errData = jsonDecode(routeResponse.body);
        _errorMessage = errData['description'] ?? 'Failed to create route for assignment.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Assign Patrol
      final String assignmentId = const Uuid().v4().toLowerCase();
      
      final Map<String, dynamic> requestBody = {
        'routeId': actualRouteId,
        'rangerId': rangerId,
        'scheduledStartAt': DateTime.now().toUtc().toIso8601String(), 
        'scheduledEndAt': DateTime.now().add(const Duration(hours: 8)).toUtc().toIso8601String(),
      };
      
      debugPrint('PUT /patrol-assignments/$assignmentId');
      debugPrint('Body: ${jsonEncode(requestBody)}');

      final response = await _apiService.put('/patrol-assignments/$assignmentId', requestBody);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _errorMessage = data['description'] ?? 'Failed to assign patrol.';
        
        if (data['error'] != null) {
          _errorMessage = '$_errorMessage: ${jsonEncode(data['error'])}';
        }
        
        debugPrint('ASSIGNMENT FAILED: $_errorMessage');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'A network error occurred.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
