import 'dart:convert';
import 'package:flutter/material.dart';
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
    required List<String> parkIds,
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
        'parkIds': parkIds,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        if (data['error'] != null &&
            data['error']['errorDescription'] != null) {
          _errorMessage = data['error']['errorDescription'];

          if (data['error']['fieldErrors'] != null) {
            final Map<String, dynamic> fieldErrors =
                data['error']['fieldErrors'];
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
        if (data['error'] != null &&
            data['error']['errorDescription'] != null) {
          _errorMessage = data['error']['errorDescription'];
          if (data['error']['fieldErrors'] != null) {
            final Map<String, dynamic> fieldErrors =
                data['error']['fieldErrors'];
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
}
